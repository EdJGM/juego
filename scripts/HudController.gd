# HudController.gd - VERSIÓN CORREGIDA CON HUD DINÁMICO
extends Node3D

# Referencias a elementos del HUD
@onready var dinero_label = $CanvasLayer/DineroContainer/DineroLabel
@onready var sol_icon = $CanvasLayer/DiaNocheContainer/Sol
@onready var luna_icon = $CanvasLayer/DiaNocheContainer/Luna
@onready var panel_pedidos = $CanvasLayer/PedidosPanel
@onready var vbox_pedidos = $CanvasLayer/PedidosPanel/VBoxContainer
@onready var inventario_panel = $CanvasLayer/Panel

# Referencias al sistema
var game_manager: Node
var player: Node
var inventario: Inventario

# Variables de estado del HUD
var pedido_actual: Dictionary = {}
var checkboxes_ingredientes: Dictionary = {}
var slots_inventario: Array[TextureRect] = []
var imagenes_ingredientes: Dictionary = {}
var nombre_pedido_label: Label
var cliente_actual: Node = null

# Configuración visual
const MAX_SLOTS_INVENTARIO = 6
const SLOT_SIZE = Vector2(100, 100)
const SLOT_SPACING = 10

func _ready():
	print("HUD Controller inicializando...")
	
	# Esperar a que todo esté listo
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Verificar si estamos en el menú
	var scene_manager = get_node_or_null("/root/SceneManager")
	if scene_manager and scene_manager.es_menu():
		print("HUD en menú - saltando inicialización")
		return
	
	# Obtener referencias
	if not obtener_referencias():
		print("ERROR: No se pudieron obtener las referencias necesarias")
		return
	
	# Configurar HUD dinámico
	configurar_hud_dinamico()
	
	# Conectar señales
	conectar_senales()
	
	# Cargar imágenes de ingredientes
	cargar_imagenes_ingredientes()
	
	# Inicializar UI
	inicializar_ui()
	
	print("HUD Controller inicializado correctamente")

func obtener_referencias() -> bool:
	# Obtener GameManager
	game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		print("ERROR: GameManager no encontrado")
		return false
	
	# Obtener jugador
	player = obtener_jugador()
	if not player:
		print("ERROR: No se pudo obtener referencia al jugador")
		return false
	
	# Obtener inventario del jugador
	inventario = obtener_inventario_jugador()
	if not inventario:
		print("⚠️ No se pudo obtener inventario del jugador")
		return false
	
	print("✓ Referencias obtenidas correctamente")
	return true

func obtener_jugador() -> Node:
	# Buscar por parent
	var parent = get_parent()
	if parent and parent.name == "Player":
		return parent
	
	# Buscar en la escena por grupo
	var jugadores = get_tree().get_nodes_in_group("player")
	if jugadores.size() > 0:
		return jugadores[0]
	
	# Búsqueda recursiva
	return buscar_jugador_recursivo(get_tree().current_scene)

func buscar_jugador_recursivo(nodo: Node) -> Node:
	if nodo.name == "Player" and nodo is CharacterBody3D:
		return nodo
	
	for child in nodo.get_children():
		var resultado = buscar_jugador_recursivo(child)
		if resultado:
			return resultado
	
	return null

func obtener_inventario_jugador() -> Inventario:
	if not player:
		return null
	
	if player.has_method("obtener_inventario"):
		return player.obtener_inventario()
	
	var inventario_nodo = player.get_node_or_null("Inventario")
	if inventario_nodo and inventario_nodo is Inventario:
		return inventario_nodo
	
	return null

func configurar_hud_dinamico():
	"""Configura los elementos dinámicos del HUD"""
	
	# Limpiar elementos existentes del panel de pedidos
	limpiar_panel_pedidos()
	
	# Crear estructura dinámica del panel de pedidos
	crear_estructura_pedidos()
	
	# Configurar panel de inventario
	configurar_panel_inventario()
	
	print("✓ HUD dinámico configurado")

func limpiar_panel_pedidos():
	"""Limpia los elementos estáticos del panel de pedidos"""
	
	# Buscar y eliminar elementos estáticos
	var elementos_a_eliminar = []
	for child in vbox_pedidos.get_children():
		if child.name in ["Pan", "Carne", "Tomate", "Lechuga", "Salsa", "Hamburguesa", "Queso"]:
			elementos_a_eliminar.append(child)
	
	for elemento in elementos_a_eliminar:
		elemento.queue_free()
	
	print("✓ Elementos estáticos del panel de pedidos eliminados")

func crear_estructura_pedidos():
	"""Crea la estructura dinámica para mostrar pedidos"""
	
	# Crear label para el nombre del pedido (si no existe)
	if not vbox_pedidos.has_node("NombrePedido"):
		var label_nombre = Label.new()
		label_nombre.name = "NombrePedido"
		label_nombre.text = "Presiona G cerca de un cliente para tomar su orden"
		label_nombre.add_theme_color_override("font_color", Color.BLACK)
		label_nombre.add_theme_font_size_override("font_size", 32)
		label_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox_pedidos.add_child(label_nombre)
		
		# Mover después del título PEDIDOS
		var titulo = vbox_pedidos.get_node_or_null("PEDIDOS")
		if titulo:
			vbox_pedidos.move_child(label_nombre, titulo.get_index() + 1)
	
	nombre_pedido_label = vbox_pedidos.get_node("NombrePedido")
	
	# Crear contenedor para ingredientes dinámicos
	if not vbox_pedidos.has_node("IngredientesContainer"):
		var ingredientes_container = VBoxContainer.new()
		ingredientes_container.name = "IngredientesContainer"
		vbox_pedidos.add_child(ingredientes_container)

func configurar_panel_inventario():
	"""Configura el panel de inventario con slots dinámicos"""
	
	# Limpiar slots existentes
	for child in inventario_panel.get_children():
		if child.name.begins_with("slot") or child.name.begins_with("panel_slot"):
			child.queue_free()
	
	slots_inventario.clear()
	
	# Crear slots de inventario
	for i in range(MAX_SLOTS_INVENTARIO):
		# Crear panel para el borde
		var panel = Panel.new()
		panel.name = "panel_slot_" + str(i)
		panel.size = SLOT_SIZE + Vector2(4, 4)  # Ligeramente más grande para el borde
		panel.position = Vector2(
			28 + (i * (SLOT_SIZE.x + SLOT_SPACING)) - 2,
			17 - 2
		)
		
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color.WHITE
		style_box.border_width_left = 2
		style_box.border_width_top = 2
		style_box.border_width_right = 2
		style_box.border_width_bottom = 2
		style_box.border_color = Color.BLACK
		panel.add_theme_stylebox_override("panel", style_box)
		
		inventario_panel.add_child(panel)
		
		# Crear slot para la imagen
		var slot = TextureRect.new()
		slot.name = "slot_" + str(i)
		slot.size = SLOT_SIZE
		slot.position = Vector2(
			28 + (i * (SLOT_SIZE.x + SLOT_SPACING)),
			17
		)
		slot.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		inventario_panel.add_child(slot)
		slots_inventario.append(slot)
	
	print("✓ ", MAX_SLOTS_INVENTARIO, " slots de inventario creados")

func cargar_imagenes_ingredientes():
	"""Carga las imágenes PNG de los ingredientes de forma segura"""
	imagenes_ingredientes = {}
	
	# Lista de ingredientes a cargar
	var ingredientes_a_cargar = [
		"food_ingredient_bun",
		"food_ingredient_bun_bottom", 
		"food_ingredient_bun_top",
		"food_ingredient_burger_cooked",
		"food_ingredient_tomato",
		"food_ingredient_tomato_slice",
		"food_ingredient_lettuce",
		"food_ingredient_lettuce_slice", 
		"food_ingredient_cheese",
		"food_ingredient_cheese_slice",
		"food_ingredient_vegetableburger_cooked"
	]
	
	var imagenes_cargadas = 0
	
	for ingrediente in ingredientes_a_cargar:
		var ruta_imagen = "res://Hud/ingredientes/" + ingrediente.replace("food_ingredient_", "") + ".png"
		
		if ResourceLoader.exists(ruta_imagen):
			var textura = load(ruta_imagen)
			if textura:
				imagenes_ingredientes[ingrediente] = textura
				imagenes_cargadas += 1
			else:
				print("⚠️ No se pudo cargar: ", ruta_imagen)
		else:
			# Crear imagen placeholder
			imagenes_ingredientes[ingrediente] = crear_imagen_placeholder(ingrediente)
			print("⚠️ Imagen no existe, creando placeholder para: ", ingrediente)
	
	print("✓ ", imagenes_cargadas, " imágenes de ingredientes cargadas, ", 
		  (ingredientes_a_cargar.size() - imagenes_cargadas), " placeholders creados")

func crear_imagen_placeholder(ingrediente: String) -> ImageTexture:
	"""Crea una imagen placeholder para ingredientes sin imagen"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	
	# Color basado en el tipo de ingrediente
	var color = Color.GRAY
	if "bun" in ingrediente:
		color = Color.SANDY_BROWN
	elif "burger" in ingrediente:
		color = Color.SADDLE_BROWN
	elif "tomato" in ingrediente:
		color = Color.TOMATO
	elif "lettuce" in ingrediente:
		color = Color.GREEN_YELLOW
	elif "cheese" in ingrediente:
		color = Color.GOLD
	
	image.fill(color)
	
	# Agregar borde
	var color_borde = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 1.0)
	for x in range(128):
		for y in range(128):
			if x < 3 or x >= 125 or y < 3 or y >= 125:
				image.set_pixel(x, y, color_borde)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func conectar_senales():
	if not game_manager:
		print("No se puede conectar señales - GameManager faltante")
		return
	
	var senales_conectadas = 0
	
	# Conectar señales del GameManager
	if game_manager.has_signal("dinero_cambiado"):
		game_manager.dinero_cambiado.connect(_on_dinero_cambiado)
		senales_conectadas += 1
	
	if game_manager.has_signal("tiempo_cambiado"):
		game_manager.tiempo_cambiado.connect(_on_tiempo_cambiado)
		senales_conectadas += 1
	
	if game_manager.has_signal("cliente_agregado"):
		game_manager.cliente_agregado.connect(_on_cliente_agregado)
		senales_conectadas += 1
	
	if game_manager.has_signal("pedido_completado"):
		game_manager.pedido_completado.connect(_on_pedido_completado)
		senales_conectadas += 1
	
	if game_manager.has_signal("pedido_fallido"):
		game_manager.pedido_fallido.connect(_on_pedido_fallido)
		senales_conectadas += 1
	
	# Conectar señales del inventario
	if inventario:
		if inventario.has_signal("item_agregado"):
			inventario.item_agregado.connect(_on_item_agregado)
			senales_conectadas += 1
		
		if inventario.has_signal("item_removido"):
			inventario.item_removido.connect(_on_item_removido)
			senales_conectadas += 1
	
	print("✓ ", senales_conectadas, " señales conectadas")

func inicializar_ui():
	actualizar_dinero(100)
	actualizar_indicador_tiempo("manana")
	mostrar_instrucciones_iniciales()

func mostrar_instrucciones_iniciales():
	"""Muestra las instrucciones iniciales en el panel de pedidos"""
	if nombre_pedido_label:
		nombre_pedido_label.text = "Presiona G cerca de un cliente\npara tomar su orden"
	
	panel_pedidos.visible = true

# === FUNCIONES DE INTERACCIÓN CON CLIENTE ===

func _input(event):
	if not Engine.is_editor_hint() and event is InputEventKey and event.pressed:
		# Tecla G para tomar orden del cliente
		if Input.is_action_just_pressed("tomar_orden"):  # Tecla G
			tomar_orden_cliente()
		# Tab para debugging
		elif Input.is_action_just_pressed("ui_text_completion_accept"):  # Tab
			debug_hud_estado()

func tomar_orden_cliente():
	"""Función para tomar la orden del cliente más cercano"""
	if not player:
		print("No hay jugador para tomar orden")
		return
	
	var cliente_cercano = buscar_cliente_mas_cercano()
	if cliente_cercano:
		var pedido = obtener_pedido_cliente(cliente_cercano)
		if not pedido.is_empty():
			cliente_actual = cliente_cercano
			if cliente_cercano.has_method("marcar_pedido_realizado"):
				cliente_cercano.marcar_pedido_realizado()
			mostrar_pedido_dinamico(pedido)
			print("✓ Orden tomada del cliente: ", pedido.get("nombre_receta", "Desconocido"))
		else:
			print("⚠️ El cliente no tiene pedido válido")
	else:
		print("⚠️ No hay clientes cerca para tomar orden")

func buscar_cliente_mas_cercano() -> Node:
	"""Busca el cliente más cercano al jugador"""
	if not player:
		return null
	
	var clientes = get_tree().get_nodes_in_group("clientes")
	var cliente_mas_cercano = null
	var distancia_minima = 3.0  # Distancia máxima para tomar orden
	
	print("Buscando clientes cerca... Clientes encontrados: ", clientes.size())
	
	for cliente in clientes:
		if not cliente.has_method("esta_esperando"):
			continue
			
		if cliente.esta_esperando():
			var distancia = player.global_position.distance_to(cliente.global_position)
			print("Cliente a distancia: ", distancia)
			
			if distancia < distancia_minima:
				distancia_minima = distancia
				cliente_mas_cercano = cliente
	
	return cliente_mas_cercano

func obtener_pedido_cliente(cliente: Node) -> Dictionary:
	"""Obtiene el pedido del cliente"""
	if cliente.has_method("obtener_pedido"):
		return cliente.obtener_pedido()
	return {}

# === CALLBACKS DE SEÑALES ===

func _on_dinero_cambiado(nuevo_dinero: int):
	actualizar_dinero(nuevo_dinero)

func _on_tiempo_cambiado(tiempo_actual: float, fase_dia: String):
	actualizar_indicador_tiempo(fase_dia)

func _on_cliente_agregado(cliente: Node):
	print("HUD: Nuevo cliente agregado - ", cliente.name)
	# Mostrar notificación de nuevo cliente
	mostrar_notificacion_cliente()

func _on_pedido_completado(pedido: Dictionary, dinero_ganado: int):
	print("HUD: Pedido completado - Ganancia: $", dinero_ganado)
	mostrar_feedback_pedido(true, dinero_ganado)
	limpiar_pedido_actual()
	
	# CORRECCIÓN 2: Forzar actualización del inventario visual después de entregar
	call_deferred("actualizar_inventario_visual")

func _on_pedido_fallido(pedido: Dictionary, dinero_perdido: int):
	print("HUD: Pedido fallido - Pérdida: $", dinero_perdido)
	mostrar_feedback_pedido(false, dinero_perdido)
	limpiar_pedido_actual()
	
	# CORRECCIÓN 2: También forzar actualización si el pedido falla
	call_deferred("actualizar_inventario_visual")

func _on_item_agregado(item):
	print("HUD: Item agregado al inventario - ", obtener_nombre_ingrediente_seguro(item))
	actualizar_inventario_visual()
	await get_tree().process_frame
	verificar_ingredientes_pedido()

func _on_item_removido(item):
	print("HUD: Item removido del inventario - ", obtener_nombre_ingrediente_seguro(item))
	actualizar_inventario_visual()
	await get_tree().process_frame
	verificar_ingredientes_pedido()

# FUNCIÓN CORREGIDA PARA OBTENER NOMBRE DE INGREDIENTE
func obtener_nombre_ingrediente_seguro(item) -> String:
	"""Obtiene el nombre del ingrediente de forma segura"""
	if not item:
		return "item_null"
	
	# Verificar si tiene la propiedad nombre_ingrediente
	if "nombre_ingrediente" in item:
		return item.nombre_ingrediente
	
	# Si es un nodo, verificar si tiene el método get
	if item.has_method("get") and item.get("nombre_ingrediente") != null:
		return item.get("nombre_ingrediente")
	
	# Fallback usando el nombre del nodo
	if "name" in item:
		return str(item.name)
	
	return "ingrediente_desconocido"

# === FUNCIONES DE ACTUALIZACIÓN DE UI ===

func actualizar_dinero(cantidad: int):
	if dinero_label:
		dinero_label.text = "$" + str(cantidad)

func actualizar_indicador_tiempo(fase: String):
	if not sol_icon or not luna_icon:
		return
	
	match fase:
		"manana":
			sol_icon.modulate = Color.YELLOW
			luna_icon.modulate = Color.GRAY
		"mediodia":
			sol_icon.modulate = Color.WHITE
			luna_icon.modulate = Color.GRAY
		"tarde":
			sol_icon.modulate = Color.ORANGE
			luna_icon.modulate = Color.GRAY
		"noche":
			sol_icon.modulate = Color.GRAY
			luna_icon.modulate = Color.WHITE

func mostrar_notificacion_cliente():
	"""Muestra notificación cuando llega un nuevo cliente"""
	if nombre_pedido_label and (pedido_actual.is_empty() or cliente_actual == null):
		nombre_pedido_label.text = "¡Nuevo cliente!\nPresiona G para tomar su orden"
		
		# Crear efecto de parpadeo
		var tween = create_tween()
		tween.tween_property(nombre_pedido_label, "modulate", Color.YELLOW, 0.5)
		tween.tween_property(nombre_pedido_label, "modulate", Color.WHITE, 0.5)
		tween.tween_property(nombre_pedido_label, "modulate", Color.YELLOW, 0.5)
		tween.tween_property(nombre_pedido_label, "modulate", Color.WHITE, 0.5)

func mostrar_pedido_dinamico(pedido: Dictionary):
	"""Muestra dinámicamente el pedido actual"""
	if not pedido.has("datos_receta"):
		print("⚠️ Pedido no tiene datos de receta")
		return
	
	pedido_actual = pedido
	var receta = pedido.datos_receta
	var ingredientes_necesarios = receta.get("ingredientes", [])
	
	print("HUD: Mostrando pedido dinámico - ", receta.get("nombre", "Sin nombre"))
	print("Ingredientes requeridos: ", ingredientes_necesarios)
	
	# Actualizar nombre del pedido
	if nombre_pedido_label:
		nombre_pedido_label.text = "PEDIDO: " + receta.get("nombre", "Pedido Desconocido")
		nombre_pedido_label.modulate = Color.WHITE
	
	# Limpiar ingredientes previos
	limpiar_ingredientes_container()
	
	# Crear checkboxes dinámicos para cada ingrediente
	var ingredientes_container = vbox_pedidos.get_node("IngredientesContainer")
	checkboxes_ingredientes.clear()
	
	for ingrediente in ingredientes_necesarios:
		var tipo = detectar_tipo_ingrediente(ingrediente)
		var checkbox = crear_checkbox_ingrediente(tipo, ingrediente)
		ingredientes_container.add_child(checkbox)
		checkboxes_ingredientes[tipo] = checkbox
		print("✓ Checkbox creado para: ", tipo)
	
	# Mostrar el panel de pedidos
	panel_pedidos.visible = true
	
	# Verificar ingredientes actuales
	call_deferred("verificar_ingredientes_pedido")

func limpiar_ingredientes_container():
	"""Limpia el contenedor de ingredientes"""
	var ingredientes_container = vbox_pedidos.get_node("IngredientesContainer")
	if not ingredientes_container:
		return
	
	for child in ingredientes_container.get_children():
		child.queue_free()

func crear_checkbox_ingrediente(tipo: String, nombre_ingrediente: String) -> CheckBox:
	"""Crea un checkbox para un ingrediente específico"""
	var checkbox = CheckBox.new()
	checkbox.name = tipo
	
	# Usar nombres más descriptivos para mostrar al usuario
	var texto_mostrar = obtener_nombre_display(tipo, nombre_ingrediente)
	checkbox.text = texto_mostrar
	
	checkbox.disabled = true
	checkbox.button_pressed = false
	
	# Configurar estilo
	checkbox.add_theme_color_override("font_color", Color.BLACK)
	checkbox.add_theme_color_override("font_disabled_color", Color.BLACK)
	checkbox.add_theme_font_size_override("font_size", 30)
	
	return checkbox

func obtener_nombre_display(tipo: String, nombre_ingrediente: String) -> String:
	"""Convierte el tipo interno a un nombre legible para el usuario"""
	match tipo:
		"pan_inferior":
			return "Pan de Abajo"
		"pan_superior":
			return "Pan de Arriba"
		"pan_generico":
			return "Pan"
		"carne":
			return "Hamburguesa"
		"carne_vegetal":
			return "Hamburguesa Vegetal"
		"tomate_cortado":
			return "Tomate Cortado"
		"tomate_entero":
			return "Tomate Entero"
		"lechuga_cortada":
			return "Lechuga Cortada"
		"lechuga_entera":
			return "Lechuga Entera"
		"queso_cortado":
			return "Queso Cortado"
		"queso_entero":
			return "Queso Entero"
		"salsa":
			return "Salsa"
		_:
			return tipo.capitalize()

func limpiar_pedido_actual():
	"""Limpia el pedido actual y vuelve a mostrar instrucciones"""
	pedido_actual = {}
	cliente_actual = null
	checkboxes_ingredientes.clear()
	
	limpiar_ingredientes_container()
	mostrar_instrucciones_iniciales()

func verificar_ingredientes_pedido():
	"""Verifica dinámicamente los ingredientes del pedido"""
	if pedido_actual.is_empty() or not inventario:
		return
	
	var ingredientes_inventario = obtener_ingredientes_inventario()
	print("HUD: Verificando ingredientes dinámicamente")
	print("Inventario: ", ingredientes_inventario)
	
	if not pedido_actual.has("datos_receta"):
		return
	
	var ingredientes_necesarios = pedido_actual.datos_receta.get("ingredientes", [])
	
	# Verificar cada tipo de ingrediente requerido
	for ingrediente_necesario in ingredientes_necesarios:
		var tipo_necesario = detectar_tipo_ingrediente(ingrediente_necesario)
		
		if checkboxes_ingredientes.has(tipo_necesario):
			var checkbox = checkboxes_ingredientes[tipo_necesario]
			if checkbox:
				var tiene_ingrediente = false
				
				# Buscar si tenemos este tipo de ingrediente
				for ingrediente_inv in ingredientes_inventario:
					if detectar_tipo_ingrediente(ingrediente_inv) == tipo_necesario:
						tiene_ingrediente = true
						break
				
				checkbox.button_pressed = tiene_ingrediente
				
				if tiene_ingrediente:
					checkbox.modulate = Color.GREEN
					print("✓ Ingrediente disponible: ", tipo_necesario)
				else:
					checkbox.modulate = Color.WHITE
					print("✗ Ingrediente faltante: ", tipo_necesario)

func actualizar_inventario_visual():
	"""Actualiza visualmente el inventario en el HUD"""
	if not inventario:
		print("No hay inventario para actualizar visualmente")
		return
	
	var items = inventario.obtener_items()
	print("Actualizando inventario visual - Items encontrados: ", items.size())
	
	# Limpiar todos los slots primero
	for i in range(slots_inventario.size()):
		var slot = slots_inventario[i]
		if slot:
			slot.texture = null
			print("Slot ", i, " limpiado")
	
	# Mostrar items en los slots (solo los que existen)
	for i in range(min(items.size(), slots_inventario.size())):
		var item = items[i]
		var slot = slots_inventario[i]
		
		if item:
			var nombre_ingrediente = obtener_nombre_ingrediente_seguro(item)
			
			# Buscar imagen del ingrediente
			if imagenes_ingredientes.has(nombre_ingrediente):
				slot.texture = imagenes_ingredientes[nombre_ingrediente]
				print("✓ Imagen asignada al slot ", i, ": ", nombre_ingrediente)
			else:
				# Imagen por defecto o placeholder
				slot.texture = crear_imagen_placeholder(nombre_ingrediente)
				print("⚠️ Usando placeholder para: ", nombre_ingrediente)
		elif slot:
			# Asegurar que el slot esté vacío si no hay item
			slot.texture = null
			print("Slot ", i, " establecido como vacío")
	
	print("Inventario visual actualizado: ", items.size(), " items mostrados", 
		  (slots_inventario.size() - items.size()), " slots vacíos")

func obtener_ingredientes_inventario() -> Array:
	if not inventario:
		return []
	
	var nombres = []
	
	if inventario.has_method("obtener_nombres_ingredientes"):
		nombres = inventario.obtener_nombres_ingredientes()
	elif inventario.has_method("obtener_items"):
		var items = inventario.obtener_items()
		for item in items:
			if item:
				nombres.append(obtener_nombre_ingrediente_seguro(item))
	
	return nombres

func detectar_tipo_ingrediente(ingrediente_nombre: String) -> String:
	if ingrediente_nombre == "":
		return "generico"
	
	var nombre = ingrediente_nombre.to_lower()
	
	# Detectar tipos específicos de pan
	if "bun_bottom" in nombre:
		return "pan_inferior"
	elif "bun_top" in nombre:
		return "pan_superior"
	elif "bun" in nombre and not ("bottom" in nombre or "top" in nombre):
		return "pan_generico"
	# Detectar tipos específicos de carne
	elif "vegetableburger" in nombre:
		return "carne_vegetal"
	elif "burger" in nombre or "meat" in nombre or "carne" in nombre:
		return "carne"
	# Detectar ingredientes cortados vs enteros
	elif "tomato_slice" in nombre:
		return "tomate_cortado"
	elif "tomato" in nombre:
		return "tomate_entero"
	elif "lettuce_slice" in nombre:
		return "lechuga_cortada"
	elif "lettuce" in nombre:
		return "lechuga_entera"
	elif "cheese_slice" in nombre:
		return "queso_cortado"
	elif "cheese" in nombre:
		return "queso_entero"
	elif "sauce" in nombre or "salsa" in nombre or "ketchup" in nombre or "mustard" in nombre:
		return "salsa"
	else:
		return "generico"

func mostrar_feedback_pedido(exitoso: bool, cantidad: int):
	var feedback = Label.new()
	feedback.position = Vector2(get_viewport().size.x / 2 - 100, get_viewport().size.y / 2)
	feedback.size = Vector2(200, 100)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback.add_theme_font_size_override("font_size", 48)
	
	if exitoso:
		feedback.text = "¡PERFECTO!\n+$" + str(cantidad)
		feedback.modulate = Color.GREEN
	else:
		feedback.text = "PEDIDO PERDIDO\n-$" + str(cantidad)
		feedback.modulate = Color.RED
	
	get_tree().current_scene.add_child(feedback)
	
	var tween = create_tween()
	tween.parallel().tween_property(feedback, "position:y", feedback.position.y - 100, 2.0)
	tween.parallel().tween_property(feedback, "scale", Vector2(1.5, 1.5), 0.5)
	tween.parallel().tween_property(feedback, "scale", Vector2(1.0, 1.0), 0.5)
	tween.parallel().tween_property(feedback, "modulate:a", 0.0, 2.0)
	tween.tween_callback(feedback.queue_free)

# === FUNCIÓN DE DEBUGGING ===

func debug_hud_estado():
	print("\n=== DEBUG HUD DINÁMICO ===")
	print("GameManager: ", game_manager != null)
	print("Player: ", player != null)
	print("Inventario: ", inventario != null)
	print("Cliente actual: ", cliente_actual != null)
	print("Pedido actual: ", not pedido_actual.is_empty())
	print("Panel pedidos visible: ", panel_pedidos.visible if panel_pedidos else "N/A")
	print("Checkboxes activos: ", checkboxes_ingredientes.size())
	
	if inventario:
		var items = obtener_ingredientes_inventario()
		print("Items inventario: ", items)
	
	if not pedido_actual.is_empty():
		print("Pedido actual: ", pedido_actual.get("nombre_receta", "Sin nombre"))
	
	var clientes = get_tree().get_nodes_in_group("clientes")
	print("Clientes en escena: ", clientes.size())
	
	print("Slots inventario: ", slots_inventario.size())
	print("===============================\n")
