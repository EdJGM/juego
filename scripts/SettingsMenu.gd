# SettingsMenu.gd - Menú de configuración CORREGIDO
extends Control

signal settings_closed

@onready var config_manager = get_node_or_null("/root/ConfigManager")

# Referencias UI
var panel: Panel
var title_label: Label
var tab_container: TabContainer

# Audio
var master_slider: HSlider
var master_label: Label
var music_slider: HSlider
var music_label: Label
var sfx_slider: HSlider
var sfx_label: Label
var mute_all_check: CheckBox

# Video
var fullscreen_check: CheckBox
var resolution_option: OptionButton

# Controles
var controls_list: VBoxContainer
var control_buttons: Dictionary = {}
var is_remapping: bool = false
var action_to_remap: String = ""
var button_to_update: Button = null

# Botones
var apply_button: Button
var back_button: Button

# Colores temáticos de cafetería
var COLOR_COFFEE_DARK = Color("#3E2723")
var COLOR_COFFEE = Color("#6D4C41")
var COLOR_COFFEE_LIGHT = Color("#8D6E63")
var COLOR_CREAM = Color("#FFF8E1")
var COLOR_GREEN = Color("#689F38")
var COLOR_GREEN_HOVER = Color("#7CB342")
var COLOR_RED = Color("#D32F2F")

var resolutions = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

# IMPORTANTE: Usar las acciones correctas del juego
var control_actions = {
	"up": "Mover Adelante",
	"down": "Mover Atrás",
	"left": "Mover Izquierda",
	"right": "Mover Derecha",
	"ui_accept": "Saltar",
	"interactuar": "Interactuar (F)",
	"entregar_pedido": "Entregar (E)"
}

func _ready():
	if config_manager == null:
		await get_tree().process_frame
		config_manager = get_node_or_null("/root/ConfigManager")
	
	# Asegurar que las acciones existan
	ensure_input_actions()
	
	create_ui()
	load_current_settings()
	connect_signals()

func ensure_input_actions():
	# Asegurar que todas las acciones existan en el InputMap
	for action in control_actions.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			# Añadir teclas por defecto
			match action:
				"up":
					var event = InputEventKey.new()
					event.keycode = KEY_W
					InputMap.action_add_event(action, event)
				"down":
					var event = InputEventKey.new()
					event.keycode = KEY_S
					InputMap.action_add_event(action, event)
				"left":
					var event = InputEventKey.new()
					event.keycode = KEY_A
					InputMap.action_add_event(action, event)
				"right":
					var event = InputEventKey.new()
					event.keycode = KEY_D
					InputMap.action_add_event(action, event)
				"interactuar":
					var event = InputEventKey.new()
					event.keycode = KEY_F
					InputMap.action_add_event(action, event)
				"entregar_pedido":
					var event = InputEventKey.new()
					event.keycode = KEY_E
					InputMap.action_add_event(action, event)

func create_ui():
	# CENTRAR EL PANEL CORRECTAMENTE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Panel principal con estilo cafetería
	panel = Panel.new()
	panel.name = "SettingsPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.size = Vector2(700, 500)
	panel.position = Vector2(-350, -250)  # Centrado
	panel.z_index = 100
	
	# Estilo del panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = COLOR_CREAM
	panel_style.border_color = COLOR_COFFEE_DARK
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(15)
	panel_style.set_expand_margin_all(10)
	panel_style.shadow_color = Color(0, 0, 0, 0.3)
	panel_style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	
	# Contenedor principal
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 15)
	panel.add_child(main_vbox)
	
	# Título
	title_label = Label.new()
	title_label.text = "⚙️ CONFIGURACIÓN"
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", COLOR_COFFEE_DARK)
	title_label.add_theme_color_override("font_shadow_color", COLOR_COFFEE_LIGHT)
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title_label)
	
	# Separador decorativo
	var separator = HSeparator.new()
	separator.add_theme_color_override("color", COLOR_COFFEE)
	separator.add_theme_constant_override("separation", 3)
	main_vbox.add_child(separator)
	
	# Tab Container con estilo
	tab_container = TabContainer.new()
	tab_container.custom_minimum_size.y = 320
	var tab_style = StyleBoxFlat.new()
	tab_style.bg_color = Color(COLOR_CREAM.r, COLOR_CREAM.g, COLOR_CREAM.b, 0.5)
	tab_style.set_corner_radius_all(10)
	tab_container.add_theme_stylebox_override("panel", tab_style)
	
	# Estilo para las pestañas
	var tab_selected = StyleBoxFlat.new()
	tab_selected.bg_color = COLOR_GREEN
	tab_selected.set_corner_radius_all(8)
	tab_container.add_theme_stylebox_override("tab_selected", tab_selected)
	
	var tab_unselected = StyleBoxFlat.new()
	tab_unselected.bg_color = COLOR_COFFEE_LIGHT
	tab_unselected.set_corner_radius_all(8)
	tab_container.add_theme_stylebox_override("tab_unselected", tab_unselected)
	
	tab_container.add_theme_color_override("font_selected_color", COLOR_CREAM)
	tab_container.add_theme_color_override("font_unselected_color", COLOR_CREAM)
	
	main_vbox.add_child(tab_container)
	
	# Crear pestañas
	create_audio_tab(tab_container)
	create_video_tab(tab_container)
	create_controls_tab(tab_container)
	
	# Botones de acción
	create_action_buttons(main_vbox)

func create_audio_tab(parent: TabContainer):
	var audio_panel = VBoxContainer.new()
	audio_panel.name = "🔊 Audio"
	audio_panel.add_theme_constant_override("separation", 20)
	parent.add_child(audio_panel)
	
	# Checkbox de Mute All
	mute_all_check = CheckBox.new()
	mute_all_check.text = "🔇 Silenciar Todo"
	mute_all_check.add_theme_font_size_override("font_size", 18)
	mute_all_check.add_theme_color_override("font_color", COLOR_COFFEE_DARK)
	audio_panel.add_child(mute_all_check)
	
	var separator = HSeparator.new()
	audio_panel.add_child(separator)
	
	# Volumen Maestro
	var master_container = create_slider_container("Volumen General", COLOR_COFFEE)
	master_slider = master_container.get_child(1)
	master_label = master_container.get_child(2)
	audio_panel.add_child(master_container)
	
	# Volumen Música
	var music_container = create_slider_container("Música de Fondo", COLOR_COFFEE)
	music_slider = music_container.get_child(1)
	music_label = music_container.get_child(2)
	audio_panel.add_child(music_container)
	
	# Volumen Efectos
	var sfx_container = create_slider_container("Efectos de Sonido", COLOR_COFFEE)
	sfx_slider = sfx_container.get_child(1)
	sfx_label = sfx_container.get_child(2)
	audio_panel.add_child(sfx_container)

func create_slider_container(label_text: String, color: Color) -> HBoxContainer:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 10)
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 180
	label.add_theme_color_override("font_color", COLOR_COFFEE_DARK)
	container.add_child(label)
	
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = 1.0
	slider.custom_minimum_size.x = 250
	
	# CORREGIR COLORES DE SLIDER - Hacer la barra visible
	var slider_bg = StyleBoxFlat.new()
	slider_bg.bg_color = COLOR_COFFEE_LIGHT
	slider_bg.content_margin_top = 8
	slider_bg.content_margin_bottom = 8
	slider_bg.set_corner_radius_all(3)
	
	var slider_fg = StyleBoxFlat.new()
	slider_fg.bg_color = COLOR_GREEN
	slider_fg.set_corner_radius_all(3)
	
	var grabber_style = StyleBoxFlat.new()
	grabber_style.bg_color = COLOR_COFFEE_DARK
	grabber_style.set_corner_radius_all(10)
	grabber_style.content_margin_left = 10
	grabber_style.content_margin_right = 10
	grabber_style.content_margin_top = 10
	grabber_style.content_margin_bottom = 10
	
	var grabber_highlight = StyleBoxFlat.new()
	grabber_highlight.bg_color = COLOR_GREEN
	grabber_highlight.set_corner_radius_all(10)
	grabber_highlight.content_margin_left = 10
	grabber_highlight.content_margin_right = 10
	grabber_highlight.content_margin_top = 10
	grabber_highlight.content_margin_bottom = 10
	
	slider.add_theme_stylebox_override("slider", slider_bg)
	slider.add_theme_stylebox_override("grabber_area", slider_fg)
	slider.add_theme_stylebox_override("grabber", grabber_style)
	slider.add_theme_stylebox_override("grabber_highlight", grabber_highlight)
	
	container.add_child(slider)
	
	var value_label = Label.new()
	value_label.text = "100%"
	value_label.custom_minimum_size.x = 60
	value_label.add_theme_color_override("font_color", COLOR_COFFEE_DARK)
	value_label.add_theme_font_size_override("font_size", 16)
	container.add_child(value_label)
	
	return container

func create_video_tab(parent: TabContainer):
	var video_panel = VBoxContainer.new()
	video_panel.name = "🖥️ Pantalla"
	video_panel.add_theme_constant_override("separation", 25)
	parent.add_child(video_panel)
	
	# Pantalla completa
	fullscreen_check = CheckBox.new()
	fullscreen_check.text = "Pantalla Completa"
	fullscreen_check.add_theme_font_size_override("font_size", 18)
	fullscreen_check.add_theme_color_override("font_color", COLOR_COFFEE_DARK)
	video_panel.add_child(fullscreen_check)
	
	# Resolución
	var resolution_container = HBoxContainer.new()
	resolution_container.add_theme_constant_override("separation", 20)
	video_panel.add_child(resolution_container)
	
	var resolution_label = Label.new()
	resolution_label.text = "Resolución:"
	resolution_label.custom_minimum_size.x = 150
	resolution_label.add_theme_font_size_override("font_size", 18)
	resolution_label.add_theme_color_override("font_color", COLOR_COFFEE_DARK)
	resolution_container.add_child(resolution_label)
	
	resolution_option = OptionButton.new()
	resolution_option.custom_minimum_size = Vector2(200, 40)
	
	# Estilo del OptionButton
	var option_style = StyleBoxFlat.new()
	option_style.bg_color = COLOR_COFFEE_LIGHT
	option_style.set_corner_radius_all(8)
	option_style.set_border_width_all(2)
	option_style.border_color = COLOR_COFFEE_DARK
	resolution_option.add_theme_stylebox_override("normal", option_style)
	
	for res in resolutions:
		resolution_option.add_item(str(int(res.x)) + "x" + str(int(res.y)))
	
	resolution_container.add_child(resolution_option)

func create_controls_tab(parent: TabContainer):
	var controls_panel = ScrollContainer.new()
	controls_panel.name = "🎮 Controles"
	parent.add_child(controls_panel)
	
	controls_list = VBoxContainer.new()
	controls_list.add_theme_constant_override("separation", 15)
	controls_panel.add_child(controls_list)
	
	var info_label = Label.new()
	info_label.text = "Haz clic en un botón para cambiar la tecla"
	info_label.add_theme_color_override("font_color", COLOR_COFFEE)
	info_label.add_theme_font_size_override("font_size", 14)
	controls_list.add_child(info_label)
	
	# Crear botones para cada acción
	for action in control_actions:
		var control_container = HBoxContainer.new()
		control_container.add_theme_constant_override("separation", 20)
		
		var action_label = Label.new()
		action_label.text = control_actions[action] + ":"
		action_label.custom_minimum_size.x = 200
		action_label.add_theme_color_override("font_color", COLOR_COFFEE_DARK)
		action_label.add_theme_font_size_override("font_size", 16)
		control_container.add_child(action_label)
		
		var key_button = Button.new()
		key_button.custom_minimum_size = Vector2(150, 35)
		key_button.text = "???"
		
		# Estilo del botón
		var button_style = StyleBoxFlat.new()
		button_style.bg_color = COLOR_COFFEE_LIGHT
		button_style.set_corner_radius_all(8)
		button_style.set_border_width_all(2)
		button_style.border_color = COLOR_COFFEE_DARK
		key_button.add_theme_stylebox_override("normal", button_style)
		
		var button_hover = button_style.duplicate()
		button_hover.bg_color = COLOR_GREEN_HOVER
		key_button.add_theme_stylebox_override("hover", button_hover)
		
		control_buttons[action] = key_button
		control_container.add_child(key_button)
		
		controls_list.add_child(control_container)

func create_action_buttons(parent: VBoxContainer):
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 30)
	parent.add_child(button_container)
	
	# Botón Aplicar
	apply_button = create_styled_button("✅ Aplicar", COLOR_GREEN)
	button_container.add_child(apply_button)
	
	# Botón Volver
	back_button = create_styled_button("↩️ Volver", COLOR_RED)
	button_container.add_child(back_button)

func create_styled_button(text: String, color: Color) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140, 45)
	button.add_theme_font_size_override("font_size", 18)
	
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = color
	button_style.set_corner_radius_all(10)
	button_style.set_border_width_all(2)
	button_style.border_color = COLOR_COFFEE_DARK
	button.add_theme_stylebox_override("normal", button_style)
	
	var hover_style = button_style.duplicate()
	hover_style.bg_color = Color(color.r * 1.2, color.g * 1.2, color.b * 1.2)
	button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = button_style.duplicate()
	pressed_style.bg_color = Color(color.r * 0.8, color.g * 0.8, color.b * 0.8)
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	button.add_theme_color_override("font_color", COLOR_CREAM)
	
	return button

func connect_signals():
	# Audio
	if master_slider:
		master_slider.value_changed.connect(_on_master_volume_changed)
	if music_slider:
		music_slider.value_changed.connect(_on_music_volume_changed)
	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	if mute_all_check:
		mute_all_check.toggled.connect(_on_mute_all_toggled)
	
	# Video
	if fullscreen_check:
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	if resolution_option:
		resolution_option.item_selected.connect(_on_resolution_selected)
	
	# Controles
	for action in control_buttons:
		var button = control_buttons[action]
		button.pressed.connect(_on_control_button_pressed.bind(action, button))
	
	# Botones principales
	if apply_button:
		apply_button.pressed.connect(_on_apply_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func load_current_settings():
	if not config_manager:
		return
	
	# Audio
	var master_vol = config_manager.get_master_volume()
	var music_vol = config_manager.get_music_volume()
	var sfx_vol = config_manager.get_sfx_volume()
	
	if master_slider:
		master_slider.value = master_vol
		_on_master_volume_changed(master_vol)
	if music_slider:
		music_slider.value = music_vol
		_on_music_volume_changed(music_vol)
	if sfx_slider:
		sfx_slider.value = sfx_vol
		_on_sfx_volume_changed(sfx_vol)
	
	# Check if audio is muted
	if mute_all_check:
		mute_all_check.button_pressed = (master_vol == 0.0)
	
	# Video
	if fullscreen_check:
		fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	
	# Obtener resolución actual
	var current_res = DisplayServer.window_get_size()
	if resolution_option:
		for i in range(resolutions.size()):
			if abs(resolutions[i].x - current_res.x) < 10 and abs(resolutions[i].y - current_res.y) < 10:
				resolution_option.selected = i
				break
	
	# Controles
	update_control_buttons()

func update_control_buttons():
	for action in control_buttons:
		var button = control_buttons[action]
		var events = InputMap.action_get_events(action)
		if events.size() > 0:
			var event = events[0]
			if event is InputEventKey:
				button.text = OS.get_keycode_string(event.keycode)
			else:
				button.text = "???"
		else:
			button.text = "Sin asignar"

# Callbacks de Audio
func _on_master_volume_changed(value: float):
	if master_label:
		master_label.text = str(int(value * 100)) + "%"
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
	
	# Si el volumen es > 0, desmarcar mute
	if value > 0 and mute_all_check and mute_all_check.button_pressed:
		mute_all_check.set_pressed_no_signal(false)

func _on_music_volume_changed(value: float):
	if music_label:
		music_label.text = str(int(value * 100)) + "%"
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))

func _on_sfx_volume_changed(value: float):
	if sfx_label:
		sfx_label.text = str(int(value * 100)) + "%"
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))

func _on_mute_all_toggled(pressed: bool):
	if pressed:
		# Guardar valores actuales y silenciar
		if master_slider:
			master_slider.value = 0.0
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	else:
		# Restaurar audio
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
		if master_slider:
			master_slider.value = 0.5  # Valor por defecto al desmutear

# Callbacks de Video - CORREGIDOS
func _on_fullscreen_toggled(pressed: bool):
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# Aplicar la resolución seleccionada al salir de fullscreen
		if resolution_option and resolution_option.selected >= 0:
			var res = resolutions[resolution_option.selected]
			DisplayServer.window_set_size(res)
			center_window()

func _on_resolution_selected(index: int):
	if index < 0 or index >= resolutions.size():
		return
	
	var new_resolution = resolutions[index]
	
	# Solo cambiar si no está en pantalla completa
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		# Aplicar nueva resolución
		DisplayServer.window_set_size(new_resolution)
		
		# Esperar un frame para que se aplique el cambio
		await get_tree().process_frame
		
		# Centrar la ventana
		center_window()
		
		print("Resolución cambiada a: ", new_resolution)

func center_window():
	var screen_size = DisplayServer.screen_get_size()
	var window_size = DisplayServer.window_get_size()
	var centered_pos = (screen_size - window_size) / 2
	DisplayServer.window_set_position(centered_pos)

# Sistema de remapeo de controles
func _on_control_button_pressed(action: String, button: Button):
	if is_remapping:
		return
	
	is_remapping = true
	action_to_remap = action
	button_to_update = button
	button.text = "Presiona una tecla..."
	button.modulate = Color.YELLOW

func _input(event):
	if is_remapping and event is InputEventKey and event.pressed:
		# Limpiar eventos anteriores
		InputMap.action_erase_events(action_to_remap)
		
		# Añadir nuevo evento
		InputMap.action_add_event(action_to_remap, event)
		
		# Actualizar botón
		button_to_update.text = OS.get_keycode_string(event.keycode)
		button_to_update.modulate = Color.WHITE
		
		# Guardar el cambio
		save_keybindings()
		
		# Resetear estado
		is_remapping = false
		action_to_remap = ""
		button_to_update = null
		
		get_viewport().set_input_as_handled()

func save_keybindings():
	# Guardar las teclas en ConfigManager si existe
	if config_manager:
		config_manager.save_keybindings()
	
	print("✅ Controles guardados")

# Botones principales
func _on_apply_pressed():
	save_settings()
	settings_closed.emit()
	hide()

func _on_back_pressed():
	settings_closed.emit()
	hide()

func save_settings():
	if not config_manager:
		return
	
	# Guardar audio
	if master_slider:
		config_manager.set_master_volume(master_slider.value)
	if music_slider:
		config_manager.set_music_volume(music_slider.value)
	if sfx_slider:
		config_manager.set_sfx_volume(sfx_slider.value)
	
	# Guardar video
	config_manager.settings.graphics.fullscreen = fullscreen_check.button_pressed if fullscreen_check else false
	
	if resolution_option and resolution_option.selected >= 0:
		var selected_res = resolutions[resolution_option.selected]
		config_manager.settings.graphics.resolution = Vector2(selected_res.x, selected_res.y)
	
	# Guardar configuración
	config_manager.save_config()
	print("✅ Configuración guardada")

# Utilidad
func linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)
