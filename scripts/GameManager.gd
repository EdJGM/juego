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

var franja_anterior: String = ""
var clientes_por_minuto_actual: float = 0.4
var modificador_paciencia_actual: float = 1.4
var max_clientes_simultaneos: int = 4

# CONFIGURACIÓN DE FRANJAS HORARIAS DEL DÍA
var configuracion_dia: Dictionary = {
	"tiempo_total_minutos": 8,
	"dinero_inicial": 150,
	"max_clientes_simultaneos": 4,  # Máximo en cualquier momento
	
	# FRANJAS HORARIAS CON FLUJO REALISTA
	"franjas_horarias": {
		"manana": {
			"inicio_porcentaje": 0.0,     # 0% - 25% del día (9:00-11:00 AM)
			"fin_porcentaje": 0.25,
			"clientes_por_minuto": 1.5,   # TRANQUILO - Pocos clientes
			"modificador_paciencia": 1.4, # Más relajados por la mañana
			"descripcion": "Mañana tranquila"
		},
		"mediodia": {
			"inicio_porcentaje": 0.25,    # 25% - 60% del día (11:00-2:00 PM)
			"fin_porcentaje": 0.6,
			"clientes_por_minuto": 4.3,   # HORA PICO - Muchos clientes
			"modificador_paciencia": 0.7, # Menos paciencia en el rush
			"descripcion": "Rush del mediodía"
		},
		"tarde": {
			"inicio_porcentaje": 0.6,     # 60% - 85% del día (2:00-4:00 PM)
			"fin_porcentaje": 0.85,
			"clientes_por_minuto": 2.5,   # MODERADO - Más que la mañana
			"modificador_paciencia": 1.1, # Paciencia normal
			"descripcion": "Tarde moderada"
		},
		"noche": {
			"inicio_porcentaje": 0.85,    # 85% - 100% del día (4:00-5:00 PM)
			"fin_porcentaje": 1.0,
			"clientes_por_minuto": 1.5,   # TRANQUILO - Como la mañana
			"modificador_paciencia": 1.3, # Relajados al final del día
			"descripcion": "Final del día"
		}
	}
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
	configurar_dia_trabajo() 
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

func configurar_dia_trabajo():
	"""Configura el día de trabajo con franjas horarias"""
	var config = configuracion_dia
	
	# Aplicar configuración básica
	tiempo_dia_total = config.tiempo_total_minutos * 60.0
	dinero = config.dinero_inicial
	max_clientes_simultaneos = config.max_clientes_simultaneos
	
	# INICIALIZAR franja anterior
	franja_anterior = obtener_franja_actual()
	actualizar_franja_horaria()
	
	print("Día de trabajo configurado:")
	print("- Duración total: ", tiempo_dia_total, " segundos")
	print("- Dinero inicial: $", dinero)
	print("- Max clientes: ", max_clientes_simultaneos)
	print("- Franja inicial: ", franja_anterior)
	
	# Actualizar UI
	dinero_cambiado.emit(dinero)

func actualizar_franja_horaria():
	"""Actualiza la configuración según la franja horaria actual"""
	var franja_actual = obtener_franja_actual()
	var config_franja = configuracion_dia.franjas_horarias[franja_actual]
	
	# GUARDAR valores anteriores para logging
	var clientes_anterior = clientes_por_minuto_actual
	
	# Actualizar configuración actual
	clientes_por_minuto_actual = config_franja.clientes_por_minuto
	modificador_paciencia_actual = config_franja.modificador_paciencia
	
	print("🔄 Franja: ", franja_actual.to_upper(), " - ", config_franja.descripcion)
	print("   Clientes/min: ", clientes_anterior, " → ", clientes_por_minuto_actual)

func obtener_franja_actual() -> String:
	"""Determina la franja horaria actual basada en el progreso del día"""
	var progreso = tiempo_transcurrido / tiempo_dia_total
	var franjas = configuracion_dia.franjas_horarias
	
	for franja_nombre in franjas.keys():
		var franja = franjas[franja_nombre]
		if progreso >= franja.inicio_porcentaje and progreso < franja.fin_porcentaje:
			return franja_nombre
	
	# Si llegamos al final del día, devolver la última franja
	return "noche"

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
		timer_spawn_clientes.one_shot = false  # ASEGURAR que NO sea one_shot
		timer_spawn_clientes.timeout.connect(_on_spawn_cliente_timer)
		print("✓ Timer spawn clientes creado")
	
	# Timer principal del juego
	if not timer_juego:
		timer_juego = Timer.new()
		add_child(timer_juego)
		timer_juego.wait_time = 0.1
		timer_juego.one_shot = false  # ASEGURAR que NO sea one_shot
		timer_juego.timeout.connect(_on_timer_juego)
		print("✓ Timer principal creado")
	
	# Configurar frecuencia inicial
	actualizar_frecuencia_clientes()
	
	# Iniciar timer principal
	timer_juego.start()
	
	print("✓ Ambos timers configurados e iniciados")

func inicializar_ui():
	dinero_cambiado.emit(dinero)
	print("UI inicializada")

func _on_timer_juego():
	tiempo_transcurrido += 0.1
	var franja_actual = obtener_franja_actual()
	
	# NUEVO: Detectar cambio de franja y actualizar frecuencia
	if franja_actual != franja_anterior:
		print("🕐 CAMBIO DE FRANJA: ", franja_anterior, " → ", franja_actual)
		actualizar_franja_horaria()
		actualizar_timer_spawn()  # NUEVA FUNCIÓN
		franja_anterior = franja_actual
	
	tiempo_cambiado.emit(tiempo_transcurrido, franja_actual)
	
	# Verificar si el día terminó
	if tiempo_transcurrido >= tiempo_dia_total:
		terminar_dia()

func actualizar_timer_spawn():
	"""Actualiza inmediatamente el timer de spawn"""
	var intervalo = 60.0 / clientes_por_minuto_actual
	
	# Detener y reconfigurar timer
	timer_spawn_clientes.stop()
	timer_spawn_clientes.wait_time = intervalo
	timer_spawn_clientes.start()
	
	print("⏰ Timer spawn actualizado: intervalo de ", "%.1f" % intervalo, " segundos")

func obtener_fase_del_dia() -> String:
	"""Alias para mantener compatibilidad"""
	return obtener_franja_actual()

func actualizar_frecuencia_clientes():
	"""SOLO para inicialización - no cambiar franjas aquí"""
	actualizar_timer_spawn()

func _on_spawn_cliente_timer():
	"""SIMPLIFICADO: Solo spawn, sin cambiar frecuencia"""
	if clientes_activos.size() < max_clientes_simultaneos:
		spawn_cliente()

func spawn_cliente():
	if not cliente_scene or puntos_spawn_clientes.is_empty():
		print("ERROR: No se puede spawnear cliente - escena o puntos de spawn faltantes")
		return
	
	var cliente = cliente_scene.instantiate()
	var entrance_pos = Vector3(-10, 0.5, 0.294) #Entrada del restaurante
	if not cliente:
		print("ERROR: No se pudo instanciar el cliente")
		return
	
	var spawn_point = puntos_spawn_clientes[randi() % puntos_spawn_clientes.size()]
	
	# Agregar cliente a la escena principal
	var main_scene = get_tree().current_scene
	main_scene.add_child(cliente)
	#cliente.global_position = spawn_point
	cliente.global_position = entrance_pos
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

func calcular_estadisticas_finales() -> Dictionary:
	var total_pedidos = pedidos_completados_hoy + pedidos_perdidos_hoy
	var eficiencia = 0.0
	if total_pedidos > 0:
		eficiencia = float(pedidos_completados_hoy) / float(total_pedidos) * 100.0
	
	return {
		"dinero_final": dinero,
		"dinero_ganado": dinero - configuracion_dia.dinero_inicial,
		"pedidos_completados": pedidos_completados_hoy,
		"pedidos_perdidos": pedidos_perdidos_hoy,
		"eficiencia": eficiencia,
		"tiempo_total": tiempo_dia_total,
		"aprobado": eficiencia >= 60.0 and dinero >= configuracion_dia.dinero_inicial
	}

func generar_pedido_aleatorio() -> Dictionary:
	if not recetas_data.has("recetas") or recetas_data["recetas"].is_empty():
		print("ERROR: No hay recetas disponibles")
		return {}
	
	# --- SOLO USAR UNA RECETA ESPECÍFICA PARA PRUEBAS ---
	#var receta_key = "hamburguesa_basica"  # Cambia esto por el nombre de la receta que quieras probar
	#var recetas = recetas_data["recetas"]
	#if not recetas.has(receta_key):
		#print("ERROR: La receta de prueba no existe")
		#return {}
	#var receta = recetas[receta_key]
	# ---------------------------------------------------

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
	
	print("\n=== VERIFICACIÓN DE PEDIDO ===")
	print("Pedido esperado: ", pedido_esperado.datos_receta.get("nombre", "Sin nombre"))
	print("Ingredientes esperados: ", ingredientes_esperados)
	print("Ingredientes entregados: ", ingredientes_entregados)
	
	# Convertir a tipos para comparación
	var tipos_esperados = []
	var tipos_entregados = []
	
	for ingrediente in ingredientes_esperados:
		var tipo = detectar_tipo_ingrediente(ingrediente)
		tipos_esperados.append(tipo)
		print("- Esperado: ", ingrediente, " → Tipo: ", tipo)
	
	for ingrediente in ingredientes_entregados:
		var tipo = detectar_tipo_ingrediente(ingrediente)
		tipos_entregados.append(tipo)
		print("- Entregado: ", ingrediente, " → Tipo: ", tipo)
	
	print("Tipos esperados: ", tipos_esperados)
	print("Tipos entregados: ", tipos_entregados)
	
	# Verificar que todos los tipos requeridos estén presentes
	for tipo_esperado in tipos_esperados:
		if not tipo_esperado in tipos_entregados:
			print("❌ FALTA TIPO: ", tipo_esperado)
			print("================================\n")
			return false
	
	print("✅ TODOS LOS TIPOS PRESENTES")
	print("================================\n")
	return true

func detectar_tipo_ingrediente(nombre_ingrediente: String) -> String:
	"""Función unificada para detectar tipos de ingredientes"""
	if nombre_ingrediente == "":
		return "generico"
	
	var nombre = nombre_ingrediente.to_lower()
	
	# Detectar tipos específicos de pan (IMPORTANTE: orden específico)
	if "bun_bottom" in nombre:
		return "pan_inferior"
	elif "bun_top" in nombre:
		return "pan_superior"
	elif "bun" in nombre and not ("bottom" in nombre or "top" in nombre):
		return "pan_generico"
	# Detectar tipos específicos de carne (CORREGIDO)
	elif "vegetableburger" in nombre:
		return "carne"  # CAMBIO: Tratarla como "carne" también
	elif "burger" in nombre or "meat" in nombre or "carne" in nombre:
		return "carne"
	# Detectar ingredientes cortados vs enteros
	elif "tomato_slice" in nombre:
		return "tomate"  # CAMBIO: Simplificar a solo "tomate"
	elif "tomato" in nombre:
		return "tomate"  # CAMBIO: Tanto entero como cortado = "tomate"
	elif "lettuce_slice" in nombre:
		return "lechuga"  # CAMBIO: Simplificar a solo "lechuga"
	elif "lettuce" in nombre:
		return "lechuga"  # CAMBIO: Tanto entera como cortada = "lechuga"
	elif "cheese_slice" in nombre:
		return "queso"  # CAMBIO: Simplificar a solo "queso"
	elif "cheese" in nombre:
		return "queso"  # CAMBIO: Tanto entero como cortado = "queso"
	elif "sauce" in nombre or "salsa" in nombre or "ketchup" in nombre or "mustard" in nombre:
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

func forzar_spawn_cliente():
	spawn_cliente()
