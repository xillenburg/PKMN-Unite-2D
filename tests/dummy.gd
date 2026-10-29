class_name Dummy
extends Fighter

# Constants
const SPRITE_PATH := "res://assets/dummy_h_1.png"
const COUNTER_DELAY := 15

# Moves
@export var counter_move: MoveData

# State
var counter_wait := 0
var counter_target: Fighter


# Setup
func _init() -> void:
	team = &"enemy"


func _ready() -> void:
	super._ready()
	var tex: Texture2D = load(SPRITE_PATH)
	if tex == null:
		push_error("Missing sprite: " + SPRITE_PATH)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	add_child(sprite)
	visual = sprite
	setup_flash()


# Per-frame update
func _physics_process(_delta: float) -> void:
	if is_defeated:
		_update_defeat_blink()
		return
	update_fighter()
	_update_counter()


# Counter attack
func _on_damaged(source: Fighter) -> void:
	if is_defeated or counter_move == null or source == null or is_lunging() or counter_wait > 0:
		return
	counter_target = source
	counter_wait = COUNTER_DELAY


func _update_counter() -> void:
	if counter_wait == 0:
		return
	counter_wait -= 1
	if counter_wait > 0:
		return
	if is_instance_valid(counter_target) and counter_move != null:
		var dist := distance_to_fighter(counter_target)
		if dist <= counter_move.attack_range:
			start_lunge(counter_target, counter_move)
		else:
			print(name, " counter canceled: target out of range (", dist, " > ", counter_move.attack_range, ")")
	counter_target = null


func _on_lunge_started(direction: Vector2) -> void:
	facing = cardinal(direction)
	if visual is Sprite2D:
		visual.flip_h = (facing == Vector2.RIGHT)
