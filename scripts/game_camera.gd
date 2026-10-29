class_name GameCamera
extends Camera2D

# Zoom levels: Maximum zoom (5.0x) is the default.
# Starting from max zoom in, zooming out has exactly 2 levels: Level 1 (3.5x) and Level 2 (2.25x full arena).
const ZOOM_LEVELS: Array[float] = [2.25, 3.5, 5.0]
const DEFAULT_ZOOM_IDX := 2 # 5.0x zoom (Maximum zoom is the default)
const PAN_SPEED := 12.0

var current_zoom_idx := DEFAULT_ZOOM_IDX
var is_free_mode: bool = false
var saved_zoom: Vector2 = Vector2(5.0, 5.0)


func _init() -> void:
	zoom = Vector2(ZOOM_LEVELS[current_zoom_idx], ZOOM_LEVELS[current_zoom_idx])
	saved_zoom = zoom


func _ready() -> void:
	add_to_group(&"game_cameras")
	top_level = true
	zoom = Vector2(ZOOM_LEVELS[current_zoom_idx], ZOOM_LEVELS[current_zoom_idx])
	saved_zoom = zoom
	_update_camera_limits()
	var p := _find_player()
	if p != null:
		global_position = get_clamped_camera_position(p.global_position)


func _process(_delta: float) -> void:
	# Camera always follows the player (clamped to map edges)
	var p := _find_player()
	if p != null:
		global_position = get_clamped_camera_position(p.global_position)


func get_map_rect() -> Rect2:
	if not is_inside_tree():
		return Rect2(-448.0, -448.0, 896.0, 896.0)
	var tree := get_tree()
	if tree != null:
		var ground = tree.get_first_node_in_group(&"ground")
		if ground == null and tree.current_scene != null:
			ground = tree.current_scene.get_node_or_null("Ground")
		if ground != null and ground.has_method("get_map_rect"):
			return ground.get_map_rect()
	return Rect2(-448.0, -448.0, 896.0, 896.0)


func _update_camera_limits() -> void:
	var map_rect := get_map_rect()
	limit_left = int(floorf(map_rect.position.x))
	limit_top = int(floorf(map_rect.position.y))
	limit_right = int(ceilf(map_rect.end.x))
	limit_bottom = int(ceilf(map_rect.end.y))


func get_clamped_camera_position(target_pos: Vector2) -> Vector2:
	var map_rect := get_map_rect()
	var vp_size := Vector2(1920, 1080)
	if is_inside_tree():
		var vp_rect := get_viewport_rect()
		if vp_rect.size.x > 0 and vp_rect.size.y > 0:
			vp_size = vp_rect.size

	var zx := maxf(zoom.x, 0.001)
	var zy := maxf(zoom.y, 0.001)
	var half_w := (vp_size.x / zx) * 0.5
	var half_h := (vp_size.y / zy) * 0.5

	var cam_x: float
	if half_w * 2.0 >= map_rect.size.x:
		cam_x = map_rect.get_center().x
	else:
		cam_x = clampf(target_pos.x, map_rect.position.x + half_w, map_rect.end.x - half_w)

	var cam_y: float
	if half_h * 2.0 >= map_rect.size.y:
		cam_y = map_rect.get_center().y
	else:
		cam_y = clampf(target_pos.y, map_rect.position.y + half_h, map_rect.end.y - half_h)

	return Vector2(cam_x, cam_y)


func _find_player() -> Fighter:
	var parent_fighter := get_parent() as Fighter
	if parent_fighter != null and is_instance_valid(parent_fighter):
		return parent_fighter
	if is_inside_tree() and get_tree() != null:
		var scene := get_tree().current_scene
		if scene != null:
			var p = scene.get_node_or_null("Player") as Fighter
			if p != null and is_instance_valid(p):
				return p
		for node in get_tree().get_nodes_in_group(&"fighters"):
			var f := node as Fighter
			if f != null and is_instance_valid(f) and f.team == &"player":
				return f
	return null


func _zoom_in() -> void:
	if current_zoom_idx < ZOOM_LEVELS.size() - 1:
		current_zoom_idx += 1
		zoom = Vector2(ZOOM_LEVELS[current_zoom_idx], ZOOM_LEVELS[current_zoom_idx])
		_update_camera_limits()
		if not is_free_mode:
			var p := _find_player()
			if p != null:
				global_position = get_clamped_camera_position(p.global_position)
		else:
			global_position = get_clamped_camera_position(global_position)
		print("Camera zoom in: ", zoom.x, "x")


func _zoom_out() -> void:
	if current_zoom_idx > 0:
		current_zoom_idx -= 1
		zoom = Vector2(ZOOM_LEVELS[current_zoom_idx], ZOOM_LEVELS[current_zoom_idx])
		_update_camera_limits()
		if not is_free_mode:
			var p := _find_player()
			if p != null:
				global_position = get_clamped_camera_position(p.global_position)
		else:
			global_position = get_clamped_camera_position(global_position)
		print("Camera zoom out: ", zoom.x, "x")


func _toggle_free_camera() -> void:
	is_free_mode = not is_free_mode
	if not is_free_mode:
		var p := _find_player()
		if p != null:
			global_position = get_clamped_camera_position(p.global_position)
		print("Camera: Following player (clamped to map edges)")
	else:
		print("Camera: Stopped following player (camera frozen at ", global_position, ")")


var _prev_tab := false
func _tab_just_pressed() -> bool:
	var tab_down := Input.is_physical_key_pressed(KEY_TAB)
	var res := tab_down and not _prev_tab
	_prev_tab = tab_down
	return res


func _key_handled_elsewhere() -> bool:
	return false


# Public API
func is_following() -> bool:
	return true
