extends Node2D

const DUMMY_SCENE := preload("res://tests/dummy.tscn")

func _ready() -> void:
	_setup_player()
	_spawn_initial_dummy()


func _setup_player() -> void:
	var player = get_node_or_null("Player")
	if player != null:
		if GameState.selected_pokemon != null:
			player.pokemon = GameState.selected_pokemon
		elif GameState.selected_pokemon_path != "" and ResourceLoader.exists(GameState.selected_pokemon_path):
			player.pokemon = load(GameState.selected_pokemon_path)
		
		if GameState.selected_tint_color != Color.WHITE:
			player.apply_color_tint(GameState.selected_tint_color)


func _spawn_initial_dummy() -> void:
	for child in get_children():
		if child.name.begins_with("Dummy"):
			return

	var player := get_node_or_null("Player") as Node2D
	var spawn_pos: Vector2 = (player.global_position if player != null else Vector2(16, 16)) + Vector2(64, 0)

	var dummy := DUMMY_SCENE.instantiate()
	dummy.name = "Dummy"
	dummy.global_position = spawn_pos
	add_child(dummy)
