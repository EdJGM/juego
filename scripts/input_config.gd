# input_config.gd - Configurar en AutoLoad
extends Node

func _ready():
	configurar_input_map()

func configurar_input_map():
	# Acción para interactuar con objetos
	if not InputMap.has_action("interactuar"):
		InputMap.add_action("interactuar")
		var event = InputEventKey.new()
		event.keycode = KEY_F
		InputMap.action_add_event("interactuar", event)
	
	# Acción para tomar orden del cliente
	if not InputMap.has_action("tomar_orden"):
		InputMap.add_action("tomar_orden")
		var event = InputEventKey.new()
		event.keycode = KEY_G
		InputMap.action_add_event("tomar_orden", event)
	
	# Acción para entregar pedidos
	if not InputMap.has_action("entregar_pedido"):
		InputMap.add_action("entregar_pedido")
		var event = InputEventKey.new()
		event.keycode = KEY_E
		InputMap.action_add_event("entregar_pedido", event)
	
	# Acción para limpiar inventario
	if not InputMap.has_action("limpiar_inventario"):
		InputMap.add_action("limpiar_inventario")
		var event = InputEventKey.new()
		event.keycode = KEY_C
		InputMap.action_add_event("limpiar_inventario", event)
	
	# Acción para pausar (ya existe como "esc")
	if not InputMap.has_action("esc"):
		InputMap.add_action("esc")
		var event = InputEventKey.new()
		event.keycode = KEY_ESCAPE
		InputMap.action_add_event("esc", event)
	
	print("Input Map configurado correctamente")

# Función para obtener las teclas configuradas
func obtener_teclas() -> Dictionary:
	return {
		"tomar_orden": "G - Tomar orden del cliente",
		"interactuar": "F - Agarrar ingredientes",
		"entregar_pedido": "E - Entregar pedido al cliente",
		"limpiar_inventario": "C - Limpiar inventario",
		"escape": "ESC - Menú de pausa",
		"movimiento": "WASD - Moverse",
		"camara": "Mouse - Mover cámara",
		"saltar": "Espacio - Saltar"
	}
