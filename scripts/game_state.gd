class_name GameState
extends RefCounted

static var selected_pokemon_path: String = "res://data/pokemon/venusaur.tres"
static var selected_pokemon: PokemonData = null
static var selected_color_hex: String = "#ffffff"
static var selected_tint_color: Color = Color.WHITE
static var selected_hue_shift: float = 0.0
static var selected_sat_mult: float = 1.0

static func set_selection(pokemon_res: PokemonData, hex: String, tint: Color, hue_shift: float = 0.0, sat_mult: float = 1.0) -> void:
	selected_pokemon = pokemon_res
	if pokemon_res != null:
		selected_pokemon_path = pokemon_res.resource_path
	selected_color_hex = hex
	selected_tint_color = tint
	selected_hue_shift = hue_shift
	selected_sat_mult = sat_mult

static func get_selected_pokemon() -> PokemonData:
	if selected_pokemon != null:
		return selected_pokemon
	if selected_pokemon_path != "" and (ResourceLoader.exists(selected_pokemon_path) or FileAccess.file_exists(selected_pokemon_path)):
		selected_pokemon = load(selected_pokemon_path) as PokemonData
		return selected_pokemon
	selected_pokemon = load("res://data/pokemon/venusaur.tres") as PokemonData
	return selected_pokemon

static func reset() -> void:
	selected_pokemon_path = "res://data/pokemon/venusaur.tres"
	selected_pokemon = null
	selected_color_hex = "#ffffff"
	selected_tint_color = Color.WHITE
	selected_hue_shift = 0.0
	selected_sat_mult = 1.0
