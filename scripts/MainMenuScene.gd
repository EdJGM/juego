# MainMenuScene.gd - Contenedor del menú y fondo
extends Node3D

@export var background_scene: PackedScene = preload("res://addons/srcoder_thirdperson_controller/scenes/test_level.tscn")
@export var menu_music: AudioStream = preload("res://Musica/Jazz In Paris.mp3")

@onready var camera = $Camera3D
@onready var ui_layer = $UILayer
@onready var main_menu = $UILayer/MainMenu
@onready var background_instance = $Background3D
@onready var music_player = $MusicPlayer

var rotation_speed = 0.2
var es_menu_principal = true

func _ready():
	print("MainMenuScene inicializando...")

	# Asegurar ConfigManager
	if not get_node_or_null("/root/ConfigManager"):
		var config_manager = preload("res://scripts/ConfigManager.gd").new()
		get_tree().root.add_child(config_manager)
		config_manager.name = "ConfigManager"
		print("✓ ConfigManager cargado")

	es_menu_principal = get_tree().current_scene == self or get_tree().current_scene.name.contains("MainMenu")

	if es_menu_principal:
		print("Configurando menú principal...")
		configurar_menu_principal()
	else:
		print("Este no es el menú principal")

func configurar_menu_principal():
	# (Se quitó mostrar cursor a pedido)
	setup_music()
	apply_volume_settings()

	if background_instance:
		disable_background_cameras(background_instance)
		disable_background_ui(background_instance)
		disable_player_controls(background_instance)
		disable_interactables(background_instance)

	setup_ui()
	setup_camera()
	setup_skybox()

func apply_volume_settings():
	var config_manager = get_node_or_null("/root/ConfigManager")
	if config_manager:
		if AudioServer.get_bus_index("Music") == -1:
			AudioServer.add_bus()
			var idx := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, "Music")
			AudioServer.set_bus_send(idx, "Master")
			print("✓ Bus de música creado")
		if music_player:
			music_player.bus = "Music"
		config_manager.apply_audio_settings()

func setup_skybox():
	if not has_node("MenuSkyEnvironment"):
		var env = WorldEnvironment.new()
		env.name = "MenuSkyEnvironment"
		var environment = Environment.new()
		environment.background_mode = Environment.BG_SKY

		var sky_material = ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color(0.05, 0.05, 0.2)
		sky_material.sky_horizon_color = Color(0.6, 0.4, 0.3)
		sky_material.ground_bottom_color = Color(0.1, 0.1, 0.1)
		sky_material.ground_horizon_color = Color(0.3, 0.2, 0.2)
		sky_material.sun_angle_max = 30
		sky_material.sun_curve = 0.15

		var sky = Sky.new()
		sky.sky_material = sky_material
		environment.sky = sky

		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment.glow_enabled = true
		environment.glow_intensity = 0.3
		environment.glow_bloom = 0.1
		environment.ambient_light_color = Color(0.3, 0.3, 0.4)
		environment.ambient_light_energy = 0.5

		env.environment = environment
		add_child(env)

func disable_background_cameras(node):
	if not es_menu_principal:
		return
	for child in node.get_children():
		if child is Camera3D and child != camera:
			child.current = false
			print("Cámara del fondo desactivada: ", child.name)
		disable_background_cameras(child)

func disable_background_ui(node):
	if not es_menu_principal:
		return
	if node.has_node("CanvasLayer"):
		var canvas_layer = node.get_node("CanvasLayer")
		canvas_layer.visible = false
		print("Interfaz de usuario del fondo desactivada")
	for child in node.get_children():
		if child is CanvasLayer and child.get_parent() != ui_layer:
			child.visible = false
			print("Interfaz de usuario adicional desactivada")
		else:
			disable_background_ui(child)

func disable_player_controls(node):
	if not es_menu_principal:
		return
	if node.has_node("Player"):
		var player = node.get_node("Player")
		player.process_mode = Node.PROCESS_MODE_DISABLED
		print("Jugador desactivado")
	for child in node.get_children():
		if child.name.to_lower().contains("player") or child.name.to_lower().contains("cliente"):
			child.process_mode = Node.PROCESS_MODE_DISABLED
			print("Entidad interactiva desactivada: ", child.name)
		else:
			disable_player_controls(child)

func disable_interactables(node):
	if not es_menu_principal:
		return
	for child in node.get_children():
		if child is Timer:
			child.paused = true
			print("Temporizador pausado: ", child.name)
		if child is Area3D or child is RigidBody3D:
			child.process_mode = Node.PROCESS_MODE_DISABLED
			print("Objeto interactivo desactivado: ", child.name)
		if child.get_script() != null:
			child.set_process(false)
			child.set_physics_process(false)
			child.set_process_input(false)
			print("Scripts desactivados para: ", child.name)
		disable_interactables(child)

func setup_camera():
	if not camera: return
	camera.position = Vector3(-2, 6, 10)
	camera.look_at(Vector3.UP, Vector3.UP)
	camera.current = true

func setup_music():
	if not music_player or not menu_music:
		print("⚠️ MusicPlayer o menu_music no encontrado")
		return
	music_player.stream = menu_music
	music_player.play()
	print("✓ Música del menú iniciada")

func setup_ui():
	if not main_menu:
		print("ERROR: MainMenu no encontrado")
		return
	if main_menu.has_signal("start_game") and not main_menu.start_game.is_connected(_on_start_game):
		main_menu.start_game.connect(_on_start_game)
	if main_menu.has_signal("quit_game") and not main_menu.quit_game.is_connected(_on_quit_game):
		main_menu.quit_game.connect(_on_quit_game)
	print("✓ UI del menú configurada")

func _process(delta):
	if es_menu_principal and background_instance:
		background_instance.rotate_y(rotation_speed * delta)

func _on_start_game():
	print("Iniciando juego...")
	get_tree().change_scene_to_file("res://addons/srcoder_thirdperson_controller/scenes/test_level.tscn")

func _on_quit_game():
	print("Saliendo del juego...")
	get_tree().quit()
