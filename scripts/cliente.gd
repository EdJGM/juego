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
var saliendo_hacia_entrada: bool = true 
var posicion_en_cola: int = 0
var distancia_cola: float = 1.5  #

# Referencias a nodos (mantener existentes)
@onready var animation_player: AnimationPlayer = $"character-female-b2/AnimationPlayer"
@onready var barra_paciencia: ProgressBar = $CanvasLayer/ProgressBar
@onready var target_recibidor = get_node("/root/TestLevel/geometry/CSGBox3D/wall_orderwindow2")
@onready var target_salida = get_node("/root/TestLevel/building_B3")

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
	
	posicion_entrada = Vector3(-10, 0.7, 0.294)

	
	# Configurar animación inicial
	if animation_player:
		animation_player.play("idle")
		print("✓ Animación inicial configurada")
	
	# Configurar barra de paciencia
	if barra_paciencia:
		barra_paciencia.value = 100
		barra_paciencia.modulate = Color.GREEN
		barra_paciencia.size = Vector2(50, 10)
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
			else:
					print("ERROR: No hay mesa asignada")
		EstadoCliente.ESPERANDO_COMIDA:
			mostrar_indicador_estado("⏰ Esperando comida")
		EstadoCliente.COMIENDO:
			mostrar_indicador_estado("🍽️ Disfrutando")
		EstadoCliente.SALIENDO_FELIZ:
			saliendo_hacia_entrada = true 
			mostrar_indicador_estado("😊 ¡Gracias!")
			objetivo_movimiento = posicion_entrada
		EstadoCliente.SALIENDO_ENOJADO:
			saliendo_hacia_entrada = true 
			mostrar_indicador_estado("😠 ¡Qué servicio!")
			objetivo_movimiento = posicion_entrada

# ========== NUEVO: IMPLEMENTACIÓN DE ESTADOS ==========
func procesar_estado_entrando(delta):
	if not is_instance_valid(target_recibidor):
		print("ERROR: target_recibidor no válido")
		return
	
	calcular_posicion_en_cola()
	
	var posicion_cola = target_recibidor.global_position + Vector3(-posicion_en_cola * distancia_cola, 0, 0)
	posicion_cola.y = 0.5
	
	var distance_to_queue_pos = global_position.distance_to(posicion_cola)
	
	# Si estamos cerca del recibidor, cambiar estado (distancia reducida para acercarse más)
	rotation.y = PI/2
	if distance_to_queue_pos < 0.5:  # Cambiado de 1.0 a 0.5 para acercarse más
		velocity = Vector3.ZERO
		cambiar_estado(EstadoCliente.EN_RECIBIDOR)
	else:
		# Calcular dirección hacia el recibidor
		var direction = (posicion_cola - global_position).normalized()
		velocity = velocity.lerp(direction * velocidad_base, 10.0 * delta)
	
	move_and_slide()
	global_position.y = 0.5
	reproducir_animacion("walk")
	
func calcular_posicion_en_cola():
	var clientes_antes_que_yo = 0
	var todos_clientes = get_tree().get_nodes_in_group("clientes")
	
	# Contar solo clientes que llegaron ANTES que yo y están esperando
	for cliente in todos_clientes:
		if cliente != self and (cliente.estado_actual == EstadoCliente.EN_RECIBIDOR or cliente.estado_actual == EstadoCliente.ESPERANDO_ATENCION) and cliente.get_instance_id() < self.get_instance_id():  # Solo los que llegaron antes
			clientes_antes_que_yo += 1
	
	posicion_en_cola = clientes_antes_que_yo
	
func procesar_estado_en_recibidor(delta):
	calcular_posicion_en_cola()
	var posicion_cola = target_recibidor.global_position + Vector3(-posicion_en_cola * distancia_cola-0.4, 0, 0)
	posicion_cola.y = 0.5
	# Interpola siempre hacia la posición de la cola
	global_position = global_position.lerp(posicion_cola, 4.0 * delta)
	
	# Cliente espera en el recibidor a ser atendido
	reproducir_animacion("idle")
	
	# Pequeña espera antes de estar listo para ordenar
	if tiempo_en_estado > 2.0:
		cambiar_estado(EstadoCliente.ESPERANDO_ATENCION)

func procesar_estado_esperando_atencion(delta):
	calcular_posicion_en_cola()
	var posicion_cola = target_recibidor.global_position + Vector3(-posicion_en_cola * distancia_cola-0.4, 0, 0)
	posicion_cola.y = 0.5
	# Interpola siempre hacia la posición de la cola
	global_position = global_position.lerp(posicion_cola, 4.0 * delta)
	
	# Si no soy el primero en la cola, solo esperar en mi posición
	if posicion_en_cola > 0:
		reproducir_animacion("idle")
		tiempo_espera_restante -= delta
		actualizar_barra_paciencia()
		return  # Salir sin procesar el resto
	
	# INTEGRACIÓN: Cliente espera en el RECIBIDOR a que tomen su orden
	reproducir_animacion("idle")
	# Actualizar barra de paciencia
	tiempo_espera_restante -= delta
	actualizar_barra_paciencia()
	
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
		mover_hacia_objetivo(objetivo_movimiento, delta)
		reproducir_animacion("sprint")
		
		if global_position.distance_to(objetivo_movimiento) < 0.8:  # Aumentar distancia de parada
			# Resetear paciencia para esperar la comida
			tiempo_espera_restante = pedido_asignado.get("paciencia_maxima", 120.0) * modificador_paciencia
			print("✅ Cliente llegó a la mesa y está esperando comida - Estado: ESPERANDO_COMIDA")
			cambiar_estado(EstadoCliente.ESPERANDO_COMIDA)
	else:
		# Error: no tiene mesa asignada
		print("ERROR: Cliente sin mesa asignada")
		cambiar_estado(EstadoCliente.SALIENDO_ENOJADO)

func procesar_estado_esperando_comida(delta):
	# INTEGRACIÓN: Cliente espera en la MESA a que le traigan la comida
	reproducir_animacion("idle")
	
	# Mantenerse cerca de la mesa
	if mesa_asignada:
		var posicion_mesa = mesa_asignada.global_position + Vector3(1.5, 0.7, 0.0)
		if global_position.distance_to(posicion_mesa) > 1.0:
			# Volver a acercarse a la mesa si se alejó
			global_position = global_position.lerp(posicion_mesa, 2.0 * delta)
	
	# Actualizar barra de paciencia
	tiempo_espera_restante -= delta
	actualizar_barra_paciencia()
	
	# Debug: mostrar que está esperando
	if int(tiempo_en_estado) % 5 == 0 and tiempo_en_estado > 4.5:
		print("🍽️ Cliente esperando comida en mesa - Paciencia restante: ", "%.1f" % tiempo_espera_restante)
	
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
	if saliendo_hacia_entrada:
		# FASE 1: Ir hacia la entrada en líneas rectas
		var distance_to_entrance = global_position.distance_to(posicion_entrada)
		
		if distance_to_entrance < 1.0:
			saliendo_hacia_entrada = false
			print("Cliente llegó a la entrada, ahora va al edificio")
		else:
			# Movimiento en líneas rectas - primero Z, luego X
			var diff_x = posicion_entrada.x - global_position.x
			var diff_z = posicion_entrada.z - global_position.z
			
			if abs(diff_z) > 0.2:  # Primero moverse en Z
				rotation.y = PI
				var direction = Vector3(0, 0, sign(diff_z))
				velocity = velocity.lerp(direction * velocidad_base, 10.0 * delta)
			elif abs(diff_x) > 0.2:  # Después moverse en X
				rotation.y = -PI/2
				var direction = Vector3(sign(diff_x), 0, 0)
				velocity = velocity.lerp(direction * velocidad_base, 10.0 * delta)
			else:
				velocity = Vector3.ZERO
	else:
		# FASE 2: Ir hacia building_B3
		if not is_instance_valid(target_salida):
			print("ERROR: building_B3 no válido")
			return
		
		var distance_to_target = global_position.distance_to(target_salida.global_position)
		
		if distance_to_target < 5.0:
			velocity = Vector3.ZERO
			reproducir_animacion("idle")
			cliente_se_fue.emit(self)
			liberar_mesa()
			programar_eliminacion()
		else:
			var direction = (target_salida.global_position - global_position).normalized()
			velocity = velocity.lerp(direction * velocidad_base, 10.0 * delta)
	
	# Aplicar gravedad
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	
	move_and_slide()
	global_position.y = 0.5
	reproducir_animacion("sprint")

func procesar_estado_saliendo_enojado(delta):
	if saliendo_hacia_entrada:
		# FASE 1: Ir hacia la entrada en líneas rectas
		var distance_to_entrance = global_position.distance_to(posicion_entrada)
		
		if distance_to_entrance < 1.0:
			saliendo_hacia_entrada = false
			print("Cliente llegó a la entrada, ahora va al edificio")
		else:
			# Movimiento en líneas rectas - primero Z, luego X
			var diff_x = posicion_entrada.x - global_position.x
			var diff_z = posicion_entrada.z - global_position.z
			
			if abs(diff_z) > 0.2:  # Primero moverse en Z
				rotation.y = PI
				var direction = Vector3(0, 0, sign(diff_z))
				velocity = velocity.lerp(direction * velocidad_base, 10.0 * delta)
			elif abs(diff_x) > 0.2:  # Después moverse en X
				rotation.y = -PI/2
				var direction = Vector3(sign(diff_x), 0, 0)
				velocity = velocity.lerp(direction * velocidad_base, 10.0 * delta)
			else:
				velocity = Vector3.ZERO
	else:
		# FASE 2: Ir hacia building_B3
		if not is_instance_valid(target_salida):
			print("ERROR: building_B3 no válido")
			return
		
		var distance_to_target = global_position.distance_to(target_salida.global_position)
		
		if distance_to_target < 5.0:
			velocity = Vector3.ZERO
			reproducir_animacion("idle")
			cliente_se_fue.emit(self)
			liberar_mesa()
			programar_eliminacion()
		else:
			var direction = (target_salida.global_position - global_position).normalized()
			velocity = velocity.lerp(direction * velocidad_base, 10.0 * delta)
	
	# Aplicar gravedad
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	
	move_and_slide()
	global_position.y = 0.5
	reproducir_animacion("sprint")

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
		label.font_size = 24
		label.position = Vector3(0, 1.0, 0)
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
	
	print("\n=== CLIENTE RECIBIENDO PEDIDO ===")
	print("Cliente esperaba: ", pedido_asignado.get("nombre_receta", "Sin nombre"))
	print("Ingredientes recibidos del jugador: ", pedido_jugador.ingredientes)
	print("================================")
	
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

func esta_esperando_comida_en_mesa() -> bool:
	"""Función específica para verificar si está esperando comida en la mesa"""
	return estado_actual == EstadoCliente.ESPERANDO_COMIDA

func obtener_estado_actual_string() -> String:
	"""Devuelve el estado actual como string para debugging"""
	match estado_actual:
		EstadoCliente.ENTRANDO:
			return "ENTRANDO"
		EstadoCliente.EN_RECIBIDOR:
			return "EN_RECIBIDOR"
		EstadoCliente.ESPERANDO_ATENCION:
			return "ESPERANDO_ATENCION"
		EstadoCliente.YENDO_A_MESA:
			return "YENDO_A_MESA"
		EstadoCliente.ESPERANDO_COMIDA:
			return "ESPERANDO_COMIDA"
		EstadoCliente.COMIENDO:
			return "COMIENDO"
		EstadoCliente.PAGANDO:
			return "PAGANDO"
		EstadoCliente.SALIENDO_FELIZ:
			return "SALIENDO_FELIZ"
		EstadoCliente.SALIENDO_ENOJADO:
			return "SALIENDO_ENOJADO"
		_:
			return "DESCONOCIDO"

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
		var head_pos = global_transform.origin + Vector3(0, 1.2, 0)
		var screen_pos = camera.unproject_position(head_pos)
		
		var viewport_size = get_viewport().get_visible_rect().size
		if screen_pos.x >= 0 and screen_pos.x <= viewport_size.x and screen_pos.y >= 0 and screen_pos.y <= viewport_size.y:
			barra_paciencia.position = screen_pos - Vector2(barra_paciencia.size.x / 2, barra_paciencia.size.y + 10)
			barra_paciencia.visible = true
		else:
			barra_paciencia.visible = false
