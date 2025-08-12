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
	"""CORRECCIÓN 2: Limpiar inventario ELIMINANDO los items en lugar de soltarlos"""
	print("Limpiando inventario...")
	
	for item in items:
		if is_instance_valid(item):
			item_removido.emit(item)
			
			# OPCIÓN A: ELIMINAR COMPLETAMENTE (RECOMENDADO)
			if item.has_method("soltar_objeto"):
				item.soltar_objeto()  # Esto ahora los elimina gracias a la corrección 3
			else:
				item.queue_free()
	
	items.clear()
	print("✓ Inventario limpiado - Todos los items eliminados")

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
	"""Función sincronizada con GameManager y HudController"""
	if nombre_ingrediente == "":
		return "generico"
	
	var nombre = nombre_ingrediente.to_lower()
	
	# IMPORTANTE: EXACTAMENTE la misma lógica
	if "bun_bottom" in nombre:
		return "pan_inferior"
	elif "bun_top" in nombre:
		return "pan_superior"
	elif "bun" in nombre and not ("bottom" in nombre or "top" in nombre):
		return "pan_generico"
	elif "vegetableburger" in nombre:
		return "carne"  # CAMBIO: Tratarla como carne
	elif "burger" in nombre or "meat" in nombre or "carne" in nombre:
		return "carne"
	elif "tomato_slice" in nombre:
		return "tomate"  # CAMBIO: Simplificado
	elif "tomato" in nombre:
		return "tomate"
	elif "lettuce_slice" in nombre:
		return "lechuga"  # CAMBIO: Simplificado
	elif "lettuce" in nombre:
		return "lechuga"
	elif "cheese_slice" in nombre:
		return "queso"  # CAMBIO: Simplificado
	elif "cheese" in nombre:
		return "queso"
	elif "sauce" in nombre or "salsa" in nombre or "ketchup" in nombre or "mustard" in nombre:
		return "salsa"
	else:
		return "generico"

func crear_pedido_desde_inventario() -> Dictionary:
	"""Crea un pedido con los ingredientes actuales del inventario"""
	var nombres_ingredientes = obtener_nombres_ingredientes()
	
	return {
		"ingredientes": nombres_ingredientes,
		"tiempo_creacion": Time.get_unix_time_from_system(),
		"jugador_id": jugador.get_instance_id() if jugador else 0
	}

func entregar_pedido_a_cliente(cliente: Node) -> bool:
	"""CORRECCIÓN 2: Entrega el pedido y LIMPIA EL INVENTARIO correctamente"""
	if items.is_empty():
		print("No hay ingredientes para entregar")
		return false
	
	if not cliente or not cliente.has_method("recibir_pedido_jugador"):
		print("Cliente inválido o sin método recibir_pedido_jugador")
		return false
	
	var pedido_jugador = crear_pedido_desde_inventario()
	
	if cliente.recibir_pedido_jugador(pedido_jugador):
		print("✓ Pedido entregado exitosamente al cliente")
		limpiar_inventario()  # Esto ahora elimina correctamente los items
		return true
	else:
		print("✗ El cliente rechazó el pedido")
		return false

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

func entregar_a_cliente_cercano():
	"""Busca el cliente más cercano y le entrega el pedido"""
	if not jugador:
		print("No hay jugador para entregar pedido")
		return
	
	var clientes = get_tree().get_nodes_in_group("clientes")
	var cliente_mas_cercano = null
	var distancia_minima = 5.0  # Aumentar distancia máxima para entregar
	
	print("\n🔍 Buscando clientes cerca... Clientes encontrados: ", clientes.size())
	print("Posición del jugador: ", jugador.global_position)
	
	for i in range(clientes.size()):
		var cliente = clientes[i]
		if not is_instance_valid(cliente):
			continue
			
		var distancia = jugador.global_position.distance_to(cliente.global_position)
		var estado = obtener_estado_cliente(cliente)
		var puede_recibir = esta_esperando_comida(cliente)
		
		print("Cliente ", i, ":")
		print("  - Posición: ", cliente.global_position)
		print("  - Distancia: ", "%.2f" % distancia)
		print("  - Estado: ", estado)
		print("  - Puede recibir: ", puede_recibir)
		
		if cliente.has_method("recibir_pedido_jugador") and puede_recibir:
			if distancia < distancia_minima:
				distancia_minima = distancia
				cliente_mas_cercano = cliente
				print("  ✅ Cliente candidato para entrega")
			else:
				print("  ❌ Muy lejos (", "%.2f" % distancia, " > ", distancia_minima, ")")
		else:
			print("  ❌ No puede recibir pedido")
				
	if cliente_mas_cercano:
		print("\n🍽️ Intentando entregar pedido a cliente más cercano (distancia: ", "%.2f" % distancia_minima, ")")
		if entregar_pedido_a_cliente(cliente_mas_cercano):
			print("✅ Pedido entregado exitosamente")
		else:
			print("❌ Fallo al entregar pedido")
	else:
		print("\n❌ No hay clientes cerca esperando pedidos")
		print("Aumenta la distancia o verifica que haya clientes en estado ESPERANDO_COMIDA")

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
	
	# CORRECCIÓN: Usar la nueva función específica del cliente
	if cliente.has_method("esta_esperando_comida_en_mesa"):
		var esperando = cliente.esta_esperando_comida_en_mesa()
		if esperando:
			print("✅ Cliente está esperando comida en mesa")
		return esperando
	
	# CORRECCIÓN: Verificar el estado usando la función de string
	if cliente.has_method("obtener_estado_actual_string"):
		var estado_string = cliente.obtener_estado_actual_string()
		print("DEBUG - Estado del cliente: ", estado_string)
		return estado_string == "ESPERANDO_COMIDA"
	
	# Fallback original mejorado
	if "estado_actual" in cliente:
		var estado = cliente.estado_actual
		print("DEBUG - Estado del cliente (enum): ", estado, " (4=ESPERANDO_COMIDA)")
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
