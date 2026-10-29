@tool
class_name Fighter
extends Node2D

# Constants
const FLASH_SHADER := preload("res://shaders/flash.gdshader")
const FLASH_FRAMES := 8
const HEADBUTT_TILT_DEGREES := 20.0
const MAX_LEVEL: int = 30

# Move Unlock Thresholds
const UNLOCK_LVL_ATK1: int = 1
const UNLOCK_LVL_ATK2: int = 15
const UNLOCK_LVL_ATK3: int = 25
const UNLOCK_LVL_UNITE: int = 30

signal leveled_up(new_level: int)
signal attack_upgrade_available(pending_points: int)
signal evolved(new_stage: int)

var pending_attack_upgrades: int = 0
var move_bonus_damage: Dictionary = {
	&"attack_1": 0,
	&"attack_2": 0,
	&"attack_3": 0,
}

# Evolution Stage State (Stage 1: Lv 1-19, Stage 2: Lv 20-29, Stage 3: Lv 30, Stage 4: Mega evolution)
var current_evolution_stage: int = 1
var is_evolving: bool = false

# Stats & Tuning
@export var max_hp := 100
@export var hurtbox_size := Vector2(20, 18)
@export var hitbox_radius := 7.0
@export var hitbox_offset := 10.0

# Level & XP system (supports float with 0.5 increments)
var level: int = 1
var xp: float = 0.0

# State
var team: StringName = &"neutral"
var hp := 100
var facing := Vector2.DOWN
var visual: CanvasItem
var flash_left := 0
var outline_visible := false
var outline_color := Color.WHITE
var outline_pulsating := false

# Audio
var sfx_player: AudioStreamPlayer2D
var hit_sfx_player: AudioStreamPlayer2D

# Defeat / Faint animation state (for defeated dummy / fighters)
var is_defeated: bool = false
var defeat_blink_timer: int = 0
const DEFEAT_BLINK_FRAMES := 24 # ~0.4s fast blinking before queue_free

# Combat boxes
var hurtbox: Hurtbox
var hitbox: Hitbox

# Base damage multiplier (amplified by Pokemon data base_damage, items, buffs/debuffs)
var base_damage_multiplier: float = 1.0

func get_base_damage() -> float:
	var mult: float = base_damage_multiplier
	if "pokemon" in self and self.pokemon != null and "base_damage" in self.pokemon:
		mult *= float(self.pokemon.base_damage)
	return mult

# Lunge state
var lunge_target: Fighter
var lunge_move: MoveData
var lunge_origin := Vector2.ZERO
var lunge_dir := Vector2.ZERO
var lunge_returning := false
var lunge_frames_left := 0
var lunge_homing := false
var lunge_forward_target_dist := 0.0
var lunge_hit_landed := false


# Setup
func _enter_tree() -> void:
	hp = max_hp
	add_to_group(&"fighters")


func _ready() -> void:
	z_index = 2 # In front of ground (-100) and emerging projectiles (1)
	if not Engine.is_editor_hint():
		_setup_combat_boxes()
		_setup_audio()


func _setup_combat_boxes() -> void:
	if hurtbox == null:
		hurtbox = Hurtbox.new()
		hurtbox.name = "Hurtbox"
		hurtbox.fighter = self
		hurtbox.size = hurtbox_size
		add_child(hurtbox)
	if hitbox == null:
		hitbox = Hitbox.new()
		hitbox.name = "Hitbox"
		hitbox.source = self
		hitbox.radius = hitbox_radius
		hitbox.hit_landed.connect(_on_hitbox_landed)
		add_child(hitbox)


func _setup_audio() -> void:
	if sfx_player == null:
		sfx_player = AudioStreamPlayer2D.new()
		sfx_player.name = "SFXPlayer"
		sfx_player.bus = AudioManager.BUS_SFX
		sfx_player.max_polyphony = 4
		add_child(sfx_player)
	if hit_sfx_player == null:
		hit_sfx_player = AudioStreamPlayer2D.new()
		hit_sfx_player.name = "HitSFXPlayer"
		hit_sfx_player.bus = AudioManager.BUS_HIT_SFX
		hit_sfx_player.max_polyphony = 4
		add_child(hit_sfx_player)
	if get_node_or_null("MoveSFXPlayer") == null:
		var move_p := AudioStreamPlayer2D.new()
		move_p.name = "MoveSFXPlayer"
		move_p.bus = AudioManager.BUS_SFX
		move_p.max_polyphony = 4
		add_child(move_p)
	if get_node_or_null("WalkSFXPlayer") == null:
		var walk_p := AudioStreamPlayer2D.new()
		walk_p.name = "WalkSFXPlayer"
		walk_p.bus = AudioManager.BUS_SFX
		walk_p.max_polyphony = 4
		add_child(walk_p)
	if get_node_or_null("ProgressionSFXPlayer") == null:
		var prog_p := AudioStreamPlayer2D.new()
		prog_p.name = "ProgressionSFXPlayer"
		prog_p.bus = AudioManager.BUS_SFX
		prog_p.max_polyphony = 4
		add_child(prog_p)


func play_sfx(path: String) -> void:
	if path == "":
		return
	AudioManager.play_sound(path, self)


func setup_flash() -> void:
	if visual == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = FLASH_SHADER
	mat.set_shader_parameter("outline_enabled", outline_visible)
	mat.set_shader_parameter("outline_color", outline_color)
	mat.set_shader_parameter("outline_width", 1.0)
	mat.set_shader_parameter("outline_pulsating", outline_pulsating)
	visual.material = mat


func set_outline(enabled: bool, col: Color = Color.WHITE, pulsating: bool = false) -> void:
	outline_visible = enabled
	outline_color = col
	outline_pulsating = pulsating
	if is_instance_valid(visual):
		var mat := visual.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("outline_enabled", enabled)
			mat.set_shader_parameter("outline_color", col)
			mat.set_shader_parameter("outline_pulsating", pulsating)


# Per-frame update
func update_fighter() -> void:
	if is_defeated:
		_update_defeat_blink()
		return
	_update_flash()
	_update_lunge()
	resolve_fighter_overlap()
	if not is_lunging():
		_reset_headbutt_tilt()
	clamp_to_map_bounds()
	var menu_node := get_node_or_null("/root/DebugMenu")
	if menu_node != null and menu_node.get("show_hitboxes"):
		queue_redraw()


func _update_defeat_blink() -> void:
	if not is_defeated:
		return
	defeat_blink_timer -= 1
	if is_instance_valid(visual):
		# Fast blinking: toggle visibility every 2 frames
		visual.visible = ((defeat_blink_timer / 2) % 2 == 0)

	if defeat_blink_timer <= 0:
		print(name, " defeated permanently. Disappearing from scene.")
		queue_free()


# GBA-style stepped binary flash (alternates white and normal every 2 frames)
func _update_flash() -> void:
	if is_evolving:
		return
	if not is_instance_valid(visual):
		return
	var mat := visual.material as ShaderMaterial
	if mat == null:
		return
	if flash_left == 0:
		return
	flash_left -= 1
	var flash_on: bool = (flash_left % 4) >= 2
	mat.set_shader_parameter("flash_color", Color.WHITE)
	mat.set_shader_parameter("flash", 1.0 if flash_on else 0.0)


func set_flash_amount(amount: float) -> void:
	if not is_instance_valid(visual):
		return
	var mat := visual.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("flash_color", Color.WHITE)
		mat.set_shader_parameter("flash", clampf(amount, 0.0, 1.0))


func set_flash_color(col: Color, amount: float) -> void:
	if not is_instance_valid(visual):
		return
	var mat := visual.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("flash_color", col)
		mat.set_shader_parameter("flash", amount)


# Evolution system:
# Stage 1: Lv 1 - 19
# Stage 2: Lv 20 - 29
# Stage 3: Lv 30
# Stage 4: Mega Evolution (unused for now)
func evolve_to_stage(target_stage: int) -> void:
	if current_evolution_stage == target_stage:
		return
	var old_stage := current_evolution_stage
	current_evolution_stage = target_stage

	_play_evolution_sequence(target_stage)
	evolved.emit(target_stage)
	print(name, " evolved from Stage ", old_stage, " to Stage ", target_stage, "! (", get_display_name(), ")")


var tree_ref: SceneTree = null


func _get_active_tree() -> SceneTree:
	if is_inside_tree() and get_tree() != null:
		return get_tree()
	if tree_ref != null:
		return tree_ref
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return main_loop
	return null


func _play_evolution_sequence(target_stage: int) -> void:
	AudioManager.play_evolution(self)
	if team == &"player":
		HapticManager.play_player_level_up()

	var tree := _get_active_tree()
	if tree == null:
		if has_method("_build_sprite"):
			call("_build_sprite", target_stage)
		return

	is_evolving = true

	# Authentic GBA-Themed Evolution Sequence:
	# 1. Stepped discrete on/off flash blinking with accelerating cadence (crisp GBA hardware frames, no smooth float blur)
	# 2. White silhouette transformation with classic GBA pulse
	# 3. Discrete stepped palette unveiling
	var tween := create_tween() if is_inside_tree() else tree.create_tween()
	var base_vis_scale: Vector2 = (visual as Node2D).scale if (is_instance_valid(visual) and visual is Node2D) else Vector2.ONE

	# Phase 1: Accelerating GBA Flash Blinks (crisp stepped on/off toggles)
	var flash_intervals := [0.12, 0.09, 0.07, 0.05, 0.04]
	for interval in flash_intervals:
		# Flash ON (solid white silhouette)
		tween.tween_callback(func(): set_flash_amount(1.0))
		tween.tween_interval(interval)
		# Flash OFF (normal sprite colors)
		tween.tween_callback(func(): set_flash_amount(0.0))
		tween.tween_interval(interval)

	# Phase 2: Silhouette Transformation & GBA Pulse (solid white)
	tween.tween_callback(func(): set_flash_amount(1.0))
	tween.tween_interval(0.10)

	# Old stage silhouette subtle pulse
	tween.tween_callback(func():
		if is_instance_valid(visual):
			visual.scale = base_vis_scale * 1.10
	)
	tween.tween_interval(0.08)
	tween.tween_callback(func():
		if is_instance_valid(visual):
			visual.scale = base_vis_scale
	)
	tween.tween_interval(0.08)

	# Transform to new evolution stage while still solid white
	tween.tween_callback(func():
		if has_method("_build_sprite"):
			call("_build_sprite", target_stage)
		set_flash_amount(1.0)
	)
	tween.tween_interval(0.04)

	# New stage silhouette expansion pulse
	tween.tween_callback(func():
		if is_instance_valid(visual):
			visual.scale = base_vis_scale * 1.12
	)
	tween.tween_interval(0.10)
	tween.tween_callback(func():
		if is_instance_valid(visual):
			visual.scale = base_vis_scale
	)
	tween.tween_interval(0.16)

	# Phase 3: Stepped GBA Unveiling (discrete palette steps)
	var unveil_steps := [0.75, 0.50, 0.25, 0.0]
	for step_val in unveil_steps:
		tween.tween_callback(func(): set_flash_amount(step_val))
		tween.tween_interval(0.08)

	tween.tween_callback(func():
		is_evolving = false
		set_flash_amount(0.0)
		if is_instance_valid(visual):
			visual.scale = base_vis_scale
	)


# Overlap prevention collision using sprite AABB boxes
func resolve_fighter_overlap() -> void:
	# Melee attacks must ignore colliders
	if is_lunging():
		return

	for node in get_tree().get_nodes_in_group(&"fighters"):
		var other := node as Fighter
		if other == null or other == self or not is_instance_valid(other):
			continue

		# Ignore other fighters that are lunging (melee attacks ignore colliders)
		if other.is_lunging():
			continue

		# AABB overlap calculation between the two sprite collision boxes (accounting for entity scale)
		var half_self := (hurtbox_size * scale.abs()) * 0.5
		var half_other := (other.hurtbox_size * other.scale.abs()) * 0.5
		var delta := global_position - other.global_position
		var overlap_x := (half_self.x + half_other.x) - absf(delta.x)
		var overlap_y := (half_self.y + half_other.y) - absf(delta.y)

		if overlap_x > 0.0 and overlap_y > 0.0:
			# Push along axis of least penetration
			var push_dir := Vector2.ZERO
			var push_amount := 0.0

			if overlap_x < overlap_y:
				push_amount = overlap_x
				push_dir = Vector2.RIGHT if delta.x >= 0.0 else Vector2.LEFT
			else:
				push_amount = overlap_y
				push_dir = Vector2.DOWN if delta.y >= 0.0 else Vector2.UP

			var self_moving: bool = ("is_walking" in self and self.get("is_walking") == true) or (self.get("dash_left") != null and int(self.get("dash_left")) > 0)
			var other_moving: bool = ("is_walking" in other and other.get("is_walking") == true) or (other.get("dash_left") != null and int(other.get("dash_left")) > 0)

			if self_moving and not other_moving:
				global_position = (global_position + push_dir * push_amount).round()
			elif other_moving and not self_moving:
				other.global_position = (other.global_position - push_dir * push_amount).round()
			else:
				var half := push_amount * 0.5
				global_position = (global_position + push_dir * half).round()
				other.global_position = (other.global_position - push_dir * half).round()


# Level & XP logic (Centralized in data/xp_manager.gd)
func get_max_xp() -> int:
	return maxi(XPManager.get_max_xp_for_level(level), 1)


func gain_xp(amount: float) -> void:
	if amount <= 0.0 or level >= MAX_LEVEL:
		return
	var start_level := level
	var old_stage: int = PokemonData.get_stage_for_level(start_level)
	xp += amount
	while xp >= float(get_max_xp()) and level < MAX_LEVEL:
		xp -= float(get_max_xp())
		level += 1
		# Health restore on level up: both player and enemy regain 5 HP
		hp = mini(hp + 5, max_hp)
		AudioManager.play_level_up(self)
		if team == &"player":
			HapticManager.play_player_level_up()
		print(name, " leveled up to Lv. ", level, "! Restored 5 HP (hp: ", hp, "/", max_hp, ")")
		leveled_up.emit(level)
	if level >= MAX_LEVEL:
		xp = 0.0

	# Attack upgrades occur every 5 level values (Lv. 5, 10, 15, 20, 25, 30)
	# Accurately supports massive level jumps (e.g., jumping from Lv. 10 to Lv. 22 earns exactly 2 points for Lv. 15 and 20)
	var points_earned: int = (level / 5) - (start_level / 5)
	if points_earned > 0:
		pending_attack_upgrades += points_earned
		attack_upgrade_available.emit(pending_attack_upgrades)

	# Evolution check: Lv 20 evolves to Stage 2, Lv 30 evolves to Stage 3
	var new_stage: int = PokemonData.get_stage_for_level(level)
	if new_stage > old_stage:
		evolve_to_stage(new_stage)
	elif new_stage < old_stage:
		current_evolution_stage = new_stage
		if has_method("_build_sprite"):
			call("_build_sprite", current_evolution_stage)


# Direct level setter supporting debugger, cheats, and level adjustments
func set_level(new_lvl: int) -> void:
	new_lvl = clampi(new_lvl, 1, MAX_LEVEL)
	if new_lvl == level:
		return

	var old_level := level
	var old_stage: int = PokemonData.get_stage_for_level(old_level)
	level = new_lvl
	xp = 0.0

	# Attack upgrades occur every 5 level values (Lv. 5, 10, 15, 20, 25, 30)
	var old_tier := old_level / 5
	var new_tier := level / 5

	if level > old_level:
		# Health restore on level up: +5 HP per level gained (clamped to max_hp)
		hp = mini(hp + 5 * (level - old_level), max_hp)
		AudioManager.play_level_up(self)
		if team == &"player":
			HapticManager.play_player_level_up()
		if new_tier > old_tier:
			var pts := new_tier - old_tier
			pending_attack_upgrades += pts
	elif level < old_level:
		if new_tier < old_tier:
			var points_lost := old_tier - new_tier
			if pending_attack_upgrades >= points_lost:
				pending_attack_upgrades -= points_lost
			else:
				var overflow := points_lost - pending_attack_upgrades
				pending_attack_upgrades = 0
				# Reduce from move bonus damage if total spent exceeds new tier
				var move_slots: Array[StringName] = [&"attack_3", &"attack_2", &"attack_1"]
				while overflow > 0:
					var reduced := false
					for slot in move_slots:
						if move_bonus_damage.get(slot, 0) > 0:
							move_bonus_damage[slot] -= 1
							overflow -= 1
							reduced = true
							if overflow == 0:
								break
					if not reduced:
						break

	attack_upgrade_available.emit(pending_attack_upgrades)
	leveled_up.emit(level)
	print(name, " level changed from Lv. ", old_level, " to Lv. ", level, " (pending points: ", pending_attack_upgrades, ")")

	# Evolution check: Lv 20 evolves to Stage 2, Lv 30 evolves to Stage 3
	var new_stage: int = PokemonData.get_stage_for_level(level)
	if new_stage > old_stage:
		evolve_to_stage(new_stage)
	elif new_stage < old_stage:
		current_evolution_stage = new_stage
		if has_method("_build_sprite"):
			call("_build_sprite", current_evolution_stage)


func change_level(delta_lvl: int) -> void:
	set_level(level + delta_lvl)


func get_move_bonus_damage(slot: StringName) -> int:
	return move_bonus_damage.get(slot, 0)


func upgrade_attack(slot: StringName) -> bool:
	if pending_attack_upgrades <= 0:
		return false
	if not move_bonus_damage.has(slot):
		return false
	move_bonus_damage[slot] += 1
	pending_attack_upgrades -= 1
	AudioManager.play_atk_level_up(self)
	print(name, " upgraded ", slot, "! Bonus damage: +", move_bonus_damage[slot], ". Remaining points: ", pending_attack_upgrades)
	attack_upgrade_available.emit(pending_attack_upgrades)
	return true


func clamp_to_map_bounds() -> void:
	var play_rect: Rect2
	var ground = null
	if is_inside_tree() and get_tree() != null:
		ground = get_tree().get_first_node_in_group(&"ground")
	if ground != null and ground.has_method("get_playable_rect"):
		play_rect = ground.get_playable_rect()
	elif ground != null and ground.has_method("get_map_rect"):
		play_rect = ground.get_map_rect().grow(-24.0)
	else:
		play_rect = Rect2(-424.0, -424.0, 848.0, 848.0)

	global_position.x = clampf(global_position.x, play_rect.position.x, play_rect.end.x)
	global_position.y = clampf(global_position.y, play_rect.position.y, play_rect.end.y)


func is_slot_unlocked(slot: StringName) -> bool:
	match slot:
		&"attack_1":
			return level >= UNLOCK_LVL_ATK1
		&"attack_2":
			return level >= UNLOCK_LVL_ATK2
		&"attack_3":
			return level >= UNLOCK_LVL_ATK3
		&"special":
			return level >= UNLOCK_LVL_UNITE
	return true


func get_slot_unlock_level(slot: StringName) -> int:
	match slot:
		&"attack_1":
			return UNLOCK_LVL_ATK1
		&"attack_2":
			return UNLOCK_LVL_ATK2
		&"attack_3":
			return UNLOCK_LVL_ATK3
		&"special":
			return UNLOCK_LVL_UNITE
	return 1


func get_slot_for_move(move_obj: MoveData) -> StringName:
	if move_obj == null:
		return &""
	for slot in [&"attack_1", &"attack_2", &"attack_3", &"special"]:
		if get_move_in_slot(slot) == move_obj:
			return slot
	return &""


func get_display_name() -> String:
	if "pokemon" in self and self.get("pokemon") != null:
		var p = self.get("pokemon")
		if p != null and p.has_method("get_stage_name"):
			var st_name: String = p.get_stage_name(current_evolution_stage)
			if st_name != "":
				return st_name.to_upper()
		if p != null and "display_name" in p and p.display_name != "":
			return p.display_name.to_upper()
	if self is Dummy or name.to_lower().contains("dummy"):
		var has_counter: bool = ("counter_move" in self and self.get("counter_move") != null)
		if has_counter or name.to_lower().contains("enemy"):
			return "DUMMY ENEMY"
		return "DUMMY"
	if name.begins_with("@"):
		return "ENEMY" if team == &"enemy" else "ALLY"
	return name.to_upper()


func get_move_in_slot(slot: StringName) -> MoveData:
	if "pokemon" in self and self.get("pokemon") != null:
		var p = self.get("pokemon")
		if p != null and p.has_method("get_move"):
			return p.get_move(slot)
	return null


# Universal range helpers: works for any move/Pokemon
func get_melee_range() -> float:
	var m := get_move_in_slot(&"attack_1")
	if m != null and m.is_melee():
		return m.get_effective_range()
	elif lunge_move != null:
		return lunge_move.get_effective_range()
	elif self is Dummy and (self as Dummy).counter_move != null:
		return (self as Dummy).counter_move.get_effective_range()
	elif m != null and m.get_effective_range() > 0.0:
		return m.get_effective_range()
	return 44.0


func get_atk2_range() -> float:
	# ATK 2 valid range is 1.5x melee range (swapped with old healthbox ring).
	return get_melee_range() * 1.5


func get_atk3_range() -> float:
	# ATK 3 valid range is 1.5x the new ATK 2 range.
	return get_atk2_range() * 1.5


# Raw ATK 2 range from move data — shared by healthbox visibility and its faint green ring.
func _get_atk2_move_range() -> float:
	var m := get_move_in_slot(&"attack_2")
	if m != null and m.attack_range > 0.0:
		return float(m.attack_range)
	return 110.0


func get_special_range() -> float:
	var m := get_move_in_slot(&"special")
	if m != null and m.attack_range > 0.0:
		return float(m.attack_range)
	return 220.0


func get_healthbox_range() -> float:
	# Healthbox visibility uses the same range as the faint green debug ring.
	return _get_atk2_move_range()


# Damage
func take_damage(amount: int, source: Fighter, move: MoveData = null) -> void:
	if is_defeated:
		return
	var actual_dmg := mini(amount, hp)
	hp = maxi(hp - amount, 0)
	flash_left = FLASH_FRAMES
	print(name, " took ", amount, " damage, hp ", hp, "/", max_hp)

	# Soft haptic feedback when an attack is landed by player (Android vibration + gamepad rumble)
	if source != null and is_instance_valid(source) and source.team == &"player":
		Input.vibrate_handheld(40) # Soft 40ms haptic bump on Android mobile
		Input.start_joy_vibration(0, 0.25, 0.0, 0.08)

	# Universal data-driven XP handled by XPManager (data/xp_manager.gd)
	if actual_dmg > 0:
		var active_move: MoveData = move
		if active_move == null and source != null and source.get("lunge_move") != null:
			active_move = source.get("lunge_move") as MoveData
		XPManager.on_attack_landed(source, self, active_move, actual_dmg)

	# Melee hit effect: hit_1.png on the hit area of the target
	var is_melee_hit: bool = (move != null and move.is_melee()) or (source != null and source.get("lunge_move") != null)
	if is_melee_hit:
		_spawn_melee_hit_effect()

	# Combat Hit Sound:
	# All successful attack hits (melee moves like Tackle, summoned entities like Razor Leaves and Solar Beams)
	# produce the combat hit sound via AudioManager.play_hit (with multi-target debounce, AudioStreamRandomizer, and limiter bus).
	var should_play_hit_sound := true
	if move != null and "play_hit_sound" in move:
		should_play_hit_sound = move.play_hit_sound
	if should_play_hit_sound:
		AudioManager.play_hit(self, move if move != null else source)
	if team == &"player":
		var dm = get_node_or_null("/root/DebugMenu")
		if dm != null and dm.has_method("flash_red_tint"):
			dm.flash_red_tint()
	_on_damaged(source)
	if hp == 0:
		AudioManager.play_faint(self)
		if source != null and is_instance_valid(source) and source != self:
			XPManager.on_fighter_defeated(source, self)
		if self is Dummy or name.begins_with("Dummy"):
			start_defeat()
		else:
			hp = max_hp


func _spawn_melee_hit_effect() -> void:
	var HitFxScript = load("res://moves/melee_hit_effect.gd")
	if HitFxScript == null:
		return
	var fx = HitFxScript.new()
	var scene_root: Node = get_tree().current_scene if (is_inside_tree() and get_tree() != null and get_tree().current_scene != null) else get_parent()
	if scene_root == null:
		scene_root = self
	scene_root.add_child(fx)
	var offset := Vector2(randf_range(-4, 4), randf_range(-4, 4))
	fx.global_position = global_position + offset


func start_defeat() -> void:
	if is_defeated:
		return
	is_defeated = true
	defeat_blink_timer = DEFEAT_BLINK_FRAMES
	set_outline(false)

	# Cancel lunge & combat boxes
	if is_lunging():
		_end_lunge()
	if hitbox != null:
		hitbox.deactivate()
	if hurtbox != null:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)

	# Remove from active groups so targeting and collisions stop
	remove_from_group(&"fighters")
	remove_from_group(&"hurtboxes")
	remove_from_group(&"hitboxes")
	print(name, " defeated! Blinking rapidly before disappearing permanently.")


# Distance from this fighter's center to the nearest point on other's hurtbox CIRCLE.
# Returns: center_distance - hurtbox_radius (clamped to 0).
# When this value <= attack_range, the attack range circle is touching the hurtbox circle.
func distance_to_fighter(other: Fighter) -> float:
	if other == null or not is_instance_valid(other):
		return 999999.0

	var center_dist: float = global_position.distance_to(other.global_position)

	# Read the live hurtbox circle radius if available, fall back to computed value
	var hurtbox_r: float = (other.hurtbox_size.x + other.hurtbox_size.y) * 0.25
	if other.hurtbox != null and other.hurtbox.has_method("get_radius"):
		hurtbox_r = other.hurtbox.get_radius() * other.scale.abs().length() / sqrt(2.0)

	# Distance from player center to the hurtbox circle edge (0 if already overlapping)
	return maxf(0.0, center_dist - hurtbox_r)


func set_hurtbox_size(new_size: Vector2) -> void:
	hurtbox_size = new_size
	if hurtbox != null:
		hurtbox.set_box_size(new_size)


# Targeting: synchronized with debug circle
func find_target(search_range: float) -> Fighter:
	var tree := _get_active_tree()
	var candidates: Array = []
	if tree != null:
		candidates = tree.get_nodes_in_group(&"fighters")
	if candidates.is_empty():
		var p := get_parent()
		if p != null:
			for child in p.get_children():
				if child is Fighter and child != self:
					candidates.append(child)

	var best: Fighter = null
	var best_dist := search_range
	for node in candidates:
		var other := node as Fighter
		if other == null or other == self or other.team == team or other.is_defeated or other.is_queued_for_deletion():
			continue
		var dist := distance_to_fighter(other)
		if dist <= best_dist:
			best = other
			best_dist = dist
	return best


func cardinal(direction: Vector2) -> Vector2:
	if absf(direction.x) > absf(direction.y):
		return Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if direction.y > 0.0 else Vector2.UP


# Melee Lunge
func start_lunge(target: Fighter, move: MoveData) -> void:
	lunge_target = target
	lunge_move = move
	lunge_origin = global_position
	lunge_returning = false
	var max_f: int = move.get("max_frames") if (move != null and "max_frames" in move and int(move.get("max_frames")) > 0) else 45
	lunge_frames_left = max_f
	lunge_homing = (target != null)
	lunge_hit_landed = false

	var dir: Vector2
	if target != null:
		var offset := target.global_position - global_position
		dir = offset.normalized() if offset.length_squared() > 0.001 else facing
	else:
		dir = facing
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	lunge_dir = dir

	# Calculate forward distance to ensure visible motion even at point-blank range
	var atk_r: float = move.get_effective_range() if move != null else 44.0
	var target_dist := global_position.distance_to(target.global_position) if target != null else atk_r
	lunge_forward_target_dist = clampf(target_dist + 6.0, 16.0, atk_r)

	_apply_headbutt_tilt()

	if hitbox != null:
		if move != null and move.hitbox_radius > 0:
			hitbox.set_radius(move.hitbox_radius)
		hitbox.position = lunge_dir * hitbox_offset
		var base_dmg: float = (move.power if move != null else 1.0) + float(get_move_bonus_damage(&"attack_1"))
		var atk_power: int = maxi(1, int(roundf(base_dmg * get_base_damage())))
		hitbox.activate(atk_power, move)

	_on_lunge_started(dir)


func start_lunge_direction(direction: Vector2, move: MoveData) -> void:
	lunge_target = null
	lunge_move = move
	lunge_origin = global_position
	lunge_returning = false
	var max_f: int = move.get("max_frames") if (move != null and "max_frames" in move and int(move.get("max_frames")) > 0) else 45
	lunge_frames_left = max_f
	lunge_homing = false
	lunge_hit_landed = false
	var atk_r: float = move.get_effective_range() if move != null else 44.0
	lunge_forward_target_dist = atk_r

	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = facing if facing != Vector2.ZERO else Vector2.DOWN
	lunge_dir = dir

	_apply_headbutt_tilt()

	if hitbox != null:
		if move != null and move.hitbox_radius > 0:
			hitbox.set_radius(move.hitbox_radius)
		hitbox.position = lunge_dir * hitbox_offset
		var base_dmg: float = (move.power if move != null else 1.0) + float(get_move_bonus_damage(&"attack_1"))
		var atk_power: int = maxi(1, int(roundf(base_dmg * get_base_damage())))
		hitbox.activate(atk_power, move)

	_on_lunge_started(lunge_dir)


func _apply_headbutt_tilt() -> void:
	if not is_instance_valid(visual) or has_method("_update_sprite"):
		return
	# Headbutt tilt on horizontal movement
	if absf(lunge_dir.x) >= absf(lunge_dir.y) and absf(lunge_dir.x) > 0.1:
		visual.rotation_degrees = HEADBUTT_TILT_DEGREES if lunge_dir.x > 0 else -HEADBUTT_TILT_DEGREES
	else:
		visual.rotation_degrees = 0.0


func _reset_headbutt_tilt() -> void:
	if is_instance_valid(visual) and visual.rotation_degrees != 0.0:
		visual.rotation_degrees = 0.0


func is_lunging() -> bool:
	return lunge_move != null


func _update_lunge() -> void:
	if lunge_move == null:
		_reset_headbutt_tilt()
		return

	if lunge_returning:
		_reset_headbutt_tilt()
		_step_toward(lunge_origin)
		if global_position == lunge_origin:
			_end_lunge()
		return

	lunge_frames_left -= 1
	if lunge_frames_left <= 0:
		_return_lunge()
		return

	var dist_from_origin := lunge_origin.distance_to(global_position)

	# Homing logic: tracks target within range during forward lunge
	if lunge_homing:
		if not is_instance_valid(lunge_target):
			lunge_homing = false
			lunge_target = null
		else:
			var dist := distance_to_fighter(lunge_target)
			if dist > lunge_move.attack_range:
				print(name, " homing lost: target out of range (", dist, " > ", lunge_move.attack_range, ")")
				lunge_homing = false
				lunge_target = null
			else:
				var to_target := lunge_target.global_position - global_position
				# If we reached or lunged through the target, start returning
				if to_target.dot(lunge_dir) <= 0.0 and dist_from_origin >= 14.0:
					_return_lunge()
					return
				elif to_target.length_squared() > 0.001 and to_target.dot(lunge_dir) > 0.0:
					lunge_dir = to_target.normalized()
					_apply_headbutt_tilt()

	# If hit already landed and reached minimum motion, begin return
	if lunge_hit_landed and dist_from_origin >= 16.0:
		_return_lunge()
		return

	# Step forward along lunge_dir at constant normal speed
	var speed: float = float(lunge_move.lunge_speed) if (lunge_move != null and "lunge_speed" in lunge_move) else 2.0
	global_position = (global_position + lunge_dir * speed).round()

	if hitbox != null:
		hitbox.position = lunge_dir * hitbox_offset

	# Check if forward lunge reached target distance or attack range limit
	dist_from_origin = lunge_origin.distance_to(global_position)
	var max_atk_r: float = lunge_move.get_effective_range() if lunge_move != null else 44.0
	if dist_from_origin >= lunge_forward_target_dist or dist_from_origin >= max_atk_r:
		_return_lunge()


func _step_toward(point: Vector2) -> void:
	var offset := point - global_position
	if offset.length() <= float(lunge_move.lunge_speed):
		global_position = point
		return
	var step := float(lunge_move.lunge_speed)
	global_position = (global_position + offset.normalized() * step).round()


func _return_lunge() -> void:
	lunge_returning = true
	_reset_headbutt_tilt()
	if hitbox != null:
		hitbox.deactivate()


func _on_hitbox_landed(_victim: Fighter) -> void:
	if is_lunging() and not lunge_returning:
		lunge_hit_landed = true
		# Ensure visible motion even on close range: only return if minimum lunge distance reached
		if lunge_origin.distance_to(global_position) >= 16.0:
			_return_lunge()


func _end_lunge() -> void:
	_reset_headbutt_tilt()
	if hitbox != null:
		hitbox.deactivate()
	lunge_move = null
	lunge_target = null
	lunge_homing = false
	lunge_returning = false
	lunge_hit_landed = false
	_on_lunge_ended()


# Debug drawing: range circles for the debug hitbox show option
func _draw() -> void:
	var menu_node := get_node_or_null("/root/DebugMenu")
	if menu_node == null or not menu_node.get("show_hitboxes"):
		return

	var melee_r := get_melee_range()
	if melee_r > 0.0:
		# Valid melee range circle — matches ATK 1 button color (orange)
		draw_arc(Vector2.ZERO, melee_r, 0.0, TAU, 48, Color(0.96, 0.58, 0.15, 0.45), 1.0)
		# Faint green ring showing the exact range used for healthbox visibility.
		var healthbox_r := get_healthbox_range()
		draw_arc(Vector2.ZERO, healthbox_r, 0.0, TAU, 48, Color(0.22, 0.78, 0.35, 0.18), 1.0)

	var atk2_r := get_atk2_range()
	if atk2_r > 0.0:
		# Valid attack 2 range circle — matches ATK 2 button color (grass green), now at 1.5x melee
		draw_arc(Vector2.ZERO, atk2_r, 0.0, TAU, 64, Color(0.22, 0.78, 0.35, 0.45), 1.0)

	var atk3_r := get_atk3_range()
	if atk3_r > 0.0:
		# Valid attack 3 range circle — matches ATK 3 button color (purple), now at 1.5x ATK 2
		draw_arc(Vector2.ZERO, atk3_r, 0.0, TAU, 64, Color(0.72, 0.32, 0.95, 0.50), 1.5)


# Hooks
func _on_damaged(_source: Fighter) -> void:
	pass


func _on_lunge_started(_direction: Vector2) -> void:
	pass


func _on_lunge_ended() -> void:
	pass
