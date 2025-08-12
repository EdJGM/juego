# PauseMenu.gd - Menú de pausa con configuración integrada
extends Control

# Variables para el menú de configuración
var settings_menu_script = preload("res://scripts/SettingsMenu.gd")
var settings_menu_instance: Control = null
var is_in_settings: bool = false

func _ready():
	# Aplicar el shader al ColorRect
	var shader_material = ShaderMaterial.new()
	shader_material.shader = load("res://Menu_pausa/menu_pausa.gdshader")
	$ColorRect.material = shader_material
	
	# Crear el menú de configuración
	settings_menu_instance = Control.new()
	settings_menu_instance.name = "SettingsMenu"
	settings_menu_instance.set_script(settings_menu_script)
	settings_menu_instance.visible = false
	settings_menu_instance.z_index = 200
	settings_menu_instance.top_level = true
	add_child(settings_menu_instance)
	
	# Conectar señal de cierre de configuración
	if settings_menu_instance.has_signal("settings_closed"):
		settings_menu_instance.settings_closed.connect(_on_settings_closed)

func _process(delta):
	test_esc()

func test_esc():
	# Si estamos en configuración, ESC vuelve al menú de pausa
	if is_in_settings:
		if Input.is_action_just_pressed("esc"):
			_on_settings_closed()
		return
	
	# Comportamiento normal del menú de pausa
	if Input.is_action_just_pressed("esc") and !get_tree().paused:
		pause()
	elif Input.is_action_just_pressed("esc") and get_tree().paused:
		regresar()

func pause():
	get_tree().paused = true
	
	# Asegurar cursor visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Hacer visible el menú y reproducir animación
	visible = true
	$AnimationPlayer.play("bluer")

func regresar():
	get_tree().paused = false
	visible = false
	$AnimationPlayer.play_backwards("bluer")

func _on_regresar_pressed() -> void:
	regresar()

func _on_configuracion_pressed() -> void:
	# Ocultar elementos del menú de pausa (excepto ColorRect, AnimationPlayer y SettingsMenu)
	for child in get_children():
		if child != settings_menu_instance and child.name != "ColorRect" and child.name != "AnimationPlayer":
			child.visible = false
	
	# Mostrar menú de configuración
	settings_menu_instance.visible = true
	is_in_settings = true

func _on_settings_closed():
	# Ocultar menú de configuración
	settings_menu_instance.visible = false
	is_in_settings = false
	
	# Volver a mostrar elementos del menú de pausa
	for child in get_children():
		if child != settings_menu_instance and child.name != "ColorRect" and child.name != "AnimationPlayer":
			child.visible = true

func _on_salir_pressed() -> void:
	get_tree().quit()
