extends Node3D

var puertas_abiertas = false
var jugador_cerca = false
var duracion_animacion = 0.5
var tiempo_transcurrido = 0.0

var puerta_superior
var puerta_inferior
var angulo_abierto = deg_to_rad(90)
var animando = false

func _ready():
	$Area3D.body_entered.connect(_on_body_entered)
	$Area3D.body_exited.connect(_on_body_exited)
	
	# Obtener referencias a las puertas
	puerta_superior = find_child("fridge_A_decorated_door_top", true)
	puerta_inferior = find_child("fridge_A_decorated_door_bottom", true)
	
	if puerta_superior and puerta_inferior:
		print("✓ Puertas encontradas correctamente")
	else:
		print("⚠️ No se encontraron las puertas")
	
	# Crear texto de instrucción
	var instruction = Label3D.new()
	instruction.text = "Presiona E para abrir/cerrar"
	instruction.font_size = 12
	instruction.name = "Instruction"
	instruction.position = Vector3(0, 2.0, 0.6)
	instruction.visible = false
	add_child(instruction)

func _process(delta):
	if jugador_cerca and Input.is_action_just_pressed("interactuar"):
		if animando or not puerta_superior or not puerta_inferior:
			return
			
		animando = true
		tiempo_transcurrido = 0.0
		
		if puertas_abiertas:
			cerrar_puertas()
		else:
			abrir_puertas()
	
	if animando and puerta_superior and puerta_inferior:
		tiempo_transcurrido += delta
		var t = clamp(tiempo_transcurrido / duracion_animacion, 0, 1)
		
		if puertas_abiertas:
			# Abrir las puertas con interpolación
			var angulo_actual_superior = puerta_superior.rotation.y
			var angulo_actual_inferior = puerta_inferior.rotation.y
			
			puerta_superior.rotation.y = lerp_angle(angulo_actual_superior, angulo_abierto, t)
			puerta_inferior.rotation.y = lerp_angle(angulo_actual_inferior, angulo_abierto, t)
		else:
			# Cerrar las puertas con interpolación
			var angulo_actual_superior = puerta_superior.rotation.y
			var angulo_actual_inferior = puerta_inferior.rotation.y
			
			puerta_superior.rotation.y = lerp_angle(angulo_actual_superior, 0, t)
			puerta_inferior.rotation.y = lerp_angle(angulo_actual_inferior, 0, t)
		
		if t >= 1.0:
			animando = false
	
	# Actualizar visibilidad de instrucción
	if has_node("Instruction"):
		$Instruction.visible = jugador_cerca

func _on_body_entered(body):
	if body.name == "Player":
		jugador_cerca = true
		if has_node("Instruction"):
			$Instruction.visible = true

func _on_body_exited(body):
	if body.name == "Player":
		jugador_cerca = false
		if has_node("Instruction"):
			$Instruction.visible = false

func abrir_puertas():
	puertas_abiertas = true

func cerrar_puertas():
	puertas_abiertas = false
