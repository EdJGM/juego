# MainMenu.gd - Menú principal estilo Cafetería Xpress
extends Control

signal start_game
signal show_levels
signal show_settings
signal show_credits
signal quit_game

# Referencias a los elementos UI
var title_label: Label
var subtitle_label: Label
var button_container: VBoxContainer
var iniciar_button: Button
var niveles_button: Button
var config_button: Button
var creditos_button: Button
var salir_button: Button

# Referencias a los menús
var settings_menu_script = preload("res://scripts/SettingsMenu.gd")
var settings_menu_instance: Control = null
var credits_menu_script = preload("res://scripts/CreditsMenu.gd")
var credits_menu_instance: Control = null

# Colores temáticos
var COLOR_COFFEE_DARK = Color("#3E2723")
var COLOR_COFFEE = Color("#6D4C41")
var COLOR_COFFEE_LIGHT = Color("#8D6E63")
var COLOR_CREAM = Color("#FFF8E1")
var COLOR_ORANGE = Color("#FF6F00")
var COLOR_ORANGE_DARK = Color("#E65100")
var COLOR_GREEN = Color("#689F38")
var COLOR_GREEN_HOVER = Color("#7CB342")
var COLOR_RED = Color("#D32F2F")

# Animación
var button_hover_scale = 1.1
var button_press_scale = 0.95
var title_float_amplitude = 5.0
var title_float_speed = 2.0
var time_passed = 0.0

func _ready():
	# Asegurar cursor visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Crear UI
	create_menu_ui()
	
	# Conectar botones
	connect_buttons()
	
	# Crear los menús
	call_deferred("create_settings_menu")
	call_deferred("create_credits_menu")
	
	# Añadir efecto de fondo
	add_animated_background()

func create_menu_ui():
	# Limpiar UI existente si existe
	for child in get_children():
		child.queue_free()
	
	# Panel de fondo principal
	var bg_panel = Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(COLOR_COFFEE_DARK.r, COLOR_COFFEE_DARK.g, COLOR_COFFEE_DARK.b, 0.7)
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(bg_panel)
	
	# Contenedor central
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)
	
	# Panel del menú
	var menu_panel = Panel.new()
	menu_panel.custom_minimum_size = Vector2(500, 600)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = COLOR_CREAM
	panel_style.border_color = COLOR_COFFEE_DARK
	panel_style.set_border_width_all(5)
	panel_style.set_corner_radius_all(20)
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_size = 15
	panel_style.set_expand_margin_all(20)
	menu_panel.add_theme_stylebox_override("panel", panel_style)
	center_container.add_child(menu_panel)
	
	# Contenedor principal vertical
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 20)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_panel.add_child(main_vbox)
	
	# Espacio superior
	main_vbox.add_child(Control.new())
	
	# Título principal con sombra
	var title_container = VBoxContainer.new()
	title_container.add_theme_constant_override("separation", 5)
	main_vbox.add_child(title_container)
	
	# Icono de café
	var coffee_icon = Label.new()
	coffee_icon.text = "☕"
	coffee_icon.add_theme_font_size_override("font_size", 48)
	coffee_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_container.add_child(coffee_icon)
	
	# Título
	title_label = Label.new()
	title_label.text = "Cafetería"
	title_label.add_theme_font_size_override("font_size", 56)
	title_label.add_theme_color_override("font_color", COLOR_ORANGE_DARK)
	title_label.add_theme_color_override("font_shadow_color", COLOR_COFFEE_DARK)
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	title_label.add_theme_constant_override("shadow_outline_size", 1)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_container.add_child(title_label)
	
	# Subtítulo
	subtitle_label = Label.new()
	subtitle_label.text = "Xpress"
	subtitle_label.add_theme_font_size_override("font_size", 42)
	subtitle_label.add_theme_color_override("font_color", COLOR_ORANGE)
	subtitle_label.add_theme_color_override("font_shadow_color", COLOR_COFFEE)
	subtitle_label.add_theme_constant_override("shadow_offset_x", 2)
	subtitle_label.add_theme_constant_override("shadow_offset_y", 2)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_container.add_child(subtitle_label)
	
	# Línea decorativa
	var separator = HSeparator.new()
	separator.add_theme_color_override("color", COLOR_COFFEE)
	separator.add_theme_constant_override("separation", 3)
	var sep_container = MarginContainer.new()
	sep_container.add_theme_constant_override("margin_left", 50)
	sep_container.add_theme_constant_override("margin_right", 50)
	sep_container.add_child(separator)
	main_vbox.add_child(sep_container)
	
	# Contenedor de botones
	button_container = VBoxContainer.new()
	button_container.add_theme_constant_override("separation", 15)
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	var button_margin = MarginContainer.new()
	button_margin.add_theme_constant_override("margin_left", 80)
	button_margin.add_theme_constant_override("margin_right", 80)
	button_margin.add_child(button_container)
	main_vbox.add_child(button_margin)
	
	# Crear botones
	iniciar_button = create_menu_button("🎮 Iniciar Juego", COLOR_GREEN)
	button_container.add_child(iniciar_button)
	
	niveles_button = create_menu_button("📊 Niveles", COLOR_COFFEE_LIGHT)
	button_container.add_child(niveles_button)
	
	config_button = create_menu_button("⚙️ Configuración", COLOR_COFFEE_LIGHT)
	button_container.add_child(config_button)
	
	creditos_button = create_menu_button("📜 Créditos", COLOR_COFFEE_LIGHT)
	button_container.add_child(creditos_button)
	
	salir_button = create_menu_button("🚪 Salir", COLOR_RED)
	button_container.add_child(salir_button)
	
	# Espacio inferior
	main_vbox.add_child(Control.new())
	
	# Footer con versión
	var footer = Label.new()
	footer.text = "v1.0.0 - © 2024"
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", COLOR_COFFEE)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(footer)

func create_menu_button(text: String, color: Color) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 55)
	button.add_theme_font_size_override("font_size", 20)
	
	# Estilo normal
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = color
	normal_style.set_corner_radius_all(12)
	normal_style.set_border_width_all(3)
	normal_style.border_color = COLOR_COFFEE_DARK
	normal_style.shadow_color = Color(0, 0, 0, 0.3)
	normal_style.shadow_size = 5
	button.add_theme_stylebox_override("normal", normal_style)
	
	# Estilo hover
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(color.r * 1.2, color.g * 1.2, color.b * 1.2, color.a)
	hover_style.shadow_size = 8
	hover_style.border_color = COLOR_ORANGE
	button.add_theme_stylebox_override("hover", hover_style)
	
	# Estilo pressed
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(color.r * 0.8, color.g * 0.8, color.b * 0.8, color.a)
	pressed_style.shadow_size = 2
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	# Color del texto
	button.add_theme_color_override("font_color", COLOR_CREAM)
	button.add_theme_color_override("font_hover_color", COLOR_CREAM)
	button.add_theme_color_override("font_pressed_color", COLOR_CREAM)
	
	# Añadir efectos de hover
	button.mouse_entered.connect(func(): _on_button_hover(button, true))
	button.mouse_exited.connect(func(): _on_button_hover(button, false))
	
	return button

func _on_button_hover(button: Button, is_hovering: bool):
	var tween = create_tween()
	if is_hovering:
		tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)
	else:
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)

func add_animated_background():
	# Añadir partículas de vapor de café (opcional)
	var particles_container = Control.new()
	particles_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	particles_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(particles_container)
	move_child(particles_container, 0)  # Mover al fondo
	
	# Crear algunos iconos flotantes de café
	for i in range(5):
		var coffee_float = Label.new()
		coffee_float.text = ["☕", "🥐", "🍰", "☕", "🥤"][i]
		coffee_float.add_theme_font_size_override("font_size", 32)
		coffee_float.modulate = Color(1, 1, 1, 0.1)
		coffee_float.position = Vector2(randf() * get_viewport().size.x, randf() * get_viewport().size.y)
		particles_container.add_child(coffee_float)
		
		# Animar flotación
		animate_floating_icon(coffee_float)

func animate_floating_icon(icon: Label):
	var tween = create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	
	var start_pos = icon.position
	var end_pos = start_pos + Vector2(randf_range(-30, 30), randf_range(-20, -10))
	
	tween.tween_property(icon, "position", end_pos, randf_range(3, 5))
	tween.tween_property(icon, "position", start_pos, randf_range(3, 5))

func connect_buttons():
	if iniciar_button:
		iniciar_button.pressed.connect(_on_iniciar_pressed)
	if niveles_button:
		niveles_button.pressed.connect(_on_niveles_pressed)
	if config_button:
		config_button.pressed.connect(_on_config_pressed)
	if creditos_button:
		creditos_button.pressed.connect(_on_creditos_pressed)
	if salir_button:
		salir_button.pressed.connect(_on_salir_pressed)

func create_settings_menu():
	settings_menu_instance = Control.new()
	settings_menu_instance.name = "SettingsMenu"
	settings_menu_instance.set_script(settings_menu_script)
	settings_menu_instance.visible = false
	settings_menu_instance.z_index = 100
	settings_menu_instance.top_level = true
	
	# Añadir como hermano del MainMenu
	get_parent().add_child(settings_menu_instance)
	
	# Conectar la señal de cierre
	if settings_menu_instance.has_signal("settings_closed"):
		settings_menu_instance.settings_closed.connect(_on_settings_closed)
	
	print("✓ Menú de configuración creado")

func create_credits_menu():
	credits_menu_instance = Control.new()
	credits_menu_instance.name = "CreditsMenu"
	credits_menu_instance.set_script(credits_menu_script)
	credits_menu_instance.visible = false
	credits_menu_instance.z_index = 100
	credits_menu_instance.top_level = true
	
	# Añadir como hermano del MainMenu
	get_parent().add_child(credits_menu_instance)
	
	# Conectar la señal de cierre
	if credits_menu_instance.has_signal("credits_closed"):
		credits_menu_instance.credits_closed.connect(_on_credits_closed)
	
	print("✓ Menú de créditos creado")

func _on_iniciar_pressed():
	# Efecto de transición
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_callback(func(): 
		start_game.emit()
		hide()
	)

func _on_niveles_pressed():
	show_levels.emit()
	# Mostrar mensaje temporal
	show_temporary_message("🚧 Próximamente disponible")

func _on_config_pressed():
	show_settings.emit()
	if settings_menu_instance == null:
		create_settings_menu()
	show_settings_menu()

func _on_creditos_pressed():
	show_credits.emit()
	if credits_menu_instance == null:
		create_credits_menu()
	show_credits_menu()

func _on_salir_pressed():
	# Animación de salida
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.2)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.2)
	tween.tween_callback(func(): quit_game.emit())

func show_settings_menu():
	if settings_menu_instance:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		visible = false
		settings_menu_instance.visible = true
		print("✓ Mostrando menú de configuración")

func show_credits_menu():
	if credits_menu_instance:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		visible = false
		credits_menu_instance.visible = true
		print("✓ Mostrando menú de créditos")

func _on_settings_closed():
	if settings_menu_instance:
		settings_menu_instance.visible = false
	visible = true
	print("✓ Volviendo al menú principal")

func _on_credits_closed():
	if credits_menu_instance:
		credits_menu_instance.visible = false
	visible = true
	print("✓ Volviendo al menú principal desde créditos")

func show_temporary_message(message: String):
	var msg_label = Label.new()
	msg_label.text = message
	msg_label.add_theme_font_size_override("font_size", 24)
	msg_label.add_theme_color_override("font_color", COLOR_CREAM)
	msg_label.add_theme_color_override("font_shadow_color", COLOR_COFFEE_DARK)
	msg_label.add_theme_constant_override("shadow_offset_x", 2)
	msg_label.add_theme_constant_override("shadow_offset_y", 2)
	
	var msg_bg = Panel.new()
	var msg_style = StyleBoxFlat.new()
	msg_style.bg_color = COLOR_COFFEE
	msg_style.set_corner_radius_all(10)
	msg_style.set_expand_margin_all(20)
	msg_bg.add_theme_stylebox_override("panel", msg_style)
	
	msg_bg.add_child(msg_label)
	msg_bg.position = Vector2(get_viewport().size.x / 2 - 150, get_viewport().size.y - 100)
	msg_bg.size = Vector2(300, 60)
	msg_label.position = Vector2(20, 15)
	
	add_child(msg_bg)
	
	# Animar aparición y desaparición
	msg_bg.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(msg_bg, "modulate", Color(1, 1, 1, 1), 0.3)
	tween.tween_interval(2.0)
	tween.tween_property(msg_bg, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_callback(msg_bg.queue_free)

func _process(delta):
	time_passed += delta
	
	# Animación flotante del título
	if title_label:
		var float_offset = sin(time_passed * title_float_speed) * title_float_amplitude
		title_label.position.y = title_label.position.y * 0.95 + float_offset * 0.05
