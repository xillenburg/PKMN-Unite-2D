@tool
class_name PokemonData
extends Resource

@export var display_name := ""
@export var base_damage: float = 1.0

@export_group("Sprites & Evolution Stages")
@export var sprite_dir := "res://assets/"
@export var sprite_prefix := ""
@export var sprite_ext := ".png"
@export var h_faces_right := false

# Stage mapping: stage index (1, 2, 3, 4) -> Dictionary of sprite pointers
# Stage 1: Base form (Lv 1 - 19)
# Stage 2: 2nd stage evolution (Lv 20 - 29)
# Stage 3: Final stage evolution (Lv 30)
# Stage 4: Mega evolution (prepared for future, unused for now)
@export var stages: Dictionary = {}

# --- Explicit sprite path exports (24 total: 6 per stage × 4 stages) ---
@export_group("Stage 1 Sprites")
@export var stage1_h1: String = ""
@export var stage1_h2: String = ""
@export var stage1_v1: String = ""
@export var stage1_v2: String = ""
@export var stage1_v3: String = ""
@export var stage1_v4: String = ""

@export_group("Stage 2 Sprites")
@export var stage2_h1: String = ""
@export var stage2_h2: String = ""
@export var stage2_v1: String = ""
@export var stage2_v2: String = ""
@export var stage2_v3: String = ""
@export var stage2_v4: String = ""

@export_group("Stage 3 Sprites")
@export var stage3_h1: String = ""
@export var stage3_h2: String = ""
@export var stage3_v1: String = ""
@export var stage3_v2: String = ""
@export var stage3_v3: String = ""
@export var stage3_v4: String = ""

@export_group("Stage 4 Sprites (Mega, Unused)")
@export var stage4_h1: String = ""
@export var stage4_h2: String = ""
@export var stage4_v1: String = ""
@export var stage4_v2: String = ""
@export var stage4_v3: String = ""
@export var stage4_v4: String = ""

@export_group("UI & Showcase")
@export var card_asset: String = ""       # Path to card asset (e.g. res://assets/ui/cards_selection/venusaur_card.png)
@export var sprite_full_body: String = "" # Path to front view sprite (e.g. res://assets/pokemon/venusaur/venu_front.png)
@export var cry_audio: String = ""        # Path to cry sound effect (e.g. res://assets/audio/cries/venusaur.mp3)

@export_group("Moves")
@export var attack_1: MoveData
@export var attack_2: MoveData
@export var attack_3: MoveData
@export var special: MoveData


static func get_stage_for_level(lvl: int) -> int:
	if lvl >= 30:
		return 3
	elif lvl >= 20:
		return 2
	return 1


func get_stage_data(stage_idx: int) -> Dictionary:
	if stages.has(stage_idx):
		return stages[stage_idx]
	if stages.has(str(stage_idx)):
		return stages[str(stage_idx)]
	if stages.has(1):
		return stages[1]
	if stages.has("1"):
		return stages["1"]
	return {}


func get_stage_name(stage_idx: int) -> String:
	var s_data := get_stage_data(stage_idx)
	if s_data.has("name"):
		return str(s_data["name"])
	return display_name


func get_sprite_path(stage_idx: int, suffix: String) -> String:
	# 1. Try explicit export fields (stage1_h1...stage4_v4)
	var explicit_path := get_sprite_for_stage(stage_idx, suffix)
	if explicit_path != "" and (ResourceLoader.exists(explicit_path) or FileAccess.file_exists(explicit_path)):
		return explicit_path

	# 2. Try stages dictionary
	var s_data := get_stage_data(stage_idx)
	if s_data.has(suffix):
		var path: String = str(s_data[suffix])
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return path

	# 3. Fallback: if specific stage asset not found on disk, try Stage 1
	if stage_idx != 1:
		var p1 := get_sprite_path(1, suffix)
		if p1 != "":
			return p1

	# 4. Legacy prefix fallback
	var legacy_path := sprite_path(suffix)
	if ResourceLoader.exists(legacy_path) or FileAccess.file_exists(legacy_path):
		return legacy_path

	# 5. General Venusaur/Bulbasaur asset fallback so missing custom sprites never crash the game
	var bulb_fb: String = "res://assets/pokemon/venusaur/bulb_" + suffix + ".png"
	if ResourceLoader.exists(bulb_fb) or FileAccess.file_exists(bulb_fb):
		return bulb_fb

	return ""


func sprite_path(suffix: String) -> String:
	var fname := sprite_prefix + "_" + suffix + sprite_ext
	if sprite_dir != "" and sprite_dir != "res://assets/":
		var p_custom := sprite_dir.path_join(fname)
		if ResourceLoader.exists(p_custom) or FileAccess.file_exists(p_custom):
			return p_custom
	# Check evolution line sub-folders under assets/pokemon/
	var folders: Array[String] = ["venusaur", "charizard", "blastoise"]
	for folder: String in folders:
		var p_sub: String = "res://assets/pokemon/" + folder + "/" + fname
		if ResourceLoader.exists(p_sub) or FileAccess.file_exists(p_sub):
			return p_sub
	var p_dir := sprite_dir.path_join(fname)
	if ResourceLoader.exists(p_dir) or FileAccess.file_exists(p_dir):
		return p_dir
	return "res://assets/" + fname


func get_move(slot: StringName) -> MoveData:
	return get(slot)


# New helper: get sprite path using explicit exports first, falling back to stages dict, then stage 1
# key format: "h1", "h2", "v1", "v2", "v3", "v4"
func get_sprite_for_stage(stage: int, key: String) -> String:
	# Map key aliases: h_1 -> h1, v_1 -> v1, etc.
	var normalized_key := key.replace("_", "")

	# 1. Try explicit export field: stage{N}_{key}
	var field_name := "stage%d_%s" % [stage, normalized_key]
	if field_name in self:
		var path: String = str(get(field_name))
		if path != "" and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
			return path

	# 2. Fall back to stages dict (old system)
	# Accept both "h1"/"h_1" style keys
	var dict_key := key
	var s_data := get_stage_data(stage)
	if s_data.has(dict_key):
		var path: String = str(s_data[dict_key])
		if path != "" and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
			return path
	# Try with underscore inserted
	var alt_key := normalized_key[0] + "_" + normalized_key.substr(1)
	if s_data.has(alt_key):
		var path: String = str(s_data[alt_key])
		if path != "" and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
			return path

	# 3. Fall back to stage 1 if file doesn't exist
	if stage != 1:
		return get_sprite_for_stage(1, key)

	# 4. Return "" if all fail (never crash)
	return ""


# UI & Showcase Getters & Fallbacks
func get_card_asset_path() -> String:
	if card_asset != "" and (ResourceLoader.exists(card_asset) or FileAccess.file_exists(card_asset)):
		return card_asset
	var lower_name := display_name.to_lower()
	var fallback := "res://assets/ui/cards_selection/%s_card.png" % lower_name
	if ResourceLoader.exists(fallback) or FileAccess.file_exists(fallback):
		return fallback
	return "res://assets/ui/cards_selection/venusaur_card.png"


func get_front_sprite_path() -> String:
	if sprite_full_body != "" and (ResourceLoader.exists(sprite_full_body) or FileAccess.file_exists(sprite_full_body)):
		return sprite_full_body
	if sprite_prefix != "":
		var candidate := sprite_dir + sprite_prefix + "_front.png"
		if ResourceLoader.exists(candidate) or FileAccess.file_exists(candidate):
			return candidate
	var lower_name := display_name.to_lower()
	var prefix_map := {
		"venusaur": "venu",
		"charizard": "chzard",
		"blastoise": "blast"
	}
	var pfx: String = prefix_map.get(lower_name, lower_name)
	var fallback := "res://assets/pokemon/%s/%s_front.png" % [lower_name, pfx]
	if ResourceLoader.exists(fallback) or FileAccess.file_exists(fallback):
		return fallback
	return "res://assets/pokemon/venusaur/venu_front.png"


func get_cry_audio_path() -> String:
	if cry_audio != "" and (ResourceLoader.exists(cry_audio) or FileAccess.file_exists(cry_audio)):
		return cry_audio
	var lower_name := display_name.to_lower()
	var fallback := "res://assets/audio/cries/%s.mp3" % lower_name
	if ResourceLoader.exists(fallback) or FileAccess.file_exists(fallback):
		return fallback
	return "res://assets/audio/cries/venusaur.mp3"


var front_sprite: String:
	get: return get_front_sprite_path()
	set(v): sprite_full_body = v

var cry_path: String:
	get: return get_cry_audio_path()
	set(v): cry_audio = v

var card_path: String:
	get: return get_card_asset_path()
	set(v): card_asset = v
