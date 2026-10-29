class_name Hurtbox
extends Area2D

@export var size := Vector2(20, 18)

var fighter: Fighter
var _col_shape: CollisionShape2D
var _circle_shape: CircleShape2D


func _init() -> void:
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	monitorable = true
	z_index = 10


func _ready() -> void:
	add_to_group(&"hurtboxes")
	_col_shape = CollisionShape2D.new()
	_circle_shape = CircleShape2D.new()
	_circle_shape.radius = _radius_from_size(size)
	_col_shape.shape = _circle_shape
	add_child(_col_shape)

	var menu_node: Node = get_node_or_null("/root/DebugMenu") if is_inside_tree() else null
	if menu_node != null and menu_node.has_signal("hitboxes_toggled"):
		menu_node.connect("hitboxes_toggled", Callable(self, "_on_hitboxes_toggled"))


# Returns the circular radius derived from a rectangular size.
# Uses the average of half-extents so the circle fits the sprite body snugly.
func _radius_from_size(s: Vector2) -> float:
	return (s.x + s.y) * 0.25


func get_radius() -> float:
	if _circle_shape != null:
		return _circle_shape.radius
	return _radius_from_size(size)


func set_box_size(new_size: Vector2) -> void:
	size = new_size
	if _circle_shape != null:
		_circle_shape.radius = _radius_from_size(new_size)
	queue_redraw()


func _on_hitboxes_toggled(_show: bool) -> void:
	queue_redraw()


func _physics_process(_delta: float) -> void:
	var menu_node: Node = get_node_or_null("/root/DebugMenu") if is_inside_tree() else null
	if menu_node != null and menu_node.get("show_hitboxes"):
		queue_redraw()


func _draw() -> void:
	var menu_node: Node = get_node_or_null("/root/DebugMenu") if is_inside_tree() else null
	if menu_node == null or not menu_node.get("show_hitboxes"):
		return
	var r := get_radius()
	# Semi-transparent green fill and bright green circle outline
	draw_circle(Vector2.ZERO, r, Color(0.1, 0.9, 0.2, 0.3))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(0.1, 1.0, 0.2, 0.9), 1.5)
