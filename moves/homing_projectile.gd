class_name HomingProjectile
extends Area2D

const BloomConfig = preload("res://data/bloom_config.gd")
const DiagonalSmokeEffect = preload("res://moves/diagonal_smoke_effect.gd")

# Constants
const DEFAULT_TEX := preload("res://assets/moves/razor_leaf.png")
const LIFETIME := 0.55          # Total lifespan before fully disappearing
const BLINK_START := 0.40      # Rapid blinking before disappearing
const HIT_RADIUS := 14.0

# Trajectory tuning
const PHASE1_DURATION := 0.16   # Initial outward burst time
const PHASE2_DURATION := 0.08   # Apex / slow-spin transition time
const BURST_SPEED_Y := 190.0    # Vertical speed coming out of top/down
const FORWARD_BIAS := 40.0      # Forward drift toward target direction
const HOMING_SPEED := 280.0     # Speed during homing curve
const STEER_RATE := 14.0        # Rate of curving toward target

# Spin tuning (GBA theme)
const SPIN_RAPID_INITIAL := 28.0 # Rapid spin right after coming out
const SPIN_SLOW := 3.0          # Significant slow-down before curve
const SPIN_RAPID_CURVE := 34.0  # Rapid spin during the curve

# Configuration
var is_top: bool = true         # True = comes out top, False = comes out down
var spread_ratio: float = 0.0   # Fan spread ratio (-1.0 to 1.0)
var source: Fighter
var move: MoveData
var target: Fighter
var damage: int = 2

# State
var time_alive: float = 0.0
var hit_done: bool = false
var velocity: Vector2 = Vector2.ZERO
var visual_angle: float = 0.0
var sprite: Sprite2D
var forward: Vector2 = Vector2.RIGHT
var scatter_dir: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Layer-wise: behind the player initially (z_index 1 < player z_index 2, above ground -100)
	z_index = 1

	# Visual setup with data-driven custom asset_path or default leaf texture
	sprite = Sprite2D.new()
	if move != null and move.asset_path != "" and ResourceLoader.exists(move.asset_path):
		var custom_tex := load(move.asset_path) as Texture2D
		sprite.texture = custom_tex if custom_tex != null else DEFAULT_TEX
	else:
		sprite.texture = DEFAULT_TEX
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Apply bloom if configured
	BloomConfig.apply_bloom_if_enabled(sprite, "razor_leaf")
	add_child(sprite)

	collision_layer = 0
	collision_mask = 0

	# Determine initial facing/forward direction from source
	if source != null and is_instance_valid(source):
		if source.facing != Vector2.ZERO:
			forward = source.facing.normalized()
		elif target != null and is_instance_valid(target):
			forward = (target.global_position - source.global_position).normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT

	# Determine scatter direction if no target
	var spread_angle_rad := spread_ratio * 0.45
	scatter_dir = forward.rotated(spread_angle_rad).normalized()

	# Initial burst velocity
	var normal_up := Vector2(-forward.y, forward.x) # Left of forward
	var side_dir := -normal_up if is_top else normal_up
	var spread_lateral := forward * (spread_ratio * 70.0)

	velocity = (side_dir * BURST_SPEED_Y) + (forward * FORWARD_BIAS) + spread_lateral
	visual_angle = velocity.angle()
	sprite.rotation = visual_angle


func _physics_process(delta: float) -> void:
	if hit_done:
		return

	time_alive += delta

	# Check for expiration
	if time_alive >= LIFETIME:
		_disappear()
		return

	# Handle rapid blinking before disappearing
	if time_alive >= BLINK_START:
		var blink_phase := int((time_alive - BLINK_START) / 0.04) % 2
		sprite.visible = (blink_phase == 0)

	# 3-Phase trajectory & spin
	if time_alive < PHASE1_DURATION:
		# Phase 1: Outward burst with rapid spin
		visual_angle += SPIN_RAPID_INITIAL * delta
		velocity = velocity.move_toward(Vector2.ZERO, delta * 300.0)
	elif time_alive < PHASE1_DURATION + PHASE2_DURATION:
		# Phase 2: Apex transition - slow spin
		visual_angle += SPIN_SLOW * delta
		velocity = velocity.move_toward(forward * 40.0, delta * 200.0)
	else:
		# Phase 3: Rapid curving homing toward target
		visual_angle += SPIN_RAPID_CURVE * delta

		var desired_dir := scatter_dir
		if target != null and is_instance_valid(target) and not target.is_defeated:
			var to_target: Vector2 = target.global_position - global_position
			if to_target.length_squared() > 1.0:
				desired_dir = to_target.normalized()
		elif source != null and is_instance_valid(source):
			var retarget_range := move.homing_range if (move != null and move.homing_range > 0.0) else (move.get_effective_range() if move != null else 110.0)
			target = source.find_target(retarget_range)
			if target != null and is_instance_valid(target) and not target.is_defeated:
				var to_target: Vector2 = target.global_position - global_position
				if to_target.length_squared() > 1.0:
					desired_dir = to_target.normalized()

		var current_dir := velocity.normalized() if velocity.length_squared() > 0.1 else forward
		var steered := current_dir.slerp(desired_dir, clampf(STEER_RATE * delta, 0.0, 1.0)).normalized()
		velocity = steered * HOMING_SPEED

	global_position += velocity * delta
	sprite.rotation = visual_angle

	# Check hurtbox collision
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

			if global_position.distance_to(f.global_position) <= HIT_RADIUS + hb_r:
				_land_hit(f)
				return


func _land_hit(victim: Fighter) -> void:
	if hit_done:
		return
	hit_done = true

	victim.take_damage(damage, source, move)

	var scene_root: Node = get_parent()
	if scene_root != null:
		DiagonalSmokeEffect.spawn_poof(scene_root, global_position, 1)

	queue_free()


func _disappear() -> void:
	if hit_done:
		return
	hit_done = true

	var scene_root: Node = get_parent()
	if scene_root != null:
		DiagonalSmokeEffect.spawn_poof(scene_root, global_position, 1)

	queue_free()


func _disappear_with_poof() -> void:
	_disappear()
