# Script para MainMenuScene.gd - CORREGIDO
extends Node3D

@export var background_scene: PackedScene = preload("res://addons/srcoder_thirdperson_controller/scenes/test_level.tscn")
@export var menu_music: AudioStream = preload("res://Musica/Jazz In Paris.mp3") 
@onready var camera = $Camera3D
@onready var ui_layer = $UILayer
@onready var main_menu = $UILayer/MainMenu
@onready var background_instance = $Background3D  
@onready var music_player = $MusicPlayer

var rotation_speed = 0.2  # Velocidad de rotación
var es_menu_principal = true  # Flag para identificar si esto es el menú

func _ready():
	print("MainMenuScene inicializando...")
	
	# Verificar si realmente estamos en el menú principal
	es_menu_principal = get_tree().current_scene == self or get_tree().current_scene.name.contains("MainMenu")
	
	if es_menu_principal:
		print("Configurando menú principal...")
		configurar_menu_principal()
	else:
		print("Este es el juego real, no aplicando lógica de menú")

func configurar_menu_principal():
	# Habilitar el mouse para el menú principal
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Configurar y reproducir música
	setup_music()

	# Solo deshabilitar funcionalidades si realmente es el menú de fondo
	if background_instance:
		disable_background_cameras(background_instance)
		disable_background_ui(background_instance)
		disable_player_controls(background_instance)
		disable_interactables(background_instance)
	
	setup_ui()
	setup_camera()
	setup_skybox()

func setup_skybox():
	# Crear un WorldEnvironment si no existe
	if not has_node("MenuSkyEnvironment"):
		var env = WorldEnvironment.new()
		env.name = "MenuSkyEnvironment"
		
		# Crear un nuevo environment
		var environment = Environment.new()
		
		# Configurar el cielo
		environment.background_mode = Environment.BG_SKY
		
		# Opción 1: Cielo procedural (atardecer urbano)
		var sky_material = ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color(0.05, 0.05, 0.2)  # Azul oscuro arriba
		sky_material.sky_horizon_color = Color(0.6, 0.4, 0.3)  # Naranja en el horizonte
		sky_material.ground_bottom_color = Color(0.1, 0.1, 0.1)  # Suelo oscuro
		sky_material.ground_horizon_color = Color(0.3, 0.2, 0.2)  # Horizonte urbano
		sky_material.sun_angle_max = 30
		sky_material.sun_curve = 0.15
		
		var sky = Sky.new()
		sky.sky_material = sky_material
		environment.sky = sky
		
		# Ajustes adicionales para mejorar la apariencia
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment.glow_enabled = true
		environment.glow_intensity = 0.3
		environment.glow_bloom = 0.1
		environment.ambient_light_color = Color(0.3, 0.3, 0.4)
		environment.ambient_light_energy = 0.5
		
		# Asignar el entorno al nodo
		env.environment = environment
		add_child(env)

# Función para desactivar cámaras SOLO en el menú
func disable_background_cameras(node):
	if not es_menu_principal:
		return
		
	for child in node.get_children():
		if child is Camera3D and child != camera:  # No desactivar la cámara del menú
			child.current = false
			print("Cámara del fondo desactivada: ", child.name)
		
		# Buscar en todos los hijos recursivamente
		disable_background_cameras(child)

# Desactivar toda la interfaz de usuario SOLO en el menú
func disable_background_ui(node):
	if not es_menu_principal:
		return
		
	if node.has_node("CanvasLayer"):
		var canvas_layer = node.get_node("CanvasLayer")
		canvas_layer.visible = false
		print("Interfaz de usuario del fondo desactivada")
	
	# Buscar recursivamente
	for child in node.get_children():
		if child is CanvasLayer and child.get_parent() != ui_layer:  # No desactivar UI del menú
			child.visible = false
			print("Interfaz de usuario adicional desactivada")
		else:
			disable_background_ui(child)

# Desactivar al jugador y sus controles SOLO en el menú
func disable_player_controls(node):
	if not es_menu_principal:
		return
		
	if node.has_node("Player"):
		var player = node.get_node("Player")
		player.process_mode = Node.PROCESS_MODE_DISABLED
		print("Jugador desactivado")
	
	if node.has_node("MouseLock"):
		var mouse_lock = node.get_node("MouseLock")
		mouse_lock.process_mode = Node.PROCESS_MODE_DISABLED
		print("MouseLock desactivado")
	
	# Buscar recursivamente
	for child in node.get_children():
		if child.name.to_lower().contains("player") or child.name.to_lower().contains("cliente"):
			child.process_mode = Node.PROCESS_MODE_DISABLED
			print("Entidad interactiva desactivada: ", child.name)
		else:
			disable_player_controls(child)

# Desactivar elementos interactivos SOLO en el menú
func disable_interactables(node):
	if not es_menu_principal:
		return
		
	# Desactivar temporizadores
	for child in node.get_children():
		if child is Timer:
			child.paused = true
			print("Temporizador pausado: ", child.name)
		
		# Desactivar áreas y cuerpos físicos
		if child is Area3D or child is RigidBody3D:
			child.process_mode = Node.PROCESS_MODE_DISABLED
			print("Objeto interactivo desactivado: ", child.name)
		
		# Desactivar scripts que podrían tener funcionalidad
		if child.get_script() != null:
			child.set_process(false)
			child.set_physics_process(false)
			child.set_process_input(false)
			print("Scripts desactivados para: ", child.name)
		
		disable_interactables(child)

func setup_camera():
	if not camera:
		return
		
	# La cámara debe estar posicionada para mostrar bien la escena
	camera.position = Vector3(-2, 6, 10)  # Ajusta según tu escena
	camera.look_at(Vector3.UP, Vector3.UP)
	camera.current = true

func setup_music():
	if not music_player or not menu_music:
		print("⚠️ MusicPlayer o menu_music no encontrado")
		return
		
	music_player.stream = menu_music
	music_player.play()
	music_player.stop()
	print("✓ Música del menú iniciada")

func setup_ui():
	if not main_menu:
		print("ERROR: MainMenu no encontrado")
		return
		
	# Conectar señales del menú
	if main_menu.has_signal("start_game"):
		if not main_menu.start_game.is_connected(_on_start_game):
			main_menu.start_game.connect(_on_start_game)
	
	if main_menu.has_signal("quit_game"):
		if not main_menu.quit_game.is_connected(_on_quit_game):
			main_menu.quit_game.connect(_on_quit_game)
	
	print("✓ UI del menú configurada")

func _process(delta):
	# Solo rotar el fondo si estamos en el menú principal
	if es_menu_principal and background_instance:
		background_instance.rotate_y(rotation_speed * delta)

func _on_start_game():
	print("Iniciando juego...")
	
	# Fade out de la música (opcional)
	if music_player and music_player.playing:
		fade_out_music()
		
	# Cambiar a la escena real del juego
	get_tree().change_scene_to_file("res://addons/srcoder_thirdperson_controller/scenes/test_level.tscn")

# Función opcional para hacer un fade out de la música
func fade_out_music():
	if not music_player:
		return
		
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, 1.0)
	tween.tween_callback(music_player.stop)

func _on_quit_game():
	print("Saliendo del juego...")
	get_tree().quit()
