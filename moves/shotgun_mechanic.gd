class_name ShotgunMechanic
extends RefCounted

const LINEAR_PROJ_SCRIPT := preload("res://moves/linear_projectile.gd")

static func execute(user: Fighter, move: MoveData) -> bool:
	if user == null or move == null:
		return false

	var r: float = move.get_effective_range()
	var n: int = move.num_entities if move.num_entities > 0 else 3
	var cone_deg: float = move.spread_angle if move.spread_angle > 0.0 else 45.0
	var base_dir: Vector2 = user.facing if user.facing != Vector2.ZERO else Vector2.RIGHT
	var scene_root: Node = _get_scene_root(user)

	move.play_sound(user)

	var bonus: int = user.get_move_bonus_damage(&"attack_3") if user.has_method("get_move_bonus_damage") else 0
	var mult: float = user.get_base_damage() if user.has_method("get_base_damage") else 1.0
	var dmg: int = maxi(1, int(roundf((move.power + float(bonus)) * mult)))

	for i in range(n):
		var offset_deg: float = 0.0
		if n > 1:
			offset_deg = -cone_deg / 2.0 + (cone_deg * float(i) / float(n - 1))
		var dir: Vector2 = base_dir.rotated(deg_to_rad(offset_deg)).normalized()
		var proj := LINEAR_PROJ_SCRIPT.new()
		proj.source = user
		proj.move = move
		proj.damage = dmg
		proj.direction = dir
		proj.max_range = r
		proj.asset_path = move.asset_path
		scene_root.add_child(proj)
		proj.global_position = user.global_position
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
