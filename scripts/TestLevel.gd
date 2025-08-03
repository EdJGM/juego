# TestLevel.gd - CON DEBUGGING MEJORADO
extends Node3D

# Referencias
var game_manager: Node
var player: CharacterBody3D
var objetos_agarrables: Array = []
var hud: Node
var inicializado: bool = false

func _ready():
	# Verificar si estamos en el juego real usando el SceneManager
	var scene_manager = get_node_or_null("/root/SceneManager")
	if scene_manager and scene_manager.es_menu():
		return
	
	# También verificar por nombre de escena como fallback
	var scene_name = get_tree().current_scene.name
	if scene_name.contains("MainMenu") or get_parent().name.contains("Background"):
		return
	
	# Evitar inicialización múltiple
	if inicializado:
		return
	
	inicializado = true
	
	# Esperar un frame para que todos los nodos estén listos
	await get_tree().process_frame
	
	# Obtener o crear GameManager
	configurar_game_manager()
	
	# Configurar el nivel
	configurar_nivel()
	
	# Configurar objetos agarrables
	configurar_objetos_agarrables()
	
	# Configurar HUD
	configurar_hud()
	
	# Configurar estaciones de trabajo
	configurar_estaciones_cocina()
	
	

func configurar_game_manager():
	# Obtener GameManager del autoload
	game_manager = get_node_or_null("/root/GameManager")
	

func configurar_nivel():
	# Buscar el jugador de manera más robusta
	player = encontrar_jugador_en_escena()
	
	if not player:
		print("ERROR: No se encontró el jugador")
		return
	
	print("✓ Jugador encontrado: ", player.name)
	
	# Asegurar que el jugador esté en el grupo correcto
	if not player.is_in_group("player"):
		player.add_to_group("player")
		print("✓ Jugador agregado al grupo 'player'")
	
	# Agregar mesas al grupo "tables"
	configurar_mesas()

func configurar_mesas():
	var mesas = [
		"geometry/CSGBox3D/table_round_A_decorated2",
		"geometry/CSGBox3D/table_round_A_decorated3",
		"geometry/CSGBox3D/table_round_A_small_decorated2",
		"geometry/CSGBox3D/table_round_A_small_decorated3"
		# Agrega aquí todas las rutas de tus mesas
	]
	for mesa_path in mesas:
		var mesa = get_node_or_null(mesa_path)
		if mesa:
			mesa.add_to_group("tables")
			print("✓ Mesa agregada al grupo 'tables': ", mesa.name, " - Posición: ", mesa.global_position)
		else:
			print("⚠️ No se encontró la mesa en la ruta: ", mesa_path)

func encontrar_jugador_en_escena() -> CharacterBody3D:
	# Buscar por nombre específico primero
	var jugador_nodo = get_node_or_null("Player")
	if jugador_nodo and jugador_nodo is CharacterBody3D:
		return jugador_nodo
	
	# Buscar recursivamente
	return buscar_jugador_recursivo(self)

func buscar_jugador_recursivo(nodo: Node) -> CharacterBody3D:
	# Verificar si el nodo actual es el jugador
	if nodo.name == "Player" and nodo is CharacterBody3D:
		return nodo
	
	# Si es CharacterBody3D y tiene script de jugador
	if nodo is CharacterBody3D and nodo.get_script():
		var script_path = nodo.get_script().resource_path
		if "player" in script_path.to_lower():
			return nodo
	
	# Buscar en los hijos
	for child in nodo.get_children():
		var resultado = buscar_jugador_recursivo(child)
		if resultado:
			return resultado
	
	return null

func configurar_hud():
	if not player:
		print("No se puede configurar HUD sin jugador")
		return
	
	# Buscar el HUD en el jugador
	hud = player.get_node_or_null("Hud")
	
	if hud:
		print("✓ HUD encontrado y configurado")
	else:
		print("⚠️ HUD no encontrado en el jugador")

func configurar_objetos_agarrables():
	
	# Limpiar la lista primero
	objetos_agarrables.clear()
	
	# Buscar objetos que ya son RigidBody3D y están en el grupo
	var objetos_preparados = get_tree().get_nodes_in_group("objetos_agarrables")
	
	for objeto in objetos_preparados:
		if objeto is RigidBody3D:
			objetos_agarrables.append(objeto)

func buscar_ingredientes_recursivo(nodo: Node, lista_ingredientes: Array):
	# Verificar por nombre del nodo
	var nombre_nodo = nodo.name.to_lower()
	if "food_ingredient" in nombre_nodo or "crate_" in nombre_nodo:
		if nodo not in lista_ingredientes:  # Evitar duplicados
			lista_ingredientes.append(nodo)
		return
	
	# Verificar por ruta del archivo de escena
	if nodo.scene_file_path != "":
		var scene_path = nodo.scene_file_path.to_lower()
		if "food_ingredient" in scene_path or ("crate" in scene_path and "food" in scene_path):
			if nodo not in lista_ingredientes:  # Evitar duplicados
				lista_ingredientes.append(nodo)
			return
	
	# Buscar en todos los hijos
	for child in nodo.get_children():
		buscar_ingredientes_recursivo(child, lista_ingredientes)

func configurar_ingrediente_como_agarrable(nodo: Node):
	# Verificar si ya tiene el script de objeto agarrable
	if nodo.get_script() and nodo.get_script().resource_path.contains("objeto_agarrable"):
		objetos_agarrables.append(nodo)
		return
	
	# Verificar el tipo de nodo actual
	var rigid_body = nodo
	
	print("Procesando nodo: ", nodo.name, " (tipo: ", nodo.get_class(), ")")
	
	if nodo is StaticBody3D:
		rigid_body = convertir_static_a_rigid(nodo)
		if not rigid_body:
			print("ERROR: No se pudo convertir ", nodo.name, " a RigidBody3D")
			return
	elif not nodo is RigidBody3D:
		print("ADVERTENCIA: ", nodo.name, " es ", nodo.get_class(), " - creando RigidBody3D wrapper")
		rigid_body = crear_rigid_body_wrapper(nodo)
		if not rigid_body:
			return
	
	# Agregar el script de objeto agarrable si no lo tiene
	if not rigid_body.get_script():
		var script_agarrable = load("res://scripts/objeto_agarrable.gd")
		if script_agarrable:
			rigid_body.set_script(script_agarrable)
			print("✓ Script agarrable agregado a ", rigid_body.name)
		else:
			print("ERROR: No se pudo cargar el script objeto_agarrable.gd")
			return
	
	# Agregar al grupo de objetos agarrables
	if not rigid_body.is_in_group("objetos_agarrables"):
		rigid_body.add_to_group("objetos_agarrables")
	
	# Configurar propiedades del RigidBody3D de manera más explícita
	var rb = rigid_body as RigidBody3D
	rb.collision_layer = 4  # Layer objetos_agarrables
	rb.collision_mask = 1   # Colisiona con mundo
	rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	rb.lock_rotation = true
	rb.gravity_scale = 0.0  # Sin gravedad
	rb.freeze = false
	rb.visible = true
	
	# Asegurar que tenga CollisionShape3D
	configurar_fisica_ingrediente_mejorada(rigid_body)
	
	# Configurar nombre del ingrediente
	configurar_nombre_ingrediente(rigid_body)
	
	objetos_agarrables.append(rigid_body)
	print("✓ Ingrediente configurado: ", rigid_body.name)

func configurar_fisica_ingrediente_mejorada(nodo: RigidBody3D):
	"""Configuración mejorada de física para ingredientes"""
	# Verificar que tenga un CollisionShape3D
	var collision_shape = null
	
	# Buscar recursivamente por CollisionShape3D
	collision_shape = buscar_collision_shape_recursivo(nodo)
	
	if not collision_shape:
		print("Creando CollisionShape3D para: ", nodo.name)
		# Crear CollisionShape3D automáticamente
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		
		# Intentar encontrar un MeshInstance3D para crear la forma
		var mesh_instance = buscar_mesh_instance_recursivo(nodo)
		
		if mesh_instance and mesh_instance.mesh:
			print("Creando forma basada en mesh para: ", nodo.name)
			# Crear forma basada en el mesh (más simple que trimesh)
			var box_shape = BoxShape3D.new()
			var aabb = mesh_instance.get_aabb()
			if aabb.size.length() > 0:
				box_shape.size = aabb.size
			else:
				box_shape.size = Vector3(0.5, 0.5, 0.5)  # Tamaño por defecto
			collision_shape.shape = box_shape
		else:
			print("Creando forma básica para: ", nodo.name)
			# Crear una forma básica
			var box_shape = BoxShape3D.new()
			box_shape.size = Vector3(0.5, 0.5, 0.5)
			collision_shape.shape = box_shape
		
		nodo.add_child(collision_shape)
		print("✓ CollisionShape3D agregado a: ", nodo.name)
	else:
		print("✓ CollisionShape3D ya existe para: ", nodo.name)

func buscar_collision_shape_recursivo(nodo: Node) -> CollisionShape3D:
	"""Busca recursivamente un CollisionShape3D"""
	if nodo is CollisionShape3D:
		return nodo
	
	for child in nodo.get_children():
		if child is CollisionShape3D:
			return child
		else:
			var result = buscar_collision_shape_recursivo(child)
			if result:
				return result
	
	return null

func buscar_mesh_instance_recursivo(nodo: Node) -> MeshInstance3D:
	if nodo is MeshInstance3D:
		return nodo
	
	for child in nodo.get_children():
		var result = buscar_mesh_instance_recursivo(child)
		if result:
			return result
	
	return null

func crear_rigid_body_wrapper(nodo_original: Node) -> RigidBody3D:
	"""Crea un RigidBody3D que envuelve un nodo que no es físico"""
	var rigid_body = RigidBody3D.new()
	var parent = nodo_original.get_parent()
	
	if not parent:
		print("ERROR: Nodo original no tiene parent")
		return null
	
	# IMPORTANTE: Guardar la posición GLOBAL original antes de mover
	var posicion_global_original = nodo_original.global_position
	var rotacion_global_original = nodo_original.global_rotation
	var escala_original = nodo_original.scale
	
	print("Posición original de ", nodo_original.name, ": ", posicion_global_original)
	
	# Configurar el nuevo RigidBody3D con la posición correcta
	rigid_body.name = nodo_original.name + "_Grabbable"
	
	# Reparentar el nodo original al RigidBody3D PRIMERO
	var original_index = nodo_original.get_index()
	parent.remove_child(nodo_original)
	parent.add_child(rigid_body)
	parent.move_child(rigid_body, original_index)
	
	# DESPUÉS configurar la posición del RigidBody3D
	rigid_body.global_position = posicion_global_original
	rigid_body.global_rotation = rotacion_global_original
	rigid_body.scale = escala_original
	
	# Ahora agregar el nodo original como hijo
	rigid_body.add_child(nodo_original)
	
	# Resetear la transformada del nodo original ya que ahora es hijo
	nodo_original.position = Vector3.ZERO
	nodo_original.rotation = Vector3.ZERO
	nodo_original.scale = Vector3.ONE
	
	print("✓ Wrapper RigidBody3D creado para: ", nodo_original.name, " en posición: ", rigid_body.global_position)
	return rigid_body

func convertir_static_a_rigid(static_body: StaticBody3D) -> RigidBody3D:
	"""Convierte un StaticBody3D a RigidBody3D manteniendo sus propiedades"""
	var rigid_body = RigidBody3D.new()
	var parent = static_body.get_parent()
	if not parent:
		print("ERROR: StaticBody3D no tiene parent")
		return null
	
	var index = static_body.get_index()
	
	# IMPORTANTE: Copiar la transformada completa ANTES de hacer cambios
	var posicion_original = static_body.global_position
	var rotacion_original = static_body.global_rotation
	var escala_original = static_body.scale
	
	print("Convirtiendo ", static_body.name, " desde posición: ", posicion_original)
	
	# Copiar propiedades básicas
	rigid_body.name = static_body.name
	
	# Mover todos los hijos al nuevo nodo
	var children_to_move = []
	for child in static_body.get_children():
		children_to_move.append(child)
	
	for child in children_to_move:
		static_body.remove_child(child)
		rigid_body.add_child(child)
	
	# Reemplazar en la escena
	parent.remove_child(static_body)
	parent.add_child(rigid_body)
	parent.move_child(rigid_body, index)
	
	# DESPUÉS aplicar la transformada
	rigid_body.global_position = posicion_original
	rigid_body.global_rotation = rotacion_original
	rigid_body.scale = escala_original
	
	# Limpiar el viejo nodo
	static_body.queue_free()
	
	print("✓ Convertido a RigidBody3D en posición: ", rigid_body.global_position)
	return rigid_body

func configurar_nombre_ingrediente(nodo: Node):
	# Detectar el tipo de ingrediente basado en el nombre
	var nombre = nodo.name.to_lower()
	var ingrediente_detectado = ""
	
	if "bun" in nombre:
		if "bottom" in nombre:
			ingrediente_detectado = "food_ingredient_bun_bottom"
		elif "top" in nombre:
			ingrediente_detectado = "food_ingredient_bun_top"
		else:
			ingrediente_detectado = "food_ingredient_bun"
	elif "burger" in nombre:
		if "vegetable" in nombre:
			ingrediente_detectado = "food_ingredient_vegetableburger_cooked"
		else:
			ingrediente_detectado = "food_ingredient_burger_cooked"
	elif "tomato" in nombre:
		ingrediente_detectado = "food_ingredient_tomato"
	elif "lettuce" in nombre:
		ingrediente_detectado = "food_ingredient_lettuce"
	elif "cheese" in nombre:
		ingrediente_detectado = "food_ingredient_cheese"
	elif "crate_buns" in nombre:
		ingrediente_detectado = "food_ingredient_bun"
	elif "crate_tomatoes" in nombre:
		ingrediente_detectado = "food_ingredient_tomato"
	else:
		ingrediente_detectado = nombre.replace("_", "")
	
	# Configurar propiedades del ingrediente si tiene el script
	if nodo.has_method("detectar_nombre_desde_escena"):
		nodo.nombre_ingrediente = ingrediente_detectado
		print("✓ Nombre configurado: ", ingrediente_detectado)

func configurar_estaciones_cocina():
	print("Configurando estaciones de cocina...")
	
	# Buscar y configurar la estufa
	var estufa = get_node_or_null("geometry/CSGBox3D/stove_multi2")
	if estufa:
		configurar_estacion_coccion(estufa, "estufa")
		print("✓ Estufa configurada")
	
	# Buscar mesas que puedan usarse como estaciones de corte
	var mesas_cocina = []
	buscar_mesas_cocina(self, mesas_cocina)
	
	for mesa in mesas_cocina:
		configurar_estacion_corte(mesa)
	
	print("✓ ", mesas_cocina.size(), " estaciones de corte configuradas")

func buscar_mesas_cocina(nodo: Node, lista_mesas: Array):
	var nombre = nodo.name.to_lower()
	if "kitchentable" in nombre and not "sink" in nombre:
		if nodo not in lista_mesas:  # Evitar duplicados
			lista_mesas.append(nodo)
			print("Mesa de cocina encontrada: ", nodo.name)
	
	for child in nodo.get_children():
		buscar_mesas_cocina(child, lista_mesas)

func configurar_estacion_coccion(estacion: Node, tipo: String):
	estacion.add_to_group("estacion_coccion")
	estacion.add_to_group("estacion_" + tipo)
	
	# Agregar área de interacción si no existe
	if not estacion.has_node("AreaInteraccion"):
		var area = Area3D.new()
		area.name = "AreaInteraccion"
		
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(3, 2, 3)
		collision.shape = shape
		
		area.add_child(collision)
		estacion.add_child(area)
		
		area.collision_layer = 0
		area.collision_mask = 2  # Layer del jugador
		
		print("✓ Área de interacción agregada a ", estacion.name)

func configurar_estacion_corte(mesa: Node):
	mesa.add_to_group("estacion_corte")
	
	# Agregar área de interacción
	if not mesa.has_node("AreaInteraccion"):
		var area = Area3D.new()
		area.name = "AreaInteraccion"
		
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(2, 1, 2)
		collision.shape = shape
		collision.position.y = 1
		
		area.add_child(collision)
		mesa.add_child(area)
		
		area.collision_layer = 0
		area.collision_mask = 2  # Layer del jugador
