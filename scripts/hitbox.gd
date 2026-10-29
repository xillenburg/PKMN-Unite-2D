class_name Hitbox
extends Area2D

signal hit_landed(victim: Fighter)

@export var radius: float = 7.0

var source: Fighter
var move: MoveData
var damage: int = 0
var active: bool = false
var _hit_victims: Array[Fighter] = []
var _col_shape: CollisionShape2D
var _circle_shape: CircleShape2D


func _init() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = false
	monitorable = false
	z_index = 11


func _ready() -> void:
	add_to_group(&"hitboxes")
	_col_shape = CollisionShape2D.new()
	_circle_shape = CircleShape2D.new()
	_circle_shape.radius = radius
	_col_shape.shape = _circle_shape
	add_child(_col_shape)

	area_entered.connect(_on_area_entered)

	var menu_node: Node = get_node_or_null("/root/DebugMenu") if is_inside_tree() else null
	if menu_node != null and menu_node.has_signal("hitboxes_toggled"):
		menu_node.connect("hitboxes_toggled", Callable(self, "_on_hitboxes_toggled"))


func set_radius(r: float) -> void:
	radius = r
	if _circle_shape != null:
		_circle_shape.radius = r
	queue_redraw()


func _on_hitboxes_toggled(_show: bool) -> void:
	queue_redraw()


func activate(dmg: int, m: MoveData = null) -> void:
	damage = dmg
	move = m
	active = true
	_hit_victims.clear()
	monitoring = true
	queue_redraw()


func deactivate() -> void:
	active = false
	move = null
	monitoring = false
	_hit_victims.clear()
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if not active:
		return

	var menu_node: Node = get_node_or_null("/root/DebugMenu") if is_inside_tree() else null
	if menu_node != null and menu_node.get("show_hitboxes"):
		queue_redraw()

	for area in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox != null:
			_try_hit(hurtbox)

	var hurtbox_candidates: Array = []
	if is_inside_tree() and get_tree() != null:
		hurtbox_candidates = get_tree().get_nodes_in_group(&"hurtboxes")
	if hurtbox_candidates.is_empty() and source != null and source.get_parent() != null:
		for sibling in source.get_parent().get_children():
			if sibling is Fighter and sibling != source and sibling.get("hurtbox") != null:
				hurtbox_candidates.append(sibling.get("hurtbox"))

	for node in hurtbox_candidates:
		var hurtbox := node as Hurtbox
		if hurtbox != null and is_instance_valid(hurtbox):
			# Use circle hurtbox: distance from hitbox center to hurtbox center minus hurtbox radius
			var hurtbox_r: float = hurtbox.get_radius() * hurtbox.global_scale.abs().length() / sqrt(2.0)
			var dist: float = global_position.distance_to(hurtbox.global_position)
			if dist <= radius + hurtbox_r:
				_try_hit(hurtbox)


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox != null:
		_try_hit(hurtbox)


func _try_hit(hurtbox: Hurtbox) -> bool:
	if not active:
		return false
	if hurtbox == null or not is_instance_valid(hurtbox.fighter):
		return false
	var victim := hurtbox.fighter
	if victim == source:
		return false
	if source != null and source.team == victim.team:
		return false
	if _hit_victims.has(victim):
		return false

	_hit_victims.append(victim)
	victim.take_damage(damage, source, move)
	hit_landed.emit(victim)
	return true


func _draw() -> void:
	var menu_node: Node = get_node_or_null("/root/DebugMenu") if is_inside_tree() else null
	if menu_node == null or not menu_node.get("show_hitboxes") or not active:
		return
	# Semi-transparent red fill and bright red outline
	draw_circle(Vector2.ZERO, radius, Color(0.9, 0.1, 0.1, 0.45))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1.0, 0.15, 0.15, 0.95), 2.0)
