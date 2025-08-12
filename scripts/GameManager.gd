# GameManager.gd - Sistema principal mejorado
extends Node

# Señales
signal dinero_cambiado(nuevo_dinero)
signal pedido_completado(pedido, dinero_ganado)
signal pedido_fallido(pedido, dinero_perdido, cliente_que_se_fue)
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

# NUEVO: Sistema de reserva de mesas
var mesas_reservadas: Array = []  # Mesas que están reservadas pero no ocupadas aún

# Sistema de música dinámica
var audio_player: AudioStreamPlayer
var musica_actual: String = ""
var volumen_musica: float = 0.5
var musica_manana: AudioStream
var musica_hora_pico: AudioStream

# ========== SISTEMA DE NIVELES ==========
var nivel_actual: int = 1
var configuracion_niveles: Dictionary = {
	1: {
		"nombre": "Nivel 1 - Principiante",
		"eficiencia_requerida": 40.0,
		"dinero_objetivo": 200,
		"descripcion": "Aprende los básicos del servicio"
	},
	2: {
		"nombre": "Nivel 2 - Experimentado", 
		"eficiencia_requerida": 60.0,
		"dinero_objetivo": 350,
		"descripcion": "Mejora tu velocidad y precisión"
	},
	3: {
		"nombre": "Nivel 3 - Experto",
		"eficiencia_requerida": 75.0,
		"dinero_objetivo": 500,
		"descripcion": "Domina la hora pico"
	},
	4: {
		"nombre": "Nivel 4 - Maestro",
		"eficiencia_requerida": 85.0,
		"dinero_objetivo": 650,
		"descripcion": "Perfección en el servicio"
	}
}

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
			"clientes_por_minuto": 6.0,   # HORA PICO INTENSIFICADA - Muchos más clientes
			"modificador_paciencia": 0.6, # Menos paciencia en el rush
			"descripcion": "🔥 RUSH INTENSO del mediodía"
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

func _ready():
	print("GameManager inicializando...")
	configurar_dia_trabajo() 
	cargar_recetas()
	inicializar_sistema_musica()  # MOVER ANTES de configurar temporizadores
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
	
	# NO iniciar música aquí - esperar a que se active explícitamente
	
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
	
	# Actualizar el cielo según la hora
	actualizar_cielo_segun_hora(franja_actual)
	
	# Cambiar la música según la nueva franja
	cambiar_musica_segun_hora(franja_actual)

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

func inicializar_sistema_musica():
	"""Inicializa el sistema de música dinámica - NO reproduce automáticamente"""
	print("🎵 Inicializando sistema de música...")
	
	# Crear el AudioStreamPlayer con configuración específica
	audio_player = AudioStreamPlayer.new()
	audio_player.name = "GameMusicPlayer"
	audio_player.volume_db = linear_to_db(volumen_musica)
	audio_player.autoplay = false
	audio_player.bus = "Master"  # Asegurar que use el bus principal
	add_child(audio_player)
	
	# Añadir a grupo para fácil identificación
	audio_player.add_to_group("game_music")
	
	print("🎵 AudioStreamPlayer creado: ", audio_player.name)
	print("🎵 Bus de audio: ", audio_player.bus)
	print("🎵 Volumen configurado: ", audio_player.volume_db)
	
	# Cargar archivos de música
	cargar_archivos_musica()
	
	# NO reproducir música automáticamente - esperar a que inicie el juego
	print("✅ Sistema de música inicializado (en espera)")

func iniciar_musica_juego():
	"""Inicia la música cuando comienza el juego (llamar desde el botón)"""
	print("🎵 Iniciando música del juego...")
	
	# SIMPLE: Solo iniciar la música directamente
	if musica_manana and audio_player:
		audio_player.stream = musica_manana
		audio_player.play()
		musica_actual = "manana"
		print("🎵 Música de mañana iniciada directamente")
		print("🎵 Estado: Playing = ", audio_player.playing)
	else:
		print("❌ No se pudo iniciar: musica_manana=", musica_manana != null, " audio_player=", audio_player != null)

func detener_musica_menu_existente():
	"""Detiene cualquier música del menú que pueda estar activa"""
	print("🎵 Buscando y deteniendo música del menú...")
	
	# Buscar todos los AudioStreamPlayer en la escena
	var todos_los_players = get_tree().get_nodes_in_group("music_players")
	for player in todos_los_players:
		if player != audio_player and player.playing:
			print("🎵 Deteniendo player externo: ", player.name)
			player.stop()
	
	# Buscar por nombre común
	var scene_root = get_tree().current_scene
	var menu_players = []
	buscar_audio_players_recursivo(scene_root, menu_players)
	
	for player in menu_players:
		if player != audio_player and player.playing:
			print("🎵 Deteniendo player encontrado: ", player.get_path())
			player.stop()

func buscar_audio_players_recursivo(node: Node, lista_players: Array):
	"""Busca recursivamente todos los AudioStreamPlayer"""
	if node is AudioStreamPlayer:
		lista_players.append(node)
	
	for child in node.get_children():
		buscar_audio_players_recursivo(child, lista_players)

func cargar_archivos_musica():
	"""Carga los archivos de música del sistema - SIMPLE"""
	print("🎵 Cargando archivos de música...")
	
	# Rutas de los archivos
	var ruta_manana = "res://audio/music/manana.ogg"
	var ruta_hora_pico = "res://audio/music/hora_pico.ogg"
	
	# Cargar música de mañana
	if ResourceLoader.exists(ruta_manana):
		musica_manana = load(ruta_manana)
		if musica_manana is AudioStreamOggVorbis:
			musica_manana.loop = true
		print("✅ Música de mañana cargada")
	else:
		print("❌ No se encontró: ", ruta_manana)
	
	# Cargar música de hora pico
	if ResourceLoader.exists(ruta_hora_pico):
		musica_hora_pico = load(ruta_hora_pico)
		if musica_hora_pico is AudioStreamOggVorbis:
			musica_hora_pico.loop = true
		print("✅ Música de hora pico cargada")
	else:
		print("❌ No se encontró: ", ruta_hora_pico)
	
	print("🎵 Archivos cargados - Mañana: ", musica_manana != null, ", Hora pico: ", musica_hora_pico != null)

func buscar_musica_fallback():
	"""Busca música existente como fallback temporal"""
	var rutas_fallback = [
		"res://Musica/Jazz In Paris.mp3",
	]
	
	for ruta in rutas_fallback:
		if ResourceLoader.exists(ruta):
			print("🎵 Usando música fallback: ", ruta)
			var stream = load(ruta)
			if not musica_manana:
				musica_manana = stream
				if stream is AudioStreamMP3:
					stream.loop = true
			if not musica_hora_pico:
				musica_hora_pico = stream
				if stream is AudioStreamMP3:
					stream.loop = true
			break

func mostrar_instrucciones_musica():
	"""Muestra instrucciones para añadir archivos de música"""
	print("\n🎵 === INSTRUCCIONES PARA AÑADIR MÚSICA ===")
	print("Para el sistema de música dinámica, necesitas:")
	print("1. Crear la carpeta: res://audio/music/")
	print("2. Añadir estos archivos de música:")
	print("   • manana.ogg - Música relajante para la mañana")
	print("   • hora_pico.ogg - Música intensa para el mediodía")
	print("3. Formatos compatibles: .ogg, .wav, .mp3")
	print("4. Recomendación: archivos .ogg comprimidos para mejor rendimiento")
	print("==========================================\n")

func cambiar_musica_segun_hora(franja: String) -> void:
	"""Cambia la música según la franja horaria - VERSIÓN SIMPLIFICADA"""
	var nueva_musica = ""
	var stream_a_reproducir = null
	
	match franja:
		"manana":
			nueva_musica = "manana"
			stream_a_reproducir = musica_manana
		"mediodia":
			nueva_musica = "hora_pico" 
			stream_a_reproducir = musica_hora_pico
		"tarde":
			# En la tarde se repite la música de la mañana
			nueva_musica = "manana"
			stream_a_reproducir = musica_manana
		"noche":
			# En la noche también música de mañana (relajante)
			nueva_musica = "manana"
			stream_a_reproducir = musica_manana
	
	# SIMPLE: Solo cambiar si es diferente y tenemos el archivo
	if nueva_musica != musica_actual and stream_a_reproducir and audio_player:
		print("🎵 Cambiando música: ", musica_actual, " → ", nueva_musica, " (", franja, ")")
		audio_player.stop()
		audio_player.stream = stream_a_reproducir
		audio_player.play()
		musica_actual = nueva_musica
		print("🎵 Nueva música reproduciendo: ", audio_player.playing)
	elif not stream_a_reproducir:
		print("⚠️ Stream no disponible para: ", franja)
	elif nueva_musica == musica_actual and not audio_player.playing:
		print("🎵 Misma música pero no estaba sonando, reiniciando...")
		audio_player.play()

# Funciones de control simplificadas eliminadas - ahora se maneja directamente

func cambiar_volumen(nuevo_volumen: float):
	"""Cambia el volumen del audio player"""
	if audio_player:
		audio_player.volume_db = linear_to_db(nuevo_volumen)

func pausar_musica():
	"""Pausa la música del juego"""
	if audio_player and audio_player.playing:
		audio_player.stream_paused = true
		print("🎵 Música pausada")

func reanudar_musica():
	"""Reanuda la música del juego"""
	if audio_player:
		audio_player.stream_paused = false
		print("🎵 Música reanudada")

func detener_musica():
	"""Detiene completamente la música"""
	if audio_player:
		audio_player.stop()
		musica_actual = ""
		print("🎵 Música detenida")

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
			},
			"hamburguesa_vegetariana": {
				"nombre": "Hamburguesa Vegetariana",
				"precio": 70,
				"tiempo_preparacion": 40,
				"ingredientes": [
					"food_ingredient_bun_bottom",
					"food_ingredient_cheese_slice",
					"food_ingredient_lettuce_slice",
					"food_ingredient_tomato_slice",
					"food_ingredient_bun_top"
				],
				"ingredientes_opcionales": [],
				"dificultad": "medio"
			},
			"ensalada": {
				"nombre": "Ensalada Fresca",
				"precio": 40,
				"tiempo_preparacion": 20,
				"ingredientes": [
					"food_ingredient_lettuce_slice",
					"food_ingredient_tomato_slice"
				],
				"ingredientes_opcionales": [],
				"dificultad": "facil"
			},
			"hamburguesa_supreme": {
				"nombre": "Hamburguesa Supreme",
				"precio": 120,
				"tiempo_preparacion": 60,
				"ingredientes": [
					"food_ingredient_bun_bottom",
					"food_ingredient_burger_cooked",
					"food_ingredient_bacon",
					"food_ingredient_cheese_slice",
					"food_ingredient_lettuce_slice",
					"food_ingredient_tomato_slice",
					"food_ingredient_onion_slice",
					"food_ingredient_pickle",
					"food_ingredient_bun_top"
				],
				"ingredientes_opcionales": [],
				"dificultad": "dificil"
			},
			"hamburguesa_breakfast": {
				"nombre": "Hamburguesa Desayuno",
				"precio": 100,
				"tiempo_preparacion": 55,
				"ingredientes": [
					"food_ingredient_bun_bottom",
					"food_ingredient_burger_cooked",
					"food_ingredient_egg_fried",
					"food_ingredient_bacon",
					"food_ingredient_cheese_slice",
					"food_ingredient_bun_top"
				],
				"ingredientes_opcionales": [],
				"dificultad": "medio"
			},
			"ensalada_deluxe": {
				"nombre": "Ensalada Deluxe",
				"precio": 60,
				"tiempo_preparacion": 30,
				"ingredientes": [
					"food_ingredient_lettuce_slice",
					"food_ingredient_tomato_slice",
					"food_ingredient_cucumber_slice",
					"food_ingredient_onion_slice",
					"food_ingredient_avocado_slice"
				],
				"ingredientes_opcionales": [],
				"dificultad": "medio"
			},
			"hamburguesa_mushroom": {
				"nombre": "Hamburguesa de Champiñones",
				"precio": 90,
				"tiempo_preparacion": 50,
				"ingredientes": [
					"food_ingredient_bun_bottom",
					"food_ingredient_burger_cooked",
					"food_ingredient_mushroom_grilled",
					"food_ingredient_cheese_slice",
					"food_ingredient_mayonnaise",
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
	print("Recetas por defecto creadas - ", recetas_data.recetas.size(), " recetas disponibles")

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
	
	# Iniciar música del juego cuando los timers se activan
	iniciar_musica_juego()
	
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
	print("🏭 GAMEMANAGER: Generando pedido ", pedido.get("nombre_receta", "Sin nombre"), " para cliente")
	
	cliente.asignar_pedido(pedido)
	
	clientes_activos.append(cliente)
	pedidos_activos.append(pedido)
	
	print("🏭 GAMEMANAGER: Cliente y pedido agregados a listas activas")
	
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

	# Filtrar recetas según el nivel actual
	var recetas = recetas_data["recetas"]
	var recetas_disponibles = []
	
	# Determinar qué recetas están disponibles según el nivel
	match nivel_actual:
		1:
			recetas_disponibles = ["hamburguesa_basica", "ensalada_simple", "hamburguesa_de_queso"]
		2:
			recetas_disponibles = ["hamburguesa_basica", "cheeseburger", "ensalada_simple", "hamburguesa_vegetariana"]
		3:
			recetas_disponibles = recetas.keys()  # Todas las recetas
		_:
			# Nivel 4 o superior - todas las recetas
			recetas_disponibles = recetas.keys()
	
	# Filtrar solo las recetas que existen en el JSON
	var recetas_existentes = []
	for receta_key in recetas_disponibles:
		if recetas.has(receta_key):
			recetas_existentes.append(receta_key)
	
	if recetas_existentes.is_empty():
		print("ERROR: No hay recetas disponibles para el nivel ", nivel_actual)
		return {}
	
	var receta_key = recetas_existentes[randi() % recetas_existentes.size()]
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
	
	# MEJORA: Emitir señal con cliente e información del pedido
	pedido_fallido.emit(pedido, penalizacion, cliente)
	print("Cliente ", cliente.name if cliente else "desconocido", " se fue decepcionado. Penalización: $", penalizacion)

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
		print("❌ ENTREGA: Cliente no encontrado en lista activa")
		return
	
	var pedido_esperado = pedidos_activos[indice]
	
	if verificar_pedido_completo(pedido_esperado, pedido_entregado_por_jugador):
		print("✅ ENTREGA: Pedido correcto - Ganancia calculada")
		
		# Calcular ganancia
		var ganancia = calcular_ganancia(pedido_esperado)
		cambiar_dinero(ganancia)
		
		# Remover cliente y pedido de las listas activas
		pedidos_activos.remove_at(indice)
		clientes_activos.remove_at(indice)
		pedidos_completados_hoy += 1
		
		# Emitir señal de pedido completado
		pedido_completado.emit(pedido_esperado, ganancia)
		
		# El cliente se va satisfecho
		if cliente and cliente.has_method("marchar_satisfecho"):
			print("✅ ENTREGA: Llamando marchar_satisfecho")
			cliente.marchar_satisfecho()
		else:
			print("❌ ENTREGA: Cliente sin método marchar_satisfecho")
	else:
		print("❌ ENTREGA: Pedido incorrecto - Cliente se va enojado")
		
		# Determinar qué tipo de error fue
		var tipos_esperados = []
		var tipos_entregados = []
		for ingrediente in pedido_esperado.datos_receta.get("ingredientes", []):
			tipos_esperados.append(detectar_tipo_ingrediente(ingrediente))
		for ingrediente in pedido_entregado_por_jugador.get("ingredientes", []):
			tipos_entregados.append(detectar_tipo_ingrediente(ingrediente))
		
		var mensaje_error = "¡Esto no es lo que pedí!"
		# Verificar si sobran ingredientes
		for tipo in tipos_entregados:
			if not tipo in tipos_esperados:
				mensaje_error = "¡Esto tiene ingredientes que no pedí!"
				break
		# Verificar si faltan ingredientes
		for tipo in tipos_esperados:
			if not tipo in tipos_entregados:
				mensaje_error = "¡Te faltan ingredientes!"
				break
		
		# CORRECCIÓN: Cliente se va enojado por pedido incorrecto
		if cliente and cliente.has_method("marcharse_enojado"):
			cliente.marcharse_enojado(mensaje_error)
		elif cliente and cliente.has_method("cambiar_estado"):
			# Fallback si no tiene marcharse_enojado
			cliente.cambiar_estado(2)  # EstadoCliente.SALIENDO_ENOJADO
		
		# Penalizar al jugador
		var penalizacion = calcular_penalizacion(pedido_esperado)
		cambiar_dinero(-penalizacion)
		
		# Remover de listas activas
		pedidos_activos.remove_at(indice)
		clientes_activos.remove_at(indice)
		pedidos_perdidos_hoy += 1
		
		# Emitir señal de pedido fallido
		pedido_fallido.emit(pedido_esperado, penalizacion, cliente)

func verificar_pedido_completo(pedido_esperado: Dictionary, pedido_entregado: Dictionary) -> bool:
	var ingredientes_esperados = pedido_esperado.datos_receta.get("ingredientes", [])
	var ingredientes_entregados = pedido_entregado.get("ingredientes", [])
	
	print("\n🔍 VALIDACIÓN: ", pedido_esperado.datos_receta.get("nombre", "Sin nombre"))
	print("   Esperados: ", ingredientes_esperados)
	print("   Entregados: ", ingredientes_entregados)
	
	# Convertir a tipos para comparación
	var tipos_esperados = []
	var tipos_entregados = []
	
	for ingrediente in ingredientes_esperados:
		var tipo = detectar_tipo_ingrediente(ingrediente)
		tipos_esperados.append(tipo)
	
	for ingrediente in ingredientes_entregados:
		var tipo = detectar_tipo_ingrediente(ingrediente)
		tipos_entregados.append(tipo)
	
	print("   Tipos esperados: ", tipos_esperados)
	print("   Tipos entregados: ", tipos_entregados)
	
	# Verificar que todos los tipos requeridos estén presentes
	for tipo_esperado in tipos_esperados:
		if not tipo_esperado in tipos_entregados:
			print("❌ VALIDACIÓN: FALTA ", tipo_esperado)
			return false
	
	# NUEVA VERIFICACIÓN: También verificar que no haya ingredientes extras
	for tipo_entregado in tipos_entregados:
		if not tipo_entregado in tipos_esperados:
			print("❌ VALIDACIÓN: SOBRA ", tipo_entregado, " (no requerido)")
			return false
	
	print("✅ VALIDACIÓN: PEDIDO CORRECTO")
	return true

func detectar_tipo_ingrediente(nombre_ingrediente: String) -> String:
	"""Función unificada para detectar tipos de ingredientes - Compatible con KayKit"""
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
	# Detectar tipos específicos de carne (BASADO EN KAYKIT)
	elif "vegetableburger" in nombre:
		return "carne_vegetal"
	elif "burger" in nombre:
		return "carne"
	elif "ham" in nombre:
		return "jamon"  # DISPONIBLE EN KAYKIT
	elif "steak" in nombre:
		return "filete"  # DISPONIBLE EN KAYKIT
	# Detectar vegetales (BASADO EN KAYKIT)
	elif "tomato" in nombre:
		return "tomate"
	elif "lettuce" in nombre:
		return "lechuga"
	elif "onion_chopped" in nombre:
		return "cebolla_picada"  # DISPONIBLE EN KAYKIT
	elif "onion" in nombre:
		return "cebolla"  # DISPONIBLE EN KAYKIT
	elif "carrot" in nombre:
		return "zanahoria"  # DISPONIBLE EN KAYKIT
	elif "potato" in nombre:
		return "papa"  # DISPONIBLE EN KAYKIT
	# Ingredientes nuevos específicos
	elif "ham_cooked" in nombre:
		return "pollo"  # food_ingredient_ham_cooked = Pollo frito
	elif "steak_pieces" in nombre:
		return "carne_frita"  # food_ingredient_steak_pieces = Trozos de carne frita
	# Otros ingredientes (BASADO EN KAYKIT)
	elif "cheese" in nombre:
		return "queso"
	elif "ketchup" in nombre:
		return "ketchup"  # DISPONIBLE EN KAYKIT
	# Fallbacks para ingredientes no disponibles
	elif "bacon" in nombre:
		return "jamon"  # Usar jamón como sustituto
	elif "pickle" in nombre:
		return "pepinillo"
	elif "avocado" in nombre:
		return "aguacate"
	elif "cucumber" in nombre:
		return "pepino"
	elif "egg" in nombre:
		return "huevo"
	elif "mushroom" in nombre:
		return "champiñon"
	elif "sauce" in nombre or "salsa" in nombre:
		return "salsa"
	elif "mustard" in nombre:
		return "mostaza"
	elif "mayo" in nombre or "mayonnaise" in nombre:
		return "mayonesa"
	elif "french_fries" in nombre or "fries" in nombre or "papas" in nombre:
		return "papas_fritas"
	elif "drink" in nombre or "soda" in nombre or "bebida" in nombre:
		return "bebida"
	else:
		# En lugar de "generico", retornar el nombre original para debugging
		print("⚠️ INGREDIENTE NO RECONOCIDO: ", nombre_ingrediente)
		return nombre_ingrediente

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
	
	var total_pedidos = pedidos_completados_hoy + pedidos_perdidos_hoy
	var eficiencia = 0.0
	if total_pedidos > 0:
		eficiencia = float(pedidos_completados_hoy) / float(total_pedidos) * 100.0
	
	var config_nivel = configuracion_niveles.get(nivel_actual, {})
	var eficiencia_requerida = config_nivel.get("eficiencia_requerida", 40.0)
	var dinero_objetivo = config_nivel.get("dinero_objetivo", 200)
	
	# Verificar si pasó el nivel
	var nivel_aprobado = eficiencia >= eficiencia_requerida and dinero >= dinero_objetivo
	
	var estadisticas = {
		"dinero_final": dinero,
		"dinero_inicial": configuracion_dia.dinero_inicial,
		"dinero_ganado": dinero - configuracion_dia.dinero_inicial,
		"pedidos_completados": pedidos_completados_hoy,
		"pedidos_perdidos": pedidos_perdidos_hoy,
		"total_pedidos": total_pedidos,
		"eficiencia": eficiencia,
		"nivel_actual": nivel_actual,
		"eficiencia_requerida": eficiencia_requerida,
		"dinero_objetivo": dinero_objetivo,
		"nivel_aprobado": nivel_aprobado,
		"tiempo_total": tiempo_dia_total,
		"nombre_nivel": config_nivel.get("nombre", "Nivel Desconocido"),
		"descripcion_nivel": config_nivel.get("descripcion", "")
	}
	
	print("NIVEL: ", config_nivel.get("nombre", "Desconocido"))
	print("Dinero final: $", dinero, " / $", dinero_objetivo, " objetivo")
	print("Eficiencia: ", "%.1f%%" % eficiencia, " / ", eficiencia_requerida, "% requerida")
	print("Pedidos completados: ", pedidos_completados_hoy)
	print("Pedidos perdidos: ", pedidos_perdidos_hoy)
	
	if nivel_aprobado:
		print("🎉 ¡NIVEL APROBADO! ¡Felicitaciones!")
		if nivel_actual < configuracion_niveles.size():
			print("🔓 Desbloqueaste el siguiente nivel")
	else:
		print("❌ Nivel no aprobado. ¡Inténtalo de nuevo!")
		if eficiencia < eficiencia_requerida:
			print("   • Necesitas mejorar tu eficiencia")
		if dinero < dinero_objetivo:
			print("   • Necesitas ganar más dinero")
	
	print("==================")
	
	dia_terminado.emit(estadisticas)
	mostrar_pantalla_resultados(estadisticas)
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
	dinero = 100  # Solo resetear dinero cuando reinicias completamente
	
	get_tree().paused = false
	dinero_cambiado.emit(dinero)
	print("Día reiniciado")

func iniciar_siguiente_nivel():
	"""Inicia el siguiente nivel manteniendo el progreso"""
	print("🎮 INICIANDO NIVEL ", nivel_actual)
	
	# Limpiar clientes activos
	for cliente in clientes_activos:
		if is_instance_valid(cliente):
			cliente.queue_free()
	
	clientes_activos.clear()
	pedidos_activos.clear()
	pedidos_completados_hoy = 0
	pedidos_perdidos_hoy = 0
	tiempo_transcurrido = 0.0
	# NO resetear dinero - mantener progreso
	
	get_tree().paused = false
	
	# Mostrar info del nuevo nivel
	var info_nivel = obtener_info_nivel_actual()
	print("📋 NUEVO NIVEL - Objetivo dinero: $", info_nivel.get("objetivo_dinero", 0))
	print("📋 NUEVO NIVEL - Objetivo pedidos: ", info_nivel.get("objetivo_pedidos", 0))
	print("📋 NUEVO NIVEL - Duración: ", info_nivel.get("duracion_minutos", 0), " minutos")
	
	dinero_cambiado.emit(dinero)
	print("✅ Nivel ", nivel_actual, " iniciado correctamente")

func forzar_spawn_cliente():
	spawn_cliente()

# ========== SISTEMA DE CIELO DINÁMICO ==========
func actualizar_cielo_segun_hora(franja: String):
	"""Cambia el cielo y ambiente según la hora del día"""
	var main_scene = get_tree().current_scene
	if not main_scene:
		return
	
	# Buscar el environment del mundo
	var world_env = main_scene.get_node_or_null("WorldEnvironment")
	if not world_env:
		print("⚠️ No se encontró WorldEnvironment para cambiar el cielo")
		return
	
	var environment = world_env.environment
	if not environment:
		print("⚠️ No hay environment configurado")
		return
	
	# Configurar colores y configuración según la franja
	match franja:
		"manana":
			# Cielo matutino - tonos dorados y azules claros
			environment.background_color = Color(0.7, 0.8, 1.0)  # Azul claro
			environment.ambient_light_color = Color(1.0, 0.9, 0.7)  # Luz dorada suave
			environment.ambient_light_energy = 0.3
			print("🌅 Cielo cambiado a: Mañana - tonos dorados")
			
		"mediodia":
			# Cielo de mediodía - brillante y claro
			environment.background_color = Color(0.4, 0.7, 1.0)  # Azul intenso
			environment.ambient_light_color = Color(1.0, 1.0, 0.9)  # Luz blanca intensa
			environment.ambient_light_energy = 0.5
			print("☀️ Cielo cambiado a: Mediodía - brillante y claro")
			
		"tarde":
			# Cielo de tarde - tonos naranjas
			environment.background_color = Color(1.0, 0.7, 0.4)  # Naranja suave
			environment.ambient_light_color = Color(1.0, 0.8, 0.6)  # Luz cálida
			environment.ambient_light_energy = 0.4
			print("🌇 Cielo cambiado a: Tarde - tonos naranjas")
			
		"noche":
			# Cielo nocturno - tonos azules oscuros
			environment.background_color = Color(0.1, 0.2, 0.4)  # Azul oscuro
			environment.ambient_light_color = Color(0.5, 0.6, 1.0)  # Luz azulada
			environment.ambient_light_energy = 0.2
			print("🌙 Cielo cambiado a: Noche - tonos azules oscuros")

# ========== SISTEMA DE PANTALLA DE RESULTADOS ==========
func mostrar_pantalla_resultados(estadisticas: Dictionary):
	"""Muestra una pantalla de resultados con los resultados del nivel"""
	
	# Crear un ColorRect de fondo semi-transparente
	var overlay = ColorRect.new()
	overlay.name = "ResultadosOverlay"
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Crear panel principal CENTRADO
	var panel = Panel.new()
	panel.name = "PanelResultados"
	panel.size = Vector2(600, 500)
	
	# CORRECCIÓN: Centrar el panel correctamente
	var viewport_size = get_viewport().get_visible_rect().size
	panel.position = Vector2(
		(viewport_size.x - panel.size.x) / 2,
		(viewport_size.y - panel.size.y) / 2
	)
	
	# Centrar el panel usando solo posición manual
	panel.position = Vector2(
		(viewport_size.x - panel.size.x) / 2,
		(viewport_size.y - panel.size.y) / 2
	)
	
	# Estilo del panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color.WHITE
	style_box.border_width_left = 4
	style_box.border_width_top = 4
	style_box.border_width_right = 4
	style_box.border_width_bottom = 4
	style_box.border_color = Color.BLACK
	style_box.corner_radius_top_left = 10
	style_box.corner_radius_top_right = 10
	style_box.corner_radius_bottom_left = 10
	style_box.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style_box)
	
	# Contenedor vertical
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	vbox.custom_minimum_size = Vector2(580, 480)
	
	# Título
	var titulo = Label.new()
	if estadisticas.nivel_aprobado:
		titulo.text = "🎉 ¡NIVEL COMPLETADO! 🎉"
		titulo.modulate = Color.GREEN
	else:
		titulo.text = "❌ NIVEL NO COMPLETADO"
		titulo.modulate = Color.RED
	
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 32)
	
	# Información del nivel
	var info_nivel = Label.new()
	info_nivel.text = estadisticas.nombre_nivel + "\n" + estadisticas.descripcion_nivel
	info_nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_nivel.add_theme_font_size_override("font_size", 18)
	info_nivel.modulate = Color.BLACK
	info_nivel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Estadísticas
	var stats = Label.new()
	stats.text = "RESULTADOS:\n\n" + \
		"💰 Dinero: $%d / $%d objetivo\n" % [estadisticas.dinero_final, estadisticas.dinero_objetivo] + \
		"📊 Eficiencia: %.1f%% / %.1f%% requerida\n" % [estadisticas.eficiencia, estadisticas.eficiencia_requerida] + \
		"✅ Pedidos completados: %d\n" % estadisticas.pedidos_completados + \
		"❌ Pedidos perdidos: %d\n" % estadisticas.pedidos_perdidos + \
		"💵 Dinero ganado: $%d" % estadisticas.dinero_ganado
	
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 16)
	stats.modulate = Color.BLACK
	
	# Botones
	var botones_container = HBoxContainer.new()
	botones_container.alignment = BoxContainer.ALIGNMENT_CENTER
	botones_container.add_theme_constant_override("separation", 20)
	
	# Botón Reintentar
	var btn_reintentar = Button.new()
	btn_reintentar.text = "REINTENTAR NIVEL"
	btn_reintentar.add_theme_font_size_override("font_size", 16)
	btn_reintentar.custom_minimum_size = Vector2(150, 50)
	btn_reintentar.pressed.connect(_on_reintentar_nivel)
	
	# Botón Siguiente Nivel (solo si aprobó)
	var btn_siguiente = Button.new()
	if estadisticas.nivel_aprobado and nivel_actual < configuracion_niveles.size():
		btn_siguiente.text = "SIGUIENTE NIVEL"
		btn_siguiente.add_theme_font_size_override("font_size", 16)
		btn_siguiente.custom_minimum_size = Vector2(150, 50)
		btn_siguiente.pressed.connect(_on_siguiente_nivel)
	else:
		btn_siguiente.text = "MENÚ PRINCIPAL"
		btn_siguiente.add_theme_font_size_override("font_size", 16)
		btn_siguiente.custom_minimum_size = Vector2(150, 50)
		btn_siguiente.pressed.connect(_on_menu_principal)
	
	# Agregar elementos
	vbox.add_child(titulo)
	vbox.add_child(info_nivel)
	vbox.add_child(stats)
	vbox.add_child(botones_container)
	
	botones_container.add_child(btn_reintentar)
	botones_container.add_child(btn_siguiente)
	
	panel.add_child(vbox)
	overlay.add_child(panel)
	
	# Agregar a la escena
	get_tree().current_scene.add_child(overlay)

func _on_reintentar_nivel():
	"""Reinicia el nivel actual"""
	cerrar_pantalla_resultados()
	reiniciar_dia()

func _on_siguiente_nivel():
	"""Avanza al siguiente nivel"""
	if nivel_actual < configuracion_niveles.size():
		nivel_actual += 1
		print("🔓 Avanzando al nivel ", nivel_actual)
	
	cerrar_pantalla_resultados()
	iniciar_siguiente_nivel()

func _on_menu_principal():
	"""Vuelve al menú principal"""
	cerrar_pantalla_resultados()
	get_tree().paused = false
	# Aquí puedes cambiar a la escena del menú principal
	get_tree().change_scene_to_file("res://Main_menu/main_menu.tscn")

func cerrar_pantalla_resultados():
	"""Cierra la pantalla de resultados"""
	var overlay = get_tree().current_scene.get_node_or_null("ResultadosOverlay")
	if overlay:
		overlay.queue_free()

# ========== FUNCIONES DE NIVELES ==========
func obtener_info_nivel_actual() -> Dictionary:
	"""Devuelve información del nivel actual"""
	return configuracion_niveles.get(nivel_actual, {})

func cambiar_nivel(nuevo_nivel: int):
	"""Cambia a un nivel específico"""
	if configuracion_niveles.has(nuevo_nivel):
		nivel_actual = nuevo_nivel
		print("Nivel cambiado a: ", nivel_actual)
	else:
		print("ERROR: Nivel ", nuevo_nivel, " no existe")

func obtener_niveles_disponibles() -> Array:
	"""Devuelve lista de niveles disponibles"""
	return configuracion_niveles.keys()

# ========== SISTEMA DE RESERVA DE MESAS ==========
func reservar_mesa(mesa: Node3D) -> bool:
	"""Reserva una mesa para un cliente"""
	if mesa and mesa not in mesas_reservadas:
		mesas_reservadas.append(mesa)
		print("Mesa reservada: ", mesa.name)
		return true
	return false

func liberar_reserva_mesa(mesa: Node3D):
	"""Libera la reserva de una mesa"""
	if mesa and mesa in mesas_reservadas:
		mesas_reservadas.erase(mesa)
		print("Reserva de mesa liberada: ", mesa.name)

func esta_mesa_reservada(mesa: Node3D) -> bool:
	"""Verifica si una mesa está reservada"""
	return mesa in mesas_reservadas

func buscar_mesa_libre_global() -> Node3D:
	"""Busca una mesa libre a nivel global considerando reservas"""
	var mesas = get_tree().get_nodes_in_group("tables")
	if mesas.is_empty():
		print("⚠️ No hay mesas en el grupo 'tables'")
		return null
	
	# Buscar la mesa más alejada de otros clientes que no esté reservada
	var mejor_mesa = null
	var mejor_distancia = 0.0
	
	for mesa in mesas:
		if not esta_mesa_reservada(mesa) and not esta_mesa_ocupada_global(mesa):
			var distancia_minima_a_otros = calcular_distancia_minima_a_otros_clientes_global(mesa)
			
			if distancia_minima_a_otros > mejor_distancia:
				mejor_distancia = distancia_minima_a_otros
				mejor_mesa = mesa
	
	return mejor_mesa

func esta_mesa_ocupada_global(mesa: Node3D) -> bool:
	"""Verifica si una mesa está ocupada por cualquier cliente"""
	for cliente in clientes_activos:
		if "mesa_asignada" in cliente and cliente.mesa_asignada == mesa:
			return true
		if cliente.global_position.distance_to(mesa.global_position) < 2.5:
			return true
	return false

func calcular_distancia_minima_a_otros_clientes_global(mesa: Node3D) -> float:
	"""Calcula la distancia mínima desde esta mesa a otros clientes sentados"""
	var distancia_minima = 999.0
	
	for cliente in clientes_activos:
		if "estado_actual" in cliente:
			var estado = cliente.estado_actual
			if estado == 4 or estado == 5:  # ESPERANDO_COMIDA o COMIENDO
				var distancia = mesa.global_position.distance_to(cliente.global_position)
				if distancia < distancia_minima:
					distancia_minima = distancia
	
	return 100.0 if distancia_minima == 999.0 else distancia_minima
