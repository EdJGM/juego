extends "res://scripts/cliente.gd"

# === NAVEGACIÓN A* ===
var navigation_system: AStarNavigation
var current_path: PackedVector3Array = []
var path_index: int = 0
var target_position: Vector3
var movement_speed: float = 1.5
var arrival_threshold: float = 0.3

enum NavigationState {
	IDLE,
	MOVING_TO_TABLE,
	WAITING_AT_TABLE,
	MOVING_TO_EXIT,
	IN_QUEUE
}
var nav_state: NavigationState = NavigationState.IDLE
var assigned_table_position: Vector3

func _ready():
	super._ready() # Llama al _ready del padre
	navigation_system = get_node_or_null("/root/NavigationSystem")
	if not navigation_system:
		print("ERROR: NavigationSystem no encontrado")
		return
	setup_navigation_behavior()

func setup_navigation_behavior():
	await get_tree().create_timer(randf() * 2.0).timeout
	if not esperando:
		return
	find_and_move_to_table()

func find_and_move_to_table():
	var available_tables = navigation_system.get_table_positions()
	if available_tables.is_empty():
		move_to_queue()
		return
	var closest_table = find_closest_table(available_tables)
	assigned_table_position = closest_table
	var path = navigation_system.find_path(global_position, assigned_table_position)
	if path.size() > 0:
		start_navigation(path, NavigationState.MOVING_TO_TABLE)
	else:
		print("No se pudo encontrar camino hacia la mesa")
		move_to_queue()

func find_closest_table(tables: Array) -> Vector3:
	var closest_table = tables[0]
	var min_distance = global_position.distance_to(closest_table)
	for table_pos in tables:
		var distance = global_position.distance_to(table_pos)
		if distance < min_distance:
			min_distance = distance
			closest_table = table_pos
	return closest_table

func move_to_queue():
	var queue_index = get_queue_index()
	var queue_pos = navigation_system.get_queue_position(queue_index)
	var path = navigation_system.find_path(global_position, queue_pos)
	if path.size() > 0:
		start_navigation(path, NavigationState.IN_QUEUE)

func get_queue_index() -> int:
	var clientes_en_cola = get_tree().get_nodes_in_group("clientes")
	var index = 0
	for cliente in clientes_en_cola:
		if cliente != self and cliente.has_method("is_in_queue") and cliente.is_in_queue():
			index += 1
	return index

func start_navigation(path: PackedVector3Array, new_state: int):
	current_path = path
	path_index = 0
	nav_state = new_state
	if current_path.size() > 0:
		target_position = current_path[0]
		if animation_player:
			animation_player.play("sprint")

func _process(delta):
	super._process(delta) # Llama al _process del padre
	if nav_state != NavigationState.IDLE and nav_state != NavigationState.WAITING_AT_TABLE:
		process_navigation(delta)

func process_navigation(delta):
	if current_path.is_empty() or path_index >= current_path.size():
		arrive_at_destination()
		return
	var current_target = current_path[path_index]
	var direction = (current_target - global_position).normalized()
	direction.y = 0
	if direction.length() > 0:
		velocity.x = direction.x * movement_speed
		velocity.z = direction.z * movement_speed
		look_at(global_position + direction, Vector3.UP)
		move_and_slide()
	var distance_to_target = Vector2(global_position.x, global_position.z).distance_to(
		Vector2(current_target.x, current_target.z)
	)
	if distance_to_target < arrival_threshold:
		path_index += 1
		if path_index < current_path.size():
			target_position = current_path[path_index]

func arrive_at_destination():
	velocity = Vector3.ZERO
	current_path.clear()
	path_index = 0
	if animation_player:
		animation_player.play("idle")
	match nav_state:
		NavigationState.MOVING_TO_TABLE:
			nav_state = NavigationState.WAITING_AT_TABLE
			print("Cliente ", name, " llegó a su mesa")
		NavigationState.IN_QUEUE:
			print("Cliente ", name, " está en la cola")
		NavigationState.MOVING_TO_EXIT:
			print("Cliente ", name, " salió del restaurante")
			cliente_se_fue.emit(self)
			queue_free()

func iniciar_salida():
	esperando = false
	var exit_position = Vector3(-10, 0.5, 3)
	var safe_exit = navigation_system.find_nearest_walkable_position(exit_position)
	var path = navigation_system.find_path(global_position, safe_exit)
	if path.size() > 0:
		start_navigation(path, NavigationState.MOVING_TO_EXIT)
	else:
		super.iniciar_salida() # Fallback al método original

func marchar_satisfecho():
	satisfecho = true
	esperando = false
	if barra_paciencia:
		barra_paciencia.modulate = Color.GREEN
		barra_paciencia.value = 100
	mostrar_satisfaccion()
	await get_tree().create_timer(2.0).timeout
	iniciar_salida()

func is_in_queue() -> bool:
	return nav_state == NavigationState.IN_QUEUE

func is_at_table() -> bool:
	return nav_state == NavigationState.WAITING_AT_TABLE

func get_navigation_state() -> int:
	return nav_state

func try_move_to_available_table():
	if nav_state != NavigationState.IN_QUEUE:
		return
	var available_tables = navigation_system.get_table_positions()
	if not available_tables.is_empty():
		find_and_move_to_table()
