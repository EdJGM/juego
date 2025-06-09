extends MultiMeshInstance3D

@export var tile_mesh: Mesh
@export var tile_spacing := Vector2(2, 2)
@export var regenerate := false : set = setup_tiles

func setup_tiles(value):
	if value:
		create_tile_grid()

func create_tile_grid():
	if not tile_mesh:
		print("Necesitas asignar un mesh de baldosa")
		return
	
	# Dimensiones estáticas del piso: size(30, 0.9, 12) scale(1)
	var floor_size = Vector2(30, 12)
	
	# Calcular número de baldosas
	var tiles_x = int(floor_size.x / tile_spacing.x)
	var tiles_z = int(floor_size.y / tile_spacing.y)
	var total_tiles = tiles_x * tiles_z
	
	print("Generando ", total_tiles, " baldosas (", tiles_x, "x", tiles_z, ")")
	
	# Configurar MultiMesh
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = tile_mesh
	multimesh.instance_count = total_tiles
	
	# Generar posiciones
	var index = 0
	for x in tiles_x:
		for z in tiles_z:
			var transform = Transform3D()
			transform.origin = Vector3(
				x * tile_spacing.x - floor_size.x * 0.5 + tile_spacing.x * 0.5,
				0.45,  # Justo encima del piso (altura 0.9 / 2)
				z * tile_spacing.y - floor_size.y * 0.5 + tile_spacing.y * 0.5
			)
			transform.basis = Basis().scaled(Vector3(1, 0.2, 1)) 
			multimesh.set_instance_transform(index, transform)
			index += 1
