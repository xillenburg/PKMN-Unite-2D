class_name BeamEffect
extends Node2D

# =============================================================================
# BEAM EFFECT (3-STAGE CONTINUOUS BEAM WITH BLOOM & PERISTALTIC WAVE)
# 
# Stages:
#  Stage 0 (Charge): Quick 0.3s punchy charge-up gathering energy over user
#                    utilizing 5 frames with high-contrast stepped strobe and scale pops.
#  Stage 1 (Beam):   Instantaneously fires 3.0s continuous beam:
#                    - Energy source flare at user (cycling 2 frames).
#                    - 4-body beam pulsating top-to-down like water swallowing down a neck.
#                    - Auto-aim lock-on when move.tracking is enabled.
#                    - Smoke particles: target smoke when striking enemy, scorch smoke otherwise.
#                    - Periodic damage ticks.
#  Stage 2 (Dissipation): Rapid stepped blinking collapse from tip down to user.
# =============================================================================

const BloomConfig = preload("res://data/bloom_config.gd")
const DiagonalSmokeEffect = preload("res://moves/diagonal_smoke_effect.gd")

const DEFAULT_CHARGE_TEX_PATH := "res://assets/moves/solar_beam_charge.png"
const DEFAULT_BEAM_TEX_PATH := "res://assets/moves/solar_beam.png"

const CHARGE_DURATION := 0.3
const BEAM_DURATION := 3.0
const DISSIPATE_DURATION := 0.35
const DAMAGE_TICK_INTERVAL := 0.25 # 4 ticks per second
const SWALLOW_STEP_INTERVAL := 0.08
const SMOKE_INTERVAL := 0.08

enum Stage {
	CHARGE = 0,
	BEAM = 1,
	DISSIPATING = 2
}

# Configuration
var source: Fighter
var move: MoveData
var target: Fighter
var attack_range: float = 220.0
var damage_per_tick: int = 2

# Runtime State
var current_stage: Stage = Stage.CHARGE
var time_in_stage: float = 0.0
var damage_timer: float = 0.0
var smoke_timer: float = 0.0

var current_aim_dir: Vector2 = Vector2.RIGHT
var current_beam_length: float = 160.0

# Textures
var charge_textures: Array[AtlasTexture] = []
var beam_textures: Array[AtlasTexture] = []

# Body frames mapping: frames 2, 3, 4, 5 of beam sheet
const BODY_FRAMES: Array[int] = [2, 3, 4, 5]

# Visual nodes
var charge_sprite: Sprite2D
var energy_sprite: Sprite2D
var body_sprites: Array[Sprite2D] = []


func _init(p_source: Fighter, p_move: MoveData = null) -> void:
	source = p_source
	move = p_move

	var base_power: float = move.power if move != null else 13.0
	var bonus_dmg := source.get_move_bonus_damage(&"attack_3") if (source != null and source.has_method("get_move_bonus_damage")) else 0
	var mult: float = source.get_base_damage() if (source != null and source.has_method("get_base_damage")) else 1.0
	damage_per_tick = maxi(1, int(roundf(float(base_power + float(bonus_dmg)) * mult / 4.0)))

	_update_attack_range()
	if source != null and is_instance_valid(source):
		global_position = source.global_position
		current_aim_dir = source.facing if source.facing != Vector2.ZERO else Vector2.RIGHT
		target = source.find_target(attack_range)

	z_index = 5 # Display above fighters (2) and ground (-100)
	_init_textures()
	_create_visuals()


func _ready() -> void:
	_update_attack_range()
	if source != null and is_instance_valid(source):
		global_position = source.global_position
		current_aim_dir = source.facing if source.facing != Vector2.ZERO else Vector2.RIGHT
		if target == null:
			target = source.find_target(attack_range)


func _exit_tree() -> void:
	if source != null and is_instance_valid(source):
		source.set_flash_color(Color.WHITE, 0.0)


func _get_source_hitbox_radius() -> float:
	if source == null or not is_instance_valid(source):
		return 10.0
	if source.hurtbox != null and source.hurtbox.has_method("get_radius"):
		return source.hurtbox.get_radius() * source.scale.abs().length() / sqrt(2.0)
	if "hurtbox_size" in source:
		var sz: Vector2 = source.get("hurtbox_size")
		return (sz.x + sz.y) * 0.25
	return 10.0


func _update_attack_range() -> void:
	if source != null and is_instance_valid(source) and source.has_method("get_atk3_range"):
		attack_range = source.get_atk3_range()
		return
	if move != null and move.range > 0.0:
		attack_range = move.range
	elif move != null and move.attack_range > 0.0:
		attack_range = move.attack_range
	else:
		attack_range = 220.0


func _init_textures() -> void:
	# 1. Charge textures: 32x160 (5 frames of 32x32)
	var charge_path := DEFAULT_CHARGE_TEX_PATH
	if move != null and move.charge_asset_path != "" and ResourceLoader.exists(move.charge_asset_path):
		charge_path = move.charge_asset_path
	if ResourceLoader.exists(charge_path):
		var raw_charge := load(charge_path) as Texture2D
		if raw_charge != null:
			for i in range(5):
				var atlas := AtlasTexture.new()
				atlas.atlas = raw_charge
				atlas.region = Rect2(0, i * 32, 32, 32)
				charge_textures.append(atlas)

	# 2. Beam textures: 32x208 (6 frames: 5 of 32x32, 1 of 32x48)
	var beam_path := DEFAULT_BEAM_TEX_PATH
	if move != null and move.asset_path != "" and ResourceLoader.exists(move.asset_path):
		beam_path = move.asset_path
	if ResourceLoader.exists(beam_path):
		var raw_beam := load(beam_path) as Texture2D
		if raw_beam != null:
			var rects := [
				Rect2(0, 0, 32, 32),    # Frame 0: Energy source flare A
				Rect2(0, 32, 32, 32),   # Frame 1: Energy source flare B
				Rect2(0, 64, 32, 32),   # Frame 2: Body frame 1 (bulge)
				Rect2(0, 96, 32, 32),   # Frame 3: Body frame 2 (medium)
				Rect2(0, 128, 32, 32),  # Frame 4: Body frame 3 (narrow)
				Rect2(0, 160, 32, 48)   # Frame 5: Body frame 4 (tip, h=48)
			]
			for r in rects:
				var atlas := AtlasTexture.new()
				atlas.atlas = raw_beam
				atlas.region = r
				beam_textures.append(atlas)


func _create_visuals() -> void:
	# Charge Sprite (Stage 0)
	charge_sprite = Sprite2D.new()
	charge_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	charge_sprite.visible = true
	if charge_textures.size() > 0:
		charge_sprite.texture = charge_textures[0]
	BloomConfig.apply_bloom_if_enabled(charge_sprite, "solar_beam")
	add_child(charge_sprite)

	# Energy Origin Sprite (Stage 1)
	energy_sprite = Sprite2D.new()
	energy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	energy_sprite.visible = false
	energy_sprite.offset = Vector2.ZERO
	BloomConfig.apply_bloom_if_enabled(energy_sprite, "solar_beam")
	add_child(energy_sprite)

	# 4 Body Sprites (Stage 1)
	for i in range(4):
		var b := Sprite2D.new()
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.visible = false
		b.offset = Vector2(0, -16 if i < 3 else -24)
		BloomConfig.apply_bloom_if_enabled(b, "solar_beam")
		add_child(b)
		body_sprites.append(b)


func _process(delta: float) -> void:
	if source == null or not is_instance_valid(source) or source.is_defeated:
		queue_free()
		return

	global_position = source.global_position
	time_in_stage += delta

	match current_stage:
		Stage.CHARGE:
			_process_charge(delta)
		Stage.BEAM:
			_process_beam(delta)
		Stage.DISSIPATING:
			_process_dissipating(delta)


func _process_charge(delta: float) -> void:
	if time_in_stage >= CHARGE_DURATION:
		_transition_to_beam()
		return

	charge_sprite.visible = true
	var progress := time_in_stage / CHARGE_DURATION
	var frame_idx := mini(int(progress * 5.0), 4)
	if frame_idx < charge_textures.size():
		charge_sprite.texture = charge_textures[frame_idx]

	# Impact frame aesthetic: high-contrast stepped strobe & scale pops
	var strobe_phase := int(time_in_stage / 0.05) % 2
	var scale_pop: float = 1.0 + (0.35 * (1.0 - progress)) if strobe_phase == 0 else 1.0
	charge_sprite.scale = Vector2(scale_pop, scale_pop)

	# Center charge gathering sunlight over center of source pokemon
	charge_sprite.global_position = source.global_position

	# Aim line during charge
	var desired_dir := source.facing if source.facing != Vector2.ZERO else Vector2.RIGHT
	var should_track: bool = move.tracking if move != null else true
	if should_track:
		if target == null or not is_instance_valid(target) or target.is_defeated or source.distance_to_fighter(target) > attack_range:
			target = source.find_target(attack_range)
		if target != null and is_instance_valid(target):
			var to_target: Vector2 = target.global_position - source.global_position
			if to_target.length_squared() > 1.0:
				desired_dir = to_target.normalized()
	current_aim_dir = desired_dir


func _transition_to_beam() -> void:
	current_stage = Stage.BEAM
	time_in_stage = 0.0
	damage_timer = 0.0
	smoke_timer = 0.0

	charge_sprite.visible = false
	energy_sprite.visible = true
	for b in body_sprites:
		b.visible = true


func _process_beam(delta: float) -> void:
	if time_in_stage >= BEAM_DURATION:
		_transition_to_dissipating()
		return

	# User blinks transparent yellow throughout the move
	var blink_cycle := int(time_in_stage / 0.08) % 2
	if blink_cycle == 0:
		source.set_flash_color(Color(1.0, 0.95, 0.2, 0.45), 0.5)
	else:
		source.set_flash_color(Color(1.0, 1.0, 0.4, 0.2), 0.2)

	# 1. Targeting & Autoaim Lock-on
	var caster_pos := source.global_position
	var should_track: bool = move.tracking if move != null else true

	if not should_track:
		target = null

	if should_track and target != null:
		if not is_instance_valid(target) or target.is_defeated:
			target = null
		elif source.distance_to_fighter(target) > attack_range:
			target = null

	if should_track and target == null and source != null and is_instance_valid(source):
		target = source.find_target(attack_range)

	var desired_dir := source.facing if source.facing != Vector2.ZERO else Vector2.RIGHT
	var desired_dist := attack_range

	if target != null and is_instance_valid(target) and not target.is_defeated:
		var to_target: Vector2 = target.global_position - caster_pos
		var dist := to_target.length()
		if source.distance_to_fighter(target) <= attack_range:
			if dist > 0.001:
				desired_dir = to_target / dist
			desired_dist = clampf(dist, 40.0, attack_range)
			current_aim_dir = desired_dir
			current_beam_length = desired_dist
		else:
			target = null

	if target == null:
		current_aim_dir = current_aim_dir.slerp(desired_dir, clampf(delta * 14.0, 0.0, 1.0)).normalized()
		current_beam_length = lerpf(current_beam_length, desired_dist, clampf(delta * 14.0, 0.0, 1.0))

	var beam_angle := current_aim_dir.angle()
	var sprite_rot := beam_angle - PI / 2.0

	# 2. Energy Flare at Source (starts at surface of the pokemon's hitbox)
	var hb_radius := _get_source_hitbox_radius()
	var energy_origin := caster_pos + current_aim_dir * hb_radius
	energy_sprite.global_position = energy_origin
	energy_sprite.rotation = sprite_rot
	energy_sprite.visible = true

	var energy_frame := int(time_in_stage * 14.0) % 2
	if energy_frame < beam_textures.size():
		energy_sprite.texture = beam_textures[energy_frame]

	# 3. The 4 Beam Bodies (Peristaltic swallow wave)
	var beam_span := maxf(current_beam_length - hb_radius, 24.0)
	var body_step := int(time_in_stage / SWALLOW_STEP_INTERVAL)

	var frame_widths := {
		2: 1.15,
		3: 1.0,
		4: 0.85,
		5: 1.0
	}

	for i in range(4):
		var b := body_sprites[i]
		var t := float(i + 1) / 4.0
		var seg_pos := energy_origin + current_aim_dir * (beam_span * t)
		b.global_position = seg_pos
		b.rotation = sprite_rot
		b.visible = true

		var frame_shift := (i - body_step) % 4
		if frame_shift < 0:
			frame_shift += 4
		var frame_idx: int = BODY_FRAMES[frame_shift]
		if frame_idx < beam_textures.size():
			b.texture = beam_textures[frame_idx]

		var seg_len: float = beam_span / 4.0
		var stretch_y: float = clampf(seg_len / 28.0, 0.75, 2.2)
		var width_mult: float = frame_widths.get(frame_idx, 1.0)
		b.scale = Vector2(width_mult, stretch_y)

	# 4. Smoke emission:
	var is_targeting_enemy := false
	if target != null and is_instance_valid(target) and not target.is_defeated:
		var t_hb_r: float = target.hurtbox.get_radius() if (target.hurtbox != null and target.hurtbox.has_method("get_radius")) else 10.0
		if body_sprites[3].global_position.distance_to(target.global_position) <= 32.0 + t_hb_r or current_beam_length >= (target.global_position - caster_pos).length() - 20.0:
			is_targeting_enemy = true

	smoke_timer += delta
	if smoke_timer >= SMOKE_INTERVAL:
		smoke_timer = 0.0
		var scene_root: Node = get_parent()
		if scene_root != null:
			if is_targeting_enemy and target != null and is_instance_valid(target):
				DiagonalSmokeEffect.spawn_target_smoke(scene_root, target.global_position)
			else:
				var tip_pos: Vector2 = body_sprites[3].global_position
				DiagonalSmokeEffect.spawn_poof(scene_root, tip_pos, 1)

	# 5. Periodic Damage Ticks
	damage_timer += delta
	if damage_timer >= DAMAGE_TICK_INTERVAL:
		damage_timer -= DAMAGE_TICK_INTERVAL
		_deal_damage_tick()


func _deal_damage_tick() -> void:
	if source == null or not is_instance_valid(source):
		return

	var fighters: Array = []
	if is_inside_tree() and get_tree() != null:
		fighters = get_tree().get_nodes_in_group(&"fighters")
	elif source.is_inside_tree() and source.get_tree() != null:
		fighters = source.get_tree().get_nodes_in_group(&"fighters")
	else:
		var p: Node = get_parent()
		if p == null:
			p = source.get_parent()
		if p != null:
			for child in p.get_children():
				if child.is_in_group(&"fighters"):
					fighters.append(child)

	if fighters.is_empty():
		return

	var caster_pos := source.global_position
	var beam_line_vec := current_aim_dir * current_beam_length

	for node in fighters:
		var f := node as Fighter
		if f == null or not is_instance_valid(f) or f == source or f.is_defeated:
			continue
		if f.team == source.team:
			continue

		var f_pos := f.global_position
		var to_f := f_pos - caster_pos
		var proj := to_f.dot(current_aim_dir)
		if proj < 0.0 or proj > current_beam_length + 20.0:
			continue

		var perp_dist := (to_f - current_aim_dir * proj).length()
		var hb_radius: float = 10.0
		if f.hurtbox != null and f.hurtbox.has_method("get_radius"):
			hb_radius = f.hurtbox.get_radius()

		if perp_dist <= 22.0 + hb_radius:
			f.take_damage(damage_per_tick, source, move)
			var scene_root: Node = get_parent()
			if scene_root != null:
				DiagonalSmokeEffect.spawn_target_smoke(scene_root, f.global_position)


func _transition_to_dissipating() -> void:
	current_stage = Stage.DISSIPATING
	time_in_stage = 0.0

	if source != null and is_instance_valid(source):
		source.set_flash_color(Color.WHITE, 0.0)


func _process_dissipating(delta: float) -> void:
	if time_in_stage >= DISSIPATE_DURATION:
		queue_free()
		return

	var progress := time_in_stage / DISSIPATE_DURATION
	var blink_phase := int(time_in_stage / 0.04) % 2
	var is_blink_on := (blink_phase == 0)

	var cutoff_segment := int(progress * 5.0)

	for i in range(4):
		var b := body_sprites[i]
		if (3 - i) < cutoff_segment:
			b.visible = false
		else:
			b.visible = is_blink_on

	if cutoff_segment >= 4:
		energy_sprite.visible = false
	else:
		energy_sprite.visible = is_blink_on
