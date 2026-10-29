@tool
extends Fighter


# Tuning
const WALK_SPEED := 1
const TAP_STEP := 32
const DASH_SPEED := 8
const DASH_DISTANCE := 64
const DASH_COOLDOWN := 90 # 1.5s move at 60 FPS
const DASH_COOLDOWN_SEC := 1.5
const DASH_ANIM_SPEED := 3.0
const LUNGE_ANIM_SPEED := 3.0
const WALK_FPS := 6.0
const IDLE_BOB_SPEED := 0.03
const IDLE_BOB_HEIGHT := 1.0
const WALK_BOB_SPEED := 0.1
const WALK_BOB_HEIGHT := 1.0

# Input
const MOVE_KEYS := {
	Vector2.UP: [KEY_UP, KEY_W],
	Vector2.DOWN: [KEY_DOWN, KEY_S],
	Vector2.LEFT: [KEY_LEFT, KEY_A],
	Vector2.RIGHT: [KEY_RIGHT, KEY_D],
}
const DASH_KEY := KEY_SPACE
const SLOT_KEYS := {
	&"attack_1": KEY_Q,
	&"attack_2": KEY_E,
	&"attack_3": KEY_R,
	&"special": KEY_F,
}

# Character
@export var pokemon: PokemonData:
	set(value):
		pokemon = value
		if is_node_ready():
			_build_sprite()

# State
var sprite: AnimatedSprite2D
var step_left := 0
var dash_left := 0
var dash_dir := Vector2.ZERO
var dash_cooldown := 0
var is_aiming_dash: bool = false
var dash_aim_dir: Vector2 = Vector2.UP
var dash_aim_indicator: DashAimArrow = null
var is_aiming_shot: bool = false
var shot_aim_slot: StringName = &""
var shot_aim_dir: Vector2 = Vector2.RIGHT
var shot_aim_indicator: ShotAimArrow = null
var is_walking := false
var bob_time := 0.0
var prev_held := {}
var prev_dash_key := false
var prev_slot_keys := {}
var slot_cooldowns := {}

# Attack Flash Blinking (Atk 1 = opaque white, Atk 2 = light green, Atk 3 = light purple)
const FLASH_COLOR_ATK1 := Color(1.0, 1.0, 1.0, 1.0)
const FLASH_COLOR_ATK2 := Color(0.40, 1.0, 0.45, 1.0)
const FLASH_COLOR_ATK3 := Color(0.85, 0.55, 1.0, 1.0)
var atk_flash_left: int = 0
var atk_flash_color: Color = Color.WHITE
var color_tint: Color = Color.WHITE
var hue_shift: float = 0.0
var sat_mult: float = 1.0


# Setup
func _init() -> void:
	team = &"player"


func _ready() -> void:
	super._ready()
	if GameState.selected_pokemon != null:
		pokemon = GameState.selected_pokemon
	elif GameState.selected_pokemon_path != "" and ResourceLoader.exists(GameState.selected_pokemon_path):
		pokemon = load(GameState.selected_pokemon_path)

	if current_evolution_stage <= 1 and pokemon != null:
		current_evolution_stage = PokemonData.get_stage_for_level(level)
	_build_sprite(current_evolution_stage)

	if GameState.selected_hue_shift != 0.0 or GameState.selected_sat_mult != 1.0:
		apply_hue_saturation(GameState.selected_hue_shift, GameState.selected_sat_mult)

	if GameState.selected_tint_color != Color.WHITE:
		apply_color_tint(GameState.selected_tint_color)


func apply_color_tint(col: Color) -> void:
	color_tint = col
	if sprite != null and is_instance_valid(sprite):
		sprite.self_modulate = col


func apply_hue_saturation(p_hue_shift: float, p_sat_mult: float) -> void:
	hue_shift = p_hue_shift
	sat_mult = p_sat_mult
	_update_shader_hsv()


func _update_shader_hsv() -> void:
	if visual != null and is_instance_valid(visual) and visual.material is ShaderMaterial:
		var mat := visual.material as ShaderMaterial
		mat.set_shader_parameter("hue_shift", hue_shift)
		mat.set_shader_parameter("sat_mult", sat_mult)


func _build_sprite(stage: int = 0) -> void:
	if stage <= 0:
		stage = current_evolution_stage
	else:
		current_evolution_stage = stage
	if sprite != null:
		sprite.queue_free()
		sprite = null
		visual = null
	if pokemon == null:
		return
	sprite = AnimatedSprite2D.new()
	add_child(sprite)
	var frames := SpriteFrames.new()
	_add_anim(frames, "h", ["h_1", "h_2"], stage)
	_add_anim(frames, "up", ["v_1", "v_2"], stage)
	_add_anim(frames, "down", ["v_3", "v_4"], stage)
	sprite.sprite_frames = frames
	visual = sprite
	setup_flash()
	_update_shader_hsv()
	if color_tint != Color.WHITE:
		sprite.self_modulate = color_tint
	is_walking = false
	_update_sprite()
	sprite.stop()
	sprite.frame = 0


func _add_anim(frames: SpriteFrames, anim_name: String, suffixes: Array, stage: int = 1) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, WALK_FPS)
	frames.set_animation_loop(anim_name, true)
	for suffix in suffixes:
		var path := pokemon.get_sprite_path(stage, suffix) if pokemon.has_method("get_sprite_path") else pokemon.sprite_path(suffix)
		var tex: Texture2D = null
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			tex = load(path)
		if tex == null:
			var fb_path := pokemon.sprite_path(suffix)
			if ResourceLoader.exists(fb_path) or FileAccess.file_exists(fb_path):
				tex = load(fb_path)
		if tex != null:
			frames.add_frame(anim_name, tex)


# Per-frame update
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or sprite == null:
		return

	update_fighter()
	_update_attack_flash()
	_update_melee_range_indicators()

	var cam := get_node_or_null("Camera2D")
	if cam != null and cam.get("is_free_mode") == true:
		_show_idle()
		return

	var held := _read_held()
	var pressed := _newly_pressed(held)
	var space_down: bool = Input.is_action_pressed("dash") or Input.is_physical_key_pressed(DASH_KEY)
	if space_down and not prev_dash_key:
		if dash_cooldown == 0 and dash_left == 0 and not is_lunging():
			start_dash_aim()
	elif not space_down and prev_dash_key:
		if is_aiming_dash:
			release_dash()
	prev_dash_key = space_down
	prev_held = held

	if is_aiming_dash:
		_update_dash_aim()

	if is_aiming_shot:
		_update_shot_aim()

	_handle_moves()

	if dash_cooldown > 0:
		dash_cooldown -= 1

	if is_lunging():
		return

	if dash_left > 0:
		_run_dash()
		resolve_fighter_overlap()
		return

	_handle_walking(held, pressed)
	resolve_fighter_overlap()


# Sprite tilt constants for 8-way directional heading
const TILT_DEGREES := 16.0
const DASH_WHITE_BLUE := Color(0.65, 0.88, 1.0, 1.0)
var current_tilt: float = 0.0
var smoke_timer: int = 0


# Input reading
func _read_held() -> Dictionary:
	var held := {}
	held[Vector2.UP] = Input.is_action_pressed("move_up") or _any_key_down(MOVE_KEYS[Vector2.UP])
	held[Vector2.DOWN] = Input.is_action_pressed("move_down") or _any_key_down(MOVE_KEYS[Vector2.DOWN])
	held[Vector2.LEFT] = Input.is_action_pressed("move_left") or _any_key_down(MOVE_KEYS[Vector2.LEFT])
	held[Vector2.RIGHT] = Input.is_action_pressed("move_right") or _any_key_down(MOVE_KEYS[Vector2.RIGHT])

	# Touch joystick integration (Android / Mobile MOBA controls)
	if is_inside_tree() and get_tree() != null:
		var tc := get_tree().get_first_node_in_group(&"touch_controls")
		if tc != null and tc.has_method("get_joystick_vector"):
			var jvec: Vector2 = tc.get_joystick_vector()
			if jvec.length() > 0.18:
				if absf(jvec.x) > 0.35:
					if jvec.x > 0.0:
						held[Vector2.RIGHT] = true
					else:
						held[Vector2.LEFT] = true
				if absf(jvec.y) > 0.35:
					if jvec.y > 0.0:
						held[Vector2.DOWN] = true
					else:
						held[Vector2.UP] = true
				if not held.has(Vector2.RIGHT) and not held.has(Vector2.LEFT) and not held.has(Vector2.UP) and not held.has(Vector2.DOWN):
					if absf(jvec.x) > absf(jvec.y):
						held[Vector2.RIGHT if jvec.x > 0.0 else Vector2.LEFT] = true
					else:
						held[Vector2.DOWN if jvec.y > 0.0 else Vector2.UP] = true
	return held


func _any_key_down(keys: Array) -> bool:
	for key in keys:
		if Input.is_physical_key_pressed(key):
			return true
	return false


func _newly_pressed(held: Dictionary) -> Vector2:
	for dir in held:
		if held[dir] and not prev_held.get(dir, false):
			return dir
	return Vector2.ZERO


func _held_dir(held: Dictionary) -> Vector2:
	var move_vec := Vector2.ZERO
	if held.get(Vector2.UP, false):
		move_vec.y -= 1.0
	if held.get(Vector2.DOWN, false):
		move_vec.y += 1.0
	if held.get(Vector2.LEFT, false):
		move_vec.x -= 1.0
	if held.get(Vector2.RIGHT, false):
		move_vec.x += 1.0
	return move_vec.normalized() if move_vec != Vector2.ZERO else Vector2.ZERO


# Walking with 8-way directional heading
func _handle_walking(held: Dictionary, pressed: Vector2) -> void:
	var move_vec := Vector2.ZERO
	if held.get(Vector2.UP, false):
		move_vec.y -= 1.0
	if held.get(Vector2.DOWN, false):
		move_vec.y += 1.0
	if held.get(Vector2.LEFT, false):
		move_vec.x -= 1.0
	if held.get(Vector2.RIGHT, false):
		move_vec.x += 1.0

	if pressed != Vector2.ZERO:
		facing = pressed
		step_left = TAP_STEP
		_update_sprite()

	if move_vec != Vector2.ZERO:
		facing = move_vec.normalized()
		_update_sprite()
		position += facing * WALK_SPEED
		step_left = maxi(step_left - WALK_SPEED, 0)
		_show_walking()
		_bob(WALK_BOB_SPEED, WALK_BOB_HEIGHT)
		_maybe_spawn_smoke(false)
		_maybe_play_walk_sound()
	elif step_left > 0:
		position += facing * WALK_SPEED
		step_left = maxi(step_left - WALK_SPEED, 0)
		_show_walking()
		_bob(WALK_BOB_SPEED, WALK_BOB_HEIGHT)
		_maybe_spawn_smoke(false)
		_maybe_play_walk_sound()
	else:
		_show_idle()
		_bob(IDLE_BOB_SPEED, IDLE_BOB_HEIGHT)
		walk_sound_timer = 0

	clamp_to_map_bounds()


var walk_sound_timer: int = 0

func _maybe_play_walk_sound() -> void:
	walk_sound_timer += 1
	if walk_sound_timer >= 18:
		walk_sound_timer = 0
		var is_diag: bool = absf(facing.x) > 0.25 and absf(facing.y) > 0.25
		AudioManager.play_walk(self, is_diag)


# Dash
func _start_dash(dir: Vector2) -> void:
	is_aiming_dash = false
	if dash_aim_indicator != null:
		dash_aim_indicator.visible = false
	facing = dir.normalized() if dir != Vector2.ZERO else facing
	dash_dir = facing
	dash_left = DASH_DISTANCE
	step_left = 0
	_update_sprite()
	sprite.speed_scale = DASH_ANIM_SPEED
	sprite.play()
	sprite.position = Vector2.ZERO
	is_walking = false
	AudioManager.play_dash(self)
	# Haptic feedback: vibrate when dashed
	HapticManager.play_dash()
	_run_dash()


func start_dash_aim() -> void:
	if dash_cooldown > 0 or dash_left > 0 or is_lunging():
		return
	is_aiming_dash = true
	var held := _read_held()
	var held_d := _held_dir(held)
	dash_aim_dir = held_d if held_d != Vector2.ZERO else facing
	if dash_aim_indicator == null:
		dash_aim_indicator = DashAimArrow.new()
		add_child(dash_aim_indicator)
	dash_aim_indicator.visible = true
	dash_aim_indicator.update_animation(dash_aim_dir)


func _update_dash_aim() -> void:
	if not is_aiming_dash:
		return
	var held := _read_held()
	var held_d := _held_dir(held)
	if held_d != Vector2.ZERO:
		dash_aim_dir = held_d
		facing = dash_aim_dir
		_update_sprite()
	if dash_aim_indicator != null:
		dash_aim_indicator.visible = true
		dash_aim_indicator.update_animation(dash_aim_dir)


func release_dash() -> void:
	if not is_aiming_dash:
		return
	is_aiming_dash = false
	if dash_aim_indicator != null:
		dash_aim_indicator.visible = false
	if dash_cooldown == 0 and dash_left == 0 and not is_lunging():
		_start_dash(dash_aim_dir)


func cancel_dash_aim() -> void:
	is_aiming_dash = false
	if dash_aim_indicator != null:
		dash_aim_indicator.visible = false


func update_dash_aim_dir(dir: Vector2) -> void:
	if not is_aiming_dash or dir == Vector2.ZERO:
		return
	dash_aim_dir = dir
	facing = dir
	_update_sprite()
	if dash_aim_indicator != null:
		dash_aim_indicator.update_animation(dash_aim_dir)


# =============================================================================
# SHOT AIMING (Hold to aim with arrow & streak, release to fire)
# =============================================================================
func is_shot_slot(slot: StringName) -> bool:
	if pokemon == null:
		return false
	var m := pokemon.get_move(slot)
	return m != null and m.is_shot()


func start_shot_aim(slot: StringName) -> void:
	if dash_left > 0 or is_lunging() or slot_cooldowns.get(slot, 0) > 0 or not is_slot_unlocked(slot):
		return
	var move := pokemon.get_move(slot) if pokemon != null else null
	if move == null or not move.is_shot():
		return

	is_aiming_shot = true
	shot_aim_slot = slot
	var held := _read_held()
	var held_d := _held_dir(held)
	shot_aim_dir = held_d if held_d != Vector2.ZERO else (facing if facing != Vector2.ZERO else Vector2.RIGHT)
	facing = shot_aim_dir
	_update_sprite()

	if shot_aim_indicator == null:
		shot_aim_indicator = ShotAimArrow.new()
		add_child(shot_aim_indicator)

	var r: float = move.get_effective_range()
	shot_aim_indicator.set_aim_range(r)
	shot_aim_indicator.visible = true
	shot_aim_indicator.update_animation(shot_aim_dir)


func _update_shot_aim() -> void:
	if not is_aiming_shot:
		return
	var held := _read_held()
	var held_d := _held_dir(held)
	if held_d != Vector2.ZERO:
		shot_aim_dir = held_d
		facing = shot_aim_dir
		_update_sprite()
	if shot_aim_indicator != null:
		shot_aim_indicator.visible = true
		shot_aim_indicator.update_animation(shot_aim_dir)


func update_shot_aim_dir(dir: Vector2) -> void:
	if not is_aiming_shot or dir == Vector2.ZERO:
		return
	shot_aim_dir = dir
	facing = dir
	_update_sprite()
	if shot_aim_indicator != null:
		shot_aim_indicator.update_animation(shot_aim_dir)


func release_shot(slot: StringName = &"") -> void:
	if not is_aiming_shot:
		return
	var target_slot := slot if slot != &"" else shot_aim_slot
	if target_slot != shot_aim_slot:
		return
	is_aiming_shot = false
	shot_aim_slot = &""
	if shot_aim_indicator != null:
		shot_aim_indicator.visible = false

	facing = shot_aim_dir
	_update_sprite()
	_use_slot(target_slot)


func cancel_shot_aim() -> void:
	is_aiming_shot = false
	shot_aim_slot = &""
	if shot_aim_indicator != null:
		shot_aim_indicator.visible = false


func _start_attack_flash(col: Color, duration_frames: int = 14) -> void:
	atk_flash_color = col
	atk_flash_left = duration_frames
	set_flash_color(atk_flash_color, 1.0)


func _update_attack_flash() -> void:
	if atk_flash_left > 0:
		atk_flash_left -= 1
		# Rapid blink every 2 frames
		var is_lit: bool = (atk_flash_left / 2) % 2 == 0
		if is_lit:
			set_flash_color(atk_flash_color, 1.0)
		else:
			set_flash_color(Color.WHITE, 0.0)
		if atk_flash_left == 0 and dash_left <= 0:
			set_flash_color(Color.WHITE, 0.0)


func _run_dash() -> void:
	var move := mini(DASH_SPEED, dash_left)
	position += dash_dir * move
	dash_left -= move

	# Blinking opaque white-blue tint when dashing (rapid arcade blink every 2 frames)
	var blink_phase: bool = (dash_left / mini(DASH_SPEED, 6)) % 2 == 0
	set_flash_color(DASH_WHITE_BLUE, 0.88 if blink_phase else 0.0)

	# Smoke trail on dash (uses smoke_2.png)
	_maybe_spawn_smoke(true)
	clamp_to_map_bounds()

	if dash_left <= 0:
		sprite.speed_scale = 1.0
		dash_cooldown = DASH_COOLDOWN
		set_flash_color(Color.WHITE, 0.0)


# Moves
func _handle_moves() -> void:
	for slot in slot_cooldowns:
		slot_cooldowns[slot] = maxi(slot_cooldowns[slot] - 1, 0)

	for slot in [&"attack_1", &"attack_2", &"attack_3", &"special"]:
		var action_name: String = str(slot)
		var is_shot := is_shot_slot(slot)
		var key_down := false
		if Input.is_action_pressed(action_name):
			key_down = true
		elif SLOT_KEYS.has(slot):
			key_down = Input.is_physical_key_pressed(SLOT_KEYS[slot])

		var prev_down: bool = prev_slot_keys.get(slot, false)
		var pressed := key_down and not prev_down
		var released := not key_down and prev_down
		prev_slot_keys[slot] = key_down

		if is_shot:
			if pressed and dash_left == 0 and not is_lunging() and slot_cooldowns.get(slot, 0) == 0 and is_slot_unlocked(slot):
				start_shot_aim(slot)
			elif released and is_aiming_shot and shot_aim_slot == slot:
				release_shot(slot)
		else:
			if pressed and dash_left == 0 and not is_lunging():
				_use_slot(slot)


func _use_slot(slot: StringName) -> void:
	var move := pokemon.get_move(slot) if pokemon != null else null
	if move == null or slot_cooldowns.get(slot, 0) > 0:
		return

	# Move Unlock Check
	if not is_slot_unlocked(slot):
		print(name, " ", slot, " is locked! Unlocks at Lv. ", get_slot_unlock_level(slot))
		return

	# If direction keys or joystick are held, align facing to 8-way direction for the attack (e.g. Tackle)
	var held := _read_held()
	var held_d := _held_dir(held)
	if held_d != Vector2.ZERO:
		facing = held_d
		_update_sprite()

	# Blinks on attack initiation removed per specification (blinks occur only on damage impact/taking hits)

	if slot == &"special":
		# Universal 60-second move (no unite for now)
		print(name, " used universal Unite move placeholder - 60s cooldown started")
		AudioManager.play_unite_button()
		slot_cooldowns[slot] = 3600
		return

	if move.execute(self):
		slot_cooldowns[slot] = move.cooldown_frames
	else:
		if slot == &"attack_1" or (move != null and move.is_melee()):
			AudioManager.play_invalid_range(self)


# Lunge hooks (Supports full 8-way directional tackle lunge)
func _on_lunge_started(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		facing = direction.normalized()
	_update_sprite()
	if sprite != null:
		sprite.speed_scale = LUNGE_ANIM_SPEED
		sprite.position = Vector2.ZERO
		sprite.play()
	is_walking = true


func _on_lunge_ended() -> void:
	if sprite != null:
		sprite.speed_scale = 1.0
	step_left = 0
	_update_sprite()
	_show_idle()


func _on_hitbox_landed(victim: Fighter) -> void:
	super._on_hitbox_landed(victim)
	# Melee attack player blink triggers ONLY when it successfully hits a target
	_start_attack_flash(FLASH_COLOR_ATK1, 14)
	HapticManager.play_tackle_hit()


func _maybe_spawn_smoke(is_dash: bool) -> void:
	var check_dir: Vector2 = dash_dir if is_dash else facing
	if not is_dash:
		# Walking smoke: ONLY for non-4 main cardinal directions (NE, NW, SE, SW)
		if absf(check_dir.x) <= 0.25 or absf(check_dir.y) <= 0.25:
			return

	smoke_timer += 1
	var interval := 3 if is_dash else 6
	if smoke_timer >= interval:
		smoke_timer = 0
		var SmokeScript = load("res://moves/diagonal_smoke_effect.gd")
		if SmokeScript == null:
			return
		# smoke_1 for non-cardinal walking (scaled by evolution stage), smoke_2 for dash
		var smoke = SmokeScript.new(is_dash, current_evolution_stage)
		var scene_root: Node = get_tree().current_scene if (is_inside_tree() and get_tree() != null and get_tree().current_scene != null) else get_parent()
		if scene_root == null:
			scene_root = self
		scene_root.add_child(smoke)
		if is_dash:
			# Spawn 22px behind player for dash trail
			var spawn_offset := -check_dir.normalized() * 22.0 + Vector2(randf_range(-4, 4), randf_range(-4, 4))
			smoke.global_position = global_position + spawn_offset
			smoke.drift_dir = -check_dir.normalized() * 0.5
		else:
			# smoke_1 generates at the center of the player
			smoke.global_position = global_position + Vector2(randf_range(-2, 2), randf_range(-2, 2))
			smoke.drift_dir = -check_dir.normalized() * 0.3


func _maybe_spawn_diagonal_smoke(is_dash: bool) -> void:
	_maybe_spawn_smoke(is_dash)


# Sprite with 8-way directional tilts on bulb_v_1 to bulb_v_4
func _update_sprite() -> void:
	if sprite == null:
		return

	var vx := facing.x
	var vy := facing.y

	if absf(vy) > 0.001:
		# Heading has vertical component -> uses vertical sprites bulb_v_1 to v_4
		if vy < 0.0:
			# Heading UP: bulb_v_1, bulb_v_2
			sprite.animation = "up"
			sprite.flip_h = false
			if vx > 0.2:
				current_tilt = TILT_DEGREES    # UP-RIGHT (+16 deg)
			elif vx < -0.2:
				current_tilt = -TILT_DEGREES   # UP-LEFT (-16 deg)
			else:
				current_tilt = 0.0             # Pure UP
		else:
			# Heading DOWN: bulb_v_3, bulb_v_4
			sprite.animation = "down"
			sprite.flip_h = false
			if vx > 0.2:
				current_tilt = -TILT_DEGREES   # DOWN-RIGHT (-16 deg)
			elif vx < -0.2:
				current_tilt = TILT_DEGREES    # DOWN-LEFT (+16 deg)
			else:
				current_tilt = 0.0             # Pure DOWN
	else:
		# Pure horizontal heading -> uses horizontal sprites bulb_h_1, bulb_h_2
		sprite.animation = "h"
		sprite.flip_h = (vx < 0.0) if pokemon.h_faces_right else (vx > 0.0)
		current_tilt = 0.0

	sprite.rotation_degrees = current_tilt


func _show_walking() -> void:
	if not is_walking or not sprite.is_playing():
		is_walking = true
		sprite.play()


func _show_idle() -> void:
	if is_walking or sprite.is_playing() or sprite.frame != 0:
		is_walking = false
		_update_sprite()
		sprite.stop()
		sprite.frame = 0
		sprite.rotation_degrees = 0.0


func _bob(speed: float, height: float) -> void:
	bob_time += speed
	sprite.position.y = -roundf(absf(sin(bob_time)) * height)


# Range indicators:
# - Melee valid range = White
func _update_melee_range_indicators() -> void:
	var melee_r := get_melee_range()

	for node in get_tree().get_nodes_in_group(&"fighters"):
		var other := node as Fighter
		if other == null or other == self or not is_instance_valid(other):
			continue
		if other.team != team:
			var dist := distance_to_fighter(other)
			if dist <= melee_r:
				# Decreased visibility outline for entity in valid melee range
				other.set_outline(true, Color(1.0, 1.0, 1.0, 0.40), false)
			else:
				other.set_outline(false)
		else:
			other.set_outline(false)


func _exit_tree() -> void:
	for node in get_tree().get_nodes_in_group(&"fighters"):
		var other := node as Fighter
		if other != null and other != self and is_instance_valid(other):
			other.set_outline(false)


# =============================================================================
# SUB-CLASS: DashAimArrow
# Visual GBA-themed aiming arrows & direction streak for hold-to-aim Dash
# Spawns main arrow and trailing arrow that becomes more transparent near endpoint
# =============================================================================
class DashAimArrow extends Node2D:
	const ARROW_TEX_PATH := "res://assets/ui/arrow.png"
	var sprite_main: Sprite2D
	var sprite_trailing: Sprite2D
	var sprite: Sprite2D # Compatibility alias for tests referencing .sprite
	var frame_count: int = 0
	var current_aim_dir: Vector2 = Vector2.UP
	const CYCLE_FRAMES := 38 # Slower, well-paced outward glide
	const STEP_COUNT := 16   # Smoother 16 retro-quantized steps (not jumpy, not buttery)

	func _init() -> void:
		z_index = 20 # Render above fighters and ground

		# 1. Main leading arrow
		sprite_main = Sprite2D.new()
		if ResourceLoader.exists(ARROW_TEX_PATH):
			sprite_main.texture = load(ARROW_TEX_PATH)
		sprite_main.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite_main.scale = Vector2(1.7, 1.7)
		sprite_main.z_index = 2
		add_child(sprite_main)
		sprite = sprite_main

		# 2. Trailing arrow that comes in behind the main arrow
		sprite_trailing = Sprite2D.new()
		if ResourceLoader.exists(ARROW_TEX_PATH):
			sprite_trailing.texture = load(ARROW_TEX_PATH)
		sprite_trailing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite_trailing.scale = Vector2(1.7, 1.7)
		sprite_trailing.z_index = 1
		add_child(sprite_trailing)

	func update_animation(aim_dir: Vector2) -> void:
		frame_count += 1
		current_aim_dir = aim_dir
		queue_redraw()

		var rot := Vector2.UP.angle_to(aim_dir)
		sprite_main.rotation = rot
		sprite_trailing.rotation = rot

		# Progress calculations: trailing arrow follows half a cycle behind
		var prog_main: float = float(frame_count % CYCLE_FRAMES) / float(CYCLE_FRAMES)
		var prog_trail: float = fmod(prog_main + 0.5, 1.0)

		# 16-step quantization
		var step_main := float(int(prog_main * float(STEP_COUNT))) / float(STEP_COUNT)
		var step_trail := float(int(prog_trail * float(STEP_COUNT))) / float(STEP_COUNT)

		# Positions along dash streak
		sprite_main.position = aim_dir * lerpf(18.0, 72.0, step_main)
		sprite_trailing.position = aim_dir * lerpf(18.0, 72.0, step_trail)

		# Transparency rule: "the more the arrow reaches the endpoint the more transparent it becomes"
		# Near origin (0.0): alpha is 0.90 (opaque). Near endpoint (1.0): alpha fades to 0.08
		var alpha_main: float = clampf((1.0 - step_main) * 0.92, 0.08, 0.92)
		var alpha_trail: float = clampf((1.0 - step_trail) * 0.92, 0.08, 0.92)

		# Rapid GBA arcade blinking tint
		var is_tint_frame: bool = (frame_count / 2) % 2 == 0
		if is_tint_frame:
			sprite_main.modulate = Color(0.45, 0.75, 1.0, alpha_main * 0.90)
			sprite_trailing.modulate = Color(0.45, 0.75, 1.0, alpha_trail * 0.90)
		else:
			sprite_main.modulate = Color(1.0, 1.0, 1.0, alpha_main)
			sprite_trailing.modulate = Color(1.0, 1.0, 1.0, alpha_trail)

	func _draw() -> void:
		# Uniform-width dash highlight beam in darker blue with decreased visibility
		# Slightly lowered pixel density (36 segments), fade strictly on both ends (NOT on sides)
		var dir := current_aim_dir.normalized()
		var perp := Vector2(-dir.y, dir.x)
		var half_w := 12.0 # Retains total beam width of 24.0px
		var streak_start := dir * 10.0
		var streak_end := dir * 76.0
		var segments := 36 # Slightly lowered pixel density
		var streak_color := Color(0.12, 0.35, 0.82) # Darker blue

		for i in range(segments):
			var t0 := float(i) / float(segments)
			var t1 := float(i + 1) / float(segments)
			var p0 := streak_start.lerp(streak_end, t0)
			var p1 := streak_start.lerp(streak_end, t1)
			var mid_t := (t0 + t1) * 0.5

			# Smooth fade strictly on both longitudinal ends:
			# Fades in smoothly at player end (0.0 to 0.20), solid in the body, fades out at tip (0.80 to 1.0)
			var end_fade: float
			if mid_t < 0.20:
				end_fade = smoothstep(0.0, 0.20, mid_t)
			elif mid_t > 0.80:
				end_fade = smoothstep(1.0, 0.80, mid_t)
			else:
				end_fade = 1.0

			# Decreased visibility (softer, darker presence)
			var seg_col := Color(streak_color.r, streak_color.g, streak_color.b, end_fade * 0.45)

			# Quad across the full beam width: uniform color across width (ZERO fade on the sides)
			var quad := PackedVector2Array([
				p0 - perp * half_w,
				p0 + perp * half_w,
				p1 + perp * half_w,
				p1 - perp * half_w
			])
			draw_colored_polygon(quad, seg_col)

			# Crisp lateral edge lines for razor-sharp side boundaries
			draw_line(p0 - perp * half_w, p1 - perp * half_w, Color(streak_color.r, streak_color.g, streak_color.b, end_fade * 0.55), 1.0)
			draw_line(p0 + perp * half_w, p1 + perp * half_w, Color(streak_color.r, streak_color.g, streak_color.b, end_fade * 0.55), 1.0)


# =============================================================================
# SUB-CLASS: ShotAimArrow
# Visual GBA-themed aiming arrow & direction streak for hold-to-aim Shot moves
# Uses the exact same arrow sprite as Dash (res://assets/ui/arrow.png), but:
# - arrow sprite scale is smaller (scale 1.0 vs 1.7)
# - highlight beam width is narrower (half_w 6.0 vs 12.0)
# =============================================================================
class ShotAimArrow extends Node2D:
	const ARROW_TEX_PATH := "res://assets/ui/arrow.png"
	var sprite_main: Sprite2D
	var sprite_trailing: Sprite2D
	var sprite: Sprite2D # Compatibility alias
	var frame_count: int = 0
	var current_aim_dir: Vector2 = Vector2.RIGHT
	var aim_range: float = 120.0
	var beam_half_width: float = 6.0 # Narrower beam width than Dash (half_w 6.0 vs 12.0)
	const CYCLE_FRAMES := 38
	const STEP_COUNT := 16

	func _init() -> void:
		z_index = 20 # Render above fighters and ground

		# 1. Main leading arrow (smaller scale: 1.0x unscaled retro size vs Dash's 1.7x)
		sprite_main = Sprite2D.new()
		if ResourceLoader.exists(ARROW_TEX_PATH):
			sprite_main.texture = load(ARROW_TEX_PATH)
		sprite_main.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite_main.scale = Vector2(1.0, 1.0)
		sprite_main.z_index = 2
		add_child(sprite_main)
		sprite = sprite_main

		# 2. Trailing arrow (smaller scale: 1.0x vs Dash's 1.7x)
		sprite_trailing = Sprite2D.new()
		if ResourceLoader.exists(ARROW_TEX_PATH):
			sprite_trailing.texture = load(ARROW_TEX_PATH)
		sprite_trailing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite_trailing.scale = Vector2(1.0, 1.0)
		sprite_trailing.z_index = 1
		add_child(sprite_trailing)

	func set_aim_range(r: float) -> void:
		if r > 0.0:
			aim_range = clampf(r, 60.0, 300.0)

	func update_animation(aim_dir: Vector2) -> void:
		frame_count += 1
		current_aim_dir = aim_dir if aim_dir != Vector2.ZERO else Vector2.RIGHT
		queue_redraw()

		var rot := Vector2.UP.angle_to(current_aim_dir)
		sprite_main.rotation = rot
		sprite_trailing.rotation = rot

		# Progress calculations: trailing arrow follows half a cycle behind
		var prog_main: float = float(frame_count % CYCLE_FRAMES) / float(CYCLE_FRAMES)
		var prog_trail: float = fmod(prog_main + 0.5, 1.0)

		# 16-step retro quantization
		var step_main := float(int(prog_main * float(STEP_COUNT))) / float(STEP_COUNT)
		var step_trail := float(int(prog_trail * float(STEP_COUNT))) / float(STEP_COUNT)

		var max_dist := aim_range - 10.0
		sprite_main.position = current_aim_dir * lerpf(16.0, max_dist, step_main)
		sprite_trailing.position = current_aim_dir * lerpf(16.0, max_dist, step_trail)

		# Fade transparency as it reaches endpoint
		var alpha_main: float = clampf((1.0 - step_main) * 0.92, 0.08, 0.92)
		var alpha_trail: float = clampf((1.0 - step_trail) * 0.92, 0.08, 0.92)

		# Rapid GBA arcade blinking tint
		var is_tint_frame: bool = (frame_count / 2) % 2 == 0
		if is_tint_frame:
			sprite_main.modulate = Color(0.45, 0.75, 1.0, alpha_main * 0.90)
			sprite_trailing.modulate = Color(0.45, 0.75, 1.0, alpha_trail * 0.90)
		else:
			sprite_main.modulate = Color(1.0, 1.0, 1.0, alpha_main)
			sprite_trailing.modulate = Color(1.0, 1.0, 1.0, alpha_trail)

	func _draw() -> void:
		var dir := current_aim_dir.normalized()
		var perp := Vector2(-dir.y, dir.x)
		var half_w := beam_half_width # 6.0px (half the width of Dash's 12.0px)
		var streak_start := dir * 10.0
		var streak_end := dir * aim_range
		var segments := 36
		var streak_color := Color(0.12, 0.35, 0.82) # Darker blue

		for i in range(segments):
			var t0 := float(i) / float(segments)
			var t1 := float(i + 1) / float(segments)
			var p0 := streak_start.lerp(streak_end, t0)
			var p1 := streak_start.lerp(streak_end, t1)
			var mid_t := (t0 + t1) * 0.5

			# Smooth fade strictly on both longitudinal ends
			var end_fade: float
			if mid_t < 0.20:
				end_fade = smoothstep(0.0, 0.20, mid_t)
			elif mid_t > 0.80:
				end_fade = smoothstep(1.0, 0.80, mid_t)
			else:
				end_fade = 1.0

			var seg_col := Color(streak_color.r, streak_color.g, streak_color.b, end_fade * 0.45)

			var quad := PackedVector2Array([
				p0 - perp * half_w,
				p0 + perp * half_w,
				p1 + perp * half_w,
				p1 - perp * half_w
			])
			draw_colored_polygon(quad, seg_col)

			draw_line(p0 - perp * half_w, p1 - perp * half_w, Color(streak_color.r, streak_color.g, streak_color.b, end_fade * 0.55), 1.0)
			draw_line(p0 + perp * half_w, p1 + perp * half_w, Color(streak_color.r, streak_color.g, streak_color.b, end_fade * 0.55), 1.0)
