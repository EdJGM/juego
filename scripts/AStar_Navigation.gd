# AStar_Navigation.gd - Sistema de navegación A* para clientes
extends Node
class_name AStarNavigation

# Grid del restaurante
var grid_size: Vector2i = Vector2i(20, 16)  # Basado en tu piso de 20x8, pero más detallado
var cell_size: float = 0.5  # Cada celda representa 0.5 unidades del mundo
var grid_offset: Vector3 = Vector3(-10, 0, -4)  # Offset para centrar el grid

# AStar2D de Godot (muy optimizado)
var astar: AStar2D
var grid: Array[Array] = []

# Tipos de celdas
enum CellType {
	WALKABLE,
	OBSTACLE,
	TABLE,
	KITCHEN_AREA,
	ENTRANCE,
	EXIT
}

func _ready():
	initialize_grid()
	setup_astar()
	scan_restaurant_layout()

func initialize_grid():
	"""Inicializar el grid 2D"""
	astar = AStar2D.new()
	
	# Crear grid vacío (todo caminable inicialmente)
	grid.resize(grid_size.x)
	for x in range(grid_size.x):
		grid[x] = []
		grid[x].resize(grid_size.y)
		for y in range(grid_size.y):
			grid[x][y] = CellType.WALKABLE

func setup_astar():
	"""Configurar AStar2D con todos los puntos"""
	var point_id = 0
	
	# Agregar todos los puntos al AStar
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var world_pos = grid_to_world(Vector2i(x, y))
			astar.add_point(point_id, Vector2(world_pos.x, world_pos.z))
			point_id += 1
	
	# Conectar puntos adyacentes
	connect_adjacent_points()

func connect_adjacent_points():
	"""Conectar puntos caminables adyacentes"""
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			if grid[x][y] == CellType.OBSTACLE:
				continue
				
			var current_id = get_point_id(x, y)
			
			# Conectar con vecinos (4-direccional para simplicidad)
			var directions = [
				Vector2i(0, 1),   # Norte
				Vector2i(1, 0),   # Este  
				Vector2i(0, -1),  # Sur
				Vector2i(-1, 0)   # Oeste
			]
			
			for dir in directions:
				var next_x = x + dir.x
				var next_y = y + dir.y
				
				if is_valid_cell(next_x, next_y) and grid[next_x][next_y] != CellType.OBSTACLE:
					var next_id = get_point_id(next_x, next_y)
					
					if not astar.are_points_connected(current_id, next_id):
						astar.connect_points(current_id, next_id)

func scan_restaurant_layout():
	"""Escanear la escena para detectar obstáculos automáticamente"""
	var space_state = get_world_3d().direct_space_state
	
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var world_pos = grid_to_world(Vector2i(x, y))
			
			# Raycast hacia abajo para detectar si hay piso
			var query = PhysicsRayQueryParameters3D.create(
				world_pos + Vector3(0, 2, 0),
				world_pos + Vector3(0, -1, 0)
			)
			query.collision_mask = 1  # Layer del mundo
			
			var result = space_state.intersect_ray(query)
			
			if not result.is_empty():
				# Hay piso, verificar si hay obstáculos
				if is_position_blocked(world_pos):
					grid[x][y] = CellType.OBSTACLE
				else:
					# Determinar tipo específico
					grid[x][y] = determine_cell_type(world_pos)
	
	# Regenerar conexiones después del escaneo
	astar.clear()
	setup_astar()

func is_position_blocked(world_pos: Vector3) -> bool:
	"""Verificar si una posición está bloqueada por obstáculos"""
	var space_state = get_world_3d().direct_space_state
	
	# Crear una pequeña cápsula para detectar obstáculos
	var query = PhysicsShapeQueryParameters3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.2
	shape.height = 1.0
	query.shape = shape
	query.transform.origin = world_pos + Vector3(0, 0.5, 0)
	query.collision_mask = 1  # Layer del mundo
	
	var results = space_state.intersect_shape(query)
	
	# Filtrar resultados para ignorar el piso
	for result in results:
		var collider = result.collider
		if collider and not is_floor(collider):
			return true
	
	return false

func determine_cell_type(world_pos: Vector3) -> CellType:
	"""Determinar el tipo específico de celda basado en la posición"""
	# Área de entrada (cerca de la puerta)
	if world_pos.z > 2:
		return CellType.ENTRANCE
	
	# Área de cocina (lado derecho)
	if world_pos.x > 5:
		return CellType.KITCHEN_AREA
	
	# Áreas con mesas
	if has_table_nearby(world_pos):
		return CellType.TABLE
	
	return CellType.WALKABLE

func has_table_nearby(world_pos: Vector3) -> bool:
	"""Verificar si hay una mesa cerca de esta posición"""
	var tables = get_tree().get_nodes_in_group("tables")
	
	for table in tables:
		if table.global_position.distance_to(world_pos) < 2.0:
			return true
	
	return false

func is_floor(node: Node) -> bool:
	"""Verificar si un nodo es el piso (para ignorarlo en obstáculos)"""
	return node.name.to_lower().contains("floor") or node.name.to_lower().contains("piso")

# === FUNCIONES PRINCIPALES DE NAVEGACIÓN ===

func find_path(start_pos: Vector3, end_pos: Vector3) -> PackedVector3Array:
	"""Encontrar camino entre dos posiciones del mundo"""
	var start_grid = world_to_grid(start_pos)
	var end_grid = world_to_grid(end_pos)
	
	if not is_valid_cell(start_grid.x, start_grid.y) or not is_valid_cell(end_grid.x, end_grid.y):
		print("Posiciones fuera del grid")
		return PackedVector3Array()
	
	var start_id = get_point_id(start_grid.x, start_grid.y)
	var end_id = get_point_id(end_grid.x, end_grid.y)
	
	var path_2d = astar.get_point_path(start_id, end_id)
	
	# Convertir path 2D a 3D
	var path_3d = PackedVector3Array()
	for point in path_2d:
		path_3d.append(Vector3(point.x, start_pos.y, point.y))
	
	return path_3d

func find_nearest_walkable_position(target_pos: Vector3) -> Vector3:
	"""Encontrar la posición caminable más cercana a un objetivo"""
	var grid_pos = world_to_grid(target_pos)
	
	# Búsqueda en espiral desde la posición objetivo
	for radius in range(1, 5):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var check_x = grid_pos.x + x
				var check_y = grid_pos.y + y
				
				if is_valid_cell(check_x, check_y) and grid[check_x][check_y] != CellType.OBSTACLE:
					return grid_to_world(Vector2i(check_x, check_y))
	
	# Si no encuentra nada, devolver posición original
	return target_pos

func get_table_positions() -> Array[Vector3]:
	"""Obtener todas las posiciones de mesas disponibles"""
	var table_positions: Array[Vector3] = []
	
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			if grid[x][y] == CellType.TABLE:
				table_positions.append(grid_to_world(Vector2i(x, y)))
	
	return table_positions

func get_queue_position(queue_index: int) -> Vector3:
	"""Obtener posición en la cola de espera"""
	var entrance_pos = Vector3(-8, 0.5, 2)  # Posición base de la cola
	var offset = Vector3(0, 0, -1.5 * queue_index)  # Separación entre clientes en cola
	return entrance_pos + offset

# === FUNCIONES DE UTILIDAD ===

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	"""Convertir coordenadas del grid a posición del mundo"""
	return Vector3(
		grid_offset.x + grid_pos.x * cell_size,
		0.5,  # Altura fija del piso
		grid_offset.z + grid_pos.y * cell_size
	)

func world_to_grid(world_pos: Vector3) -> Vector2i:
	"""Convertir posición del mundo a coordenadas del grid"""
	return Vector2i(
		int((world_pos.x - grid_offset.x) / cell_size),
		int((world_pos.z - grid_offset.z) / cell_size)
	)

func get_point_id(x: int, y: int) -> int:
	"""Obtener ID único de un punto en el grid"""
	return y * grid_size.x + x

func is_valid_cell(x: int, y: int) -> bool:
	"""Verificar si las coordenadas del grid son válidas"""
	return x >= 0 and x < grid_size.x and y >= 0 and y < grid_size.y

func get_world_3d() -> World3D:
	"""Obtener el mundo 3D actual"""
	return get_tree().current_scene.get_world_3d()

# === FUNCIONES DE DEBUG ===

func debug_draw_grid():
	"""Dibujar el grid para debugging (llamar desde _draw de un Control)"""
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var world_pos = grid_to_world(Vector2i(x, y))
			var color = Color.GREEN
			
			match grid[x][y]:
				CellType.OBSTACLE:
					color = Color.RED
				CellType.TABLE:
					color = Color.BLUE
				CellType.KITCHEN_AREA:
					color = Color.YELLOW
				CellType.ENTRANCE:
					color = Color.PURPLE
				CellType.EXIT:
					color = Color.ORANGE
			
			# Aquí necesitarías código específico de Godot para dibujar en 3D
			# O crear debug markers como pequeños cubos de colores

func debug_path(start: Vector3, end: Vector3):
	"""Debug de un camino específico"""
	var path = find_path(start, end)
	print("Camino de ", start, " a ", end, ":")
	for i in range(path.size()):
		print("  [", i, "] ", path[i])
	print("Distancia total: ", calculate_path_distance(path))

func calculate_path_distance(path: PackedVector3Array) -> float:
	"""Calcular distancia total de un camino"""
	var total_distance = 0.0
	for i in range(1, path.size()):
		total_distance += path[i-1].distance_to(path[i])
	return total_distance
