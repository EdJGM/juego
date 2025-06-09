extends Node3D

@export var tiempo_espera := 10.0 # segundos
@export var velocidad_salida := 2.0 # velocidad al irse
@export var tiempo_giro := 0.5 # segundos para girar
var tiempo_restante := 0.0
var esperando := true
var yendose := false
var girando := false
var tiempo_girado := 0.0
var rotacion_inicial : float
var rotacion_final : float

@onready var animation_player : AnimationPlayer = $"character-male-e2/AnimationPlayer"
#@onready var barra_paciencia : TextureProgressBar = $CanvasLayer/BarraPaciencia
@onready var barra_paciencia : ProgressBar = $CanvasLayer/ProgressBar

func _ready():
	tiempo_restante = tiempo_espera
	animation_player.play("idle") #animacion idle por defector

func _process(delta):
	if esperando:
		tiempo_restante -= delta
		if animation_player.current_animation != "idle":
			animation_player.play("idle")		
		if tiempo_restante <= 0:
			iniciar_giro()
	elif girando:
		tiempo_girado += delta
		var t = clamp(tiempo_girado / tiempo_giro, 0, 1)
		rotation.y = lerp_angle(rotacion_inicial, rotacion_final, t)
		if t >= 1.0:
			girando = false
			irse()
	elif yendose:
		# Camina hacia adelante según la rotación actual
		translate(transform.basis.x * velocidad_salida * delta)
		if animation_player.current_animation != "sprint":
			animation_player.play("sprint")
	
	# Actualiza el valor de la barra
	barra_paciencia.value = tiempo_restante / tiempo_espera * 100
	
	# la barra siga la cabeza del cliente en pantalla
	var head_pos = global_transform.origin + Vector3(0, 1, 0) # Ajusta el 2 según la altura
	var screen_pos = get_viewport().get_camera_3d().unproject_position(head_pos)
	barra_paciencia.position = screen_pos

func iniciar_giro():
	esperando = false
	girando = true
	tiempo_girado = 0.0
	rotacion_inicial = rotation.y
	rotacion_final = rotation.y + PI # Gira 180 grados (media vuelta)
	if animation_player.current_animation != "idle":
		animation_player.play("idle")

func irse():
	yendose = true
	print("El cliente se va porque esperó demasiado.")
	await get_tree().create_timer(2.0).timeout
	queue_free()
