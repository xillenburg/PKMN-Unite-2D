class_name BeamMechanic
extends RefCounted

const BEAM_EFFECT_SCRIPT := preload("res://moves/beam_effect.gd")

static func execute(user: Fighter, move: MoveData) -> bool:
	if user == null or move == null:
		return false

	move.play_sound(user)

	var scene_root: Node = _get_scene_root(user)
	var effect := BEAM_EFFECT_SCRIPT.new(user, move)
	scene_root.add_child(effect)
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
