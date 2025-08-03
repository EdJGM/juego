extends CharacterBody3D

const MOVE_SPEED := 1.0
@onready var path_follow: PathFollow3D = get_parent()
@onready var animation_player: AnimationPlayer = find_child("AnimationPlayer", true, false)

var moving_forward := true

func _ready() -> void:
	if path_follow:
		path_follow.loop = false

func _physics_process(delta: float) -> void:
	if path_follow:
		if moving_forward:
			path_follow.progress += MOVE_SPEED * delta
			if path_follow.progress_ratio >= 0.99:
				moving_forward = false
				rotation.y += PI
		else:
			path_follow.progress -= MOVE_SPEED * delta
			if path_follow.progress_ratio <= 0.01:
				moving_forward = true
				rotation.y += PI
		
		reproducir_animacion("walk")

func reproducir_animacion(nombre_animacion: String):
	if animation_player and animation_player.current_animation != nombre_animacion:
		animation_player.play(nombre_animacion)
