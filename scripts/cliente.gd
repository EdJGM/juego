# cliente.gd - MEJORADO
extends CharacterBody3D

# Señales
signal cliente_se_fue(cliente)
signal pedido_entregado(cliente, pedido)

# Variables del pedido
var pedido_asignado: Dictionary = {}
var tiempo_espera_restante: float = 0.0
var esperando := true
var yendose := false
var girando := false
var satisfecho := false

# Variables de movimiento
@export var velocidad_salida := 2.0
@export var tiempo_giro := 0.5
var tiempo_girado := 0.0
var rotacion_inicial: float
var rotacion_final: float

# Referencias a nodos
@onready var animation_player: AnimationPlayer = $"character-female-b2/AnimationPlayer"
@onready var barra_paciencia: ProgressBar = $CanvasLayer/ProgressBar

# Referencias al sistema
var game_manager: Node

func _ready():
	print("Cliente inicializando...")
	
	# Obtener GameManager
	game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		print("ERROR: GameManager no encontrado en cliente")
	else:
		print("✓ Cliente conectado al GameManager")
	
	# Agregar al grupo de clientes
	add_to_group("clientes")
	
	# Configurar animación inicial
	if animation_player:
		animation_player.play("idle")
		print("✓ Animación inicial configurada")
	else:
		print("⚠️ AnimationPlayer no encontrado")
	
	# Configurar barra de paciencia
	if barra_paciencia:
		barra_paciencia.value = 100
		barra_paciencia.modulate = Color.GREEN
		print("✓ Barra de paciencia configurada")
	else:
		print("⚠️ ProgressBar no encontrado")
	
	print("Cliente inicializado correctamente")

func asignar_pedido(pedido: Dictionary):
	if pedido.is_empty():
		print("ERROR: Pedido vacío asignado al cliente")
		return
	
	pedido_asignado = pedido
	tiempo_espera_restante = pedido.get("paciencia_maxima", 120.0)
	
	print("Cliente recibió pedido: ", pedido_asignado.get("nombre_receta", "Desconocido"))
	print("Paciencia asignada: ", tiempo_espera_restante, " segundos")
	
	# Mostrar información del pedido (placeholder para UI futura)
	mostrar_info_pedido()

func mostrar_info_pedido():
	"""Muestra información del pedido sobre la cabeza del cliente"""
	if not pedido_asignado.has("datos_receta"):
		return
	
	var receta = pedido_asignado.datos_receta
	var nombre_plato = receta.get("nombre", "Pedido")
	
	# Crear label flotante (simple versión)
	if has_node("InfoPedido"):
		$InfoPedido.queue_free()
	
	var label = Label3D.new()
	label.name = "InfoPedido"
	label.text = nombre_plato
	label.font_size = 16
	label.position = Vector3(0, 2.2, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _process(delta):
	if esperando and not satisfecho:
		procesar_espera(delta)
	elif girando:
		procesar_giro(delta)
	elif yendose:
		procesar_salida(delta)
	
	# Actualizar posición de UI
	actualizar_ui_posicion()

func procesar_espera(delta):
	tiempo_espera_restante -= delta
	actualizar_barra_paciencia()
	
	# Asegurar animación idle
	if animation_player and animation_player.current_animation != "idle":
		animation_player.play("idle")
	
	# Verificar si se agotó la paciencia
	if tiempo_espera_restante <= 0:
		iniciar_salida()

func procesar_giro(delta):
	tiempo_girado += delta
	var progreso = clamp(tiempo_girado / tiempo_giro, 0, 1)
	rotation.y = lerp_angle(rotacion_inicial, rotacion_final, progreso)
	
	if progreso >= 1.0:
		girando = false
		iniciar_caminata()

func procesar_salida(delta):
	# Caminar hacia adelante según la rotación actual
	var direccion = -transform.basis.z  # Hacia adelante en la dirección que mira
	translate(direccion * velocidad_salida * delta)
	
	# Asegurar animación de caminar
	if animation_player and animation_player.current_animation != "sprint":
		animation_player.play("sprint")

func actualizar_barra_paciencia():
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
	if not barra_paciencia:
		return
	
	# Mantener la barra sobre la cabeza del cliente
	var camera = get_viewport().get_camera_3d()
	if camera:
		var head_pos = global_transform.origin + Vector3(0, 2.5, 0)
		var screen_pos = camera.unproject_position(head_pos)
		
		# Verificar que la posición está en pantalla
		var viewport_size = get_viewport().get_visible_rect().size
		if screen_pos.x >= 0 and screen_pos.x <= viewport_size.x and screen_pos.y >= 0 and screen_pos.y <= viewport_size.y:
			barra_paciencia.position = screen_pos - Vector2(barra_paciencia.size.x / 2, barra_paciencia.size.y + 10)
		else:
			# Cliente fuera de pantalla, ocultar barra
			barra_paciencia.visible = false

func iniciar_salida():
	"""Inicia el proceso de salida del cliente decepcionado"""
	esperando = false
	girando = true
	tiempo_girado = 0.0
	rotacion_inicial = rotation.y
	rotacion_final = rotation.y + PI  # Gira 180 grados
	
	print("Cliente ", name, " está decepcionado y se va")
	
	# Cambiar animación a idle durante el giro
	if animation_player and animation_player.current_animation != "idle":
		animation_player.play("idle")

func iniciar_caminata():
	"""Inicia la caminata de salida"""
	yendose = true
	cliente_se_fue.emit(self)
	
	# Programar eliminación después de un tiempo
	var timer = Timer.new()
	timer.wait_time = 10.0
	timer.one_shot = true
	timer.timeout.connect(_on_timer_salida)
	add_child(timer)
	timer.start()

func _on_timer_salida():
	print("Cliente ", name, " eliminado después de salir")
	queue_free()

func marchar_satisfecho():
	"""Llamado cuando el pedido se entrega correctamente"""
	satisfecho = true
	esperando = false
	
	if barra_paciencia:
		barra_paciencia.modulate = Color.GREEN
		barra_paciencia.value = 100
	
	print("Cliente ", name, " está satisfecho y se va contento")
	
	# Opcional: animación de felicidad
	mostrar_satisfaccion()
	
	# Iniciar salida después de un momento
	await get_tree().create_timer(1.0).timeout
	iniciar_salida()

func mostrar_satisfaccion():
	"""Muestra feedback visual de satisfacción"""
	# Cambiar el texto del pedido a "¡Gracias!"
	if has_node("InfoPedido"):
		var label = $InfoPedido
		label.text = "¡Gracias!"
		label.modulate = Color.GREEN
		
		# Animar el texto
		var tween = create_tween()
		tween.tween_property(label, "position:y", label.position.y + 0.5, 1.0)
		tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)

func recibir_pedido_jugador(pedido_jugador: Dictionary) -> bool:
	"""Recibe el pedido del jugador y verifica si es correcto"""
	if not esperando or satisfecho:
		print("Cliente no está esperando pedidos")
		return false
	
	if not pedido_jugador.has("ingredientes"):
		print("Pedido del jugador no tiene ingredientes")
		return false
	
	print("Cliente recibiendo pedido del jugador...")
	print("Ingredientes recibidos: ", pedido_jugador.ingredientes)
	
	# Emitir señal para que GameManager valide
	pedido_entregado.emit(self, pedido_jugador)
	
	# Siempre retornar true aquí, GameManager decidirá si es correcto
	return true

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
	return esperando and not satisfecho and not yendose

func esta_satisfecho() -> bool:
	return satisfecho

func obtener_info_completa() -> Dictionary:
	"""Devuelve toda la información del cliente para debugging"""
	return {
		"nombre": name,
		"esperando": esta_esperando(),
		"satisfecho": esta_satisfecho(),
		"yendose": yendose,
		"tiempo_restante": tiempo_espera_restante,
		"porcentaje_paciencia": obtener_porcentaje_paciencia(),
		"pedido": obtener_nombre_pedido(),
		"ingredientes_requeridos": obtener_ingredientes_requeridos(),
		"posicion": global_position
	}

# Función para forzar la salida del cliente (debugging)
func forzar_salida():
	if esperando:
		iniciar_salida()

# Función para debugging
func debug_cliente():
	var info = obtener_info_completa()
	print("\n=== DEBUG CLIENTE ===")
	for key in info.keys():
		print(key, ": ", info[key])
	print("====================\n")
