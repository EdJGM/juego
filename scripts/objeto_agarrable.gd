# objeto_agarrable.gd - CORRECCIONES APLICADAS
extends RigidBody3D
class_name ObjetoAgarrable

# Señales
signal objeto_agarrado(objeto)
signal objeto_soltado(objeto)
signal jugador_cerca_cambiado(cerca)

# Variables del objeto
@export var nombre_ingrediente: String = ""
@export var es_ingrediente: bool = true
@export var puede_agarrarse: bool = true
@export var valor_nutricional: int = 10
@export var tiempo_coccion: float = 0.0
@export var requiere_corte: bool = false

# Estados
var siendo_agarrado: bool = false
var jugador_cerca: bool = false
var posicion_original: Vector3
var rotacion_original: Vector3
var resaltado: bool = false

# Referencias
var jugador_actual: Node = null
var area_deteccion: Area3D
var indicador_interaccion: Node3D

func _ready():
	print("ObjetoAgarrable inicializando: ", name)
	
	# IMPORTANTE: Solo inicializar si estamos en el juego real
	var scene_manager = get_node_or_null("/root/SceneManager")
	if scene_manager and scene_manager.es_menu():
		print("Objeto en menú - saltando inicialización")
		return
	
	# Configurar propiedades del RigidBody3D
	configurar_propiedades_fisicas()
	
	# Guardar posición original
	posicion_original = global_position
	rotacion_original = rotation
	
	# Detectar nombre del ingrediente si no está establecido
	if es_ingrediente and nombre_ingrediente.is_empty():
		detectar_nombre_desde_escena()
	
	# Agregar al grupo
	if not is_in_group("objetos_agarrables"):
		add_to_group("objetos_agarrables")
	
	# IMPORTANTE: Asegurar que el objeto sea visible inicialmente
	visible = true
	collision_layer = 4
	collision_mask = 1
	
	# Crear área de detección y esperar a que esté lista
	await get_tree().process_frame
	crear_area_deteccion_mejorada()
	
	# Crear indicador de interacción
	await get_tree().process_frame
	crear_indicador_interaccion()
	
	print("✓ ObjetoAgarrable configurado: ", nombre_ingrediente)

func _process(_delta):
	# Verificar input cada frame si el jugador está cerca
	if jugador_cerca and puede_agarrarse and not siendo_agarrado:
		if Input.is_action_just_pressed("interactuar"):
			print("PROCESO: Tecla F detectada para ", nombre_ingrediente)
			intentar_agarrar()

func configurar_propiedades_fisicas():
	"""Configura las propiedades físicas del objeto"""
	collision_layer = 4  # Layer objetos_agarrables
	collision_mask = 1   # Colisiona con mundo
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	lock_rotation = true
	gravity_scale = 0.0  # Sin gravedad para evitar que se caigan
	mass = 0.5
	
	# Asegurar que no esté congelado inicialmente
	freeze = false

func crear_area_deteccion_mejorada():
	"""Crea el área de detección mejorada para el jugador - RADIO REDUCIDO"""
	# Eliminar área anterior si existe
	if has_node("AreaDeteccion"):
		$AreaDeteccion.queue_free()
	
	# Crear nueva área
	area_deteccion = Area3D.new()
	area_deteccion.name = "AreaDeteccion"
	add_child(area_deteccion)
	
	# Configurar área
	area_deteccion.collision_layer = 0  # No colisiona con nada
	area_deteccion.collision_mask = 2   # Solo detecta jugadores (layer 2)
	area_deteccion.monitoring = true
	area_deteccion.monitorable = false
	
	# CORRECCIÓN 1: Crear forma de colisión MÁS PEQUEÑA
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 1.2  # REDUCIDO de 2.0 a 1.2
	collision_shape.shape = sphere_shape
	collision_shape.name = "DetectionShape"
	
	area_deteccion.add_child(collision_shape)
	
	# Conectar señales con one-shot disabled para múltiples detecciones
	area_deteccion.body_entered.connect(_on_jugador_entro)
	area_deteccion.body_exited.connect(_on_jugador_salio)
	
	print("✓ Área de detección mejorada creada para ", name, " con radio: ", sphere_shape.radius)

func crear_indicador_interaccion():
	"""Crea un indicador visual para la interacción"""
	# Eliminar indicador anterior si existe
	if has_node("IndicadorInteraccion"):
		$IndicadorInteraccion.queue_free()
	
	indicador_interaccion = Label3D.new()
	indicador_interaccion.name = "IndicadorInteraccion"
	indicador_interaccion.text = "[F] " + nombre_ingrediente
	indicador_interaccion.font_size = 16
	indicador_interaccion.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	indicador_interaccion.position = Vector3(0, 2.0, 0)  # Más alto
	indicador_interaccion.visible = false
	indicador_interaccion.modulate = Color.YELLOW
	
	# Configurar el material del texto para que sea más visible
	indicador_interaccion.material_override = StandardMaterial3D.new()
	var material = indicador_interaccion.material_override as StandardMaterial3D
	material.flags_unshaded = true
	material.albedo_color = Color.YELLOW
	
	add_child(indicador_interaccion)
	print("✓ Indicador creado para ", name, " con texto: ", indicador_interaccion.text)

func detectar_nombre_desde_escena():
	"""Detecta el tipo de ingrediente desde el nombre de la escena o nodo"""
	var nombre_detectado = ""
	
	# Primero intentar desde el archivo de escena
	if scene_file_path != "":
		var filename = scene_file_path.get_file().get_basename()
		nombre_detectado = filename
	
	# Si no, usar el nombre del nodo
	if nombre_detectado.is_empty():
		nombre_detectado = name
	
	# Limpiar y procesar el nombre
	nombre_detectado = nombre_detectado.to_lower()
	
	# Detectar tipo específico
	if "bun" in nombre_detectado:
		if "bottom" in nombre_detectado:
			nombre_ingrediente = "food_ingredient_bun_bottom"
		elif "top" in nombre_detectado:
			nombre_ingrediente = "food_ingredient_bun_top"
		else:
			nombre_ingrediente = "food_ingredient_bun"
	elif "burger" in nombre_detectado:
		if "vegetable" in nombre_detectado:
			nombre_ingrediente = "food_ingredient_vegetableburger_cooked"
		elif "uncooked" in nombre_detectado or "raw" in nombre_detectado:
			nombre_ingrediente = "food_ingredient_burger_uncooked"
			tiempo_coccion = 15.0
		else:
			nombre_ingrediente = "food_ingredient_burger_cooked"
	elif "tomato" in nombre_detectado:
		if "slice" in nombre_detectado:
			nombre_ingrediente = "food_ingredient_tomato_slice"
		else:
			nombre_ingrediente = "food_ingredient_tomato"
			requiere_corte = true
	elif "lettuce" in nombre_detectado:
		if "slice" in nombre_detectado:
			nombre_ingrediente = "food_ingredient_lettuce_slice"
		else:
			nombre_ingrediente = "food_ingredient_lettuce"
			requiere_corte = true
	elif "cheese" in nombre_detectado:
		if "slice" in nombre_detectado:
			nombre_ingrediente = "food_ingredient_cheese_slice"
		else:
			nombre_ingrediente = "food_ingredient_cheese"
			requiere_corte = true
	elif "crate" in nombre_detectado:
		# Detectar tipo de caja
		if "buns" in nombre_detectado:
			nombre_ingrediente = "food_ingredient_bun"
		elif "tomatoes" in nombre_detectado:
			nombre_ingrediente = "food_ingredient_tomato"
		elif "lettuce" in nombre_detectado:
			nombre_ingrediente = "food_ingredient_lettuce"
		elif "cheese" in nombre_detectado:
			nombre_ingrediente = "food_ingredient_cheese"
	else:
		nombre_ingrediente = nombre_detectado.replace("_", "")
	
	print("Ingrediente detectado: ", nombre_ingrediente)

func _on_jugador_entro(body):
	print("Algo entró en el área: ", body.name, " - Es jugador: ", body.is_in_group("player"))
	
	if body.is_in_group("player") and puede_agarrarse and not siendo_agarrado:
		jugador_cerca = true
		jugador_actual = body
		mostrar_indicador_interaccion(true)
		jugador_cerca_cambiado.emit(true)
		print("✓ Jugador cerca de ", nombre_ingrediente)

func _on_jugador_salio(body):
	if body.is_in_group("player") and body == jugador_actual:
		jugador_cerca = false
		jugador_actual = null
		mostrar_indicador_interaccion(false)
		jugador_cerca_cambiado.emit(false)
		print("Jugador se alejó de ", nombre_ingrediente)

func mostrar_indicador_interaccion(mostrar: bool):
	"""Muestra u oculta el indicador de interacción"""
	if indicador_interaccion:
		indicador_interaccion.visible = mostrar and puede_agarrarse and not siendo_agarrado
		print("Indicador ", name, " visible: ", indicador_interaccion.visible)
	
	# Cambiar el resaltado del objeto
	cambiar_resaltado(mostrar and puede_agarrarse and not siendo_agarrado)

func cambiar_resaltado(activar: bool):
	"""Cambia el resaltado visual del objeto"""
	if activar == resaltado:
		return
	
	resaltado = activar
	var mesh_instance = encontrar_mesh_instance()
	
	if mesh_instance:
		if resaltado:
			# Para MeshInstance3D necesitamos cambiar el material, no modulate
			if mesh_instance.material_override == null:
				# Crear un material básico si no existe
				var material = StandardMaterial3D.new()
				material.albedo_color = Color(1.3, 1.3, 1.0)  # Tinte amarillento
				mesh_instance.material_override = material
			else:
				# Si ya tiene material, modificar el color
				var material = mesh_instance.material_override
				if material is StandardMaterial3D:
					material.albedo_color = Color(1.3, 1.3, 1.0)
		else:
			# Restaurar material original
			mesh_instance.material_override = null
		print("Resaltado cambiado para ", name, ": ", activar)

func encontrar_mesh_instance() -> MeshInstance3D:
	"""Busca recursivamente un MeshInstance3D en los hijos"""
	return buscar_mesh_recursivo(self)

func buscar_mesh_recursivo(node: Node) -> MeshInstance3D:
	"""Búsqueda recursiva de MeshInstance3D"""
	if node is MeshInstance3D:
		return node
	
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		elif child.get_child_count() > 0:
			var found = buscar_mesh_recursivo(child)
			if found:
				return found
	return null

func _input(event):
	# Solo procesar eventos de teclado para evitar errores con mouse motion
	if not event is InputEventKey or not event.pressed:
		return
		
	# Solo procesar input si el objeto no está siendo agarrado y estamos en juego
	var scene_manager = get_node_or_null("/root/SceneManager")
	if scene_manager and scene_manager.es_menu():
		return
		
	if not jugador_cerca or not puede_agarrarse or siendo_agarrado:
		return
	
	if Input.is_action_just_pressed("interactuar"):  # Tecla F
		print("Tecla F presionada cerca de ", nombre_ingrediente)
		intentar_agarrar()

func intentar_agarrar():
	"""Intenta que el jugador agarre este objeto"""
	if not jugador_actual or siendo_agarrado:
		print("No se puede agarrar: jugador=", jugador_actual != null, ", siendo_agarrado=", siendo_agarrado)
		return
	
	print("Intentando agarrar objeto: ", nombre_ingrediente)
	
	# Verificar que el jugador tenga inventario
	var inventario = null
	if jugador_actual.has_method("obtener_inventario"):
		inventario = jugador_actual.obtener_inventario()
	
	if not inventario:
		print("ERROR: Jugador no tiene inventario")
		return
	
	if not inventario.puede_agregar_item():
		print("ADVERTENCIA: Inventario del jugador está lleno")
		return
	
	# Agarrar el objeto
	agarrar_objeto(inventario)

func agarrar_objeto(inventario: Inventario = null):
	"""Proceso de agarrar el objeto"""
	if siendo_agarrado:
		print("ERROR: Objeto ya está siendo agarrado")
		return
	
	# Obtener inventario si no se pasó como parámetro
	if not inventario and jugador_actual and jugador_actual.has_method("obtener_inventario"):
		inventario = jugador_actual.obtener_inventario()
	
	if not inventario:
		print("ERROR: No se pudo obtener inventario para agarrar objeto")
		return
	
	print("Agarrando objeto: ", nombre_ingrediente)
	
	# Agregar al inventario PRIMERO
	if inventario.agregar_item(self):
		# Solo después de agregarlo exitosamente, cambiar estado
		siendo_agarrado = true
		freeze = true
		
		# Ocultar el objeto en el mundo
		visible = false
		collision_layer = 0
		collision_mask = 0
		
		# Ocultar indicadores
		mostrar_indicador_interaccion(false)
		
		# Deshabilitar área de detección
		if area_deteccion:
			area_deteccion.monitoring = false
		
		objeto_agarrado.emit(self)
		print("✓ Objeto agarrado exitosamente: ", nombre_ingrediente)
	else:
		print("ERROR: No se pudo agregar al inventario")

func soltar_objeto(nueva_posicion: Vector3 = Vector3.ZERO):
	"""CORRECCIÓN 3: Suelta el objeto y lo ELIMINA en lugar de dejarlo en el mundo"""
	if not siendo_agarrado:
		print("ADVERTENCIA: Objeto no estaba siendo agarrado")
		return
	
	print("Eliminando objeto entregado: ", nombre_ingrediente)
	
	# Cambiar estado PRIMERO
	siendo_agarrado = false
	
	# OPCIÓN A: ELIMINAR EL OBJETO COMPLETAMENTE (RECOMENDADO)
	objeto_soltado.emit(self)
	queue_free()  # Eliminar el objeto para siempre
	
	# OPCIÓN B: Si prefieres que regrese a su posición original, descomenta esto y comenta lo de arriba:
	# restaurar_a_posicion_original()

func restaurar_a_posicion_original():
	"""Alternativa: restaurar el objeto a su posición original"""
	freeze = false
	visible = true
	collision_layer = 4
	collision_mask = 1
	
	# Reactivar área de detección
	if area_deteccion:
		area_deteccion.monitoring = true
	
	# Restaurar posición original
	global_position = posicion_original
	rotation = rotacion_original
	
	objeto_soltado.emit(self)
	print("✓ Objeto restaurado a posición original: ", nombre_ingrediente)

# Resto de funciones sin cambios importantes
func obtener_info() -> Dictionary:
	return {
		"nombre": nombre_ingrediente,
		"es_ingrediente": es_ingrediente,
		"valor": valor_nutricional,
		"tipo": detectar_tipo_ingrediente(),
		"puede_agarrarse": puede_agarrarse,
		"siendo_agarrado": siendo_agarrado,
		"requiere_corte": requiere_corte,
		"tiempo_coccion": tiempo_coccion,
		"jugador_cerca": jugador_cerca
	}

func detectar_tipo_ingrediente() -> String:
	var nombre = nombre_ingrediente.to_lower()
	
	if "bun" in nombre:
		return "pan"
	elif "burger" in nombre or "meat" in nombre:
		return "carne"
	elif "lettuce" in nombre:
		return "lechuga"
	elif "tomato" in nombre:
		return "tomate"
	elif "cheese" in nombre:
		return "queso"
	elif "vegetableburger" in nombre:
		return "carne"
	else:
		return "generico"

func debug_objeto():
	print("\n=== DEBUG OBJETO AGARRABLE ===")
	print("Nombre: ", name)
	print("Ingrediente: ", nombre_ingrediente)
	print("Posición: ", global_position)
	print("Visible: ", visible)
	print("Collision layer: ", collision_layer)
	print("Siendo agarrado: ", siendo_agarrado)
	print("Jugador cerca: ", jugador_cerca)
	print("Puede agarrarse: ", puede_agarrarse)
	if area_deteccion:
		print("Área detección activa: ", area_deteccion.monitoring)
		print("Bodies en área: ", area_deteccion.get_overlapping_bodies().size())
		for body in area_deteccion.get_overlapping_bodies():
			print("  - ", body.name, " (grupo player: ", body.is_in_group("player"), ")")
	else:
		print("NO HAY ÁREA DE DETECCIÓN")
	print("=============================\n")

# Función para forzar detección (debugging)
func forzar_deteccion_manual():
	if not area_deteccion:
		return
	
	var bodies = area_deteccion.get_overlapping_bodies()
	print("Detección manual - Bodies encontrados: ", bodies.size())
	for body in bodies:
		if body.is_in_group("player"):
			_on_jugador_entro(body)
			break
