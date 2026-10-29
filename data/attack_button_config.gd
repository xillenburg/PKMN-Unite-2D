class_name AttackButtonConfig
extends RefCounted

# =============================================================================
# DATA-DRIVEN ATTACK BUTTON ASSET REGISTRY
# 
# Easily edit which texture asset each attack button slot utilizes.
# - attack_1 (Melee): utilizes attack_melee.png
# - attack_2, attack_3, special, dash: utilize attack_blank.png
# 
# Buttons draw their assigned icon tinted based on their circular button theme color.
# =============================================================================

const PATH_ATTACK_MELEE := "res://assets/ui/attack_melee.png"
const PATH_ATTACK_BLANK := "res://assets/ui/attack_blank.png"

# Editable mapping from button slot name to asset path
static var ASSET_MAPPING: Dictionary = {
	&"attack_1": PATH_ATTACK_MELEE,
	&"attack_2": PATH_ATTACK_BLANK,
	&"attack_3": PATH_ATTACK_BLANK,
	&"special":  PATH_ATTACK_BLANK,
	&"dash":     PATH_ATTACK_BLANK,
}

static var _texture_cache: Dictionary = {}


static func get_asset_path(slot: StringName) -> String:
	return ASSET_MAPPING.get(slot, PATH_ATTACK_BLANK)


static func set_asset_path(slot: StringName, path: String) -> void:
	ASSET_MAPPING[slot] = path
	_texture_cache.erase(slot)


static func get_texture(slot: StringName) -> Texture2D:
	if _texture_cache.has(slot):
		return _texture_cache[slot]

	var path: String = get_asset_path(slot)
	if path != "" and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		var tex := load(path) as Texture2D
		if tex != null:
			_texture_cache[slot] = tex
			return tex

	if ResourceLoader.exists(PATH_ATTACK_BLANK):
		var fallback := load(PATH_ATTACK_BLANK) as Texture2D
		_texture_cache[slot] = fallback
		return fallback

	return null
