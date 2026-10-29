class_name MeleeHitEffect
extends Node2D

const BloomConfig = preload("res://data/bloom_config.gd")

const HIT_TEX_PRIMARY := "res://assets/moves/hit_1.png"
const HIT_TEX_FALLBACK := "res://assets/hit_1.png"

# Enhanced impact appearance: enlarged size & longer duration to be clearly visible (18 frames = ~0.30s)
const TOTAL_FRAMES := 18

var sprite: Sprite2D
var frame_counter: int = 0
var base_alpha: float = 0.95
var base_gray: float = 0.90


func _init() -> void:
	z_index = 30 # Render on top of fighters and HUD world items

	sprite = Sprite2D.new()
	var tex_path := HIT_TEX_PRIMARY if ResourceLoader.exists(HIT_TEX_PRIMARY) else HIT_TEX_FALLBACK
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Enlarged initial scale for high visibility on mobile screens
	sprite.scale = Vector2(2.5, 2.5)

	# Random rotation for uniqueness
	sprite.rotation = randf_range(0.0, TAU)

	# Opaque with random transparency
	base_alpha = randf_range(0.85, 1.0)

	# Random tint within white to gray spectrum
	base_gray = randf_range(0.75, 1.0)
	sprite.modulate = Color(base_gray, base_gray, base_gray, base_alpha)

	# Apply 2D bloom effect if enabled in data/bloom_config.gd (Tackle has bloom)
	BloomConfig.apply_bloom_if_enabled(sprite, "tackle", 2.2, 3.5, Color(1.0, 1.0, 0.95, 1.0))

	add_child(sprite)


func _physics_process(_delta: float) -> void:
	frame_counter += 1

	# Impact pop, sustained hit flash, then stepped arcade decay
	if frame_counter <= 4:
		sprite.scale = Vector2(3.0, 3.0)
		sprite.modulate = Color(base_gray, base_gray, base_gray, base_alpha)
	elif frame_counter <= 11:
		sprite.scale = Vector2(2.5, 2.5)
		sprite.modulate = Color(base_gray, base_gray, base_gray, base_alpha * 0.85)
	elif frame_counter < TOTAL_FRAMES:
		sprite.scale = Vector2(1.8, 1.8)
		sprite.modulate = Color(base_gray, base_gray, base_gray, base_alpha * 0.45)
	else:
		queue_free()
