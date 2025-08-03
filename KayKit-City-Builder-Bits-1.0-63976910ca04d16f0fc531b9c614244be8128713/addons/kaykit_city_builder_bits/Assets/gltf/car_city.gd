extends Node3D

const MOVE_SPEED := 4.0
@onready var path_follow: PathFollow3D = get_parent()

func _physics_process(delta: float) -> void:
	# Mover a lo largo del path
	if path_follow:
		path_follow.progress += MOVE_SPEED * delta
		
		# Opcional: reiniciar el path cuando llegue al final
		if path_follow.progress_ratio >= 1.0:
			path_follow.progress_ratio = 0.0
