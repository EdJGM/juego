# cliente.gd - CON FSM IMPLEMENTADA
extends CharacterBody3D

# Señales (mantener las existentes)
signal cliente_se_fue(cliente)
signal pedido_entregado(cliente, pedido)

# ========== NUEVO: SISTEMA FSM ==========
enum EstadoCliente {
	ENTRANDO,           # Cliente entra al restaurante
	EN_RECIBIDOR,       # Cliente espera en el recibidor
	ESPERANDO_ATENCION, # Espera a que el jugador tome su orden (en recibidor)
	YENDO_A_MESA,       # Va hacia la mesa asignada después de ordenar
	ESPERANDO_COMIDA,   # Espera en la mesa a que le traigan la comida
	COMIENDO,           # Come la comida (opcional)
	PAGANDO,            # Paga la cuenta
	SALIENDO_FELIZ,     # Sale satisfecho
	SALIENDO_ENOJADO    # Sale molesto
}

var estado_actual: EstadoCliente = EstadoCliente.ENTRANDO
var tiempo_en_estado: float = 0.0
var mesa_asignada: Node3D = null

# Posiciones importantes del restaurante
var posicion_recibidor: Vector3 = Vector3(0, 0.5, 0.294)  # Misma Y y Z que la entrada
var posicion_entrada: Vector3 = Vector3(-10, 0.5, 0.294)
var en_recibidor: bool = false

# Configuración de personalidad del cliente
var tipo_cliente: String = "normal"  # "rapido", "paciente", "exigente"
var modificador_paciencia: float = 1.0
var velocidad_base: float = 1.5

# ========== VARIABLES EXISTENTES (modificadas) ==========
var pedido_asignado: Dictionary = {}
var tiempo_espera_restante: float = 0.0
var pedido_realizado: bool = false

# Variables de movimiento (actualizadas)
@export var velocidad_salida := 2.0
@export var tiempo_giro := 0.5
var tiempo_girado := 0.0
var rotacion_inicial: float
var rotacion_final: float
var objetivo_movimiento: Vector3

# Referencias a nodos (mantener existentes)
@onready var animation_player: AnimationPlayer = $"character-female-b2/AnimationPlayer"
@onready var barra_paciencia: ProgressBar = $CanvasLayer/ProgressBar

# Referencias al sistema
var game_manager: Node

func _ready():
	print("Cliente FSM inicializando...")

	# Configuración inicial (mantener existente)
	game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		print("ERROR: GameManager no encontrado en cliente")
	else:
		print("✓ Cliente conectado al GameManager")
	
	# Agregar al grupo de clientes
	add_to_group("clientes")
	
	# NUEVO: Configurar tipo de cliente aleatorio
	inicializar_tipo_cliente()
	
	# DEBUG: Mostrar posición inicial
	global_position = posicion_entrada
	print("DEBUG - Posición inicial del cliente: ", global_position)
	print("DEBUG - Rotación inicial: ", rotation_degrees)
	
	# Configurar animación inicial
	if animation_player:
		animation_player.play("idle")
		print("✓ Animación inicial configurada")
	
	# Configurar barra de paciencia
	if barra_paciencia:
		barra_paciencia.value = 100
		barra_paciencia.modulate = Color.GREEN
		print("✓ Barra de paciencia configurada")
	
	# NUEVO: Iniciar FSM
	cambiar_estado(EstadoCliente.ENTRANDO)
	print("Cliente FSM inicializado correctamente")

# ========== NUEVO: SISTEMA FSM PRINCIPAL ==========
func _process(delta):
	tiempo_en_estado += delta
	
	# Procesar estado actual
	match estado_actual:
		EstadoCliente.ENTRANDO:
			procesar_estado_entrando(delta)
		EstadoCliente.EN_RECIBIDOR:
			procesar_estado_en_recibidor(delta)
		EstadoCliente.ESPERANDO_ATENCION:
			procesar_estado_esperando_atencion(delta)
		EstadoCliente.YENDO_A_MESA:
			procesar_estado_yendo_a_mesa(delta)
		EstadoCliente.ESPERANDO_COMIDA:
			procesar_estado_esperando_comida(delta)
		EstadoCliente.COMIENDO:
			procesar_estado_comiendo(delta)
		EstadoCliente.PAGANDO:
			procesar_estado_pagando(delta)
		EstadoCliente.SALIENDO_FELIZ:
			procesar_estado_saliendo_feliz(delta)
		EstadoCliente.SALIENDO_ENOJADO:
			procesar_estado_saliendo_enojado(delta)
	
	# Actualizar UI (mantener funcionalidad existente)
	actualizar_ui_posicion()

func cambiar_estado(nuevo_estado: EstadoCliente):
	# Salir del estado actual
	salir_estado(estado_actual)
	
	# Cambiar al nuevo estado
	var estado_anterior = estado_actual
	estado_actual = nuevo_estado
	tiempo_en_estado = 0.0
	
	# Entrar al nuevo estado
	entrar_estado(nuevo_estado)
	
	print("Cliente ", name, " cambió de ", EstadoCliente.keys()[estado_anterior], " a ", EstadoCliente.keys()[nuevo_estado])

func salir_estado(estado: EstadoCliente):
	match estado:
		EstadoCliente.EN_RECIBIDOR:
			en_recibidor = false
		EstadoCliente.ESPERANDO_ATENCION:
			# Reservar mesa cuando se toma la orden
			if not mesa_asignada:
				mesa_asignada = buscar_mesa_libre()

func entrar_estado(estado: EstadoCliente):
	match estado:
		EstadoCliente.ENTRANDO:
			objetivo_movimiento = posicion_recibidor
		EstadoCliente.EN_RECIBIDOR:
			en_recibidor = true
			# Generar pedido cuando llega al recibidor
			generar_pedido_segun_tipo()
			mostrar_indicador_estado("📋 Esperando mesero")
		EstadoCliente.ESPERANDO_ATENCION:
			mostrar_indicador_estado("🙋‍♂️ Listo para ordenar")
		EstadoCliente.YENDO_A_MESA:
			if mesa_asignada:
				objetivo_movimiento = mesa_asignada.global_position
				objetivo_movimiento.x += 1.5
				objetivo_movimiento.y = 0.7
				objetivo_movimiento.z += 0.0
				mostrar_indicador_estado("🚶‍♂️ Yendo a mesa")
				print("DEBUG - Objetivo mesa: ", objetivo_movimiento, " Mesa: ", mesa_asignada.name)
			else:
					print("ERROR: No hay mesa asignada")
		EstadoCliente.ESPERANDO_COMIDA:
			mostrar_indicador_estado("⏰ Esperando comida")
		EstadoCliente.COMIENDO:
			mostrar_indicador_estado("🍽️ Disfrutando")
		EstadoCliente.SALIENDO_FELIZ:
			mostrar_indicador_estado("😊 ¡Gracias!")
			objetivo_movimiento = posicion_entrada
		EstadoCliente.SALIENDO_ENOJADO:
			mostrar_indicador_estado("😠 ¡Qué servicio!")
			objetivo_movimiento = posicion_entrada

# ========== NUEVO: IMPLEMENTACIÓN DE ESTADOS ==========
func procesar_estado_entrando(delta):
	# Caminar hacia adelante en X
	#var direccion = Vector3(1, 0, 0)  # Avanzar en X positivo
	#translate(direccion * velocidad_base * delta)

	# Rotar para mirar hacia X (alinear -Z local con +X global)
	#var target_rotation = 0.0  # -90 grados en radianes
	rotation.y = PI/2
	var direccion = -transform.basis.x
	translate(direccion*velocidad_base*delta)

	reproducir_animacion("sprint")

	# Verificar si llegó al recibidor (solo comparar X)
	if abs(global_position.x - posicion_recibidor.x) < 0.3:
		cambiar_estado(EstadoCliente.EN_RECIBIDOR)

func procesar_estado_en_recibidor(delta):
	# Cliente espera en el recibidor a ser atendido
	reproducir_animacion("idle")
	
	# Pequeña espera antes de estar listo para ordenar
	if tiempo_en_estado > 2.0:
		cambiar_estado(EstadoCliente.ESPERANDO_ATENCION)

func procesar_estado_esperando_atencion(delta):
	# INTEGRACIÓN: Cliente espera en el RECIBIDOR a que tomen su orden
	reproducir_animacion("idle")
	
	# Actualizar barra de paciencia
	tiempo_espera_restante -= delta
	actualizar_barra_paciencia()
	
	print("DEBUG - Pedido realizado: ", pedido_realizado, " Mesa asignada: ", mesa_asignada != null)
	
	# Si el jugador toma la orden (manejado por HUD con tecla G)
	if pedido_realizado:
		# Verificar que tiene mesa asignada antes de ir
		if not mesa_asignada:
			mesa_asignada = buscar_mesa_libre()
		
		if mesa_asignada:
			print("✓ Cliente yendo a mesa: ", mesa_asignada.name)
			cambiar_estado(EstadoCliente.YENDO_A_MESA)
		else:
			print("No hay mesas disponibles - cliente se va molesto")
			cambiar_estado(EstadoCliente.SALIENDO_ENOJADO)
	
	# Si se agota la paciencia en el recibidor
	if tiempo_espera_restante <= 0:
		print("Cliente se va - no tomaron su orden en el recibidor")
		cambiar_estado(EstadoCliente.SALIENDO_ENOJADO)

func procesar_estado_yendo_a_mesa(delta):
	# Cliente camina hacia su mesa asignada
	if mesa_asignada:
		print("DEBUG - Posición actual: ", global_position, " Objetivo: ", objetivo_movimiento, " Distancia: ", global_position.distance_to(objetivo_movimiento))
		mover_hacia_objetivo(objetivo_movimiento, delta)
		reproducir_animacion("sprint")
		
		if global_position.distance_to(objetivo_movimiento) < 0.8:
			# Resetear paciencia para esperar la comida
			tiempo_espera_restante = pedido_asignado.get("paciencia_maxima", 120.0) * modificador_paciencia
			cambiar_estado(EstadoCliente.ESPERANDO_COMIDA)
	else:
		# Error: no tiene mesa asignada
		print("ERROR: Cliente sin mesa asignada")
		cambiar_estado(EstadoCliente.SALIENDO_ENOJADO)

func procesar_estado_esperando_comida(delta):
	# INTEGRACIÓN: Cliente espera en la MESA a que le traigan la comida
	reproducir_animacion("idle")
	
	# Actualizar barra de paciencia
	tiempo_espera_restante -= delta
	actualizar_barra_paciencia()
	
	# La entrega se maneja en tu código existente con la función recibir_pedido_jugador()
	
	if tiempo_espera_restante <= 0:
		print("Cliente se va - tardaron mucho con la comida")
		cambiar_estado(EstadoCliente.SALIENDO_ENOJADO)

func procesar_estado_comiendo(delta):
	# El cliente "come" la comida (opcional, para inmersión)
	reproducir_animacion("idle")
	
	var tiempo_comiendo = get_tiempo_comiendo()
	if tiempo_en_estado > tiempo_comiendo:
		cambiar_estado(EstadoCliente.PAGANDO)

func procesar_estado_pagando(delta):
	# Proceso de pago (automático)
	reproducir_animacion("idle")
	
	if tiempo_en_estado > 2.0:  # Toma 2 segundos pagar
		# Dar propina basada en la experiencia
		dar_propina_segun_experiencia()
		cambiar_estado(EstadoCliente.SALIENDO_FELIZ)

func procesar_estado_saliendo_feliz(delta):
	# Cliente camina hacia la salida SOLO en eje X
	# De (0, 0.5, 0.294) a (-10, 0.5, 0.294)
	
	var objetivo_x = objetivo_movimiento.x
	var direccion_x = sign(objetivo_x - global_position.x)
	
	velocity.x = direccion_x * velocidad_base
	velocity.z = 0  # No moverse en Z
	velocity.y += get_gravity().y * delta  # Mantener gravedad
	
	move_and_slide()
	reproducir_animacion("sprint")
	
	# Verificar si llegó a la salida (solo comparar X)
	if abs(global_position.x - objetivo_x) < 0.5:
		# Usar tu señal existente
		cliente_se_fue.emit(self)
		liberar_mesa()
		programar_eliminacion()

func procesar_estado_saliendo_enojado(delta):
	# Cliente camina molesto hacia la salida SOLO en eje X
	# De (0, 0.5, 0.294) a (-10, 0.5, 0.294)
	
	var objetivo_x = objetivo_movimiento.x
	var direccion_x = sign(objetivo_x - global_position.x)
	
	velocity.x = direccion_x * velocidad_base
	velocity.z = 0  # No moverse en Z
	velocity.y += get_gravity().y * delta  # Mantener gravedad
	
	move_and_slide()
	reproducir_animacion("sprint")
	
	# Verificar si llegó a la salida (solo comparar X)
	if abs(global_position.x - objetivo_x) < 0.5:
		# Usar tu señal existente
		cliente_se_fue.emit(self)
		liberar_mesa()
		programar_eliminacion()

func marcar_pedido_realizado():
	"""Marca que el pedido fue tomado por el jugador"""
	pedido_realizado = true
	print("✓ Pedido marcado como realizado para cliente FSM")

# ========== NUEVO: FUNCIONES DE UTILIDAD FSM ==========
func inicializar_tipo_cliente():
	var tipos = ["normal", "rapido", "paciente", "exigente"]
	tipo_cliente = tipos[randi() % tipos.size()]
	
	match tipo_cliente:
		"rapido":
			modificador_paciencia = 0.6  # 40% menos paciencia
			velocidad_base = 2.5
			print("Cliente rápido generado")
		"paciente":
			modificador_paciencia = 1.8  # 80% más paciencia
			velocidad_base = 1.2
			print("Cliente paciente generado")
		"exigente":
			modificador_paciencia = 0.8  # 20% menos paciencia
			velocidad_base = 1.0
			print("Cliente exigente generado")
		"normal":
			modificador_paciencia = 1.0
			velocidad_base = 1.5
			print("Cliente normal generado")

func buscar_mesa_libre() -> Node3D:
	var mesas = get_tree().get_nodes_in_group("tables")
	if mesas.is_empty():
		print("⚠️ No hay mesas en el grupo 'tables'")
		return null
	
	for mesa in mesas:
		# Verificar si la mesa está libre (puedes agregar lógica más compleja aquí)
		if not tiene_cliente_cerca(mesa):
			print("✓ Mesa libre encontrada: ", mesa.name)
			return mesa
	
	print("⚠️ No hay mesas libres disponibles")
	return null

func tiene_cliente_cerca(mesa: Node3D) -> bool:
	var clientes = get_tree().get_nodes_in_group("clientes")
	for cliente in clientes:
		if cliente != self and cliente.global_position.distance_to(mesa.global_position) < 2.0:
			return true
	return false

func liberar_mesa():
	if mesa_asignada:
		print("Mesa liberada: ", mesa_asignada.name)
		mesa_asignada = null

func mover_hacia_objetivo(objetivo: Vector3, delta: float):
	var direccion = (objetivo - global_position).normalized()
	# Verificar que la dirección sea válida
	if direccion.length() < 0.1:
		print("DEBUG - Ya está en el objetivo")
		return
	velocity.x = direccion.x * velocidad_base
	velocity.z = direccion.z * velocidad_base
	velocity.y = 0
	
	# Asegurar que esté en el suelo
	if global_position.y != 0.5:
		global_position.y = 0.5	
	
	move_and_slide()
	
	# Rotar hacia la dirección de movimiento
	if direccion.length() > 0.1:
		var look_direction = Vector3(direccion.x, 0, direccion.z)
		if look_direction.length() > 0.1:
			var target_rotation = atan2(look_direction.x, look_direction.z)
			rotation.y = lerp_angle(rotation.y, target_rotation, 5.0 * delta)
			
	print("DEBUG - Moviendo. Velocity: ", velocity, " Dirección: ", direccion)

func get_tiempo_decision() -> float:
	var tiempo_base = 4.0
	match tipo_cliente:
		"rapido":
			return tiempo_base * 0.5
		"paciente":
			return tiempo_base * 1.5
		"exigente":
			return tiempo_base * 2.0
		_:
			return tiempo_base

func get_tiempo_comiendo() -> float:
	var tiempo_base = 8.0
	match tipo_cliente:
		"rapido":
			return tiempo_base * 0.3
		"paciente":
			return tiempo_base * 1.5
		"exigente":
			return tiempo_base * 1.0
		_:
			return tiempo_base

func generar_pedido_segun_tipo():
	# INTEGRACIÓN: Modificar tu generación de pedido existente
	if not game_manager:
		return
	
	# Usar tu lógica existente pero con modificaciones según el tipo
	var pedido_base = game_manager.generar_pedido_aleatorio() if game_manager.has_method("generar_pedido_aleatorio") else {}
	
	if pedido_base.is_empty():
		print("⚠️ No se pudo generar pedido base")
		return
	
	# Modificar paciencia según tipo de cliente
	if pedido_base.has("paciencia_maxima"):
		pedido_base.paciencia_maxima *= modificador_paciencia
		tiempo_espera_restante = pedido_base.paciencia_maxima
	
	pedido_asignado = pedido_base
	print("Pedido generado para cliente ", tipo_cliente, " en recibidor: ", pedido_asignado.get("nombre_receta", "Sin nombre"))

func mostrar_indicador_estado(texto: String):
	# Actualizar el indicador existente o crear uno nuevo
	if has_node("InfoPedido"):
		$InfoPedido.text = texto
	else:
		var label = Label3D.new()
		label.name = "InfoPedido"
		label.text = texto
		label.font_size = 14
		label.position = Vector3(0, 2.2, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)

func dar_propina_segun_experiencia():
	# Calcular propina basada en qué tan bien fue atendido
	var propina_base = 10
	var experiencia_score = 1.0
	
	# Factores que afectan la propina
	if tiempo_espera_restante > pedido_asignado.get("paciencia_maxima", 120) * 0.7:
		experiencia_score += 0.5  # Servicio rápido
	
	if tipo_cliente == "exigente":
		experiencia_score *= 0.8  # Los exigentes dan menos propina
	elif tipo_cliente == "paciente":
		experiencia_score *= 1.2  # Los pacientes son más generosos
	
	var propina_final = int(propina_base * experiencia_score)
	
	if game_manager and game_manager.has_method("cambiar_dinero"):
		game_manager.cambiar_dinero(propina_final)
		print("Cliente ", tipo_cliente, " dio propina de $", propina_final)

func reproducir_animacion(nombre_animacion: String):
	if animation_player and animation_player.current_animation != nombre_animacion:
		animation_player.play(nombre_animacion)

func programar_eliminacion():
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()

# ========== INTEGRACIÓN: MANTENER FUNCIONES EXISTENTES ==========

func asignar_pedido(pedido: Dictionary):
	# MODIFICADO: Ahora se llama desde generar_pedido_segun_tipo()
	pedido_asignado = pedido
	tiempo_espera_restante = pedido.get("paciencia_maxima", 120.0) * modificador_paciencia
	print("Cliente FSM recibió pedido: ", pedido_asignado.get("nombre_receta", "Desconocido"))

func recibir_pedido_jugador(pedido_jugador: Dictionary) -> bool:
	# INTEGRACIÓN: Mantener tu lógica existente - ahora se entrega en la MESA
	if estado_actual != EstadoCliente.ESPERANDO_COMIDA:
		print("Cliente no está esperando comida en la mesa actualmente")
		return false
	
	if not pedido_jugador.has("ingredientes"):
		print("Pedido del jugador no tiene ingredientes")
		return false
	
	print("Cliente FSM recibiendo pedido del jugador en la mesa...")
	print("Ingredientes recibidos: ", pedido_jugador.ingredientes)
	
	# Emitir señal para que GameManager valide (tu lógica existente)
	pedido_entregado.emit(self, pedido_jugador)
	
	return true

func marchar_satisfecho():
	# MODIFICADO: Cambiar estado en lugar de lógica directa
	print("Cliente FSM marchando satisfecho")
	if barra_paciencia:
		barra_paciencia.modulate = Color.GREEN
		barra_paciencia.value = 100
	
	# Cambiar al estado de comiendo (opcional) o directo a pagando
	if estado_actual == EstadoCliente.ESPERANDO_COMIDA:
		cambiar_estado(EstadoCliente.COMIENDO)

# Mantener funciones existentes de utilidad
func obtener_pedido() -> Dictionary:
	return pedido_asignado.duplicate()

func obtener_ingredientes_requeridos() -> Array:
	if pedido_asignado.has("datos_receta"):
		return pedido_asignado.datos_receta.get("ingredientes", [])
	return []

func obtener_nombre_pedido() -> String:
	if pedido_asignado.has("datos_receta"):
		return pedido_asignado.datos_receta.get("nombre", "Pedido Desconocido")
	return "Sin Pedido"

func obtener_tiempo_restante() -> float:
	return tiempo_espera_restante

func obtener_porcentaje_paciencia() -> float:
	if pedido_asignado.has("paciencia_maxima"):
		var paciencia_maxima = pedido_asignado.paciencia_maxima
		return (tiempo_espera_restante / paciencia_maxima) * 100.0
	return 0.0

func esta_esperando() -> bool:
	return estado_actual == EstadoCliente.ESPERANDO_ATENCION

func esta_satisfecho() -> bool:
	return estado_actual == EstadoCliente.SALIENDO_FELIZ

func actualizar_barra_paciencia():
	# MANTENER: Tu función existente
	if not barra_paciencia or not pedido_asignado.has("paciencia_maxima"):
		return
	
	var paciencia_maxima = pedido_asignado.paciencia_maxima
	var porcentaje = (tiempo_espera_restante / paciencia_maxima) * 100
	
	barra_paciencia.value = max(0, porcentaje)
	
	# Cambiar color según la paciencia restante
	if porcentaje > 60:
		barra_paciencia.modulate = Color.GREEN
	elif porcentaje > 30:
		barra_paciencia.modulate = Color.YELLOW
	else:
		barra_paciencia.modulate = Color.RED

func actualizar_ui_posicion():
	# MANTENER: Tu función existente
	if not barra_paciencia:
		return
	
	var camera = get_viewport().get_camera_3d()
	if camera:
		var head_pos = global_transform.origin + Vector3(0, 2.5, 0)
		var screen_pos = camera.unproject_position(head_pos)
		
		var viewport_size = get_viewport().get_visible_rect().size
		if screen_pos.x >= 0 and screen_pos.x <= viewport_size.x and screen_pos.y >= 0 and screen_pos.y <= viewport_size.y:
			barra_paciencia.position = screen_pos - Vector2(barra_paciencia.size.x / 2, barra_paciencia.size.y + 10)
			barra_paciencia.visible = true
		else:
			barra_paciencia.visible = false

# ========== FUNCIONES DE DEBUG ==========
func debug_cliente_fsm():
	print("\n=== DEBUG CLIENTE FSM ===")
	print("Estado actual: ", EstadoCliente.keys()[estado_actual])
	print("Tiempo en estado: ", tiempo_en_estado)
	print("Tipo de cliente: ", tipo_cliente)
	print("En recibidor: ", en_recibidor)
	print("Mesa asignada: ", mesa_asignada.name if mesa_asignada else "ninguna")
	print("Pedido realizado: ", pedido_realizado)
	print("Tiempo restante: ", tiempo_espera_restante)
	print("Posición actual: ", global_position)
	print("Objetivo: ", objetivo_movimiento)
	print("========================\n")

func forzar_estado(nuevo_estado: EstadoCliente):
	# Para debugging - forzar cambio a cualquier estado
	cambiar_estado(nuevo_estado)
