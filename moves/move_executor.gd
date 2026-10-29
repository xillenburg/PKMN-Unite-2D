class_name MoveExecutor
extends RefCounted

const MeleeMechanicScript = preload("res://moves/melee_mechanic.gd")
const HomingMechanicScript = preload("res://moves/homing_mechanic.gd")
const ShotgunMechanicScript = preload("res://moves/shotgun_mechanic.gd")
const ShotMechanicScript = preload("res://moves/shot_mechanic.gd")
const BeamMechanicScript = preload("res://moves/beam_mechanic.gd")

static func execute(user: Fighter, move: MoveData) -> bool:
	if move == null or user == null:
		return false
	match move.get_move_type():
		"melee":
			return MeleeMechanicScript.execute(user, move)
		"homing":
			return HomingMechanicScript.execute(user, move)
		"shotgun":
			return ShotgunMechanicScript.execute(user, move)
		"shot":
			return ShotMechanicScript.execute(user, move)
		"beam":
			return BeamMechanicScript.execute(user, move)
		_:
			return MeleeMechanicScript.execute(user, move)
