class_name DiagonalSmokeEffect
extends Node2D

const SMOKE_1_PRIMARY := "res://assets/moves/smoke_1.png"
const SMOKE_1_FALLBACK := "res://assets/smoke_1.png"
const SMOKE_2_PRIMARY := "res://assets/moves/smoke_2.png"
const SMOKE_2_FALLBACK := "res://assets/smoke_2.png"

# Arcade theme stepped keyframe decay (5 frames per step, 4 steps = 20 frames = ~0.33s)
const STEP_FRAMES := 5
const TOTAL_STEPS := 4

var sprite: Sprite2D
var frame_counter: int = 0
var current_step: int = 0
var base_alpha: float = 0.90
var base_gray: float = 0.85
var drift_dir: Vector2 = Vector2.ZERO
var is_dash_smoke: bool = false
var is_target_sizzle: bool = false
var evolution_stage: int = 1
var stage_scale: float = 1.0


# Static helper to spawn a poof of smoke_1 with arcade randomness
static func spawn_poof(parent: Node, spawn_pos: Vector2, evo_stage: int = 1) -> DiagonalSmokeEffect:
	var smoke := DiagonalSmokeEffect.new(false, evo_stage) # Uses smoke_1.png
	if parent != null:
		parent.add_child(smoke)
	smoke.global_position = spawn_pos + Vector2(randf_range(-3, 3), randf_range(-3, 3))
	var ang := randf_range(0.0, TAU)
	smoke.drift_dir = Vector2(cos(ang), sin(ang)) * 0.35
	return smoke


# Static helper to spawn smoke_2 on a target (sizzling thermal plume on Solar Beam target impact)
static func spawn_target_smoke(parent: Node, spawn_pos: Vector2) -> DiagonalSmokeEffect:
	var smoke := DiagonalSmokeEffect.new(true, 1) # Uses smoke_2.png
	smoke.is_target_sizzle = true
	if parent != null:
		parent.add_child(smoke)
	smoke.global_position = spawn_pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))
	# Upward buoyant thermal drift for sizzling steam / plume
	smoke.drift_dir = Vector2(randf_range(-0.50, 0.50), randf_range(-1.35, -0.75))
	smoke._init_sizzle()
	return smoke


func _init_sizzle() -> void:
	if sprite == null:
		return
	# Sizzling hot start: compact puff with searing solar steam tint
	var init_s := randf_range(1.10, 1.35)
	sprite.scale = Vector2(init_s, init_s)
	base_alpha = randf_range(0.85, 0.98)
	sprite.modulate = Color(1.0, 0.96, 0.82, base_alpha)


func _init(use_dash_smoke: bool = false, evo_stage: int = 1) -> void:
	is_dash_smoke = use_dash_smoke
	evolution_stage = evo_stage

	# Scale relative to evolution stage: Stage 1 default, then +0.5x bigger per stage
	if not is_dash_smoke:
		stage_scale = 1.0 + float(maxi(1, evo_stage) - 1) * 0.5
	else:
		stage_scale = 1.0

	# Layer-wise: smoke_1 generated below Pokémon player (z_index 1 < player 2); dash smoke 3 (over player)
	z_index = 3 if is_dash_smoke else 1

	sprite = Sprite2D.new()
	var primary_path := SMOKE_2_PRIMARY if is_dash_smoke else SMOKE_1_PRIMARY
	var fallback_path := SMOKE_2_FALLBACK if is_dash_smoke else SMOKE_1_FALLBACK
	var tex_path := primary_path if ResourceLoader.exists(primary_path) else fallback_path
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Scale: smoke_1 base 1.3x scaled by stage_scale
	var init_scale: float = 1.8 if is_dash_smoke else (1.3 * stage_scale)
	sprite.scale = Vector2(init_scale, init_scale)

	# Random rotation for uniqueness
	sprite.rotation = randf_range(0.0, TAU)

	# Opaque with random transparency
	base_alpha = randf_range(0.80, 0.98)

	# Random tint within white to gray spectrum
	base_gray = randf_range(0.70, 0.98)
	sprite.modulate = Color(base_gray, base_gray, base_gray, base_alpha)

	add_child(sprite)


func _physics_process(_delta: float) -> void:
	frame_counter += 1
	if frame_counter >= STEP_FRAMES:
		frame_counter = 0
		current_step += 1
		if current_step >= TOTAL_STEPS:
			queue_free()
			return
		_apply_arcade_step()

	# Sizzle plumes rise buoyantly; standard smoke drifts subtly
	if is_target_sizzle:
		global_position += drift_dir * 0.95
		drift_dir.y -= 0.03 # Upward buoyant rise
	else:
		global_position += drift_dir * 0.4


func _apply_arcade_step() -> void:
	if sprite == null:
		return

	if is_target_sizzle:
		# Sizzling thermal plume billows outward and upward before evaporating
		match current_step:
			1:
				sprite.scale = Vector2(1.75, 1.75)
				sprite.modulate = Color(0.96, 0.93, 0.85, base_alpha * 0.85)
			2:
				sprite.scale = Vector2(2.15, 2.15)
				sprite.modulate = Color(0.88, 0.88, 0.88, base_alpha * 0.55)
			3:
				sprite.scale = Vector2(2.50, 2.50)
				sprite.modulate = Color(0.80, 0.80, 0.80, base_alpha * 0.20)
		return

	var scale_factor: float = 1.0 if is_dash_smoke else ((1.3 / 1.8) * stage_scale)
	match current_step:
		1:
			sprite.scale = Vector2(1.5, 1.5) * scale_factor
			sprite.modulate = Color(base_gray, base_gray, base_gray, base_alpha * 0.75)
		2:
			sprite.scale = Vector2(1.2, 1.2) * scale_factor
			sprite.modulate = Color(base_gray, base_gray, base_gray, base_alpha * 0.50)
		3:
			sprite.scale = Vector2(0.8, 0.8) * scale_factor
			sprite.modulate = Color(base_gray, base_gray, base_gray, base_alpha * 0.25)
