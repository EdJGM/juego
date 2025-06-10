extends Control

@onready var optionsMenu = preload("res://Menu_pausa/menu_pausa.tscn")

func _process(delta):
	test_esc()

func test_esc():
	if Input.is_action_just_pressed("esc") and !get_tree().paused:
		pause()
	elif Input.is_action_just_pressed("esc") and get_tree().paused:
		regresar()

func pause():
	get_tree().paused = true
	$AnimationPlayer.play("bluer")

func regresar():
	get_tree().paused = false
	$AnimationPlayer.play_backwards("bluer")

func _on_regresar_pressed() -> void:
	regresar()

func _on_configuracion_pressed() -> void:
	pass # Aquí puedes abrir una escena de configuración, por ejemplo.

func _on_salir_pressed() -> void:
	get_tree().quit()

# Si quieres cambiar de escena, hazlo dentro de una función, por ejemplo:
# func cambiar_a_menu_pausa():
#     get_tree().change_scene_to_file("res://Menu_pausa/menu_pausa.tscn")
