class_name XPSystem
extends RefCounted

const CONFIG_PATH := "res://data/xp_manager.cfg"
static var _config_file: ConfigFile = null

static func _ensure_config() -> ConfigFile:
	if _config_file != null:
		return _config_file
	_config_file = ConfigFile.new()
	var err := _config_file.load(CONFIG_PATH)
	if err != OK:
		# Create default in-memory config if file cannot be read
		_config_file.set_value("kill_xp", "base_kill_xp", 50.0)
		_config_file.set_value("kill_xp", "level_multiplier", 1.0)
		_config_file.set_value("damage_xp", "damage_taken_multiplier", 0.5)
		_config_file.set_value("level_progression", "base_level_xp", 20)
		_config_file.set_value("level_progression", "level_xp_growth", 10)
		_config_file.set_value("default", "atk_1", 1.0)
		_config_file.set_value("default", "atk_2", 2.0)
		_config_file.set_value("default", "atk_3", 3.0)
	return _config_file


static func reload_config() -> void:
	_config_file = null
	_ensure_config()


const BASE_KILL_XP: float = 50.0
const BASE_LEVEL_XP: int = 20
const LEVEL_XP_GROWTH: int = 10

static func get_base_kill_xp() -> float:
	return float(_ensure_config().get_value("kill_xp", "base_kill_xp", BASE_KILL_XP))

static func get_base_level_xp() -> int:
	return int(_ensure_config().get_value("level_progression", "base_level_xp", BASE_LEVEL_XP))

static func get_level_xp_growth() -> int:
	return int(_ensure_config().get_value("level_progression", "level_xp_growth", LEVEL_XP_GROWTH))


# Universal XP for attack moves
# Reads section [<pokemon_name>] with sub-keys atk_1, atk_2, atk_3.
# Unite moves (special) do not yield XP (always return 0).
static func get_move_xp(slot_name: StringName, move: MoveData = null, pokemon_name: String = "") -> int:
	if slot_name == &"special":
		return 0 # Unite moves do not yield XP

	var cfg := _ensure_config()
	var sub_key := ""
	match slot_name:
		&"attack_1":
			sub_key = "atk_1"
		&"attack_2":
			sub_key = "atk_2"
		&"attack_3":
			sub_key = "atk_3"

	var section := pokemon_name.to_lower().strip_edges()
	if section != "" and cfg.has_section(section) and sub_key != "" and cfg.has_section_key(section, sub_key):
		return int(cfg.get_value(section, sub_key))

	if sub_key != "" and cfg.has_section_key("default", sub_key):
		return int(cfg.get_value("default", sub_key))

	if move != null and "xp_gain" in move and move.xp_gain > 0:
		return int(move.xp_gain)

	match slot_name:
		&"attack_1": return 1
		&"attack_2": return 2
		&"attack_3": return 3

	return 1


# Universal XP for taking damage: multiplier from config (default 0.5)
static func get_damage_taken_xp(damage: int) -> float:
	if damage <= 0:
		return 0.0
	var mult: float = float(_ensure_config().get_value("damage_xp", "damage_taken_multiplier", 0.5))
	return float(damage) * mult


# Max XP threshold for a given level
static func get_max_xp_for_level(level: int) -> int:
	var base_lvl := get_base_level_xp()
	var growth := get_level_xp_growth()
	return base_lvl + (maxi(level, 1) - 1) * growth


# Scaled Kill EXP formula: (base_kill_xp * level_multiplier * victim_lvl)
static func calculate_kill_xp(victim_level: int) -> float:
	var cfg := _ensure_config()
	var base_k: float = float(cfg.get_value("kill_xp", "base_kill_xp", 50.0))
	var mult: float = float(cfg.get_value("kill_xp", "level_multiplier", 1.0))
	return base_k * mult * float(maxi(victim_level, 1))


# Scaled EXP helper for external references
static func calculate_scaled_exp(base_exp: float, enemy_lvl: int) -> float:
	return base_exp * float(maxi(enemy_lvl, 1))


# Unified single-point handler for attack landing & damage XP processing
static func on_attack_landed(attacker: Object, defender: Object, move: MoveData, actual_dmg: int) -> void:
	# 1. Attacker gains data-driven flat XP from config
	if attacker != null and is_instance_valid(attacker) and attacker != defender:
		var slot: StringName = attacker.get_slot_for_move(move) if attacker.has_method("get_slot_for_move") else &""
		var pname := ""
		if "pokemon" in attacker and attacker.get("pokemon") != null:
			var p_obj: Object = attacker.get("pokemon")
			if "display_name" in p_obj:
				pname = str(p_obj.get("display_name"))
		var attacker_xp: float = float(get_move_xp(slot, move, pname))
		if attacker.has_method("gain_xp"):
			attacker.gain_xp(attacker_xp)
		print(attacker.name, " gained ", attacker_xp, " XP from landing attack (", move.display_name if move != null else "move", ")")

	# 2. Defender gains flat XP: damage taken * damage_taken_multiplier
	if defender != null and is_instance_valid(defender) and actual_dmg > 0:
		var taken_xp: float = get_damage_taken_xp(actual_dmg)
		if taken_xp > 0.0 and defender.has_method("gain_xp"):
			defender.gain_xp(taken_xp)
			print(defender.name, " gained ", taken_xp, " XP from taking ", actual_dmg, " damage")


# Handler for defeating / killing an enemy
static func on_fighter_defeated(killer: Object, victim: Object) -> void:
	if killer == null or not is_instance_valid(killer) or killer == victim:
		return
	var victim_lvl: int = maxi(victim.level if (victim != null and is_instance_valid(victim) and "level" in victim) else 1, 1)
	var kill_xp: float = calculate_kill_xp(victim_lvl)
	if killer.has_method("gain_xp"):
		killer.gain_xp(kill_xp)
	print(killer.name, " gained ", kill_xp, " Kill XP for defeating ", victim.name if victim != null else "enemy")
