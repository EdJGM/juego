# CreditsMenu.gd - Menú de Créditos estilo Cafetería (centrado corregido)
extends Control

signal credits_closed

# Colores temáticos
var COLOR_COFFEE_DARK = Color("#3E2723")
var COLOR_COFFEE      = Color("#6D4C41")
var COLOR_COFFEE_LIGHT= Color("#8D6E63")
var COLOR_CREAM       = Color("#FFF8E1")
var COLOR_ORANGE      = Color("#FF6F00")
var COLOR_ORANGE_DARK = Color("#E65100")
var COLOR_GREEN       = Color("#689F38")

# Referencias UI
var scroll_container: ScrollContainer
var credits_content: VBoxContainer
var back_button: Button
var auto_scroll_speed: float = 30.0
var is_auto_scrolling: bool = true

func _ready():
	# Ocupar toda la pantalla
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	create_credits_ui()
	# Iniciar scroll automático tras breve delay
	await get_tree().create_timer(0.5).timeout
	is_auto_scrolling = true

func create_credits_ui():
	# Panel de fondo con transparencia
	var bg_panel = Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(COLOR_COFFEE_DARK.r, COLOR_COFFEE_DARK.g, COLOR_COFFEE_DARK.b, 0.9)
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(bg_panel)

	# Panel central de créditos
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)

	var credits_panel = Panel.new()
	credits_panel.custom_minimum_size = Vector2(700, 600)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = COLOR_CREAM
	panel_style.border_color = COLOR_COFFEE_DARK
	panel_style.set_border_width_all(5)
	panel_style.set_corner_radius_all(20)
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_size = 15
	panel_style.set_expand_margin_all(20)
	credits_panel.add_theme_stylebox_override("panel", panel_style)
	center_container.add_child(credits_panel)

	# Contenedor principal del panel
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 20)
	credits_panel.add_child(main_vbox)

	# Título de Créditos (centrado y ancho completo)
	var title_label = Label.new()
	title_label.text = "☕ CRÉDITOS ☕"
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.add_theme_color_override("font_color", COLOR_ORANGE_DARK)
	title_label.add_theme_color_override("font_shadow_color", COLOR_COFFEE_DARK)
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(title_label)

	# Separador decorativo
	var separator = HSeparator.new()
	separator.add_theme_color_override("color", COLOR_COFFEE)
	separator.add_theme_constant_override("separation", 3)
	main_vbox.add_child(separator)

	# Scroll Container para el contenido (sin horizontal; ocupa todo el ancho)
	scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size.y = 450
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll_container)

	# Contenido de créditos (VBox) — ocupa todo el ancho
	credits_content = VBoxContainer.new()
	credits_content.add_theme_constant_override("separation", 25)
	credits_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(credits_content)

	# Logo/título del juego
	add_game_title()

	# Universidad
	add_section_title("🎓 INSTITUCIÓN")
	add_credit_text("UNIVERSIDAD DE LAS FUERZAS ARMADAS", 20, COLOR_COFFEE_DARK)
	add_credit_text("ESPE", 18, COLOR_COFFEE)

	add_spacing()

	# Departamento
	add_section_title("📚 DEPARTAMENTO")
	add_credit_text("DEPARTAMENTO DE CIENCIAS DE LA COMPUTACIÓN", 18, COLOR_COFFEE_DARK)
	add_credit_text("INGENIERÍA DE SOFTWARE", 18, COLOR_COFFEE_DARK)

	add_spacing()

	# Materia
	add_section_title("🎮 MATERIA")
	add_credit_text("Desarrollo de Videojuegos", 20, COLOR_COFFEE_DARK)
	add_credit_text("NRC: 23362", 16, COLOR_COFFEE)

	add_spacing()

	# Equipo de Desarrollo (centrado)
	add_section_title("👥 EQUIPO DE DESARROLLO")

	var developers = [
		{"name": "Bazurto Christopher", "role": "Desarrollador"},
		{"name": "Antoni Toapanta",     "role": "Desarrollador"},
		{"name": "Echeverria Luis",      "role": "Desarrollador"},
		{"name": "Gallegos Edgar",       "role": "Desarrollador"}
	]
	for dev in developers:
		add_developer(dev.name, dev.role)

	add_spacing()

	# Fecha
	add_section_title("📅 FECHA DE ENTREGA")
	add_credit_text("12 de Agosto de 2025", 18, COLOR_COFFEE_DARK)

	add_spacing()
	add_spacing()

	# Agradecimientos
	add_section_title("💝 AGRADECIMIENTOS ESPECIALES")
	add_credit_text("A todos los profesores y compañeros", 16, COLOR_COFFEE)
	add_credit_text("que hicieron posible este proyecto", 16, COLOR_COFFEE)

	add_spacing()

	# Tecnología
	add_section_title("⚙️ DESARROLLADO CON")
	add_credit_text("Godot Engine 4.3", 18, COLOR_COFFEE_DARK)
	add_credit_text("Con mucho ☕ y dedicación", 16, COLOR_COFFEE)

	add_spacing()
	add_spacing()

	# Mensaje final (centrado)
	var final_container = VBoxContainer.new()
	final_container.add_theme_constant_override("separation", 5)
	final_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_content.add_child(final_container)

	var thanks_label = Label.new()
	thanks_label.text = "¡Gracias por jugar!"
	thanks_label.add_theme_font_size_override("font_size", 24)
	thanks_label.add_theme_color_override("font_color", COLOR_ORANGE)
	thanks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thanks_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	final_container.add_child(thanks_label)

	var coffee_emoji = Label.new()
	coffee_emoji.text = "☕☕☕"
	coffee_emoji.add_theme_font_size_override("font_size", 32)
	coffee_emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coffee_emoji.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	final_container.add_child(coffee_emoji)

	# Espaciado final para scroll
	for i in range(10):
		add_spacing()

	# Botón de volver (centrado)
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(button_container)

	back_button = create_styled_button("↩️ Volver", COLOR_COFFEE)
	button_container.add_child(back_button)
	back_button.pressed.connect(_on_back_pressed)

# ---------------------- Helpers de UI (centrado y ancho completo) ----------------------

func add_game_title():
	var title_container = VBoxContainer.new()
	title_container.add_theme_constant_override("separation", 5)
	title_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_content.add_child(title_container)

	var game_title = Label.new()
	game_title.text = "Cafetería Xpress"
	game_title.add_theme_font_size_override("font_size", 36)
	game_title.add_theme_color_override("font_color", COLOR_ORANGE_DARK)
	game_title.add_theme_color_override("font_shadow_color", COLOR_COFFEE)
	game_title.add_theme_constant_override("shadow_offset_x", 2)
	game_title.add_theme_constant_override("shadow_offset_y", 2)
	game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_container.add_child(game_title)

	var subtitle = Label.new()
	subtitle.text = "Un juego de gestión y velocidad"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", COLOR_COFFEE)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_container.add_child(subtitle)

# SECTION TITLE centrado + ancho completo
func add_section_title(text: String):
	var section_label = Label.new()
	section_label.text = text
	section_label.add_theme_font_size_override("font_size", 22)
	section_label.add_theme_color_override("font_color", COLOR_GREEN)
	section_label.add_theme_color_override("font_shadow_color", COLOR_COFFEE_DARK)
	section_label.add_theme_constant_override("shadow_offset_x", 1)
	section_label.add_theme_constant_override("shadow_offset_y", 1)
	section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_content.add_child(section_label)

# CREDIT TEXT centrado + autowrap + ancho completo
func add_credit_text(text: String, size: int, color: Color):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_content.add_child(label)

# DESARROLLADOR centrado (nombre y rol)
func add_developer(name: String, role: String):
	var main_container = VBoxContainer.new()
	main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_theme_constant_override("separation", 4)
	credits_content.add_child(main_container)

	var dev_label = Label.new()
	dev_label.text = "👨‍💻 " + name
	dev_label.add_theme_font_size_override("font_size", 18)
	dev_label.add_theme_color_override("font_color", COLOR_COFFEE_DARK)
	dev_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dev_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(dev_label)

	var role_label = Label.new()
	role_label.text = role
	role_label.add_theme_font_size_override("font_size", 14)
	role_label.add_theme_color_override("font_color", COLOR_COFFEE_LIGHT)
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(role_label)

func add_spacing():
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 10
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_content.add_child(spacer)

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

# ---------------------- Comportamiento: auto-scroll y volver ----------------------

func _process(delta):
	# Auto-scroll de los créditos
	if is_auto_scrolling and scroll_container:
		var scrollbar = scroll_container.get_v_scroll_bar()
		if scrollbar:
			var new_value = scrollbar.value + auto_scroll_speed * delta
			if new_value >= scrollbar.max_value:
				await get_tree().create_timer(2.0).timeout
				scrollbar.value = 0
			else:
				scrollbar.value = new_value

func _input(event):
	# Detener auto-scroll si el usuario interactúa
	if event is InputEventMouseButton or event is InputEventKey:
		is_auto_scrolling = false
		# Reanudar después de 3 segundos de inactividad
		await get_tree().create_timer(3.0).timeout
		if not is_auto_scrolling:
			is_auto_scrolling = true

func _on_back_pressed():
	credits_closed.emit()
	queue_free()
