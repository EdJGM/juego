# cliente_navegacion_corregida.gd - VERSIÓN CORREGIDA
extends CharacterBody3D

# CONFIGURACIÓN DE VELOCIDAD MÁS LENTA Y REALISTA
const SPEED = 1.5  # Reducido de 5.0 a 1.5 para movimiento más natural
const EPSILON = 0.1  # Para comparaciones de float más precisas

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
var target_position: Vector3
var ground_y: float = 0.0
var has_reached_target: bool = false
var debug_counter: int = 0
var movement_locked: bool = false  # Para evitar saltos de posición

func _ready():
	print("=== CLIENTE NAVEGACIÓN INICIALIZANDO ===")
	
	# CONFIGURACIÓN MÁS CONSERVADORA DEL NAVIGATION AGENT
	nav_agent.path_desired_distance = 0.3
	nav_agent.target_desired_distance = 0.8
	nav_agent.path_max_distance = 20.0
	nav_agent.avoidance_enabled = false
	nav_agent.path_height_offset = 0.0
	nav_agent.path_postprocessing = NavigationPathQueryParameters3D.PATH_POSTPROCESSING_EDGECENTERED
	
	# CONFIGURACIÓN DE AVOIDANCE (deshabilitada para evitar problemas)
	nav_agent.radius = 0.5
	nav_agent.height = 1.8
	nav_agent.max_speed = SPEED
	
	# ESTABLECER ALTURA DEL SUELO
	ground_y = global_position.y
	print("Posición inicial del cliente: ", global_position)
	print("Altura del suelo fijada en: ", ground_y)
	
	call_deferred("setup_navigation")

func setup_navigation():
	await get_tree().process_frame
	await get_tree().process_frame  # Esperar frames adicionales
	
	var target_node = get_tree().get_current_scene().get_node_or_null("Target")
	if target_node:
		target_position = target_node.global_transform.origin
		target_position.y = ground_y  # FIJAR A LA ALTURA DEL SUELO INMEDIATAMENTE
		
		print("Target encontrado en: ", target_position)
		print("Target ajustado a altura del suelo: ", target_position)
		
		var initial_distance = global_position.distance_to(target_position)
		print("Distancia inicial al target: ", initial_distance)
		
		# VERIFICAR QUE LA DISTANCIA SEA RAZONABLE
		if initial_distance > 50:
			print("WARNING: Distancia muy grande, puede haber problemas")
		
		# CONFIGURAR TARGET
		nav_agent.target_position = target_position
		
		# ESPERAR Y VERIFICAR PATH
		await get_tree().process_frame
		await get_tree().process_frame
		
		validate_navigation_path()
	else:
		print("ERROR: Nodo Target no encontrado")
		print("Nodos disponibles en la escena:")
		list_scene_nodes(get_tree().current_scene, 0)

func validate_navigation_path():
	var path = nav_agent.get_current_navigation_path()
	print("Path calculado con ", path.size(), " puntos")
	
	if path.size() == 0:
		print("ERROR: No se pudo calcular un path válido")
		print("Usando movimiento directo como fallback")
		return
	
	if path.size() == 1:
		print("WARNING: Path tiene solo 1 punto")
	
	# MOSTRAR ALGUNOS PUNTOS DEL PATH PARA DEBUG
	print("Puntos del path:")
	for i in range(min(3, path.size())):
		print("  Punto ", i, ": ", path[i])
	
	if path.size() > 3:
		print("  ...")
		print("  Último punto: ", path[-1])
	
	# VERIFICAR QUE EL PATH NO TENGA SALTOS EXTRAÑOS
	for i in range(1, path.size()):
		var distance = path[i].distance_to(path[i-1])
		if distance > 10:
			print("WARNING: Salto grande en el path entre puntos ", i-1, " y ", i, " - Distancia: ", distance)

func _physics_process(delta: float) -> void:
	# MANTENER AL PERSONAJE EN EL SUELO SIEMPRE
	if abs(global_position.y - ground_y) > EPSILON:
		global_position.y = ground_y
	
	velocity.y = 0
	
	# SI EL MOVIMIENTO ESTÁ BLOQUEADO, NO HACER NADA
	if movement_locked:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	# VERIFICAR DISTANCIA AL TARGET FINAL (SOLO EN X y Z)
	var distance_to_target = Vector2(
		target_position.x - global_position.x,
		target_position.z - global_position.z
	).length()
	
	# DEBUG CADA 3 SEGUNDOS
	debug_counter += 1
	if debug_counter % 180 == 0:
		print("DEBUG: Posición actual: ", global_position)
		print("DEBUG: Target: ", target_position)
		print("DEBUG: Distancia al target: ", distance_to_target)
		print("DEBUG: NavigationAgent terminado: ", nav_agent.is_navigation_finished())
		
		# VERIFICAR SI ESTÁ ALEJÁNDOSE MUCHO
		if distance_to_target > 100:
			print("ERROR: Cliente se alejó demasiado, BLOQUEANDO MOVIMIENTO")
			movement_locked = true
			return
	
	# SI LLEGÓ AL TARGET, PARAR COMPLETAMENTE
	if distance_to_target <= nav_agent.target_desired_distance:
		if not has_reached_target:
			print("DEBUG: ¡Cliente llegó al target!")
			print("DEBUG: Posición final: ", global_position)
			print("DEBUG: Distancia final: ", distance_to_target)
			has_reached_target = true
			movement_locked = true  # BLOQUEAR MOVIMIENTO COMPLETAMENTE
		
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	# NAVEGACIÓN NORMAL
	if not nav_agent.is_navigation_finished() and not has_reached_target:
		var next_point = nav_agent.get_next_path_position()
		next_point.y = ground_y  # ASEGURAR QUE ESTÉ A LA ALTURA DEL SUELO
		
		# VERIFICAR QUE EL SIGUIENTE PUNTO SEA RAZONABLE
		var distance_to_next = global_position.distance_to(next_point)
		
		if distance_to_next > 20:  # Si el siguiente punto está muy lejos
			print("WARNING: Siguiente punto muy lejos (", distance_to_next, "), usando movimiento directo")
			move_directly_to_target()
			return
		
		# MOVIMIENTO NORMAL HACIA EL SIGUIENTE PUNTO
		if distance_to_next > nav_agent.path_desired_distance:
			var direction = (next_point - global_position).normalized()
			direction.y = 0  # ASEGURAR QUE NO HAY MOVIMIENTO VERTICAL
			
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
			
			# DEBUG OCASIONAL DEL MOVIMIENTO
			if debug_counter % 60 == 0:  # Cada segundo
				print("DEBUG: Moviéndose hacia: ", next_point)
				print("DEBUG: Dirección: ", direction)
		else:
			velocity.x = 0
			velocity.z = 0
	else:
		velocity = Vector3.ZERO
	
	# APLICAR MOVIMIENTO
	move_and_slide()
	
	# VERIFICAR QUE NO HAYA SALTADO DE POSICIÓN DESPUÉS DEL MOVIMIENTO
	var position_after_move = global_position
	if abs(position_after_move.y - ground_y) > EPSILON:
		print("WARNING: El personaje saltó de altura después del movimiento")
		global_position.y = ground_y

func move_directly_to_target():
	"""Movimiento directo cuando NavigationAgent falla"""
	var direction = Vector3(
		target_position.x - global_position.x,
		0,
		target_position.z - global_position.z
	).normalized()
	
	velocity.x = direction.x * SPEED * 0.5  # Movimiento más lento en modo directo
	velocity.z = direction.z * SPEED * 0.5
	
	print("DEBUG: Movimiento directo hacia target")

func recalculate_path():
	"""Recalcula el path cuando hay problemas"""
	print("DEBUG: Recalculando navegación...")
	nav_agent.target_position = target_position
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	validate_navigation_path()

func list_scene_nodes(node: Node, depth: int):
	"""Lista todos los nodos de la escena para debug"""
	var indent = ""
	for i in range(depth):
		indent += "  "
	
	print(indent, "- ", node.name, " (", node.get_class(), ")")
	
	if depth < 2:  # Solo 2 niveles para no saturar
		for child in node.get_children():
			list_scene_nodes(child, depth + 1)

# FUNCIÓN PARA RESETEAR EL CLIENTE SI HAY PROBLEMAS
func reset_navigation():
	"""Función de emergencia para resetear la navegación"""
	print("DEBUG: Reseteando navegación del cliente")
	movement_locked = false
	has_reached_target = false
	global_position.y = ground_y
	
	if target_position != Vector3.ZERO:
		nav_agent.target_position = target_position
		await get_tree().process_frame
		validate_navigation_path()

# FUNCIÓN PARA DEBUGGING MANUAL
func debug_navigation_status():
	print("\n=== DEBUG NAVEGACIÓN ===")
	print("Posición actual: ", global_position)
	print("Target: ", target_position)
	print("Distancia al target: ", global_position.distance_to(target_position))
	print("NavigationAgent terminado: ", nav_agent.is_navigation_finished())
	print("Ha llegado al target: ", has_reached_target)
	print("Movimiento bloqueado: ", movement_locked)
	print("Altura del suelo: ", ground_y)
	print("=========================\n")

# INPUT PARA DEBUGGING (opcional)
func _input(event):
	if event.is_action_pressed("ui_accept"):  # Espacio
		debug_navigation_status()
	elif event.is_action_pressed("ui_cancel"):  # Escape
		reset_navigation()
