# GameManager.gd - Sistema principal mejorado
extends Node

# Señales
signal dinero_cambiado(nuevo_dinero)
signal pedido_completado(pedido, dinero_ganado)
signal pedido_fallido(pedido, dinero_perdido)
signal tiempo_cambiado(tiempo_actual, fase_dia)
signal cliente_agregado(cliente)
signal nuevo_pedido_generado(pedido)
signal dia_terminado(estadisticas)

# Variables del juego
var dinero: int = 100
var tiempo_transcurrido: float = 0.0
var tiempo_dia_total: float = 480.0  # 8 minutos = 8 horas de juego
var recetas_data: Dictionary = {}
var pedidos_activos: Array = []
var clientes_activos: Array = []
var pedidos_completados_hoy: int = 0
var pedidos_perdidos_hoy: int = 0

# Referencias a escenas
@export var cliente_scene: PackedScene
var puntos_spawn_clientes: Array[Vector3] = []

# Configuración
var paciencia_base: float = 120.0
var clientes_por_minuto: Dictionary = {
	"manana": 0.8,
	"mediodia": 2.0, 
	"tarde": 1.2,
	"noche": 0.4
}

# Configuración de dificultad por fase del día
var modificador_paciencia: Dictionary = {
	"manana": 1.2,    # Más paciencia por la mañana
	"mediodia": 0.8,  # Menos paciencia al mediodía (rush)
	"tarde": 1.0,     # Paciencia normal
	"noche": 1.1      # Más paciencia por la noche
}

# Temporizadores
var timer_spawn_clientes: Timer
var timer_juego: Timer
var nivel_actual: String = "facil"

func _ready():
	print("GameManager inicializando...")
	cargar_recetas()
	configurar_temporizadores()
	configurar_escenas()
	inicializar_ui()
	print("GameManager inicializado correctamente")

func configurar_escenas():
	# Cargar la escena del cliente si no está asignada
	if not cliente_scene:
		cliente_scene = preload("res://addons/srcoder_thirdperson_controller/scenes/cliente.tscn")
	
	# Configurar puntos de spawn por defecto si están vacíos
	if puntos_spawn_clientes.is_empty():
		puntos_spawn_clientes = [
			Vector3(-1, 0.5, 0.2),
			Vector3(-0.5, 0.5, 0.2),
			Vector3(-1.5, 0.5, 0.2)
		]

func cargar_recetas():
	var file_path = "res://data/recetas.json"
	
	if not FileAccess.file_exists(file_path):
		print("Archivo de recetas no encontrado, creando recetas por defecto")
		crear_recetas_por_defecto()
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("No se pudo abrir el archivo de recetas")
		crear_recetas_por_defecto()
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result == OK:
		recetas_data = json.data
		print("Recetas cargadas correctamente: ", recetas_data.recetas.size(), " recetas")
	else:
		print("Error al parsear recetas: ", json.error_string, " en línea ", json.error_line)
		crear_recetas_por_defecto()

func crear_recetas_por_defecto():
	recetas_data = {
		"recetas": {
			"hamburguesa_basica": {
				"nombre": "Hamburguesa Básica",
				"precio": 50,
				"tiempo_preparacion": 30,
				"ingredientes": [
					"food_ingredient_bun_bottom",
					"food_ingredient_burger_cooked", 
					"food_ingredient_bun_top"
				],
				"ingredientes_opcionales": [],
				"dificultad": "facil"
			},
			"hamburguesa_completa": {
				"nombre": "Hamburguesa Completa",
				"precio": 80,
				"tiempo_preparacion": 45,
				"ingredientes": [
					"food_ingredient_bun_bottom",
					"food_ingredient_burger_cooked",
					"food_ingredient_lettuce_slice",
					"food_ingredient_tomato_slice",
					"food_ingredient_cheese_slice",
					"food_ingredient_bun_top"
				],
				"ingredientes_opcionales": [],
				"dificultad": "medio"
			}
		},
		"configuracion_juego": {
			"tiempo_dia_minutos": 8,
			"dinero_inicial": 100,
			"paciencia_base_segundos": 120
		}
	}
	print("Recetas por defecto creadas")

func configurar_temporizadores():
	# Timer para spawning de clientes
	if not timer_spawn_clientes:
		timer_spawn_clientes = Timer.new()
		add_child(timer_spawn_clientes)
		timer_spawn_clientes.timeout.connect(_on_spawn_cliente_timer)
	
	# Timer principal del juego
	if not timer_juego:
		timer_juego = Timer.new()
		add_child(timer_juego)
		timer_juego.wait_time = 0.1
		timer_juego.timeout.connect(_on_timer_juego)
	
	actualizar_frecuencia_clientes()
	timer_juego.start()

func inicializar_ui():
	dinero_cambiado.emit(dinero)
	print("UI inicializada")

func _on_timer_juego():
	tiempo_transcurrido += 0.1
	var fase_actual = obtener_fase_del_dia()
	tiempo_cambiado.emit(tiempo_transcurrido, fase_actual)
	
	# Verificar si el día terminó
	if tiempo_transcurrido >= tiempo_dia_total:
		terminar_dia()

func obtener_fase_del_dia() -> String:
	var porcentaje = tiempo_transcurrido / tiempo_dia_total
	
	if porcentaje < 0.25:
		return "manana"
	elif porcentaje < 0.6:
		return "mediodia" 
	elif porcentaje < 0.85:
		return "tarde"
	else:
		return "noche"

func actualizar_frecuencia_clientes():
	var fase = obtener_fase_del_dia()
	var frecuencia = clientes_por_minuto.get(fase, 1.0)
	var intervalo = 60.0 / frecuencia
	
	timer_spawn_clientes.wait_time = intervalo
	if not timer_spawn_clientes.is_stopped():
		timer_spawn_clientes.stop()
	timer_spawn_clientes.start()

func _on_spawn_cliente_timer():
	if clientes_activos.size() < 5:  # Máximo 5 clientes simultáneos
		spawn_cliente()
	actualizar_frecuencia_clientes()

func spawn_cliente():
	if not cliente_scene or puntos_spawn_clientes.is_empty():
		print("ERROR: No se puede spawnear cliente - escena o puntos de spawn faltantes")
		return
	
	var cliente = cliente_scene.instantiate()
	if not cliente:
		print("ERROR: No se pudo instanciar el cliente")
		return
	
	var spawn_point = puntos_spawn_clientes[randi() % puntos_spawn_clientes.size()]
	
	# Agregar cliente a la escena principal
	var main_scene = get_tree().current_scene
	main_scene.add_child(cliente)
	cliente.global_position = spawn_point
	cliente.add_to_group("clientes")
	
	# Generar pedido aleatorio
	var pedido = generar_pedido_aleatorio()
	cliente.asignar_pedido(pedido)
	
	clientes_activos.append(cliente)
	pedidos_activos.append(pedido)
	
	# Conectar señales del cliente
	if cliente.has_signal("cliente_se_fue"):
		cliente.cliente_se_fue.connect(_on_cliente_se_fue)
	if cliente.has_signal("pedido_entregado"):
		cliente.pedido_entregado.connect(_on_pedido_entregado)
	
	cliente_agregado.emit(cliente)
	nuevo_pedido_generado.emit(pedido)
	print("Cliente spawneado con pedido: ", pedido.get("nombre_receta", "Sin nombre"))

func generar_pedido_aleatorio() -> Dictionary:
	if not recetas_data.has("recetas") or recetas_data["recetas"].is_empty():
		print("ERROR: No hay recetas disponibles")
		return {}
	
	var recetas = recetas_data["recetas"]
	var recetas_keys = recetas.keys()
	var receta_key = recetas_keys[randi() % recetas_keys.size()]
	var receta = recetas[receta_key]
	
	# Calcular paciencia basada en la fase del día
	var fase_actual = obtener_fase_del_dia()
	var paciencia_modificada = paciencia_base * modificador_paciencia.get(fase_actual, 1.0)
	
	# Ajustar paciencia basada en la dificultad de la receta
	var dificultad = receta.get("dificultad", "facil")
	match dificultad:
		"facil":
			paciencia_modificada *= 1.2
		"medio":
			paciencia_modificada *= 1.0
		"dificil":
			paciencia_modificada *= 0.8
	
	var pedido = {
		"id": Time.get_unix_time_from_system() + randi(),
		"nombre_receta": receta_key,
		"datos_receta": receta,
		"tiempo_creacion": tiempo_transcurrido,
		"paciencia_maxima": paciencia_modificada,
		"ingredientes_completados": [],
		"fase_creacion": fase_actual
	}
	
	return pedido

func _on_cliente_se_fue(cliente):
	var indice = clientes_activos.find(cliente)
	if indice == -1:
		return
	
	var pedido = pedidos_activos[indice]
	
	# Penalizar por pedido perdido
	var penalizacion = calcular_penalizacion(pedido)
	cambiar_dinero(-penalizacion)
	
	pedidos_activos.remove_at(indice)
	clientes_activos.remove_at(indice)
	pedidos_perdidos_hoy += 1
	
	pedido_fallido.emit(pedido, penalizacion)
	print("Cliente se fue decepcionado. Penalización: $", penalizacion)

func calcular_penalizacion(pedido: Dictionary) -> int:
	var precio_base = pedido.datos_receta.get("precio", 20)
	var penalizacion_base = precio_base * 0.3
	
	# Penalización mayor durante el rush del mediodía
	var fase = pedido.get("fase_creacion", "manana")
	if fase == "mediodia":
		penalizacion_base *= 1.5
	
	return int(penalizacion_base)

func _on_pedido_entregado(cliente, pedido_entregado_por_jugador):
	var indice = clientes_activos.find(cliente)
	if indice == -1:
		print("ERROR: Cliente no encontrado en lista activa")
		return
	
	var pedido_esperado = pedidos_activos[indice]
	
	if verificar_pedido_completo(pedido_esperado, pedido_entregado_por_jugador):
		# Calcular ganancia
		var ganancia = calcular_ganancia(pedido_esperado)
		cambiar_dinero(ganancia)
		
		pedidos_activos.remove_at(indice)
		clientes_activos.remove_at(indice)
		pedidos_completados_hoy += 1
		
		pedido_completado.emit(pedido_esperado, ganancia)
		print("¡Pedido completado! Ganancia: $", ganancia)
		
		# El cliente se va satisfecho
		if cliente.has_method("marchar_satisfecho"):
			cliente.marchar_satisfecho()
	else:
		print("Pedido incompleto o incorrecto")
		# Aquí podrías agregar retroalimentación visual

func verificar_pedido_completo(pedido_esperado: Dictionary, pedido_entregado: Dictionary) -> bool:
	var ingredientes_esperados = pedido_esperado.datos_receta.get("ingredientes", [])
	var ingredientes_entregados = pedido_entregado.get("ingredientes", [])
	
	print("Verificando pedido:")
	print("Esperados: ", ingredientes_esperados)
	print("Entregados: ", ingredientes_entregados)
	
	# Verificar que todos los ingredientes requeridos estén presentes
	for ingrediente in ingredientes_esperados:
		var tipo_esperado = detectar_tipo_ingrediente(ingrediente)
		var encontrado = false
		
		for ingrediente_entregado in ingredientes_entregados:
			var tipo_entregado = detectar_tipo_ingrediente(ingrediente_entregado)
			if tipo_esperado == tipo_entregado:
				encontrado = true
				break
		
		if not encontrado:
			print("Falta ingrediente tipo: ", tipo_esperado)
			return false
	
	print("¡Todos los ingredientes están presentes!")
	return true

func detectar_tipo_ingrediente(nombre_ingrediente: String) -> String:
	nombre_ingrediente = nombre_ingrediente.to_lower()
	
	if "bun" in nombre_ingrediente or "pan" in nombre_ingrediente:
		return "pan"
	elif "burger" in nombre_ingrediente or "meat" in nombre_ingrediente or "carne" in nombre_ingrediente:
		return "carne"
	elif "tomato" in nombre_ingrediente or "tomate" in nombre_ingrediente:
		return "tomate"
	elif "lettuce" in nombre_ingrediente or "lechuga" in nombre_ingrediente:
		return "lechuga"
	elif "cheese" in nombre_ingrediente or "queso" in nombre_ingrediente:
		return "queso"
	elif "sauce" in nombre_ingrediente or "salsa" in nombre_ingrediente:
		return "salsa"
	else:
		return "generico"

func calcular_ganancia(pedido: Dictionary) -> int:
	var precio_base = pedido.datos_receta.get("precio", 50)
	var tiempo_restante = pedido.paciencia_maxima - (tiempo_transcurrido - pedido.tiempo_creacion)
	
	# Bonificación por rapidez
	var porcentaje_tiempo = tiempo_restante / pedido.paciencia_maxima
	var bonificacion = 1.0
	
	if porcentaje_tiempo > 0.7:
		bonificacion = 1.5  # Muy rápido
	elif porcentaje_tiempo > 0.4:
		bonificacion = 1.2  # Rápido
	elif porcentaje_tiempo > 0.1:
		bonificacion = 1.0  # Normal
	else:
		bonificacion = 0.7  # Tarde
	
	# Bonificación extra durante el rush del mediodía
	var fase = pedido.get("fase_creacion", "manana")
	if fase == "mediodia":
		bonificacion *= 1.1
	
	return int(precio_base * bonificacion)

func cambiar_dinero(cantidad: int):
	dinero += cantidad
	dinero = max(0, dinero)
	dinero_cambiado.emit(dinero)

func terminar_dia():
	print("\n=== DÍA TERMINADO ===")
	
	var estadisticas = {
		"dinero_final": dinero,
		"pedidos_completados": pedidos_completados_hoy,
		"pedidos_perdidos": pedidos_perdidos_hoy,
		"eficiencia": float(pedidos_completados_hoy) / float(pedidos_completados_hoy + pedidos_perdidos_hoy) * 100.0 if (pedidos_completados_hoy + pedidos_perdidos_hoy) > 0 else 0.0
	}
	
	print("Dinero final: $", dinero)
	print("Pedidos completados: ", pedidos_completados_hoy)
	print("Pedidos perdidos: ", pedidos_perdidos_hoy)
	print("Eficiencia: ", "%.1f%%" % estadisticas.eficiencia)
	print("==================")
	
	dia_terminado.emit(estadisticas)
	get_tree().paused = true

# Funciones de utilidad
func obtener_receta(nombre_receta: String) -> Dictionary:
	if recetas_data.has("recetas") and recetas_data["recetas"].has(nombre_receta):
		return recetas_data["recetas"][nombre_receta]
	return {}

func obtener_todas_las_recetas() -> Dictionary:
	return recetas_data.get("recetas", {})

func obtener_pedidos_activos() -> Array:
	return pedidos_activos.duplicate()

func obtener_clientes_activos() -> Array:
	return clientes_activos.duplicate()

func obtener_estadisticas_dia() -> Dictionary:
	return {
		"tiempo_transcurrido": tiempo_transcurrido,
		"fase_actual": obtener_fase_del_dia(),
		"dinero_actual": dinero,
		"pedidos_completados": pedidos_completados_hoy,
		"pedidos_perdidos": pedidos_perdidos_hoy,
		"clientes_activos": clientes_activos.size()
	}

# Función para debugging
func forzar_spawn_cliente():
	spawn_cliente()

func reiniciar_dia():
	# Limpiar clientes activos
	for cliente in clientes_activos:
		if is_instance_valid(cliente):
			cliente.queue_free()
	
	clientes_activos.clear()
	pedidos_activos.clear()
	pedidos_completados_hoy = 0
	pedidos_perdidos_hoy = 0
	tiempo_transcurrido = 0.0
	dinero = 100
	
	get_tree().paused = false
	dinero_cambiado.emit(dinero)
	print("Día reiniciado")
