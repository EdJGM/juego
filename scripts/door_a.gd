extends Node3D

var abierta = false
var jugador_cerca = false
var rotacion_abierta = deg_to_rad(90)
var rotacion_cerrada = 0.0

func _ready():
	$Area3D.body_entered.connect(_on_body_entered)
	$Area3D.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	#print("Entró:", body.name)
	if body.name == "Player":
		jugador_cerca = true

func _on_body_exited(body):
	#print("Salió:", body.name)
	if body.name == "Player":
		jugador_cerca = false

func _process(delta):
	#if jugador_cerca:
		#print("Jugador cerca")
	if jugador_cerca and Input.is_action_just_pressed("interactuar"):
		print("Interacción detectada")
		if abierta:
			cerrar_puerta()
		else:
			abrir_puerta()

func abrir_puerta():
	rotation.y = rotacion_abierta
	abierta = true

func cerrar_puerta():
	rotation.y = rotacion_cerrada
	abierta = false
