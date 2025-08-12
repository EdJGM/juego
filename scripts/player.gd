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

# Control estricto de una acción por vez
var procesando_interaccion: bool = false
var ultimo_tiempo_interaccion: float = 0.0
var cooldown_interaccion: float = 1.0  # 1 segundo entre interacciones

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
	
	# Manejar interacciones usando Input global con control estricto
	if Input.is_action_just_pressed("interactuar"):  # Tecla F
		var tiempo_actual = Time.get_ticks_msec() / 1000.0
		
		# Verificar si ya estamos procesando o en cooldown
		if procesando_interaccion:
			print("🚫 PLAYER: Ya procesando interacción, ignorando...")
			return
			
		if tiempo_actual - ultimo_tiempo_interaccion < cooldown_interaccion:
			print("🚫 PLAYER: En cooldown, ignorando...")
			return
		
		print("🎯 PLAYER: Tecla F presionada - INICIANDO interacción")
		ultimo_tiempo_interaccion = tiempo_actual
		procesando_interaccion = true
		interactuar_con_objeto_cercano()
	elif Input.is_action_just_pressed("entregar_pedido"):  # Tecla E
		entregar_pedido()
	elif Input.is_action_just_pressed("limpiar_inventario"):  # Tecla C
		if inventario:
			inventario.limpiar_inventario()

func interactuar_con_objeto_cercano():
	print("🔄 PLAYER: === INICIANDO INTERACCIÓN ===")
	
	# Buscar objetos cercanos
	var objetos_cercanos = buscar_objetos_agarrables_cercanos()
	print("🎯 PLAYER: Objetos encontrados: ", objetos_cercanos.size())
	
	# GARANTIZAR QUE SOLO PROCESAMOS 1 OBJETO
	if objetos_cercanos.size() > 0:
		var objeto = objetos_cercanos[0]  # SOLO el primero
		print("🎯 PLAYER: Procesando objeto: ", objeto.nombre_ingrediente)
		
		if objeto.puede_agarrarse:
			if inventario.puede_agregar_item():
				print("🎯 PLAYER: Creando UN SOLO clon...")
				# Crear clon directamente aquí para control total
				var clon = objeto.crear_clon_para_inventario()
				if clon:
					if inventario.agregar_item(clon):
						print("✅ PLAYER: EXACTAMENTE 1 objeto agregado")
					else:
						clon.queue_free()
						print("❌ PLAYER: Error al agregar al inventario")
				else:
					print("❌ PLAYER: Error al crear clon")
			else:
				print("❌ PLAYER: Inventario lleno")
		else:
			print("❌ PLAYER: Objeto no se puede agarrar")
	else:
		print("❌ PLAYER: No hay objetos cerca")
	
	# RESETEAR FLAG AL FINAL
	procesando_interaccion = false
	print("🔄 PLAYER: === INTERACCIÓN COMPLETADA ===")

func buscar_objetos_agarrables_cercanos() -> Array:
	var objetos_cercanos = []
	var radio_busqueda = 2.5  # Radio más pequeño para más precisión
	
	# Buscar todos los ObjetoAgarrable en el nivel
	var objetos = get_tree().get_nodes_in_group("objetos_agarrables")
	
	for objeto in objetos:
		if objeto and is_instance_valid(objeto):
			var distancia = global_position.distance_to(objeto.global_position)
			
			# Solo objetos cercanos, visibles y no siendo agarrados
			if distancia <= radio_busqueda and objeto.visible and objeto.puede_agarrarse:
				objetos_cercanos.append(objeto)
	
	# Ordenar por distancia - el más cercano primero
	objetos_cercanos.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	
	# LIMITAR A SOLO 1 OBJETO - el más cercano
	if objetos_cercanos.size() > 1:
		objetos_cercanos = [objetos_cercanos[0]]
	
	return objetos_cercanos

func entregar_pedido():
	if inventario:
		inventario.entregar_a_cliente_cercano()

func obtener_inventario() -> Inventario:
	return inventario

func rotate_model(direction: Vector3, delta : float) -> void:
	#rotate the model to match the springarm
	playermodel.basis = lerp(playermodel.basis, Basis.looking_at(direction), 10.0 * delta)
