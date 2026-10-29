@tool
extends Node2D

const TILE_SIZE := 32
# Reduced map size: 28x28 tiles (896x896px)
var half_map := 14
const COLOR_A := Color("5fa84a")
const COLOR_B := Color("57a043")
const COLOR_BORDER := Color("2c4424")
const COLOR_BORDER_OUTER := Color("172613")
const COLOR_BORDER_INNER := Color("7eb85e")


func _ready() -> void:
	add_to_group(&"ground")
	z_index = -100


func get_map_rect() -> Rect2:
	var total_size := float(half_map * 2 * TILE_SIZE)
	return Rect2(-float(half_map * TILE_SIZE), -float(half_map * TILE_SIZE), total_size, total_size)


func get_playable_rect() -> Rect2:
	# Margin from outer wall to keep fighters comfortably on-screen
	return get_map_rect().grow(-24.0)


func _draw() -> void:
	# 1. Ground tiles
	for x in range(-half_map, half_map):
		for y in range(-half_map, half_map):
			var color := COLOR_A if (x + y) % 2 == 0 else COLOR_B
			draw_rect(Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE), color)

	# 2. Outer boundary border: solid prominent arena barrier to clearly mark playable edge
	var total_size := float(half_map * 2 * TILE_SIZE)
	var top_left := Vector2(-half_map * TILE_SIZE, -half_map * TILE_SIZE)
	var boundary_rect := Rect2(top_left, Vector2(total_size, total_size))

	# Heavy dark outer wall frame
	draw_rect(boundary_rect.grow(8.0), COLOR_BORDER_OUTER, false, 18.0)
	# Primary arena boundary line
	draw_rect(boundary_rect, COLOR_BORDER, false, 8.0)
	# Crisp inner edge accent line
	draw_rect(boundary_rect.grow(-4.0), COLOR_BORDER_INNER, false, 2.0)


func set_half_map(val: int) -> void:
	half_map = val
	queue_redraw()
