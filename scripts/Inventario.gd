# Inventario.gd - CORRECCIÓN 2: LIMPIAR INVENTARIO AL ENTREGAR
extends Node
class_name Inventario

# Señales
signal item_agregado(item)
signal item_removido(item)
signal inventario_lleno
signal receta_completada(receta)
signal pedido_creado(pedido)

# Variables
@export var capacidad_maxima: int = 6
var items: Array[ObjetoAgarrable] = []
var entregando_pedido: bool = false

# Referencias
var jugador: CharacterBody3D
var game_manager: Node

func _ready():
	print("Inventario inicializando...")
	
	# Obtener referencia al jugador
	jugador = get_parent()
	if jugador and jugador is CharacterBody3D:
		print("✓ Inventario conectado al jugador: ", jugador.name)
		
		# Asegurar que el jugador esté en el grupo correcto
		if not jugador.is_in_group("player"):
			jugador.add_to_group("player")
	else:
		print("⚠️ Inventario no tiene parent jugador válido")
	
	# Obtener GameManager
	game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		print("✓ Inventario conectado al GameManager")
	else:
		print("⚠️ GameManager no encontrado")
	
	print("Inventario inicializado - Capacidad: ", capacidad_maxima)

func puede_agregar_item() -> bool:
	return items.size() < capacidad_maxima

func agregar_item(item: ObjetoAgarrable) -> bool:
	if not puede_agregar_item():
		print("Inventario lleno - no se puede agregar item")
		inventario_lleno.emit()
		return false
	
	if not item:
		print("ERROR: Intentando agregar item null")
		return false
	
	items.append(item)
	item_agregado.emit(item)
	
	# CORRECCIÓN: Usar función segura para obtener nombre
	var nombre = obtener_nombre_ingrediente_seguro(item)
	print("Item agregado al inventario: ", nombre, " (", items.size(), "/", capacidad_maxima, ")")
	
	# Verificar si se puede crear un pedido
	verificar_pedido_completo()
	
	return true

# FUNCIÓN CORREGIDA PARA OBTENER NOMBRE DE INGREDIENTE DE FORMA SEGURA
func obtener_nombre_ingrediente_seguro(item) -> String:
	"""Obtiene el nombre del ingrediente de forma segura"""
	if not item:
		return "item_null"
	
	# Verificar si tiene la propiedad nombre_ingrediente directamente
	if "nombre_ingrediente" in item:
		return item.nombre_ingrediente
	
	# Si es un nodo, verificar si tiene métodos para acceder a propiedades
	if item.has_method("get"):
		var nombre = item.get("nombre_ingrediente")
		if nombre != null:
			return str(nombre)
	
	# Fallback usando el nombre del nodo
	if "name" in item:
		return str(item.name)
	
	return "ingrediente_desconocido"

func remover_item(item: ObjetoAgarrable) -> bool:
	if not item:
		print("ERROR: Intentando remover item null")
		return false
	
	var index = items.find(item)
	if index != -1:
		items.remove_at(index)
		item_removido.emit(item)
		var nombre = obtener_nombre_ingrediente_seguro(item)
		print("Item removido del inventario: ", nombre)
		return true
	
	print("Item no encontrado en inventario para remover")
	return false

func remover_item_por_indice(indice: int) -> ObjetoAgarrable:
	if indice >= 0 and indice < items.size():
		var item = items[indice]
		items.remove_at(indice)
		item_removido.emit(item)
		var nombre = obtener_nombre_ingrediente_seguro(item)
		print("Item removido por índice: ", nombre)
		return item
	
	print("Índice inválido para remover item: ", indice)
	return null

func obtener_items() -> Array[ObjetoAgarrable]:
	return items.duplicate()

func obtener_nombres_ingredientes() -> Array:
	var nombres = []
	for item in items:
		if item:
			nombres.append(obtener_nombre_ingrediente_seguro(item))
		else:
			print("⚠️ Item inválido en inventario")
	return nombres

func tiene_ingrediente(nombre: String) -> bool:
	for item in items:
		if item and obtener_nombre_ingrediente_seguro(item) == nombre:
			return true
	return false

func tiene_ingrediente_tipo(tipo: String) -> bool:
	"""Verifica si tiene un ingrediente del tipo especificado"""
	for item in items:
		if item and detectar_tipo_ingrediente(obtener_nombre_ingrediente_seguro(item)) == tipo:
			return true
	return false

func contar_ingrediente(nombre: String) -> int:
	var count = 0
	for item in items:
		if item and obtener_nombre_ingrediente_seguro(item) == nombre:
			count += 1
	return count

func contar_ingrediente_tipo(tipo: String) -> int:
	"""Cuenta cuántos ingredientes de un tipo específico hay"""
	var count = 0
	for item in items:
		if item and detectar_tipo_ingrediente(obtener_nombre_ingrediente_seguro(item)) == tipo:
			count += 1
	return count

func limpiar_inventario():
	"""Limpiar inventario ELIMINANDO los items cuando se confirma entrega"""
	print("✅ ENTREGA: Limpiando inventario...")
	
	# Marcar que estamos entregando pedido
	entregando_pedido = true
	
	for item in items:
		if is_instance_valid(item):
			item_removido.emit(item)
			
			# ELIMINAR CLONES: Los objetos en inventario son clones, se eliminan
			item.queue_free()
	
	items.clear()
	
	# Resetear estado usando call_deferred para evitar async
	call_deferred("resetear_estado_entrega")
	
	print("✅ ENTREGA: Inventario limpiado")

func resetear_estado_entrega():
	"""Resetea el estado de entrega"""
	entregando_pedido = false

func verificar_pedido_completo():
	"""Verifica si los ingredientes actuales forman un pedido completo"""
	if not game_manager:
		return
	
	var pedidos_activos = []
	if game_manager.has_method("obtener_pedidos_activos"):
		pedidos_activos = game_manager.obtener_pedidos_activos()
	
	for pedido in pedidos_activos:
		if verificar_ingredientes_para_pedido(pedido):
			var nombre_receta = "Sin nombre"
			if pedido.has("datos_receta"):
				nombre_receta = pedido.datos_receta.get("nombre", "Sin nombre")
			print("¡Pedido completo detectado!: ", nombre_receta)
			pedido_creado.emit(pedido)
			return

func verificar_ingredientes_para_pedido(pedido: Dictionary) -> bool:
	"""Verifica si tenemos todos los ingredientes para un pedido específico"""
	if not pedido.has("datos_receta"):
		return false
	
	var ingredientes_necesarios = pedido.datos_receta.get("ingredientes", [])
	var ingredientes_inventario = obtener_nombres_ingredientes()
	
	var nombre_receta = pedido.datos_receta.get("nombre", "Sin nombre")
	print("Verificando pedido: ", nombre_receta)
	print("Necesarios: ", ingredientes_necesarios)
	print("Disponibles: ", ingredientes_inventario)
	
	# Verificar que tenemos todos los tipos de ingredientes necesarios
	for ingrediente_necesario in ingredientes_necesarios:
		var tipo_necesario = detectar_tipo_ingrediente(ingrediente_necesario)
		
		if not tiene_ingrediente_tipo(tipo_necesario):
			print("Falta ingrediente tipo: ", tipo_necesario)
			return false
	
	return true

func detectar_tipo_ingrediente(nombre_ingrediente: String) -> String:
	"""Función sincronizada con GameManager y HudController - Compatible con JSON externo"""
	if nombre_ingrediente == "":
		return "generico"
	
	var nombre = nombre_ingrediente.to_lower()
	
	# IMPORTANTE: EXACTAMENTE la misma lógica que GameManager
	if "bun_bottom" in nombre:
		return "pan_inferior"
	elif "bun_top" in nombre:
		return "pan_superior"
	elif "bun" in nombre and not ("bottom" in nombre or "top" in nombre):
		return "pan_generico"
	elif "vegetableburger" in nombre:
		return "carne_vegetal"  # Distinguir hamburguesa vegetal
	elif "burger" in nombre or "meat" in nombre or "carne" in nombre:
		return "carne"
	# Detectar vegetales
	elif "tomato" in nombre:
		return "tomate"  # Tanto "tomato" como "tomato_slice"
	elif "lettuce" in nombre:
		return "lechuga"  # Tanto "lettuce" como "lettuce_slice"
	elif "onion_chopped" in nombre:
		return "cebolla_picada"
	elif "onion" in nombre:
		return "cebolla"
	elif "pickle" in nombre:
		return "pepinillo"
	elif "avocado" in nombre:
		return "aguacate"
	elif "cucumber" in nombre:
		return "pepino"
	elif "carrot" in nombre:
		return "zanahoria"
	# Otros ingredientes
	elif "cheese" in nombre:
		return "queso"  # Tanto "cheese" como "cheese_slice"
	elif "bacon" in nombre:
		return "tocino"
	elif "egg" in nombre:
		return "huevo"
	elif "mushroom" in nombre:
		return "champiñon"
	elif "ham_cooked" in nombre:
		return "pollo"
	elif "steak_pieces" in nombre:
		return "carne_frita"
	# Salsas y condimentos
	elif "sauce" in nombre or "salsa" in nombre:
		return "salsa"
	elif "ketchup" in nombre:
		return "ketchup"
	elif "mustard" in nombre:
		return "mostaza"
	elif "mayo" in nombre or "mayonnaise" in nombre:
		return "mayonesa"
	# Extras
	elif "french_fries" in nombre or "fries" in nombre or "papas" in nombre:
		return "papas_fritas"
	elif "drink" in nombre or "soda" in nombre or "bebida" in nombre:
		return "bebida"
	else:
		# En lugar de "generico", retornar el nombre original para debugging
		print("⚠️ INVENTARIO - INGREDIENTE NO RECONOCIDO: ", nombre_ingrediente)
		return nombre_ingrediente

func crear_pedido_desde_inventario() -> Dictionary:
	"""Crea un pedido con los ingredientes actuales del inventario"""
	var nombres_ingredientes = obtener_nombres_ingredientes()
	
	return {
		"ingredientes": nombres_ingredientes,
		"tiempo_creacion": Time.get_unix_time_from_system(),
		"jugador_id": jugador.get_instance_id() if jugador else 0
	}

func entregar_pedido_a_cliente(cliente: Node) -> bool:
	"""Entrega el pedido y limpia el inventario"""
	print("🍽️ ENTREGA: Intentando entregar a ", cliente.name if cliente else "null")
	print("   Estado cliente: ", cliente.obtener_estado_actual_string() if cliente.has_method("obtener_estado_actual_string") else "desconocido")
	print("   Items inventario: ", items.size())
	
	if items.is_empty():
		print("❌ ENTREGA: Sin ingredientes")
		return false
	
	if not cliente or not cliente.has_method("recibir_pedido_jugador"):
		print("❌ ENTREGA: Cliente inválido")
		return false
	
	var pedido_jugador = crear_pedido_desde_inventario()
	
	# CORRECCIÓN: NO limpiar automáticamente
	# El inventario se limpiará solo cuando el GameManager confirme que el pedido fue aceptado
	var entrega_exitosa = cliente.recibir_pedido_jugador(pedido_jugador)
	
	if entrega_exitosa:
		print("✅ ENTREGA: Pedido enviado al cliente - Esperando validación GameManager")
		return true
	else:
		print("❌ ENTREGA: Cliente rechazó pedido")
		return false

func limpiar_inventario_diferido():
	"""Función para limpiar inventario de forma diferida"""
	limpiar_inventario()
	print("✅ ENTREGA: Inventario limpiado")

func _input(event):
	if not jugador:
		return
	
	# Solo procesar input si este inventario pertenece al jugador activo
	var current_player = get_tree().get_nodes_in_group("player")
	if current_player.is_empty() or current_player[0] != jugador:
		return
	
	if event.is_action_pressed("entregar_pedido"):  # Tecla E
		entregar_a_cliente_cercano()
	elif event.is_action_pressed("limpiar_inventario"):  # Tecla C
		limpiar_inventario()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_Q:  # Tecla Q
		eliminar_ultimo_ingrediente()

func entregar_a_cliente_cercano():
	"""Busca el cliente más cercano y le entrega el pedido"""
	if not jugador:
		return
	
	var clientes = get_tree().get_nodes_in_group("clientes")
	var cliente_mas_cercano = null
	var distancia_minima = 5.0
	
	for cliente in clientes:
		if not is_instance_valid(cliente):
			continue
			
		var distancia = jugador.global_position.distance_to(cliente.global_position)
		var puede_recibir = esta_esperando_comida(cliente)
		
		if cliente.has_method("recibir_pedido_jugador") and puede_recibir:
			if distancia < distancia_minima:
				distancia_minima = distancia
				cliente_mas_cercano = cliente
				
	if cliente_mas_cercano:
		entregar_pedido_a_cliente(cliente_mas_cercano)
	else:
		print("❌ ENTREGA: No hay clientes cerca esperando")

func obtener_estado_cliente(cliente: Node) -> String:
	"""Obtiene el estado actual del cliente para debugging"""
	if cliente.has_method("obtener_estado_actual_string"):
		return cliente.obtener_estado_actual_string()
	
	if "estado_actual" in cliente:
		var estado_enum = cliente.estado_actual
		return "Estado_" + str(estado_enum)
	
	return "Desconocido"

func esta_esperando_comida(cliente: Node) -> bool:
	"""Verifica si el cliente está esperando comida EN LA MESA"""
	if not cliente.has_method("recibir_pedido_jugador"):
		return false
	
	# Usar la nueva función específica del cliente
	if cliente.has_method("esta_esperando_comida_en_mesa"):
		return cliente.esta_esperando_comida_en_mesa()
	
	# Verificar el estado usando la función de string
	if cliente.has_method("obtener_estado_actual_string"):
		var estado_string = cliente.obtener_estado_actual_string()
		return estado_string == "ESPERANDO_COMIDA"
	
	# Fallback original
	if "estado_actual" in cliente:
		var estado = cliente.estado_actual
		return estado == 4  # EstadoCliente.ESPERANDO_COMIDA
	
	# Último fallback para clientes sin FSM
	if cliente.has_method("esta_esperando"):
		return cliente.esta_esperando()
	
	return false

# Funciones para la UI y estadísticas
func obtener_info_items() -> Array:
	var info = []
	for item in items:
		if item and item.has_method("obtener_info"):
			info.append(item.obtener_info())
		else:
			var nombre = obtener_nombre_ingrediente_seguro(item)
			info.append({
				"nombre": nombre,
				"tipo": detectar_tipo_ingrediente(nombre),
				"valido": item != null
			})
	return info

func obtener_capacidad() -> Dictionary:
	return {
		"actual": items.size(),
		"maxima": capacidad_maxima,
		"porcentaje": float(items.size()) / float(capacidad_maxima) * 100.0,
		"libre": capacidad_maxima - items.size()
	}

func obtener_resumen_tipos() -> Dictionary:
	"""Devuelve un resumen de los tipos de ingredientes en el inventario"""
	var tipos = {}
	
	for item in items:
		if item:
			var nombre = obtener_nombre_ingrediente_seguro(item)
			var tipo = detectar_tipo_ingrediente(nombre)
			if tipos.has(tipo):
				tipos[tipo] += 1
			else:
				tipos[tipo] = 1
	
	return tipos

func soltar_item(indice: int):
	"""Suelta un item específico del inventario"""
	if not jugador:
		print("No hay jugador para soltar item")
		return
	
	var item = remover_item_por_indice(indice)
	if item:
		# Colocar el item frente al jugador
		var posicion_frente = jugador.global_position + jugador.transform.basis.z * -2
		posicion_frente.y = jugador.global_position.y + 0.5
		
		# Hacer que el item sea visible y físico de nuevo
		if "visible" in item:
			item.visible = true
		if "collision_layer" in item:
			item.collision_layer = 4
		if "collision_mask" in item:
			item.collision_mask = 1
		if "global_position" in item:
			item.global_position = posicion_frente
		
		if item.has_method("soltar_objeto"):
			item.soltar_objeto(posicion_frente)
		
		var nombre = obtener_nombre_ingrediente_seguro(item)
		print("Item soltado: ", nombre)

func esta_vacio() -> bool:
	return items.is_empty()

func esta_lleno() -> bool:
	return items.size() >= capacidad_maxima

func esta_entregando_pedido() -> bool:
	"""Indica si el inventario está siendo limpiado para entregar un pedido"""
	return entregando_pedido

func eliminar_ultimo_ingrediente():
	"""Elimina el último ingrediente agregado al inventario (LIFO - Last In, First Out)"""
	if items.is_empty():
		print("🗑️ INVENTARIO: No hay ingredientes para eliminar")
		return
	
	# Obtener el último ingrediente (último agregado)
	var ultimo_item = items[items.size() - 1]
	var nombre_ingrediente = "ingrediente desconocido"
	
	if ultimo_item and ultimo_item.has_method("obtener_nombre_ingrediente_seguro"):
		nombre_ingrediente = obtener_nombre_ingrediente_seguro(ultimo_item)
	elif ultimo_item:
		nombre_ingrediente = obtener_nombre_ingrediente_seguro(ultimo_item)
	
	print("🗑️ INVENTARIO: Devolviendo último ingrediente: ", nombre_ingrediente)
	
	# Eliminar del inventario
	items.remove_at(items.size() - 1)
	item_removido.emit(ultimo_item)
	
	# ELIMINAR CLON: El objeto en inventario es un clon, simplemente eliminarlo
	if is_instance_valid(ultimo_item):
		ultimo_item.queue_free()
	
	print("✅ INVENTARIO: Ingrediente devuelto (", items.size(), "/", capacidad_maxima, " restantes)")
