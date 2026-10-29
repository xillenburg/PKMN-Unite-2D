class_name LinearProjectile
extends Area2D

const DEFAULT_TEX_PATH := "res://assets/moves/hit_1.png"

var source: Fighter
var move: MoveData
var damage: int = 1
var direction: Vector2 = Vector2.RIGHT
var speed: float = 280.0
var max_range: float = 120.0
var hit_radius: float = 12.0
var asset_path: String = ""

var _distance_traveled: float = 0.0
var _hit_done: bool = false
var _sprite: Sprite2D


func _ready() -> void:
	z_index = 3
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var tex_to_load := asset_path if (asset_path != "" and ResourceLoader.exists(asset_path)) else DEFAULT_TEX_PATH
	if ResourceLoader.exists(tex_to_load):
		_sprite.texture = load(tex_to_load)
	add_child(_sprite)

	if direction != Vector2.ZERO:
		_sprite.rotation = direction.angle()


func _physics_process(delta: float) -> void:
	if _hit_done:
		return

	var step := speed * delta
	global_position += direction * step
	_distance_traveled += step

	# Check for collision with enemy hurtbox circles
	var tree := get_tree()
	if tree != null:
		for node in tree.get_nodes_in_group(&"fighters"):
			var f := node as Fighter
			if f == null or not is_instance_valid(f) or f == source or f.is_defeated:
				continue
			if source != null and f.team == source.team:
				continue

			var hb_r: float = 10.0
			if f.hurtbox != null and f.hurtbox.has_method("get_radius"):
				hb_r = f.hurtbox.get_radius() * f.scale.abs().length() / sqrt(2.0)

			if global_position.distance_to(f.global_position) <= hit_radius + hb_r:
				_land_hit(f)
				return

	if _distance_traveled >= max_range:
		queue_free()


func _land_hit(victim: Fighter) -> void:
	if _hit_done:
		return
	_hit_done = true

	victim.take_damage(damage, source, move)

	var p := get_parent()
	if p != null:
		var scene_root: Node = p
		DiagonalSmokeEffect.spawn_poof(scene_root, global_position, 1)

	queue_free()
