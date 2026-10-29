@tool
class_name MoveData
extends Resource

# Standard string constants
const PHYSICAL := "physical"
const SPECIAL := "special"

const MELEE := "melee"
const HOMING := "homing"
const SHOTGUN := "shotgun"
const SHOT := "shot"
const BEAM := "beam"

# Backward compatibility dictionaries for code using MoveData.Category.PHYSICAL or MoveData.MoveType.MELEE
const Category = {
	"PHYSICAL": "physical",
	"SPECIAL": "special",
}

const MoveType = {
	"MELEE": "melee",
	"HOMING": "homing",
	"SHOTGUN": "shotgun",
	"SHOT": "shot",
	"BEAM": "beam",
}

@export var display_name := ""

# Move Category: string ("physical" or "special"). Int conversion supported.
@export var move_category: String = "physical":
	get:
		return _move_category
	set(v):
		var s := str(v).to_lower().strip_edges()
		if s == "1" or s == "special":
			_move_category = "special"
		else:
			_move_category = "physical"

# Move Type: string ("melee", "homing", "shotgun", "shot", "beam"). Int conversion supported.
@export var move_type: String = "melee":
	get:
		return _move_type
	set(v):
		var s := str(v).to_lower().strip_edges()
		match s:
			"0", "melee": _move_type = "melee"
			"1", "homing": _move_type = "homing"
			"2", "shotgun": _move_type = "shotgun"
			"3", "shot": _move_type = "shot"
			"4", "beam": _move_type = "beam"
			_: _move_type = s if s != "" else "melee"

var _move_category: String = "physical"
var _move_type: String = "melee"

# Damage & timing
@export var power: float = 1.0
@export var cooldown_frames: int = 60
@export var range: float = 0.0           # targeting/valid range in pixels
@export var attack_range: float = 0.0    # backward-compat alias for range

# Projectile config (HOMING / SHOTGUN / SHOT)
@export var num_entities: int = 1        # how many projectiles to spawn
@export var spread_angle: float = 60.0   # SHOTGUN: cone width in degrees
@export var homing_range: float = 0.0    # HOMING: tracking override (0 = use range)
@export var shoot_interval: float = 0.0  # SHOT: delay in seconds between successive shots (if num_entities > 1)

# BEAM config
@export var tracking: bool = false       # whether beam locks onto target in range

# Assets
@export var asset_path: String = ""      # primary sprite/projectile path
@export var charge_asset_path: String = "" # optional charge texture (e.g. beam charge)
@export var sound_path: String = ""
@export var play_hit_sound: bool = true

# Hitbox configuration for melee
@export var hitbox_radius: float = 7.0
@export var lunge_speed: float = 2.0
@export var contact_distance: float = 20.0
@export var max_frames: int = 45

# XP (float for flexibility)
@export var xp_gain: float = 1.0

# Backward-compat: keep 'type' as @export so old .tres files still load it
@export var type: String = ""

# Cooldown in seconds (alias of cooldown_frames)
var cooldown: float:
	get: return float(cooldown_frames) / 60.0
	set(v): cooldown_frames = int(v * 60.0)


func get_category() -> String:
	return _move_category


func get_move_type() -> String:
	return _move_type


func is_physical() -> bool:
	return _move_category == "physical"


func is_special() -> bool:
	return _move_category == "special"


func is_melee() -> bool:
	return _move_type == "melee"


func is_homing() -> bool:
	return _move_type == "homing"


func is_shotgun() -> bool:
	return _move_type == "shotgun"


var shot_interval: float:
	get:
		return shoot_interval
	set(v):
		shoot_interval = v


func is_shot() -> bool:
	return _move_type == "shot"


func is_beam() -> bool:
	return _move_type == "beam"


func get_effective_range() -> float:
	if range > 0.0:
		return range
	if attack_range > 0.0:
		return attack_range
	match _move_type:
		"melee": return 44.0
		"homing": return 110.0
		"shotgun": return 140.0
		"shot": return 160.0
		"beam": return 220.0
	return 44.0


func _spawn_leaf(fighter: Fighter, scene_root: Node, target: Fighter, sr: float) -> Node:
	var HomingMechanicScript = load("res://moves/homing_mechanic.gd")
	return HomingMechanicScript.spawn_entity(fighter, scene_root, target, sr, self)


func play_sound(user: Node2D) -> void:
	if sound_path == "":
		return
	var fighter := user as Fighter
	if fighter != null and fighter.has_method("play_sfx"):
		fighter.play_sfx(sound_path)


func execute(user: Node2D) -> bool:
	var fighter := user as Fighter
	if fighter != null:
		return MoveExecutor.execute(fighter, self)
	print(user.name, " used ", display_name)
	play_sound(user)
	return true
