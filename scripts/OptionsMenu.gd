extends Control

var config_manager

# Referencias a los controles de UI
@onready var tab_container = $VBoxContainer/TabContainer

# Tab de Audio
@onready var master_slider = $VBoxContainer/TabContainer/Audio/VBoxContainer/MasterVolume/HSlider
@onready var master_label = $VBoxContainer/TabContainer/Audio/VBoxContainer/MasterVolume/ValueLabel
@onready var music_slider = $VBoxContainer/TabContainer/Audio/VBoxContainer/MusicVolume/HSlider
@onready var music_label = $VBoxContainer/TabContainer/Audio/VBoxContainer/MusicVolume/ValueLabel
@onready var sfx_slider = $VBoxContainer/TabContainer/Audio/VBoxContainer/SFXVolume/HSlider
@onready var sfx_label = $VBoxContainer/TabContainer/Audio/VBoxContainer/SFXVolume/ValueLabel

# Tab de Video
@onready var fullscreen_check = $VBoxContainer/TabContainer/Video/VBoxContainer/FullscreenContainer/CheckBox
@onready var resolution_option = $VBoxContainer/TabContainer/Video/VBoxContainer/ResolutionContainer/OptionButton

# Tab de Controles
@onready var forward_button = $VBoxContainer/TabContainer/Controles/ScrollContainer/VBoxContainer/ForwardContainer/Button
@onready var backward_button = $VBoxContainer/TabContainer/Controles/ScrollContainer/VBoxContainer/BackwardContainer/Button
@onready var left_button = $VBoxContainer/TabContainer/Controles/ScrollContainer/VBoxContainer/LeftContainer/Button
@onready var right_button = $VBoxContainer/TabContainer/Controles/ScrollContainer/VBoxContainer/RightContainer/Button
@onready var jump_button = $VBoxContainer/TabContainer/Controles/ScrollContainer/VBoxContainer/JumpContainer/Button

# Botones principales
@onready var apply_button = $VBoxContainer/ButtonContainer/ApplyButton
@onready var cancel_button = $VBoxContainer/ButtonContainer/CancelButton
@onready var default_button = $VBoxContainer/ButtonContainer/DefaultButton

# Variables para remapeo de controles
var is_remapping = false
var action_to_remap = ""
var button_to_update = null

# Señal para cuando se cierre el menú
signal options_closed

func _ready():
	# Asegurarse de que ConfigManager esté en el árbol
	if not get_node_or_null("/root/ConfigManager"):
		get_tree().root.add_child(config_manager)
		config_manager.name = "ConfigManager"
	else:
		config_manager = get_node("/root/ConfigManager")
	
	setup_ui()
	load_current_settings()
	connect_signals()

func setup_ui():
	# Configurar sliders
	master_slider.min_value = 0
	master_slider.max_value = 100
	master_slider.step = 1
	
	music_slider.min_value = 0
	music_slider.max_value = 100
	music_slider.step = 1
	
	sfx_slider.min_value = 0
	sfx_slider.max_value = 100
	sfx_slider.step = 1
	
	# Llenar opciones de resolución
	resolution_option.clear()
	for res in config_manager.available_resolutions:
		resolution_option.add_item(str(int(res.x)) + "x" + str(int(res.y)))

func load_current_settings():
	# Cargar valores de audio
	master_slider.value = config_manager.master_volume * 100
	master_label.text = str(int(master_slider.value)) + "%"
	
	music_slider.value = config_manager.music_volume * 100
	music_label.text = str(int(music_slider.value)) + "%"
	
	sfx_slider.value = config_manager.sfx_volume * 100
	sfx_label.text = str(int(sfx_slider.value)) + "%"
	
	# Cargar valores de video
	fullscreen_check.button_pressed = config_manager.fullscreen
	
	# Encontrar la resolución actual en la lista
	for i in range(config_manager.available_resolutions.size()):
		if config_manager.available_resolutions[i] == config_manager.resolution:
			resolution_option.selected = i
			break
	
	# Cargar controles
	update_control_buttons()

func update_control_buttons():
	forward_button.text = config_manager.get_key_name(config_manager.key_bindings["move_forward"])
	backward_button.text = config_manager.get_key_name(config_manager.key_bindings["move_backward"])
	left_button.text = config_manager.get_key_name(config_manager.key_bindings["move_left"])
	right_button.text = config_manager.get_key_name(config_manager.key_bindings["move_right"])
	jump_button.text = config_manager.get_key_name(config_manager.key_bindings["jump"])

func connect_signals():
	# Audio
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	
	# Video
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	resolution_option.item_selected.connect(_on_resolution_selected)
	
	# Controles
	forward_button.pressed.connect(func(): start_key_remap("move_forward", forward_button))
	backward_button.pressed.connect(func(): start_key_remap("move_backward", backward_button))
	left_button.pressed.connect(func(): start_key_remap("move_left", left_button))
	right_button.pressed.connect(func(): start_key_remap("move_right", right_button))
	jump_button.pressed.connect(func(): start_key_remap("jump", jump_button))
	
	# Botones principales
	apply_button.pressed.connect(_on_apply_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	default_button.pressed.connect(_on_default_pressed)

# Callbacks de Audio
func _on_master_volume_changed(value):
	master_label.text = str(int(value)) + "%"
	config_manager.set_master_volume(value / 100.0)

func _on_music_volume_changed(value):
	music_label.text = str(int(value)) + "%"
	config_manager.set_music_volume(value / 100.0)

func _on_sfx_volume_changed(value):
	sfx_label.text = str(int(value)) + "%"
	config_manager.set_sfx_volume(value / 100.0)

# Callbacks de Video
func _on_fullscreen_toggled(pressed):
	config_manager.set_fullscreen(pressed)

func _on_resolution_selected(index):
	config_manager.set_resolution(config_manager.available_resolutions[index])

# Sistema de remapeo de controles
func start_key_remap(action: String, button: Button):
	if is_remapping:
		return
	
	is_remapping = true
	action_to_remap = action
	button_to_update = button
	button.text = "Presiona una tecla..."
	button.modulate = Color.YELLOW

func _input(event):
	if is_remapping and event is InputEventKey and event.pressed:
		config_manager.set_key_binding(action_to_remap, event.keycode)
		button_to_update.text = config_manager.get_key_name(event.keycode)
		button_to_update.modulate = Color.WHITE
		is_remapping = false
		action_to_remap = ""
		button_to_update = null
		get_viewport().set_input_as_handled()

# Botones principales
func _on_apply_pressed():
	config_manager.save_config()
	emit_signal("options_closed")
	queue_free()

func _on_cancel_pressed():
	config_manager.load_config()
	config_manager.apply_all_settings()
	emit_signal("options_closed")
	queue_free()

func _on_default_pressed():
	config_manager.reset_to_defaults()
	load_current_settings()
