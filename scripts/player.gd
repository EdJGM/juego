extends CharacterBody3D

@export_category("Player Movement")
@export var speed := 5.0
@export var jump_velocity := 4.5
const ROTATION_SPEED := 6.0

#slowly rotate the charcter to point in the direction of the camera_pivot
@onready var camera_pivot : Node3D = $camera_pivot
@onready var playermodel : Node3D = $playermodel

# Sistema de inventario
@onready var inventario : Inventario

enum animation_state {IDLE,RUNNING,JUMPING}
var player_animation_state : animation_state = animation_state.IDLE
@onready var animation_player : AnimationPlayer = $"playermodel/character-male-e2/AnimationPlayer"

# Variables de interacción
var objeto_cercano : ObjetoAgarrable = null
var objetos_detectados: Array = []

func _ready():
	print("Player inicializando...")
	
	# IMPORTANTE: Configurar las capas de colisión correctamente
	collision_layer = 2  # Player está en layer 2
	collision_mask = 1   # Player colisiona con mundo (layer 1)
	
	# Crear el inventario
	inventario = Inventario.new()
	inventario.name = "Inventario"
	add_child(inventario)
	
	# Agregar el jugador al grupo
	add_to_group("player")
	
	print("✓ Player configurado - Layer: ", collision_layer, ", Mask: ", collision_mask)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
		#player_animation_state = animation_state.JUMPING
		

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction = (camera_pivot.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		#now rotate the model
		rotate_model(direction, delta)
		player_animation_state = animation_state.RUNNING
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		player_animation_state = animation_state.IDLE
	
	if not is_on_floor():
		player_animation_state = animation_state.JUMPING
	
	move_and_slide()
	#tell the playeranimationcontroller about the animation state
	match player_animation_state:
		animation_state.IDLE:
			animation_player.play("idle")
		animation_state.RUNNING:
			animation_player.play("sprint")
		animation_state.JUMPING:
			animation_player.play("jump")

func _input(event):
	# Solo procesar eventos de teclado para evitar errores
	if not event is InputEventKey or not event.pressed:
		return
	
	# Manejar interacciones usando Input global
	if Input.is_action_just_pressed("interactuar"):  # Tecla F
		print("Player: Tecla F presionada")
		interactuar_con_objeto_cercano()
	elif Input.is_action_just_pressed("entregar_pedido"):  # Tecla E
		entregar_pedido()
	elif Input.is_action_just_pressed("limpiar_inventario"):  # Tecla C
		if inventario:
			inventario.limpiar_inventario()
	
	# Debug
	elif Input.is_action_just_pressed("ui_text_completion_accept"):  # Tab
		debug_player_estado()

func interactuar_con_objeto_cercano():
	# Buscar objetos cercanos usando múltiples métodos
	var objetos_cercanos = buscar_objetos_agarrables_cercanos()
	
	print("Player: Buscando objetos cercanos...")
	print("Objetos encontrados: ", objetos_cercanos.size())
	
	if objetos_cercanos.size() > 0:
		var objeto = objetos_cercanos[0]  # Tomar el más cercano
		print("Objeto más cercano: ", objeto.name, " - ", objeto.nombre_ingrediente)
		
		if objeto.puede_agarrarse and not objeto.siendo_agarrado:
			if inventario.puede_agregar_item():
				print("Intentando agarrar objeto...")
				objeto.agarrar_objeto()
			else:
				print("Inventario lleno")
		else:
			print("Objeto no se puede agarrar - puede_agarrarse: ", objeto.puede_agarrarse, ", siendo_agarrado: ", objeto.siendo_agarrado)
	else:
		print("No hay objetos cerca para agarrar")
		# Debug adicional
		debug_objetos_en_area()

func buscar_objetos_agarrables_cercanos() -> Array:
	var objetos_cercanos = []
	var radio_busqueda = 3.0
	
	# Buscar todos los ObjetoAgarrable en el nivel
	var objetos = get_tree().get_nodes_in_group("objetos_agarrables")
	
	print("Total objetos agarrables en escena: ", objetos.size())
	
	for objeto in objetos:
		if objeto and is_instance_valid(objeto):
			var distancia = global_position.distance_to(objeto.global_position)
			print("Objeto: ", objeto.name, " - Distancia: ", distancia, " - Visible: ", objeto.visible)
			
			if distancia <= radio_busqueda and objeto.visible and not objeto.siendo_agarrado:
				objetos_cercanos.append(objeto)
	
	# Ordenar por distancia
	objetos_cercanos.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	
	return objetos_cercanos

func debug_objetos_en_area():
	print("\n=== DEBUG OBJETOS EN ÁREA ===")
	print("Posición del jugador: ", global_position)
	print("Layer del jugador: ", collision_layer)
	print("Mask del jugador: ", collision_mask)
	
	var objetos = get_tree().get_nodes_in_group("objetos_agarrables")
	print("Total objetos agarrables: ", objetos.size())
	
	for i in range(objetos.size()):
		var objeto = objetos[i]
		if objeto and is_instance_valid(objeto):
			var distancia = global_position.distance_to(objeto.global_position)
			print("Objeto ", i, ":")
			print("  - Nombre: ", objeto.name)
			print("  - Ingrediente: ", objeto.nombre_ingrediente if "nombre_ingrediente" in objeto else "N/A")
			print("  - Posición: ", objeto.global_position)
			print("  - Distancia: ", distancia)
			print("  - Visible: ", objeto.visible if "visible" in objeto else "N/A")
			print("  - Puede agarrarse: ", objeto.puede_agarrarse if "puede_agarrarse" in objeto else "N/A")
			print("  - Siendo agarrado: ", objeto.siendo_agarrado if "siendo_agarrado" in objeto else "N/A")
			
			# Debug del área de detección
			if objeto.has_method("debug_objeto"):
				objeto.debug_objeto()
	
	print("=============================\n")

func entregar_pedido():
	if inventario:
		inventario.entregar_a_cliente_cercano()

func obtener_inventario() -> Inventario:
	return inventario

func rotate_model(direction: Vector3, delta : float) -> void:
	#rotate the model to match the springarm
	playermodel.basis = lerp(playermodel.basis, Basis.looking_at(direction), 10.0 * delta)

func debug_player_estado():
	print("\n=== DEBUG PLAYER ===")
	print("Posición: ", global_position)
	print("Layer: ", collision_layer)
	print("Mask: ", collision_mask)
	print("Grupo player: ", is_in_group("player"))
	print("Inventario: ", inventario != null)
	if inventario:
		var items = inventario.obtener_items()
		print("Items en inventario: ", items.size())
		for i in range(items.size()):
			var item = items[i]
			print("  [", i, "] ", item.nombre_ingrediente if item else "null")
	print("===================\n")

# Función para testing manual de agarrar objetos
func forzar_agarrar_objeto_cercano():
	var objetos = buscar_objetos_agarrables_cercanos()
	if objetos.size() > 0:
		var objeto = objetos[0]
		if objeto.has_method("forzar_deteccion_manual"):
			objeto.forzar_deteccion_manual()
		objeto.agarrar_objeto()
