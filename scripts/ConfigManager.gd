# ConfigManager.gd - Gestor de configuración básico
extends Node

# Configuración por defecto
var settings = {
	"audio": {
		"master_volume": 1.0,
		"music_volume": 1.0,
		"sfx_volume": 1.0
	},
	"graphics": {
		"fullscreen": false,
		"resolution": Vector2(1920, 1080),
		"vsync": true,
		"shadows": true,
		"antialiasing": true
	},
	"controls": {
		"mouse_sensitivity": 1.0,
		"invert_y": false,
		"keybindings": {}  # Guardará las teclas personalizadas
	},
	"game": {
		"difficulty": 1,  # 0: Fácil, 1: Normal, 2: Difícil
		"language": "es",
		"subtitles": true
	}
}

const CONFIG_FILE_PATH = "user://game_settings.cfg"

func _ready():
	# Crear buses de audio si no existen
	ensure_audio_buses()
	# Cargar configuración guardada
	load_config()
	# Aplicar configuración inicial
	apply_all_settings()

func ensure_audio_buses():
	# Asegurar que existan los buses de audio necesarios
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
		print("✓ Bus 'Music' creado")
	
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")
		print("✓ Bus 'SFX' creado")

# Funciones de Audio
func get_master_volume() -> float:
	return settings.audio.master_volume

func set_master_volume(value: float):
	settings.audio.master_volume = clamp(value, 0.0, 1.0)
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(settings.audio.master_volume))

func get_music_volume() -> float:
	return settings.audio.music_volume

func set_music_volume(value: float):
	settings.audio.music_volume = clamp(value, 0.0, 1.0)
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(settings.audio.music_volume))

func get_sfx_volume() -> float:
	return settings.audio.sfx_volume

func set_sfx_volume(value: float):
	settings.audio.sfx_volume = clamp(value, 0.0, 1.0)
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(settings.audio.sfx_volume))

# Funciones de Gráficos
func is_fullscreen() -> bool:
	return settings.graphics.fullscreen

func set_fullscreen(value: bool):
	settings.graphics.fullscreen = value
	if value:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func get_resolution() -> Vector2:
	return settings.graphics.resolution

func set_resolution(value: Vector2):
	settings.graphics.resolution = value
	if not is_fullscreen():
		DisplayServer.window_set_size(Vector2i(value.x, value.y))

func set_vsync(value: bool):
	settings.graphics.vsync = value
	if value:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

# Funciones de Controles
func get_mouse_sensitivity() -> float:
	return settings.controls.mouse_sensitivity

func set_mouse_sensitivity(value: float):
	settings.controls.mouse_sensitivity = clamp(value, 0.1, 3.0)

# Funciones de Juego
func get_difficulty() -> int:
	return settings.game.difficulty

func set_difficulty(value: int):
	settings.game.difficulty = clamp(value, 0, 2)

func get_language() -> String:
	return settings.game.language

func set_language(value: String):
	settings.game.language = value

func get_quality() -> int:
	# 0: Baja, 1: Media, 2: Alta, 3: Ultra
	return 2  # Por defecto Alta

func set_quality(value: int):
	# Aquí puedes implementar cambios de calidad gráfica
	pass

# Guardar y Cargar
func save_config():
	var config = ConfigFile.new()
	
	# Audio
	config.set_value("audio", "master_volume", settings.audio.master_volume)
	config.set_value("audio", "music_volume", settings.audio.music_volume)
	config.set_value("audio", "sfx_volume", settings.audio.sfx_volume)
	
	# Gráficos
	config.set_value("graphics", "fullscreen", settings.graphics.fullscreen)
	config.set_value("graphics", "resolution", settings.graphics.resolution)
	config.set_value("graphics", "vsync", settings.graphics.vsync)
	config.set_value("graphics", "shadows", settings.graphics.shadows)
	config.set_value("graphics", "antialiasing", settings.graphics.antialiasing)
	
	# Controles
	config.set_value("controls", "mouse_sensitivity", settings.controls.mouse_sensitivity)
	config.set_value("controls", "invert_y", settings.controls.invert_y)
	
	# Guardar keybindings
	save_keybindings_to_config(config)
	
	# Juego
	config.set_value("game", "difficulty", settings.game.difficulty)
	config.set_value("game", "language", settings.game.language)
	config.set_value("game", "subtitles", settings.game.subtitles)
	
	var error = config.save(CONFIG_FILE_PATH)
	if error == OK:
		print("✓ Configuración guardada")
	else:
		print("❌ Error al guardar configuración: ", error)

func save_keybindings_to_config(config: ConfigFile):
	var keybindings = {}
	var actions = ["up", "down", "left", "right", "ui_accept", "interactuar", "entregar_pedido"]
	
	for action in actions:
		if InputMap.has_action(action):
			var events = InputMap.action_get_events(action)
			if events.size() > 0 and events[0] is InputEventKey:
				keybindings[action] = events[0].keycode
	
	config.set_value("controls", "keybindings", keybindings)

func save_keybindings():
	save_config()  # Guardar toda la configuración incluyendo las teclas

func load_config():
	var config = ConfigFile.new()
	var error = config.load(CONFIG_FILE_PATH)
	
	if error != OK:
		print("⚠️ No se pudo cargar configuración, usando valores por defecto")
		return
	
	# Audio
	settings.audio.master_volume = config.get_value("audio", "master_volume", 1.0)
	settings.audio.music_volume = config.get_value("audio", "music_volume", 1.0)
	settings.audio.sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
	
	# Gráficos
	settings.graphics.fullscreen = config.get_value("graphics", "fullscreen", false)
	settings.graphics.resolution = config.get_value("graphics", "resolution", Vector2(1920, 1080))
	settings.graphics.vsync = config.get_value("graphics", "vsync", true)
	settings.graphics.shadows = config.get_value("graphics", "shadows", true)
	settings.graphics.antialiasing = config.get_value("graphics", "antialiasing", true)
	
	# Controles
	settings.controls.mouse_sensitivity = config.get_value("controls", "mouse_sensitivity", 1.0)
	settings.controls.invert_y = config.get_value("controls", "invert_y", false)
	
	# Cargar keybindings
	var keybindings = config.get_value("controls", "keybindings", {})
	load_keybindings_from_config(keybindings)
	
	# Juego
	settings.game.difficulty = config.get_value("game", "difficulty", 1)
	settings.game.language = config.get_value("game", "language", "es")
	settings.game.subtitles = config.get_value("game", "subtitles", true)
	
	print("✓ Configuración cargada")

func load_keybindings_from_config(keybindings: Dictionary):
	for action in keybindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		
		# Limpiar eventos actuales
		InputMap.action_erase_events(action)
		
		# Añadir el nuevo evento
		var event = InputEventKey.new()
		event.keycode = keybindings[action]
		InputMap.action_add_event(action, event)
		
		print("✓ Tecla cargada: ", action, " = ", OS.get_keycode_string(keybindings[action]))

func apply_all_settings():
	# Aplicar audio
	set_master_volume(settings.audio.master_volume)
	set_music_volume(settings.audio.music_volume)
	set_sfx_volume(settings.audio.sfx_volume)
	
	# Aplicar gráficos
	set_fullscreen(settings.graphics.fullscreen)
	if not settings.graphics.fullscreen:
		set_resolution(settings.graphics.resolution)
	set_vsync(settings.graphics.vsync)
	
	print("✓ Configuración aplicada")

func apply_audio_settings():
	set_master_volume(settings.audio.master_volume)
	set_music_volume(settings.audio.music_volume)
	set_sfx_volume(settings.audio.sfx_volume)

# Utilidad
func linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)
