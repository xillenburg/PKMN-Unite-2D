class_name MeleeMechanic
extends RefCounted

static func execute(user: Fighter, move: MoveData) -> bool:
	if user == null or move == null:
		return false
	if user.is_lunging():
		return false
	var r: float = move.get_effective_range()
	var target := user.find_target(r)
	if target == null:
		return false
	move.play_sound(user)
	user.start_lunge(target, move)
	return true
