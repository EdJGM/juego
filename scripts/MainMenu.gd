# MainMenu.gd (tu Control del menú)
extends Control

signal start_game
signal show_levels
signal show_settings
signal show_credits
signal quit_game

@onready var iniciar_button = $VBoxContainer/ButtonContainer/IniciarJuego
@onready var niveles_button = $VBoxContainer/ButtonContainer/Niveles
@onready var config_button = $VBoxContainer/ButtonContainer/Configuracion
@onready var creditos_button = $VBoxContainer/ButtonContainer/Creditos
@onready var salir_button = $VBoxContainer/ButtonContainer/Salir

func _ready():
	connect_buttons()
	add_background_blur()  # Efecto opcional

func connect_buttons():
	iniciar_button.pressed.connect(_on_iniciar_pressed)
	niveles_button.pressed.connect(_on_niveles_pressed)
	config_button.pressed.connect(_on_config_pressed)
	creditos_button.pressed.connect(_on_creditos_pressed)
	salir_button.pressed.connect(_on_salir_pressed)

# Funciones de los botones
func _on_iniciar_pressed():
	start_game.emit()
	hide()

func _on_niveles_pressed():
	show_levels.emit()

func _on_config_pressed():
	show_settings.emit()

func _on_creditos_pressed():
	show_credits.emit()

func _on_salir_pressed():
	quit_game.emit()

func add_background_blur():
	# Agregar un fondo semi-transparente para mejor legibilidad
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.3)  # Negro semi-transparente
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	move_child(background, 0)  # Mover al fondo
