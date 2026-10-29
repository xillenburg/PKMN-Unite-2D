class_name ShotMechanic
extends RefCounted

const LINEAR_PROJ_SCRIPT := preload("res://moves/linear_projectile.gd")

static func execute(user: Fighter, move: MoveData) -> bool:
	if user == null or move == null:
		return false

	var r: float = move.get_effective_range()
	var n: int = move.num_entities if move.num_entities > 0 else 1
	var dir: Vector2 = user.facing if user.facing != Vector2.ZERO else Vector2.RIGHT
	var scene_root: Node = _get_scene_root(user)

	move.play_sound(user)

	var bonus: int = user.get_move_bonus_damage(&"attack_2") if user.has_method("get_move_bonus_damage") else 0
	var mult: float = user.get_base_damage() if user.has_method("get_base_damage") else 1.0
	var dmg: int = maxi(1, int(roundf((move.power + float(bonus)) * mult)))

	if n > 1 and move.shoot_interval > 0.0:
		_spawn_burst_with_interval(user, scene_root, dir, r, dmg, move, n)
	else:
		for i in range(n):
			var proj := LINEAR_PROJ_SCRIPT.new()
			proj.source = user
			proj.move = move
			proj.damage = dmg
			proj.direction = dir
			proj.max_range = r
			proj.asset_path = move.asset_path
			scene_root.add_child(proj)
			proj.global_position = user.global_position + dir * float(i * 8)
	return true


static func _spawn_burst_with_interval(user: Fighter, scene_root: Node, dir: Vector2, r: float, dmg: int, move: MoveData, count: int) -> void:
	for i in range(count):
		if i > 0:
			var tree: SceneTree = null
			if user.is_inside_tree():
				tree = user.get_tree()
			elif scene_root.is_inside_tree():
				tree = scene_root.get_tree()
			if tree != null:
				await tree.create_timer(move.shoot_interval).timeout
			if not is_instance_valid(user) or user.is_defeated:
				return
		var proj := LINEAR_PROJ_SCRIPT.new()
		proj.source = user
		proj.move = move
		proj.damage = dmg
		proj.direction = dir
		proj.max_range = r
		proj.asset_path = move.asset_path
		scene_root.add_child(proj)
		proj.global_position = user.global_position


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
