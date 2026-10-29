class_name HomingMechanic
extends RefCounted

const HOMING_PROJ_SCRIPT := preload("res://moves/homing_projectile.gd")
const LEAF_DELAY_SEC := 0.2

static func execute(user: Fighter, move: MoveData) -> bool:
	if user == null or move == null:
		return false

	var tracking_range: float = move.homing_range if move.homing_range > 0.0 else (move.range if move.range > 0.0 else (user.get_atk2_range() if user.has_method("get_atk2_range") else 110.0))
	var target := user.find_target(tracking_range)

	move.play_sound(user)

	var scene_root: Node = _get_scene_root(user)
	var n: int = move.num_entities if move.num_entities > 0 else 5
	var spread_ratios: Array[float] = []
	if n <= 1:
		spread_ratios.append(0.0)
	else:
		for i in range(n):
			spread_ratios.append(-1.0 + (2.0 * float(i) / float(n - 1)))

	_spawn_homing_with_delay(user, scene_root, target, spread_ratios, move, tracking_range)
	return true


static func _get_scene_root(user: Node2D) -> Node:
	if user.is_inside_tree() and user.get_tree() != null:
		var cs := user.get_tree().current_scene
		if cs != null:
			return cs
		var r := user.get_tree().root
		if r != null:
			return r
	var p := user.get_parent()
	if p != null:
		return p
	return user


static func _spawn_homing_with_delay(fighter: Fighter, scene_root: Node, initial_target: Fighter, spread_ratios: Array[float], move: MoveData, tracking_range: float) -> void:
	var target: Fighter = initial_target
	var bonus: int = fighter.get_move_bonus_damage(&"attack_2") if fighter.has_method("get_move_bonus_damage") else 0
	var mult: float = fighter.get_base_damage() if fighter.has_method("get_base_damage") else 1.0
	var dmg: int = maxi(1, int(roundf((move.power + float(bonus)) * mult)))

	for i in range(spread_ratios.size()):
		if i > 0:
			if not is_instance_valid(fighter) or not fighter.is_inside_tree() or fighter.get_tree() == null:
				return
			await fighter.get_tree().create_timer(LEAF_DELAY_SEC).timeout
			if not is_instance_valid(fighter) or not is_instance_valid(scene_root) or not fighter.is_inside_tree():
				return
			if target == null or not is_instance_valid(target) or target.is_defeated:
				target = fighter.find_target(tracking_range)

		var sr: float = spread_ratios[i]
		spawn_entity(fighter, scene_root, target, sr, move)


static func spawn_entity(fighter: Fighter, scene_root: Node, target: Fighter, sr: float, move: MoveData) -> HomingProjectile:
	var bonus: int = fighter.get_move_bonus_damage(&"attack_2") if (fighter != null and fighter.has_method("get_move_bonus_damage")) else 0
	var mult: float = fighter.get_base_damage() if (fighter != null and fighter.has_method("get_base_damage")) else 1.0
	var dmg: int = maxi(1, int(roundf((move.power + float(bonus)) * mult)))
	var proj := HOMING_PROJ_SCRIPT.new()
	proj.is_top = (sr < 0.0)
	proj.spread_ratio = sr
	proj.source = fighter
	proj.move = move
	proj.target = target
	proj.damage = dmg
	scene_root.add_child(proj)
	if fighter != null and is_instance_valid(fighter):
		proj.global_position = fighter.global_position
	return proj
