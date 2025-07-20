# SceneManager.gd - Autoload para gestión de escenas
extends Node

enum SceneType {
	MENU,
	GAME,
	UNKNOWN
}

var scene_type_actual: SceneType = SceneType.UNKNOWN

func _ready():
	# Detectar el tipo de escena al cambiar
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node):
	# Detectar cuando cambia la escena principal
	if node == get_tree().current_scene:
		detectar_tipo_escena()

func detectar_tipo_escena():
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
	
	var scene_name = current_scene.name.to_lower()
	
	if "mainmenu" in scene_name or "menu" in scene_name:
		scene_type_actual = SceneType.MENU
		print("SceneManager: Detectado MENÚ")
	elif "testlevel" in scene_name or "game" in scene_name or "level" in scene_name:
		scene_type_actual = SceneType.GAME
		print("SceneManager: Detectado JUEGO")
		
		# Configurar GameManager para el juego
		await get_tree().process_frame
		configurar_game_manager_para_juego()
	else:
		scene_type_actual = SceneType.UNKNOWN
		print("SceneManager: Tipo de escena desconocido: ", scene_name)

func configurar_game_manager_para_juego():
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and scene_type_actual == SceneType.GAME:
		# Solo configurar si no están ya configurados
		if game_manager.puntos_spawn_clientes.is_empty():
			game_manager.puntos_spawn_clientes = [
				Vector3(-1, 0.5, 0.2),
				Vector3(-0.5, 0.5, 0.2),
				Vector3(-1.5, 0.5, 0.2)
			]
			print("SceneManager: Puntos de spawn configurados")
		
		# Spawnear un cliente inicial después de un momento
		await get_tree().create_timer(2.0).timeout
		if game_manager.has_method("forzar_spawn_cliente"):
			game_manager.forzar_spawn_cliente()
			print("SceneManager: Cliente inicial spawneado")

func es_menu() -> bool:
	return scene_type_actual == SceneType.MENU

func es_juego() -> bool:
	return scene_type_actual == SceneType.GAME

func obtener_tipo_escena() -> SceneType:
	return scene_type_actual
