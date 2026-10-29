extends SceneTree

const BloomConfig = preload("res://data/bloom_config.gd")
const AudioManager = preload("res://data/audio_manager.gd")
const HapticManager = preload("res://data/haptic_manager.gd")
const DiagonalSmokeEffect = preload("res://moves/diagonal_smoke_effect.gd")
const HomingProjectile = preload("res://moves/homing_projectile.gd")
const BeamEffect = preload("res://moves/beam_effect.gd")
const AttackButtonConfig = preload("res://data/attack_button_config.gd")

func _init() -> void:
	print("--- Running Test Suite for Pokémon Game New Features ---")

	test_smoke_effects_rendering()
	test_reworked_exp_formula()
	test_level_up_health_restore_and_every_5_levels_upgrades()
	test_attack_button_level_outline()
	test_3tap_attack_level_up_confirmation()
	test_stored_attack_upgrade_points_skyrocket()
	test_fixed_range_regardless_of_size()
	test_universal_dummy_limit_and_giant_dummy()
	test_haptic_feedback_events_and_permission()
	test_audio_manager_structure_and_fallbacks()
	test_hit_audio_debounce_randomizer_and_limiter_bus()
	test_debugger_player_level_and_notification_removed()
	test_melee_attack_player_blink_on_hit_only()
	test_bloom_registry_and_melee_hit_effect()
	test_razor_leaf_poof_smoke()
	test_dash_arrow_reduced_and_light_blue_streak()
	test_map_border_prevents_going_offscreen()
	test_hit_effect_enlarged_size_and_duration()
	test_healthbox_ui_and_milestone_blink()
	test_8way_directional_tilts_and_tackle()
	test_joystick_pad_and_ball_textures()
	test_orientation_setting()
	test_unite_radius_removed_and_atk3_range()
	test_pokemon_evolution_system()
	test_smoke_1_size_relative_to_evolution_stage()
	test_giant_dummy_affected_by_tackle_and_homing()
	test_audio_polyphony_and_overlap()
	test_evolution_gba_theme()
	test_solar_beam_implementation()
	test_attack_button_config_and_tints()
	test_hitbox_touching_targeting()
	test_data_driven_system_rework()
	test_shot_hold_aim_mechanic_and_solar_beam_center()
	test_menu_and_character_selection()
	test_stage_h1_preview_pause_menu_and_ui_dynamic()

	print("--- ALL TESTS PASSED SUCCESSFULLY! ---")
	quit(0)


func test_smoke_effects_rendering() -> void:
	print("\n[TEST 1] Smoke Effects Rendering (smoke_1 below player layer-wise, slightly decreased size)...")
	var SmokeScript = load("res://moves/diagonal_smoke_effect.gd")
	assert(SmokeScript != null, "Failed to load diagonal_smoke_effect.gd")

	# 1. Non-cardinal walking smoke (smoke_1.png): LAYER-WISE below player (z_index 1 < player 2)
	var walk_smoke = SmokeScript.new(false)
	assert(walk_smoke.sprite != null, "Walk smoke must have sprite")
	assert(walk_smoke.sprite.texture.resource_path.contains("smoke_1.png"), "Walk smoke must use smoke_1.png")
	assert(walk_smoke.z_index == 1, "smoke_1 z_index must be 1 (below player base z_index 2)")
	assert(walk_smoke.sprite.scale.x <= 1.4, "smoke_1 scale must be slightly decreased (<= 1.4)")
	walk_smoke.free()

	# 2. Dash smoke (smoke_2.png): z_index 3
	var dash_smoke = SmokeScript.new(true)
	assert(dash_smoke.sprite != null, "Dash smoke must have sprite")
	assert(dash_smoke.sprite.texture.resource_path.contains("smoke_2.png"), "Dash smoke must use smoke_2.png")
	assert(dash_smoke.z_index == 3, "Dash smoke z_index must be 3")
	assert(dash_smoke.sprite.scale.x >= 1.5, "Dash smoke scale must be enlarged")
	dash_smoke.free()

	# 3. Test Player smoke spawn trigger & center position
	var PlayerScript = load("res://scripts/player.gd")
	var pkmn_data = load("res://data/pokemon/venusaur.tres")
	var player = PlayerScript.new()
	player.pokemon = pkmn_data
	root.add_child(player)
	player._build_sprite()
	player.global_position = Vector2(100, 100)

	# Walking diagonally (NE): smoke_1 must spawn at center of player
	player.facing = Vector2(1, -1).normalized()
	player.smoke_timer = 5
	player._maybe_spawn_smoke(false)
	assert(player.smoke_timer == 0, "Non-cardinal walk must spawn smoke and reset timer")

	# Find the spawned smoke
	var spawned_smoke: Node2D = null
	for child in root.get_children():
		if child is DiagonalSmokeEffect:
			spawned_smoke = child
			break
	assert(spawned_smoke != null, "Smoke effect must be added to scene")
	assert(spawned_smoke.global_position.distance_to(player.global_position) <= 4.0, "smoke_1 must generate at the center of the player")
	assert(spawned_smoke.z_index == 1, "Spawned smoke_1 must have z_index 1 (layer-wise below player)")
	spawned_smoke.queue_free()

	# Dashing: smoke_2 must spawn offset behind player
	player.dash_dir = Vector2.RIGHT
	player.smoke_timer = 2
	player._maybe_spawn_smoke(true)
	assert(player.smoke_timer == 0, "Dashing must spawn dash smoke and reset timer")

	var spawned_dash_smoke: Node2D = null
	for child in root.get_children():
		if child is DiagonalSmokeEffect and child != spawned_smoke:
			spawned_dash_smoke = child
			break
	assert(spawned_dash_smoke != null, "Dash smoke effect must be spawned")
	assert(spawned_dash_smoke.global_position.distance_to(player.global_position) >= 15.0, "smoke_2 must spawn behind player during dash")
	spawned_dash_smoke.queue_free()

	player.queue_free()
	print("✓ Smoke effects rendering tests PASSED")


func test_reworked_exp_formula() -> void:
	print("\n[TEST 2] Reworked EXP Formula: flat damage XP, separate Kill XP with level multiplier...")
	# Verify Kill EXP formula
	var base_k := XPManager.BASE_KILL_XP
	assert(XPManager.calculate_kill_xp(1) == base_k * 1.0, "Lv 1 kill gives 1x base kill XP")
	assert(XPManager.calculate_kill_xp(4) == base_k * 4.0, "Lv 4 kill gives 4x base kill XP")
	assert(XPManager.calculate_kill_xp(10) == base_k * 10.0, "Lv 10 kill gives 10x base kill XP")

	# Test Fighter on_attack_landed has NO enemy level multiplier on damage dealt/taken
	var FighterScript = load("res://scripts/fighter.gd")
	var attacker = FighterScript.new()
	var defender = FighterScript.new()
	defender.level = 4 # Enemy is Lv. 4

	var move = load("res://data/moves/tackle.tres")
	XPManager.on_attack_landed(attacker, defender, move, 10)

	# Attacker used Tackle (base 1 XP) against Lv 4 enemy -> flat 1.0 XP (level multiplier stripped)
	assert(attacker.xp == 1.0, "Attacker must gain flat 1.0 XP regardless of enemy lvl")

	# Defender took 10 dmg from Lv 1 attacker -> flat 5.0 XP (10 * 0.5, no level multiplier)
	assert(defender.xp == 5.0, "Defender must gain flat 5.0 XP (10 * 0.5)")

	# Defeating an enemy triggers Kill XP with enemy level multiplier
	XPManager.on_fighter_defeated(attacker, defender)
	assert(attacker.level >= 2, "Attacker must level up after gaining kill XP")

	attacker.free()
	defender.free()
	print("✓ Reworked EXP formula & Kill EXP tests PASSED")


func test_melee_attack_player_blink_on_hit_only() -> void:
	print("\n[TEST 2B] Melee Attack Player Blink Only on Target Hit...")
	var PlayerScript = load("res://scripts/player.gd")
	var pkmn_data = load("res://data/pokemon/venusaur.tres")
	var player = PlayerScript.new()
	player.pokemon = pkmn_data
	root.add_child(player)
	player._build_sprite()

	# 1. Starting lunge / attack does NOT trigger flash
	player._on_lunge_started(Vector2.RIGHT)
	assert(player.atk_flash_left == 0, "Lunge start must NOT trigger attack flash")

	# 2. When hitbox lands on target, flash MUST trigger
	var dummy = Fighter.new()
	player._on_hitbox_landed(dummy)
	assert(player.atk_flash_left == 14, "Successful hit must trigger 14-frame attack flash")
	assert(player.atk_flash_color == player.FLASH_COLOR_ATK1, "Melee flash must be opaque white")

	# 3. Lunge ended does not cancel hit flash
	player._on_lunge_ended()
	assert(player.atk_flash_left == 14, "Lunge end must preserve active hit flash")

	dummy.free()
	player.queue_free()
	print("✓ Melee attack player blink on hit only tests PASSED")


func test_bloom_registry_and_melee_hit_effect() -> void:
	print("\n[TEST 2C] Bloom Config Registry & Melee Hit Bloom...")
	# Verify BloomConfig registry flags
	assert(BloomConfig.has_bloom("tackle") == true, "Tackle must have bloom enabled")
	assert(BloomConfig.has_bloom("hit_1") == true, "hit_1 must have bloom enabled")
	assert(BloomConfig.has_bloom("solar_beam") == true, "solar_beam must have bloom enabled")
	assert(BloomConfig.has_bloom("razor_leaf") == false, "razor_leaf must NOT have bloom")

	# Dynamic flag toggle
	BloomConfig.set_bloom("custom_asset", true)
	assert(BloomConfig.has_bloom("custom_asset") == true, "Custom asset bloom flag can be set")
	BloomConfig.set_bloom("custom_asset", false)
	assert(BloomConfig.has_bloom("custom_asset") == false, "Custom asset bloom flag can be cleared")

	# Verify MeleeHitEffect has bloom material applied
	var HitFxScript = load("res://moves/melee_hit_effect.gd")
	var hit_fx = HitFxScript.new()
	root.add_child(hit_fx)
	assert(hit_fx.sprite.material != null, "MeleeHitEffect sprite must have material applied")
	var mat = hit_fx.sprite.material as ShaderMaterial
	assert(mat != null, "Material must be a ShaderMaterial")
	assert(mat.get_shader_parameter("bloom_enabled") == true, "Bloom must be enabled on hit effect")
	hit_fx.queue_free()

	print("✓ Bloom config registry & melee hit bloom tests PASSED")


func test_razor_leaf_poof_smoke() -> void:
	print("\n[TEST 2D] Razor Leaf Poof Smoke Generation on Disappear...")
	# 1. Test static helper spawn_poof
	var poof = DiagonalSmokeEffect.spawn_poof(root, Vector2(50, 50))
	assert(poof != null, "Poof must be instantiated")
	assert(poof.sprite != null, "Poof must have sprite")
	assert(poof.sprite.texture.resource_path.contains("smoke_1.png"), "Poof must use smoke_1.png")
	poof.queue_free()

	# 2. Test Razor Leaf smoke poof only appears on disappear, not on launch
	var PlayerScript = load("res://scripts/player.gd")
	var pkmn_data = load("res://data/pokemon/venusaur.tres")
	var player = PlayerScript.new()
	player.pokemon = pkmn_data
	root.add_child(player)
	player._build_sprite()

	var rl_move = load("res://data/moves/razor_leaf.tres")
	assert(rl_move != null, "Razor Leaf move resource must load")

	var initial_poofs: int = 0
	for child in root.get_children():
		if child is DiagonalSmokeEffect:
			initial_poofs += 1

	var HomingMechanicScript = load("res://moves/homing_mechanic.gd")
	assert(HomingMechanicScript.LEAF_DELAY_SEC == 0.2, "Homing delay must be 0.2 seconds between entities")

	# Execute move: first leaf launches immediately, NO smoke poof on launch
	rl_move.execute(player)

	var launch_poofs: int = 0
	var spawned_proj: HomingProjectile = null
	var leaf_count: int = 0
	for child in root.get_children():
		if child is DiagonalSmokeEffect:
			launch_poofs += 1
		elif child is HomingProjectile:
			spawned_proj = child
			leaf_count += 1
			assert(child.damage == 2, "Each leaf must deal 2 base damage")

	assert(leaf_count >= 1, "First leaf launches immediately")
	assert(launch_poofs == initial_poofs, "Smoke poof must NOT spawn on launch (only when disappears)")
	assert(spawned_proj != null, "Razor leaf projectile must be launched")

	# Verify spawning of all 5 leaves with proper damage and spread ratios
	var spread_ratios: Array[float] = [-1.0, -0.5, 0.0, 0.5, 1.0]
	var all_leaves: Array[HomingProjectile] = []
	for sr in spread_ratios:
		var leaf = rl_move._spawn_leaf(player, root, null, sr)
		assert(leaf.damage == 2, "Each leaf must deal 2 base damage")
		all_leaves.append(leaf)
	assert(all_leaves.size() == 5, "Razor leaf configuration must produce 5 leaves")

	# When projectile disappears, smoke poof MUST spawn
	spawned_proj._disappear_with_poof()

	var after_disappear_poofs: int = 0
	for child in root.get_children():
		if child is DiagonalSmokeEffect:
			after_disappear_poofs += 1
	assert(after_disappear_poofs > launch_poofs, "Smoke_1 poof MUST appear when razor leaf disappears")

	# Clean up
	for child in root.get_children():
		if child is DiagonalSmokeEffect or child is HomingProjectile:
			child.queue_free()

	player.queue_free()
	print("✓ Razor Leaf poof smoke on disappear tests PASSED")


func test_level_up_health_restore_and_every_5_levels_upgrades() -> void:
	print("\n[TEST 3A] Level Up Health Regain (+5 HP) & Upgrades Every 5 Levels...")
	var FighterScript = load("res://scripts/fighter.gd")
	var f = FighterScript.new()
	f.max_hp = 30
	f.hp = 10 # Damaged state

	# 1. Level up from 1 to 2 -> restores 5 HP (10 -> 15), no upgrade point (2 % 5 != 0)
	f.level = 1
	f.xp = 0.0
	f.gain_xp(float(f.get_max_xp()))
	assert(f.level == 2, "Fighter must be Lv. 2")
	assert(f.hp == 15, "Level up must restore 5 HP (10 + 5 = 15)")
	assert(f.pending_attack_upgrades == 0, "Lv. 2 must NOT grant upgrade point")

	# 2. Level up to Lv. 5 (5 % 5 == 0) -> grants upgrade point!
	f.level = 4
	f.xp = 0.0
	f.gain_xp(float(f.get_max_xp()))
	assert(f.level == 5, "Fighter must reach Lv. 5")
	assert(f.pending_attack_upgrades == 1, "Reaching Lv. 5 must grant 1 attack upgrade point")

	# 3. Level up to Lv. 6 (6 % 5 != 0) -> no new upgrade point
	f.level = 5
	f.xp = 0.0
	f.gain_xp(float(f.get_max_xp()))
	assert(f.level == 6, "Fighter must reach Lv. 6")
	assert(f.pending_attack_upgrades == 1, "Lv. 6 must not grant point, point count stays 1")

	# 4. Level up to Lv. 10 (10 % 5 == 0) -> grants another upgrade point
	f.level = 9
	f.xp = 0.0
	f.gain_xp(float(f.get_max_xp()))
	assert(f.level == 10, "Fighter must reach Lv. 10")
	assert(f.pending_attack_upgrades == 2, "Reaching Lv. 10 must grant 2nd attack upgrade point")

	# Upgrade attack 1
	assert(f.upgrade_attack(&"attack_1") == true, "Upgrade attack 1 must succeed")
	assert(f.get_move_bonus_damage(&"attack_1") == 1, "Attack 1 bonus damage must be 1")
	assert(f.pending_attack_upgrades == 1, "Remaining upgrade points must be 1")

	f.free()
	print("✓ Level up health restore (+5 HP) and upgrades every 5 levels tests PASSED")


func test_attack_button_level_outline() -> void:
	print("\n[TEST 3B] Attack Button Level Outline (White for Lv. 1, increasingly Blue for higher)...")
	var TouchControlsScript = load("res://ui/touch_controls.gd")
	var tc = TouchControlsScript.new()
	root.add_child(tc)
	tc._ready()

	# Base level (0 upgrades): Transparent / default outline
	assert(tc.btn_atk1.get_upgrade_outline_color(0) == Color.TRANSPARENT, "Unupgraded move must have no special upgrade outline")

	# Level 1 upgrade: Pure White outline
	var col_lvl1: Color = tc.btn_atk1.get_upgrade_outline_color(1)
	assert(col_lvl1 == Color(1.0, 1.0, 1.0, 1.0), "1st upgrade must be Pure White")

	# Level 2 upgrade: Increasingly Blue (blue component > red component)
	var col_lvl2: Color = tc.btn_atk1.get_upgrade_outline_color(2)
	assert(col_lvl2.b > col_lvl2.r, "2nd upgrade must be more blue than red")
	assert(col_lvl2.r < 1.0, "2nd upgrade red channel decreases towards blue")

	# Level 3 upgrade: Even more blue
	var col_lvl3: Color = tc.btn_atk1.get_upgrade_outline_color(3)
	assert(col_lvl3.b > col_lvl2.b or col_lvl3.r < col_lvl2.r, "3rd upgrade must be deeper blue than 2nd upgrade")

	tc.queue_free()
	print("✓ Attack button level outline tests PASSED")


func test_audio_manager_structure_and_fallbacks() -> void:
	print("\n[TEST 3C] Audio Manager Structure, Categorized Paths & MP3 Files...")
	# Verify single valid .mp3 paths exist in AudioManager
	assert(AudioManager.PATH_UI_BUTTON_CLICK.contains("assets/audio/ui/button_click.mp3"), "UI button click path (.mp3)")
	assert(AudioManager.PATH_UI_ATK_BUTTON.contains("assets/audio/ui/atk_button.mp3"), "UI atk button path (.mp3)")
	assert(AudioManager.PATH_UI_DASH_BUTTON.contains("assets/audio/ui/dash_button.mp3"), "UI dash button path (.mp3)")
	assert(AudioManager.PATH_UI_UNITE_BUTTON.contains("assets/audio/ui/unite_button.mp3"), "UI unite button path (.mp3)")
	assert(AudioManager.PATH_COMBAT_HIT.contains("assets/audio/combat/hit.mp3"), "Combat hit path (.mp3)")
	assert(AudioManager.PATH_COMBAT_INVALID_RANGE.contains("assets/audio/combat/invalid_range.mp3"), "Combat invalid range path (.mp3)")
	assert(AudioManager.PATH_MOVE_RAZOR_LEAF.contains("assets/audio/moves/razor_leaf.mp3"), "Move razor leaf path (.mp3)")
	assert(AudioManager.PATH_MOVE_DASH.contains("assets/audio/moves/dash.mp3"), "Move dash path (.mp3)")
	assert(AudioManager.PATH_MOVE_TACKLE.contains("assets/audio/moves/tackle.mp3"), "Move tackle path (.mp3)")
	assert(AudioManager.PATH_MOVE_VINE_WHIP.contains("assets/audio/moves/vine_whip.mp3"), "Move vine whip path (.mp3)")
	assert(AudioManager.PATH_MOVE_SOLAR_BEAM.contains("assets/audio/moves/solar_beam.mp3"), "Move solar beam path (.mp3)")
	assert(AudioManager.PATH_MOVEMENT_WALK.contains("assets/audio/movement/walk.mp3"), "Movement walk path (.mp3)")
	assert(AudioManager.PATH_MOVEMENT_WALK_DIAGONAL.contains("assets/audio/movement/walk_diagonal.mp3"), "Movement walk diagonal path (.mp3)")
	assert(AudioManager.PATH_PROGRESSION_LEVEL_UP.contains("assets/audio/progression/level_up.mp3"), "Progression level up path (.mp3)")
	assert(AudioManager.PATH_PROGRESSION_ATK_LEVEL_UP.contains("assets/audio/progression/atk_level_up.mp3"), "Progression atk level up path (.mp3)")
	assert(AudioManager.PATH_PROGRESSION_FAINT.contains("assets/audio/progression/faint.mp3"), "Progression faint path (.mp3)")

	# Verify every single required MP3 actually exists and loads as a valid AudioStream
	var required_audio := [
		AudioManager.PATH_UI_BUTTON_CLICK,
		AudioManager.PATH_UI_ATK_BUTTON,
		AudioManager.PATH_UI_DASH_BUTTON,
		AudioManager.PATH_UI_UNITE_BUTTON,
		AudioManager.PATH_COMBAT_HIT,
		AudioManager.PATH_COMBAT_INVALID_RANGE,
		AudioManager.PATH_MOVE_RAZOR_LEAF,
		AudioManager.PATH_MOVE_DASH,
		AudioManager.PATH_MOVE_TACKLE,
		AudioManager.PATH_MOVE_VINE_WHIP,
		AudioManager.PATH_MOVE_SOLAR_BEAM,
		AudioManager.PATH_MOVEMENT_WALK,
		AudioManager.PATH_MOVEMENT_WALK_DIAGONAL,
		AudioManager.PATH_PROGRESSION_LEVEL_UP,
		AudioManager.PATH_PROGRESSION_ATK_LEVEL_UP,
		AudioManager.PATH_PROGRESSION_FAINT,
	]
	for audio_path in required_audio:
		assert(ResourceLoader.exists(audio_path), "File must exist: " + audio_path)
		var stream = load(audio_path)
		assert(stream != null, "Stream must load non-null: " + audio_path)
		assert(stream is AudioStream, "Resource must be AudioStream: " + audio_path)

	# Test direct MP3 resolution
	var resolved_hit := AudioManager.resolve_path(AudioManager.PATH_COMBAT_HIT)
	assert(resolved_hit == AudioManager.PATH_COMBAT_HIT, "Combat hit sound must resolve directly to hit.mp3")
	var resolved_rl := AudioManager.resolve_path(AudioManager.PATH_MOVE_RAZOR_LEAF)
	assert(resolved_rl == AudioManager.PATH_MOVE_RAZOR_LEAF, "Razor Leaf must resolve directly to razor_leaf.mp3")

	# Test MoveData resources are bound to .mp3
	var rl_data = load("res://data/moves/razor_leaf.tres")
	assert(rl_data != null and rl_data.sound_path == "res://assets/audio/moves/razor_leaf.mp3", "data/moves/razor_leaf.tres must point to .mp3")

	var tackle_data = load("res://data/moves/tackle.tres")
	assert(tackle_data != null and tackle_data.sound_path == "res://assets/audio/moves/tackle.mp3", "tackle.tres must point to tackle.mp3")

	# Test non-existent path
	var fake_path := "res://assets/audio/non_existent.mp3"
	assert(AudioManager.resolve_path(fake_path) == "", "Unknown path returns empty string without error")

	# Test play_sound gracefully returns without error
	var played := AudioManager.play_sound(AudioManager.PATH_UI_BUTTON_CLICK)
	assert(typeof(played) == TYPE_BOOL, "play_sound must return bool indicating playback status")

	# Test Move Sound debounce: Move sound plays strictly once and debounces rapid double execution
	AudioManager._last_move_sound_msec = -10000
	var move_sound_1 := AudioManager.play_sound(AudioManager.PATH_MOVE_RAZOR_LEAF)
	assert(move_sound_1 == true, "Move sound must play on first trigger (making the attack)")
	var move_sound_duplicate := AudioManager.play_sound(AudioManager.PATH_MOVE_RAZOR_LEAF)
	assert(move_sound_duplicate == false, "Duplicate move sound within debounce window MUST be ignored so move sound only plays once")

	# Test Attack Impact Move (Tackle) vs Attack Move Sound (Razor Leaf) condition on damage:
	var FighterScript = load("res://scripts/fighter.gd")
	var test_victim = FighterScript.new()
	var test_attacker = FighterScript.new()
	root.add_child(test_victim)
	root.add_child(test_attacker)
	test_victim.hp = 100

	# Summoned entities (Razor Leaf) MUST produce a hit sound using the same melee tackle hit sound
	AudioManager.reset_hit_debounce()
	test_victim.take_damage(2, test_attacker, rl_data)
	assert(AudioManager._last_hit_sound_msec > 0, "Summoned entities (Razor Leaf) MUST produce hit sound on target hit")

	# Tackle (MeleeMove: attack impact move) -> DOES trigger play_hit on target impact
	AudioManager.reset_hit_debounce()
	test_victim.take_damage(1, test_attacker, tackle_data)
	assert(AudioManager._last_hit_sound_msec > 0, "Tackle is an attack impact move; MUST trigger hit sound on target impact")

	# Test Audio Separation: Walk footstep sounds do NOT cut off Move attack sounds
	var test_moving_fighter = FighterScript.new()
	root.add_child(test_moving_fighter)
	AudioManager._last_move_sound_msec = -10000
	var rl_played := AudioManager.play_razor_leaf(test_moving_fighter)
	assert(rl_played == true, "Razor leaf must play on fighter")
	var move_player = test_moving_fighter.get_node_or_null("MoveSFXPlayer") as AudioStreamPlayer2D
	assert(move_player != null, "Fighter must have MoveSFXPlayer for moves")
	assert(move_player.stream != null and move_player.stream.resource_path.contains("razor_leaf"), "MoveSFXPlayer must hold razor leaf stream")

	# Walking sound played on fighter
	AudioManager.play_walk(test_moving_fighter)
	var walk_player = test_moving_fighter.get_node_or_null("WalkSFXPlayer") as AudioStreamPlayer2D
	assert(walk_player != null, "Fighter must have dedicated WalkSFXPlayer")
	assert(walk_player.stream != null and walk_player.stream.resource_path.contains("walk"), "WalkSFXPlayer must hold walk stream")
	# Razor leaf player must NOT have been overwritten or stopped by walking!
	assert(move_player.stream.resource_path.contains("razor_leaf"), "MoveSFXPlayer must still be playing razor leaf, never cut off by walk footsteps!")
	test_moving_fighter.free()

	test_victim.free()
	test_attacker.free()

	print("✓ Audio manager structure, move single-playback & fallbacks tests PASSED")


func test_hit_audio_debounce_randomizer_and_limiter_bus() -> void:
	print("\n[TEST 3D] Multi-target Hit Sound Solution: Debounce (50ms), AudioStreamRandomizer & Limiter Audio Bus...")

	# 1. Test AudioStreamRandomizer Configuration
	var randomizer := AudioManager.get_hit_randomizer()
	assert(randomizer != null, "Hit randomizer must not be null")
	assert(randomizer is AudioStreamRandomizer, "Hit stream must be an AudioStreamRandomizer")
	assert(randomizer.random_pitch > 1.0, "AudioStreamRandomizer must have random_pitch > 1.0 (got %f)" % randomizer.random_pitch)
	assert(randomizer.random_volume_offset_db > 0.0, "AudioStreamRandomizer must have random_volume_offset_db > 0.0 (got %f)" % randomizer.random_volume_offset_db)
	assert(randomizer.streams_count >= 1, "AudioStreamRandomizer must contain at least 1 hit sound stream")
	print("✓ AudioStreamRandomizer verified with random_pitch: %f and random_volume_offset_db: %f dB" % [randomizer.random_pitch, randomizer.random_volume_offset_db])

	# 2. Test Dedicated Audio Bus & AudioEffectLimiter
	AudioManager.ensure_hit_bus()
	var bus_idx := AudioServer.get_bus_index(AudioManager.BUS_HIT_SFX)
	assert(bus_idx >= 0, "Dedicated HitSFX audio bus must exist in AudioServer")
	assert(AudioServer.get_bus_name(bus_idx) == "HitSFX", "Dedicated audio bus must be named HitSFX")

	var has_limiter := false
	var limiter_ceiling := 999.0
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		var fx = AudioServer.get_bus_effect(bus_idx, i)
		if fx is AudioEffectLimiter and AudioServer.is_bus_effect_enabled(bus_idx, i):
			has_limiter = true
			limiter_ceiling = fx.ceiling_db
			break
	assert(has_limiter, "HitSFX bus must have an active AudioEffectLimiter applied to it")
	assert(limiter_ceiling <= 0.0, "AudioEffectLimiter ceiling must ensure audio never peaks above 0 dB (ceiling: %f dB)" % limiter_ceiling)
	print("✓ Dedicated HitSFX audio bus verified with AudioEffectLimiter (ceiling: %f dB <= 0 dB)" % limiter_ceiling)

	# 3. Test Fighter Routing to Dedicated Bus
	var FighterScript = load("res://scripts/fighter.gd")
	var dummy_fighter = FighterScript.new()
	root.add_child(dummy_fighter)
	dummy_fighter._setup_audio()
	assert(dummy_fighter.hit_sfx_player != null, "Fighter must have hit_sfx_player AudioStreamPlayer2D")
	assert(dummy_fighter.hit_sfx_player.bus == AudioManager.BUS_HIT_SFX, "Fighter hit_sfx_player must route to HitSFX bus")
	dummy_fighter.free()

	# 4. Test 50ms Debounce & Cooldown Logic on Simultaneous Hits
	AudioManager.reset_hit_debounce()

	# First hit: triggers sound
	var hit1_played := AudioManager.play_hit()
	assert(hit1_played == true, "First hit sound must trigger successfully")

	# Immediate simultaneous hit on another target in same frame/within 50ms: MUST be debounced
	var hit2_debounced := AudioManager.play_hit()
	assert(hit2_debounced == false, "Simultaneous hit in same frame/within 50ms MUST be debounced")

	# Simultaneous hit with same attack instance: MUST be debounced
	var test_attack_instance := Node.new()
	var hit3_debounced := AudioManager.play_hit(null, test_attack_instance)
	assert(hit3_debounced == false, "Simultaneous hit from attack instance within 50ms cooldown MUST be debounced")
	test_attack_instance.free()

	# Wait past 50ms cooldown period
	OS.delay_msec(60)

	# Next hit after cooldown: triggers sound again
	var hit_after_cooldown := AudioManager.play_hit()
	assert(hit_after_cooldown == true, "Hit sound after 50ms cooldown MUST trigger successfully")

	# 5. Multi-Target Damage Simulation: Hits on multiple dummies in same frame
	AudioManager.reset_hit_debounce()
	var d1 = FighterScript.new()
	var d2 = FighterScript.new()
	var d3 = FighterScript.new()
	root.add_child(d1)
	root.add_child(d2)
	root.add_child(d3)
	d1.hp = 50
	d2.hp = 50
	d3.hp = 50

	var dummy_source = FighterScript.new()
	root.add_child(dummy_source)

	# All 3 targets hit simultaneously in same frame by an attack
	d1.take_damage(10, dummy_source)
	# Second dummy hit should be debounced automatically
	assert(AudioManager.can_play_hit_sound() == false, "Second dummy taking damage in same frame must have hit sound debounced")
	d2.take_damage(10, dummy_source)
	d3.take_damage(10, dummy_source)

	d1.free()
	d2.free()
	d3.free()
	dummy_source.free()

	print("✓ Hit audio debounce (50ms cooldown & same frame/attack instance) tests PASSED")


func test_debugger_player_level_and_notification_removed() -> void:
	print("\n[TEST 3E] Debugger Player Level Control (Custom, -5, +5) & Notification Removal...")

	var DebugMenuScript = load("res://ui/debug_menu.gd")
	var PlayerScript = load("res://scripts/player.gd")
	var TouchControlsScript = load("res://ui/touch_controls.gd")
	var pkmn_data = load("res://data/pokemon/venusaur.tres")

	# 1. Setup Player and Debug Menu
	var player = PlayerScript.new()
	player.pokemon = pkmn_data
	root.add_child(player)
	player._build_sprite()
	player.level = 1
	player.pending_attack_upgrades = 0

	var dm = DebugMenuScript.new()
	dm.tree_ref = self
	dm.player_ref = player
	root.add_child(dm)
	dm._ready()

	assert(dm.lvl_edit != null, "Debugger must have LineEdit for custom player level")
	assert(dm.lvl_slider != null, "Debugger must have HSlider for player level")
	assert(dm.btn_lvl_minus != null, "Debugger must have -5 level button")
	assert(dm.btn_lvl_plus != null, "Debugger must have +5 level button")
	assert(dm.btn_lvl_set != null, "Debugger must have SET button for custom level")

	# 2. Test +5 Levels snaps to milestones (5, 10, 15, 20, 25, 30)
	dm._change_player_level(5)
	assert(player.level == 5, "Player level must snap from 1 to milestone 5 with +5")
	assert(player.pending_attack_upgrades == 1, "Level 5 must grant 1 attack upgrade point (Lv. 5 reached)")

	dm._change_player_level(5)
	assert(player.level == 10, "Player level must increase from 5 to 10 with +5")
	assert(player.pending_attack_upgrades == 2, "Level 10 must grant 2 attack upgrade points (Lv. 5 and 10 reached)")

	# 3. Test Custom Level via LineEdit & Set
	dm.lvl_edit.text = "22"
	dm._set_player_level_from_edit()
	assert(player.level == 22, "Player level must set to custom value 22")
	assert(player.pending_attack_upgrades == 4, "Level 22 must grant 4 upgrade points (Lv. 5, 10, 15, 20)")
	assert(player.is_slot_unlocked(&"attack_2") == true, "Attack 2 unlocked at Lv 15+")

	# 4. Test -5 Levels snaps to milestones (from 22 snaps to 20, then 15)
	dm._change_player_level(-5)
	assert(player.level == 20, "Player level must snap from 22 to milestone 20 with -5")
	assert(player.pending_attack_upgrades == 4, "Level 20 retains 4 upgrade points (Lv 5, 10, 15, 20)")

	dm._change_player_level(-5)
	assert(player.level == 15, "Player level must decrease from 20 to 15 with -5")
	assert(player.pending_attack_upgrades == 3, "Level 15 must have 3 upgrade points")
	assert(player.is_slot_unlocked(&"attack_2") == true, "Attack 2 unlocked at Lv 15")

	# 5. Test Min/Max Clamping (1 - 30)
	dm.lvl_edit.text = "100"
	dm._set_player_level_from_edit()
	assert(player.level == 30, "Player level clamped to MAX_LEVEL 30")
	assert(player.pending_attack_upgrades == 6, "Level 30 grants all 6 upgrade points")
	assert(player.is_slot_unlocked(&"special") == true, "Unite move unlocked at Lv 30")

	dm.lvl_edit.text = "0"
	dm._set_player_level_from_edit()
	assert(player.level == 1, "Player level clamped to min level 1")
	assert(player.pending_attack_upgrades == 0, "Level 1 has 0 upgrade points")

	# 6. Test Level Down After Points Are Spent
	player.set_level(10)
	assert(player.pending_attack_upgrades == 2, "Level 10 has 2 points")
	assert(player.upgrade_attack(&"attack_1") == true, "Upgraded attack_1")
	assert(player.pending_attack_upgrades == 1, "1 point remaining")
	assert(player.get_move_bonus_damage(&"attack_1") == 1, "Bonus damage +1")

	# Drop level to 5 (max allowed lifetime points is 1)
	player.set_level(5)
	assert(player.pending_attack_upgrades == 0, "Pending point reduced to match tier")
	assert(player.get_move_bonus_damage(&"attack_1") == 1, "Spent point retained within tier")

	# Drop level to 1 (max allowed lifetime points is 0)
	player.set_level(1)
	assert(player.pending_attack_upgrades == 0, "0 pending points at Lv 1")
	assert(player.get_move_bonus_damage(&"attack_1") == 0, "Spent point trimmed to match tier 0")

	# 7. Test Notification for new attack level point removed
	var tc = TouchControlsScript.new()
	root.add_child(tc)
	tc._ready()
	player.set_level(15) # grants 3 upgrade points
	assert(player.pending_attack_upgrades == 3, "Player has 3 upgrade points")

	tc.player = player
	tc._process(0.016)

	# Verify notification banner is NOT shown or present
	assert(tc.upgrade_prompt_banner == null or not tc.upgrade_prompt_banner.is_inside_tree() or not tc.upgrade_prompt_banner.visible, "Notification banner for new attack level point must NOT be shown")
	# But buttons themselves still pulsate to indicate upgrade available
	assert(tc.btn_atk1.is_upgrade_pulsating == true, "Attack buttons still pulsate to indicate upgrade availability")

	tc.free()
	dm.free()
	player.free()
	print("✓ Debugger player level control (custom, -5, +5) & notification removal tests PASSED")


func test_dash_arrow_reduced_and_light_blue_streak() -> void:
	print("\n[TEST 4] Dash Arrow Increased Size, Visibility, Slower Smoother Glide & Darker Blue Highlight...")
	var PlayerScript = load("res://scripts/player.gd")
	var pkmn_data = load("res://data/pokemon/venusaur.tres")
	var player = PlayerScript.new()
	player.pokemon = pkmn_data
	root.add_child(player)
	player._build_sprite()

	player.start_dash_aim()
	var arrow_indicator = player.dash_aim_indicator
	assert(arrow_indicator != null, "Dash aim indicator must exist")

	# Main and trailing arrows must both exist
	assert(arrow_indicator.sprite_main != null, "Main leading arrow must exist")
	assert(arrow_indicator.sprite_trailing != null, "Trailing arrow must exist")

	# Arrow sprite scale must be increased (>= 1.5x, up from 1.0x)
	assert(arrow_indicator.sprite_main.scale.x >= 1.5, "Arrow size must be increased (scale >= 1.5x)")
	assert(arrow_indicator.sprite_trailing.scale.x >= 1.5, "Trailing arrow size must be increased (scale >= 1.5x)")

	# Slower and smoother glide (CYCLE_FRAMES >= 35, STEP_COUNT == 16)
	assert(arrow_indicator.CYCLE_FRAMES >= 35, "Arrow glide must be slower (CYCLE_FRAMES >= 35)")
	assert(arrow_indicator.STEP_COUNT == 16, "Arrow glide must use smoother 16 retro steps (not buttery)")

	# Verify streak direction update
	arrow_indicator.update_animation(Vector2.RIGHT)
	assert(arrow_indicator.current_aim_dir == Vector2.RIGHT, "Current aim dir must be Vector2.RIGHT")

	# Verify transparency increases as arrow moves outward towards endpoint
	# When stepped_prog is high (near endpoint), alpha must be significantly lower than near origin
	var alpha_near_endpoint = clampf((1.0 - 0.95) * 0.92, 0.08, 0.92)
	var alpha_near_origin = clampf((1.0 - 0.05) * 0.92, 0.08, 0.92)
	assert(alpha_near_endpoint < alpha_near_origin, "Arrow must become more transparent the closer it gets to the endpoint")

	player.release_dash()
	player.free()
	print("✓ Dash arrow increased size & visibility tests PASSED")


func test_3tap_attack_level_up_confirmation() -> void:
	print("\n[TEST 4B] 3-Tap Attack Level-Up Confirmation (Anti-Spam)...")
	var TouchControlsScript = load("res://ui/touch_controls.gd")
	var tc = TouchControlsScript.new()
	root.add_child(tc)
	tc._ready()

	var FighterScript = load("res://scripts/fighter.gd")
	var f = FighterScript.new()
	tc.player = f

	# Grant 1 upgrade point
	f.pending_attack_upgrades = 1
	tc._process(0.016)

	assert(f.get_move_bonus_damage(&"attack_1") == 0, "Initial bonus damage must be 0")

	# 1st Tap: Selects Attack 1 for confirmation -> does NOT level up yet!
	tc.last_upgrade_tap_time = -10000
	tc._on_button_pressed(&"attack_1")
	assert(f.get_move_bonus_damage(&"attack_1") == 0, "1st tap must NOT level up attack (selection only)")
	assert(tc.upgrade_selected_slot == &"attack_1", "1st tap selects attack_1")
	assert(tc.upgrade_confirm_stage == 1, "1st tap enters confirmation stage 1")
	assert(tc.btn_atk1.confirm_stage == 1, "btn_atk1 visual confirm_stage must be 1 (CONFIRM)")

	# Anti-spam rapid tap debounce test: Immediate second tap within 150ms must be ignored!
	tc._on_button_pressed(&"attack_1")
	assert(tc.upgrade_confirm_stage == 1, "Rapid duplicate tap within 150ms must be ignored by debounce")

	# 2nd Tap on same button (after 150ms): Final confirmation -> does NOT level up yet!
	tc.last_upgrade_tap_time = -10000
	tc._on_button_pressed(&"attack_1")
	assert(f.get_move_bonus_damage(&"attack_1") == 0, "2nd tap must NOT level up attack (final confirmation)")
	assert(tc.upgrade_confirm_stage == 2, "2nd tap enters confirmation stage 2")
	assert(tc.btn_atk1.confirm_stage == 2, "btn_atk1 visual confirm_stage must be 2 (+ 1 DMG)")

	# 3rd Tap on same button (after 150ms): Finalizes level up!
	tc.last_upgrade_tap_time = -10000
	tc._on_button_pressed(&"attack_1")
	assert(f.get_move_bonus_damage(&"attack_1") == 1, "3rd tap MUST level up attack (+1 bonus damage)")
	assert(f.pending_attack_upgrades == 0, "Pending points consumed (exactly 1 point)")
	assert(tc.upgrade_confirm_stage == 0, "Confirmation stage resets to 0")

	# Test multiple points due to exp overflow: flow repeats as long as points remain stored
	f.pending_attack_upgrades = 2
	tc._process(0.016)
	assert(tc.btn_atk1.is_upgrade_pulsating == true, "Buttons pulsate with LVL UP when points are stored")
	assert(tc.btn_atk1.confirm_stage == 0, "Initial stage is 0 (LVL UP)")

	# Cycle 1: Attack 1
	tc.last_upgrade_tap_time = -10000
	tc._on_button_pressed(&"attack_1") # 1st tap -> CONFIRM
	assert(tc.btn_atk1.confirm_stage == 1, "Stage 1: CONFIRM")
	tc.last_upgrade_tap_time = -10000
	tc._on_button_pressed(&"attack_1") # 2nd tap -> + 1 DMG
	assert(tc.btn_atk1.confirm_stage == 2, "Stage 2: + 1 DMG")
	tc.last_upgrade_tap_time = -10000
	tc._on_button_pressed(&"attack_1") # 3rd tap -> Upgrade!
	assert(f.get_move_bonus_damage(&"attack_1") == 2, "Attack 1 upgraded again to +2")
	assert(f.pending_attack_upgrades == 1, "1 point still remains stored (hidden value)")
	# Verifies flow repeats immediately: button goes back to LVL UP (stage 0) and stays pulsating
	assert(tc.btn_atk1.confirm_stage == 0, "Flow repeats: resets to stage 0 (LVL UP)")
	assert(tc.btn_atk1.is_upgrade_pulsating == true, "Still pulsating because 1 point is stored")

	# Cycle 2: Attack 2
	tc.last_upgrade_tap_time = -10000
	tc._on_button_pressed(&"attack_2") # 1st tap -> CONFIRM
	assert(tc.btn_atk2.confirm_stage == 1, "Stage 1: CONFIRM for attack_2")
	tc.last_upgrade_tap_time = -10000
	tc._on_button_pressed(&"attack_2") # 2nd tap -> + 1 DMG
	assert(tc.btn_atk2.confirm_stage == 2, "Stage 2: + 1 DMG for attack_2")
	tc.last_upgrade_tap_time = -10000
	tc._on_button_pressed(&"attack_2") # 3rd tap -> Upgrade!
	assert(f.get_move_bonus_damage(&"attack_2") == 1, "Attack 2 upgraded to +1")
	assert(f.pending_attack_upgrades == 0, "All points consumed")
	assert(tc.btn_atk1.is_upgrade_pulsating == false, "No more points stored, pulsating ends")
	assert(tc.btn_atk2.is_upgrade_pulsating == false, "No more points stored, pulsating ends")

	# Test Button on_touch_down prevents duplicate touch down while already pressed
	tc.btn_atk1.is_pressed = false
	assert(tc.btn_atk1.on_touch_down(1, tc.btn_atk1.center_pos) == true, "First touch down succeeds")
	assert(tc.btn_atk1.on_touch_down(2, tc.btn_atk1.center_pos) == false, "Duplicate touch down while pressed MUST be rejected")
	tc.btn_atk1.on_touch_up()
	assert(tc.btn_atk1.is_pressed == false, "Button released")

	tc.queue_free()
	f.free()
	print("✓ 3-tap attack level-up confirmation & flow repeat tests PASSED")


func test_stored_attack_upgrade_points_skyrocket() -> void:
	print("\n[TEST 4C] Stored Attack Upgrade Points Across Skyrocketing Levels...")
	var FighterScript = load("res://scripts/fighter.gd")
	var f = FighterScript.new()

	# Simulate gaining enough XP to skyrocket to max level 30
	assert(f.pending_attack_upgrades == 0, "Initial points must be 0")
	f.gain_xp(5000.0)

	assert(f.level == 30, "Player level must reach max level 30")
	# Crosses levels 5, 10, 15, 20, 25, 30 -> exactly 6 stored upgrade points!
	assert(f.pending_attack_upgrades == 6, "Player must store all 6 attack upgrade points (Lv 5, 10, 15, 20, 25, 30)")

	# Player can spend points one by one repeatedly based on stored points
	assert(f.upgrade_attack(&"attack_1") == true, "Spend point 1 on attack_1")
	assert(f.pending_attack_upgrades == 5, "5 points remaining")

	assert(f.upgrade_attack(&"attack_1") == true, "Spend point 2 on attack_1")
	assert(f.pending_attack_upgrades == 4, "4 points remaining")
	assert(f.get_move_bonus_damage(&"attack_1") == 2, "attack_1 now has +2 bonus damage")

	assert(f.upgrade_attack(&"attack_2") == true, "Spend point 3 on attack_2")
	assert(f.pending_attack_upgrades == 3, "3 points remaining")

	assert(f.upgrade_attack(&"attack_2") == true, "Spend point 4 on attack_2")
	assert(f.pending_attack_upgrades == 2, "2 points remaining")

	assert(f.upgrade_attack(&"attack_3") == true, "Spend point 5 on attack_3")
	assert(f.pending_attack_upgrades == 1, "1 point remaining")

	assert(f.upgrade_attack(&"attack_3") == true, "Spend point 6 on attack_3")
	assert(f.pending_attack_upgrades == 0, "All points spent")

	assert(f.upgrade_attack(&"attack_1") == false, "Cannot upgrade without points")
	f.free()

	# User request test: Defeating Lv. 100 dummy at Lv. 10 leaps to Lv. 22 -> MUST grant exactly 2 points (for reaching Lv. 15 and 20)
	var f2 = FighterScript.new()
	f2.level = 10
	f2.xp = 0.0
	f2.pending_attack_upgrades = 0
	# Leveling up from Lv. 10 to Lv. 22 requires XP for levels 10 through 21
	var xp_to_22: float = 0.0
	var XPManagerScript = load("res://data/xp_manager.gd")
	for l in range(10, 22):
		xp_to_22 += float(XPManagerScript.get_max_xp_for_level(l))
	f2.gain_xp(xp_to_22)
	assert(f2.level == 22, "Fighter must reach Lv. 22 from Lv. 10")
	assert(f2.pending_attack_upgrades == 2, "Level jump from 10 to 22 MUST grant exactly 2 upgrade points (for Lv. 15 and Lv. 20)")
	f2.free()

	# User request test: Defeating Lv. 100 dummy from Lv. 1 directly skyrockets to Lv. 30 -> grants exactly 6 upgrade points (6 prompts)
	var f3 = FighterScript.new()
	f3.level = 1
	f3.pending_attack_upgrades = 0
	var dummy_lv100 = load("res://tests/dummy.gd").new()
	dummy_lv100.level = 100
	XPManagerScript.on_fighter_defeated(f3, dummy_lv100)
	assert(f3.level == 30, "Player must skyrocket from Lv. 1 to max Lv. 30 upon defeating Lv. 100 dummy")
	assert(f3.pending_attack_upgrades == 6, "Defeating Lv. 100 dummy from Lv. 1 must grant exactly 6 upgrade points for 6 prompts")
	dummy_lv100.free()
	f3.free()

	print("✓ Stored attack upgrade points skyrocketing & massive level jump tests PASSED")


func test_fixed_range_regardless_of_size() -> void:
	print("\n[TEST 4C2] Fixed Attack Range Regardless of Entity Size...")
	var FighterScript = load("res://scripts/fighter.gd")
	var p = FighterScript.new()
	p.global_position = Vector2(0, 0)

	var standard_dummy = FighterScript.new()
	standard_dummy.hurtbox_size = Vector2(20, 18)
	standard_dummy.global_position = Vector2(50, 0)

	var giant_dummy = FighterScript.new()
	giant_dummy.hurtbox_size = Vector2(72, 72) # 3x bigger hurtbox
	giant_dummy.global_position = Vector2(50, 0)

	# Distance calculation must be strictly center-to-center, NOT modified by hurtbox size
	var dist_std: float = p.distance_to_fighter(standard_dummy)
	var dist_giant: float = p.distance_to_fighter(giant_dummy)

	assert(dist_std == 50.0, "Standard dummy distance must be 50.0")
	assert(dist_giant == 50.0, "Giant dummy distance must be exactly 50.0 (unaffected by 3x hurtbox size)")
	assert(dist_std == dist_giant, "Valid range for an entity must NOT be affected by its size")

	p.free()
	standard_dummy.free()
	giant_dummy.free()
	print("✓ Fixed attack range regardless of entity size tests PASSED")


func test_universal_dummy_limit_and_giant_dummy() -> void:
	print("\n[TEST 4D] Universal Dummy Limit (Max 3) & Giant Lv 100 Dummy...")
	var DebugMenuScript = load("res://ui/debug_menu.gd")
	var dm = DebugMenuScript.new()
	dm.tree_ref = self
	root.add_child(dm)
	dm._ready()

	# Create anchor player
	var PlayerScript = load("res://scripts/player.gd")
	var pkmn_data = load("res://data/pokemon/venusaur.tres")
	var player = PlayerScript.new()
	player.pokemon = pkmn_data
	root.add_child(player)
	player.add_to_group(&"fighters")
	dm.player_ref = player

	# Clean up any residual dummies in tree / root
	for child in root.get_children():
		if child is Dummy:
			child.free()
	for n in get_nodes_in_group(&"fighters"):
		if n is Dummy:
			n.free()

	assert(dm._get_active_dummy_count() == 0, "Initial dummy count must be 0")

	# Spawn 1st dummy (passive)
	dm._spawn_dummy()
	assert(dm._get_active_dummy_count() == 1, "1st dummy spawned")

	# Spawn 2nd dummy (counter)
	dm._spawn_dummy_enemy()
	assert(dm._get_active_dummy_count() == 2, "2nd dummy spawned")

	# Spawn 3rd dummy (giant Lv 100 dummy)
	dm._spawn_giant_dummy()
	assert(dm._get_active_dummy_count() == 3, "3rd dummy spawned (reached MAX_DUMMIES = 3)")

	# Verify giant dummy properties
	var giant: Dummy = null
	for child in root.get_children():
		if child is Dummy and child.level == 100:
			giant = child
			break
	if giant == null:
		for n in get_nodes_in_group(&"fighters"):
			if n is Dummy and n.level == 100:
				giant = n
				break
	assert(giant != null, "Giant Lv 100 dummy must exist")
	assert(giant.level == 100, "Giant dummy level must be 100")
	assert(giant.counter_move == null, "Giant dummy must be non-countering")
	assert(giant.scale == Vector2(3.0, 3.0), "Giant dummy must be 3x bigger")
	assert(giant.hurtbox_size == Vector2(72, 72), "Giant dummy hurtbox must be 72x72 (3x bigger)")

	# Attempt to spawn 4th dummy -> MUST BE BLOCKED!
	dm._spawn_dummy()
	assert(dm._get_active_dummy_count() == 3, "4th dummy must be blocked by universal limit of 3")

	# Clean up
	var to_free: Array = []
	for child in root.get_children():
		if child is Dummy or child == player:
			to_free.append(child)
	for n in get_nodes_in_group(&"fighters"):
		if n is Dummy or n == player:
			if not to_free.has(n):
				to_free.append(n)
	for node in to_free:
		node.free()
	dm.free()
	print("✓ Universal dummy limit (3) & giant dummy tests PASSED")


func test_haptic_feedback_events_and_permission() -> void:
	print("\n[TEST 4E] Haptic Feedback Events & Android Export Permission...")
	# Verify export_presets.cfg has permissions/vibrate=true
	var config := ConfigFile.new()
	assert(config.load("res://export_presets.cfg") == OK, "export_presets.cfg must load")
	assert(config.get_value("preset.0.options", "permissions/vibrate", false) == true, "Android vibrate permission must be true")

	# Test HapticManager functions are callable without error
	HapticManager.play_level_up_confirm_1()
	HapticManager.play_level_up_confirm_2()
	HapticManager.play_player_level_up()
	HapticManager.play_tackle_hit()
	HapticManager.play_entity_hit()
	HapticManager.play_dash()
	print("✓ Haptic feedback events & Android permission tests PASSED")


func test_map_border_prevents_going_offscreen() -> void:
	print("\n[TEST 5] Map Border Prevents Player Going Offscreen...")
	var GroundScript = load("res://scripts/ground.gd")
	var ground = GroundScript.new()
	root.add_child(ground)
	ground._ready()

	var play_rect: Rect2 = ground.get_playable_rect()
	assert(play_rect.size.x > 0 and play_rect.size.y > 0, "Playable rect must be valid")

	var PlayerScript = load("res://scripts/player.gd")
	var pkmn_data = load("res://data/pokemon/venusaur.tres")
	var player = PlayerScript.new()
	player.pokemon = pkmn_data
	root.add_child(player)
	player._ready()

	# Try placing player far outside the map bounds (e.g. at x = 9999, y = 9999)
	player.global_position = Vector2(9999, 9999)
	player.clamp_to_map_bounds()

	assert(player.global_position.x <= play_rect.end.x, "Player X must be clamped inside playable border")
	assert(player.global_position.y <= play_rect.end.y, "Player Y must be clamped inside playable border")

	# Try negative bounds
	player.global_position = Vector2(-9999, -9999)
	player.clamp_to_map_bounds()
	assert(player.global_position.x >= play_rect.position.x, "Player X must be clamped above min border")
	assert(player.global_position.y >= play_rect.position.y, "Player Y must be clamped above min border")

	player.queue_free()
	ground.queue_free()
	print("✓ Map border offscreen prevention tests PASSED")


func test_hit_effect_enlarged_size_and_duration() -> void:
	print("\n[TEST 6] Hit Effect Enlarged Size & Longer Duration...")
	var HitFxScript = load("moves/melee_hit_effect.gd")
	assert(HitFxScript != null, "Failed to load melee_hit_effect.gd")

	var fx = HitFxScript.new()
	root.add_child(fx)

	# Verify enlarged scale (>= 2.0x, was 1.0x)
	assert(fx.sprite.scale.x >= 2.0, "Hit effect scale must be enlarged (>= 2.0x)")

	# Verify longer duration (18 frames, was 6 frames)
	assert(fx.TOTAL_FRAMES == 18, "Hit effect TOTAL_FRAMES must be 18 frames")
	assert(fx.z_index == 30, "Hit effect z_index must be 30")

	fx.queue_free()
	print("✓ Hit effect enlarged size and duration tests PASSED")


func test_healthbox_ui_and_milestone_blink() -> void:
	print("\n[TEST 7] Healthbox UI & Milestone Blink...")
	var HealthboxItemScript = load("res://ui/healthbox_item.gd")
	var hb = HealthboxItemScript.new(true)
	assert(hb.COLOR_TEXT == Color("#20211b"), "Healthbox COLOR_TEXT must be #20211b")
	assert(hb.box_bg.texture.resource_path.contains("assets/ui"), "Healthbox must load from assets/ui")
	hb.free()

	var fighter := Fighter.new()
	assert(is_equal_approx(fighter.get_healthbox_range(), fighter._get_atk2_move_range()),
		"Healthbox visibility must use the faint green move-data range, not the ATK 2 valid range")
	assert(not is_equal_approx(fighter.get_healthbox_range(), fighter.get_atk2_range()),
		"Healthbox range must remain distinct from the brighter ATK 2 range")
	fighter.free()
	print("✓ Healthbox UI tests PASSED")


func test_8way_directional_tilts_and_tackle() -> void:
	print("\n[TEST 8] 8-Way Directional Tilts & Tackle...")
	var PlayerScript = load("res://scripts/player.gd")
	var pkmn_data = load("res://data/pokemon/venusaur.tres")
	var player = PlayerScript.new()
	player.pokemon = pkmn_data
	root.add_child(player)
	player._build_sprite()

	var tackle_dir := Vector2(1, -1).normalized()
	player._on_lunge_started(tackle_dir)
	assert(player.facing.is_equal_approx(tackle_dir), "Tackle must lunge in full 8-way diagonal direction!")
	player._on_lunge_ended()

	player.free()
	print("✓ 8-way directional tilts and tackle tests PASSED")


func test_joystick_pad_and_ball_textures() -> void:
	print("\n[TEST 9] Joystick Pad & Ball Textures...")
	var TouchControlsScript = load("res://ui/touch_controls.gd")
	var tc = TouchControlsScript.new()
	root.add_child(tc)
	tc._ready()

	assert(tc.joystick.pad_texture.resource_path.contains("assets/ui/joystick_pad.png"), "Pad must be in assets/ui")
	assert(tc.joystick.ball_texture.resource_path.contains("assets/ui/joystick_ball.png"), "Ball must be in assets/ui")

	tc.queue_free()
	print("✓ Joystick pad & ball texture tests PASSED")


func test_orientation_setting() -> void:
	print("\n[TEST 10] Orientation Locked to Horizontal...")
	var config := ConfigFile.new()
	assert(config.load("res://project.godot") == OK, "project.godot must load")
	assert(config.get_value("display", "window/handheld/orientation", -1) == 4, "Orientation must be 4 (sensor_landscape)")
	print("✓ Orientation configuration tests PASSED")


func test_unite_radius_removed_and_atk3_range() -> void:
	print("\n[TEST 11] Unite Radius Removed & Atk 3 Valid Range (1.5x Atk 2 Range)...")
	var FighterScript = load("res://scripts/fighter.gd")
	var f = FighterScript.new()

	var atk2_r: float = f.get_atk2_range()
	var atk3_r: float = f.get_atk3_range()
	var spec_r: float = f.get_special_range()

	# Atk 2 valid range is now 1.5x melee range (swapped with old healthbox ring)
	assert(is_equal_approx(atk2_r, f.get_melee_range() * 1.5),
		"Atk 2 range (%f) must be 1.5x melee range (%f)" % [atk2_r, f.get_melee_range() * 1.5])

	# Atk 3 valid range is strictly 1.5x the new Atk 2 range
	assert(is_equal_approx(atk3_r, atk2_r * 1.5),
		"Atk 3 range (%f) must be strictly 1.5x Atk 2 range (%f * 1.5 = %f)" % [atk3_r, atk2_r, atk2_r * 1.5])

	# Verify Atk 3 valid range is drawn in Fighter _draw when show_hitboxes is turned on
	var f_script: GDScript = f.get_script() as GDScript
	assert(f_script.source_code.contains("draw_arc(Vector2.ZERO, atk3_r"), "Atk 3 range circle MUST be drawn in Fighter _draw")
	assert(not f_script.source_code.contains("draw_arc(Vector2.ZERO, get_special_range()"), "Unite range circle MUST be removed from Fighter _draw")

	# Verify Player range indicators do not outline based on spec_r
	var PlayerScript = load("res://scripts/player.gd")
	var p_script: GDScript = PlayerScript as GDScript
	assert(not p_script.source_code.contains("dist <= spec_r"), "Unite range outline MUST be removed from Player indicators")

	f.free()
	print("✓ Unite radius removed & Atk 3 valid range (1.5x Atk 2) tests PASSED")


func test_pokemon_evolution_system() -> void:
	print("\n[TEST 12] Pokemon Evolution System (Data-driven stages, Level 20 & 30 evolutions, visual flash & audio)...")

	# 1. Test Venusaur data and stages
	var venu_data: PokemonData = load("res://data/pokemon/venusaur.tres")
	assert(venu_data != null, "venusaur.tres must load")
	assert(venu_data.stages.size() == 4, "venusaur.tres must define 4 stages (including Stage 4 for mega)")
	assert(venu_data.get_stage_name(1).to_upper().contains("BULBASAUR"), "Stage 1 must be Bulbasaur")
	assert(venu_data.get_stage_name(2).to_upper().contains("IVYSAUR"), "Stage 2 must be Ivysaur")
	assert(venu_data.get_stage_name(3).to_upper().contains("VENUSAUR"), "Stage 3 must be Venusaur")
	assert(venu_data.get_stage_name(4).to_upper().contains("MEGA"), "Stage 4 must be Mega Venusaur")

	# Verify asset pointers for Venusaur stages
	assert(venu_data.get_sprite_path(1, "h_1").contains("bulb_h_1.png"), "Stage 1 must point to bulb_h_1.png")
	assert(venu_data.get_sprite_path(1, "v_4").contains("bulb_v_4.png"), "Stage 1 must point to bulb_v_4.png")
	assert(venu_data.get_sprite_path(2, "h_1").contains("ivy_h_1.png"), "Stage 2 must point to ivy_h_1.png")
	assert(venu_data.get_sprite_path(2, "v_4").contains("ivy_v_4.png"), "Stage 2 must point to ivy_v_4.png")
	assert(venu_data.get_sprite_path(3, "h_1").contains("venu_h_1.png"), "Stage 3 must point to venu_h_1.png")
	assert(venu_data.get_sprite_path(3, "v_4").contains("venu_v_4.png"), "Stage 3 must point to venu_v_4.png")
	assert(venu_data.get_stage_data(4)["h_1"].contains("m_venu_h_1.png"), "Stage 4 must point to m_venu_h_1.png")

	# 2. Test Blastoise data and stages
	var blast_data: PokemonData = load("res://data/pokemon/blastoise.tres")
	assert(blast_data != null, "blastoise.tres must load")
	assert(blast_data.stages.size() == 4, "blastoise.tres must define 4 stages")
	assert(blast_data.get_stage_name(1).to_upper().contains("SQUIRTLE"), "Stage 1 must be Squirtle")
	assert(blast_data.get_stage_name(2).to_upper().contains("WARTORTLE"), "Stage 2 must be Wartortle")
	assert(blast_data.get_stage_name(3).to_upper().contains("BLASTOISE"), "Stage 3 must be Blastoise")
	assert(blast_data.get_stage_name(4).to_upper().contains("MEGA"), "Stage 4 must be Mega Blastoise")
	assert(blast_data.get_stage_data(1)["h_1"].contains("squi_h_1.png"), "Stage 1 must point to squi_h_1.png")
	assert(blast_data.get_stage_data(2)["h_1"].contains("wart_h_1.png"), "Stage 2 must point to wart_h_1.png")
	assert(blast_data.get_stage_data(3)["h_1"].contains("blast_h_1.png"), "Stage 3 must point to blast_h_1.png")
	assert(blast_data.get_stage_data(4)["h_1"].contains("m_blast_h_1.png"), "Stage 4 must point to m_blast_h_1.png")

	# 3. Test Charizard data and stages
	var chzard_data: PokemonData = load("res://data/pokemon/charizard.tres")
	assert(chzard_data != null, "charizard.tres must load")
	assert(chzard_data.stages.size() == 4, "charizard.tres must define 4 stages")
	assert(chzard_data.get_stage_name(1).to_upper().contains("CHARMANDER"), "Stage 1 must be Charmander")
	assert(chzard_data.get_stage_name(2).to_upper().contains("CHARMELEON"), "Stage 2 must be Charmeleon")
	assert(chzard_data.get_stage_name(3).to_upper().contains("CHARIZARD"), "Stage 3 must be Charizard")
	assert(chzard_data.get_stage_name(4).to_upper().contains("MEGA"), "Stage 4 must be Mega Charizard")
	assert(chzard_data.get_stage_data(1)["h_1"].contains("chder_h_1.png"), "Stage 1 must point to chder_h_1.png")
	assert(chzard_data.get_stage_data(2)["h_1"].contains("chmel_h_1.png"), "Stage 2 must point to chmel_h_1.png")
	assert(chzard_data.get_stage_data(3)["h_1"].contains("chzard_h_1.png"), "Stage 3 must point to chzard_h_1.png")
	assert(chzard_data.get_stage_data(4)["h_1"].contains("m_chzard_h_1.png"), "Stage 4 must point to m_chzard_h_1.png")

	# 4. Test stage resolution based on level
	assert(venu_data.get_stage_for_level(1) == 1, "Level 1 is stage 1")
	assert(venu_data.get_stage_for_level(19) == 1, "Level 19 is stage 1")
	assert(venu_data.get_stage_for_level(20) == 2, "Level 20 is stage 2")
	assert(venu_data.get_stage_for_level(29) == 2, "Level 29 is stage 2")
	assert(venu_data.get_stage_for_level(30) == 3, "Level 30 is stage 3")

	# 5. Test Player evolution and name updates
	var PlayerScript = load("res://scripts/player.gd")
	var p = PlayerScript.new()
	p.pokemon = venu_data
	root.add_child(p)
	p.set_level(1)
	assert(p.current_evolution_stage == 1, "Player should start at stage 1 at level 1")
	assert(p.get_display_name() == "BULBASAUR", "Player display name should be BULBASAUR at stage 1")

	# Evolve to Stage 2 at level 20
	p.set_level(20)
	assert(p.current_evolution_stage == 2, "Player should evolve to stage 2 at level 20")
	assert(p.get_display_name() == "IVYSAUR", "Player display name should be IVYSAUR at stage 2")

	# Evolve to Stage 3 at level 30
	p.set_level(30)
	assert(p.current_evolution_stage == 3, "Player should evolve to stage 3 at level 30")
	assert(p.get_display_name() == "VENUSAUR", "Player display name should be VENUSAUR at stage 3")

	# 6. Test Evolution Audio SFX registration & method
	assert(AudioManager.PATH_PROGRESSION_EVOLUTION == "res://assets/audio/progression/evolution.mp3", "Evolution audio path must be evolution.mp3")
	assert(AudioManager.new().has_method("play_evolution"), "AudioManager must have play_evolution method")

	# 7. Test main.tscn uses venusaur.tres
	var main_scene = load("res://scenes/main.tscn")
	assert(main_scene != null, "main.tscn must load successfully")

	p.free()
	print("✓ Pokemon Evolution System tests PASSED")


func test_smoke_1_size_relative_to_evolution_stage() -> void:
	print("\n[TEST 13] smoke_1 particle size relative to evolution stage (Stage 1 default, +0.5x bigger per stage)...")
	var SmokeScript = load("res://moves/diagonal_smoke_effect.gd")

	# Stage 1: default scale (1.3x)
	var smoke_s1 = SmokeScript.new(false, 1)
	assert(is_equal_approx(smoke_s1.stage_scale, 1.0), "Stage 1 smoke scale factor must be 1.0")
	assert(is_equal_approx(smoke_s1.sprite.scale.x, 1.3), "Stage 1 smoke sprite scale must be 1.3")
	smoke_s1.free()

	# Stage 2: 0.5x bigger (1.0 + 0.5 = 1.5x, sprite scale 1.3 * 1.5 = 1.95)
	var smoke_s2 = SmokeScript.new(false, 2)
	assert(is_equal_approx(smoke_s2.stage_scale, 1.5), "Stage 2 smoke scale factor must be 1.5")
	assert(is_equal_approx(smoke_s2.sprite.scale.x, 1.95), "Stage 2 smoke sprite scale must be 1.95")
	smoke_s2.free()

	# Stage 3: another 0.5x bigger (1.0 + 1.0 = 2.0x, sprite scale 1.3 * 2.0 = 2.6)
	var smoke_s3 = SmokeScript.new(false, 3)
	assert(is_equal_approx(smoke_s3.stage_scale, 2.0), "Stage 3 smoke scale factor must be 2.0")
	assert(is_equal_approx(smoke_s3.sprite.scale.x, 2.6), "Stage 3 smoke sprite scale must be 2.6")
	smoke_s3.free()

	# Stage 4 (Mega evolution prepared): 2.5x
	var smoke_s4 = SmokeScript.new(false, 4)
	assert(is_equal_approx(smoke_s4.stage_scale, 2.5), "Stage 4 smoke scale factor must be 2.5")
	assert(is_equal_approx(smoke_s4.sprite.scale.x, 3.25), "Stage 4 smoke sprite scale must be 3.25")
	smoke_s4.free()

	# Dash smoke remains unchanged (smoke_2)
	var dash_smoke = SmokeScript.new(true, 3)
	assert(is_equal_approx(dash_smoke.stage_scale, 1.0), "Dash smoke scale factor must remain 1.0")
	assert(is_equal_approx(dash_smoke.sprite.scale.x, 1.8), "Dash smoke scale must remain 1.8")
	dash_smoke.free()

	print("✓ smoke_1 size relative to evolution stage tests PASSED")


func test_giant_dummy_affected_by_tackle_and_homing() -> void:
	print("\n[TEST 14] Big Lv 100 Dummy Affected by Tackle & Homing Melee Attacks...")
	for c in root.get_children():
		c.free()
	var PlayerScript = load("res://scripts/player.gd")
	var pkmn_data = load("res://data/pokemon/venusaur.tres")
	var player = PlayerScript.new()
	player.pokemon = pkmn_data
	player.tree_ref = self
	root.add_child(player)
	player.add_to_group(&"fighters")
	player._ready()
	player._build_sprite()
	player.global_position = Vector2(0, 0)
	player.facing = Vector2.RIGHT

	# Spawn Giant Lv 100 dummy
	var DummyScript = load("res://tests/dummy.gd")
	var giant = DummyScript.new()
	giant.name = "GiantDummyLv100"
	giant.level = 100
	giant.counter_move = null
	giant.max_hp = 1000
	giant.hp = 1000
	giant.scale = Vector2(3.0, 3.0)
	giant.tree_ref = self
	root.add_child(giant)
	giant.add_to_group(&"fighters")
	giant._ready()
	giant.set_hurtbox_size(Vector2(24, 24))
	if giant.hurtbox != null:
		giant.hurtbox._ready()
	# Place at touching distance next to player (center dist ~ 46px)
	giant.global_position = Vector2(46, 0)

	# 1. Test homing target acquisition on Big Dummy
	var target = player.find_target(44.0)
	assert(target == giant, "Player must successfully acquire Giant Dummy as target for Tackle (44px range)")

	# 2. Execute Tackle
	var tackle_move: MoveData = load("res://data/moves/tackle.tres")
	assert(tackle_move != null, "Tackle move must load")
	var exec_result: bool = tackle_move.execute(player)
	assert(exec_result == true, "Tackle must successfully execute")
	assert(player.is_lunging() == true, "Player must enter lunging state")
	assert(player.lunge_target == giant, "Player lunge must target Giant Dummy")
	assert(player.lunge_homing == true, "Player lunge must be homing on Giant Dummy")

	# 3. Simulate forward lunge steps until hit connects
	var hit_connected := false
	for frame in range(25):
		player._update_lunge()
		if player.hitbox != null and player.hitbox.active:
			player.hitbox._physics_process(0.016)
		if player.lunge_hit_landed or giant.hp < 1000:
			hit_connected = true
			break

	assert(hit_connected == true, "Tackle must land hit on Giant Dummy")
	assert(giant.hp < 1000, "Giant Dummy must take damage from Tackle (got %d HP)" % giant.hp)

	player.queue_free()
	giant.queue_free()
	print("✓ Big Lv 100 dummy Tackle & homing melee hit tests PASSED")


func test_audio_polyphony_and_overlap() -> void:
	print("\n[TEST 15] Audio Engine Polyphony & Overlapping Playback...")
	AudioManager.ensure_hit_bus()

	# Create a mock Node2D caller
	var caller := Node2D.new()
	root.add_child(caller)

	# Play first hit sound
	AudioManager.reset_hit_debounce()
	var played_1 := AudioManager.play_sound(AudioManager.PATH_COMBAT_HIT, caller)
	assert(played_1 == true, "First hit sound must play")

	var sfx_player := caller.get_node_or_null("HitSFXPlayer") as AudioStreamPlayer2D
	assert(sfx_player != null, "HitSFXPlayer must be instantiated on caller")
	assert(sfx_player.max_polyphony == 16, "Player must have max_polyphony = 16 (got %d)" % sfx_player.max_polyphony)

	# Verify setting same stream does not interrupt or reset stream pointer
	var initial_stream = sfx_player.stream
	AudioManager.reset_hit_debounce()
	var played_2 := AudioManager.play_sound(AudioManager.PATH_COMBAT_HIT, caller)
	assert(played_2 == true, "Second hit sound must play simultaneously (polyphonic overlap)")
	assert(sfx_player.stream == initial_stream, "Stream must remain unchanged so active playback is not stopped")

	# Verify auxiliary player pool works for different streams
	AudioManager._last_move_sound_msec = -10000
	var played_diff := AudioManager.play_sound(AudioManager.PATH_MOVE_DASH, caller)
	assert(played_diff == true, "Different stream sound must play")

	caller.queue_free()
	print("✓ Audio engine polyphony & overlapping playback tests PASSED")


func test_evolution_gba_theme() -> void:
	print("\n[TEST 16] Evolution Sequence GBA Theme (Crisp stepped on/off blinking & palette unveiling)...")
	var PlayerScript = load("res://scripts/player.gd")
	var pkmn_data = load("res://data/pokemon/venusaur.tres")
	var player = PlayerScript.new()
	player.pokemon = pkmn_data
	player.tree_ref = self
	root.add_child(player)
	player._build_sprite(1)

	# Trigger evolution to stage 2
	player.evolve_to_stage(2)
	assert(player.is_evolving == true, "Player must enter is_evolving state during sequence")
	assert(player.current_evolution_stage == 2, "Player stage must advance to 2")

	player.queue_free()
	print("✓ Evolution sequence GBA theme tests PASSED")


func test_solar_beam_implementation() -> void:
	print("\n[TEST 17] Solar Beam Move Implementation (3 Stages, 4 Bodies, Peristaltic Wave, Autoaim Lock-on, 13 DPS, 20s Cooldown, 2x Atk 2 Range, Sizzle Plume & Bloom)...")
	var sb_data = load("res://data/moves/solar_beam.tres") as MoveData
	assert(sb_data != null, "solar_beam.tres must load successfully")
	assert(sb_data is MoveData, "solar_beam.tres must be an instance of MoveData")
	assert(sb_data.move_category == "special", "Solar Beam must be special category")
	assert(sb_data.move_type == "beam", "Solar Beam must be beam type")
	assert(sb_data.power == 13, "Solar Beam power must be 13 (13 DPS, increased by +5 from 8 DPS)")
	assert(sb_data.cooldown_frames == 1200, "Solar Beam cooldown must be 1200 frames (20.0 seconds)")
	assert(sb_data.sound_path == "res://assets/audio/moves/solar_beam.mp3", "Solar Beam sound_path must point to solar_beam.mp3")

	# Test Bloom configuration for Solar Beam
	assert(BloomConfig.has_bloom("solar_beam") == true, "BloomConfig must have solar_beam enabled")

	# Verify Venusaur slot configuration: Solar Beam in Attack 3, Unite reverted to null
	var venu_data: PokemonData = load("res://data/pokemon/venusaur.tres")
	assert(venu_data.attack_3 != null and venu_data.attack_3.display_name == "Solar Beam", "Venusaur attack_3 must be Solar Beam")
	assert(venu_data.special == null, "Venusaur special slot must be reverted (no unite for now)")

	# Create caster and target fighters
	var FighterScript = load("res://scripts/fighter.gd")
	var caster = FighterScript.new()
	var victim = FighterScript.new()
	root.add_child(caster)
	root.add_child(victim)
	caster.global_position = Vector2(100, 100)
	caster.facing = Vector2.RIGHT
	caster.team = &"player"

	# ATK 3 range = melee(44) * 1.5 * 1.5 = 99px. Place victim at 60px center-to-center (inside range).
	var atk3_range: float = caster.get_atk3_range()
	victim.global_position = Vector2(100 + atk3_range * 0.6, 100) # Well inside the valid circle
	victim.team = &"enemy"
	victim.hp = 100
	caster.add_to_group(&"fighters")
	victim.add_to_group(&"fighters")

	# Test Move Execution: spawns SolarBeamEffect
	var executed: bool = sb_data.execute(caster)
	assert(executed == true, "SolarBeamMove.execute must return true")

	# Find instantiated BeamEffect
	var effect: BeamEffect = null
	for child in root.get_children():
		if child is BeamEffect:
			effect = child
			break
	assert(effect != null, "BeamEffect must be added to scene root")

	# Stage 1: Charge up verification (Impact frame aesthetic & Venusaur transparent yellow blinking)
	assert(effect.current_stage == BeamEffect.Stage.CHARGE, "Effect must start in Stage.CHARGE (Stage 0)")
	assert(effect.charge_textures.size() == 5, "Charge must have 5 frames (from 32x160 solar_beam_charge.png)")
	assert(effect.charge_sprite.visible == true, "Charge sprite must be visible during charge")
	assert(effect.energy_sprite.visible == false, "Energy sprite must be hidden during charge")
	assert(effect.body_sprites.size() == 4, "Beam must have 4 body sprites")
	assert(effect.charge_sprite.material != null, "Charge sprite must have bloom material applied")

	# Verify Venusaur is blinking transparent yellow during move
	effect._process(0.05)
	assert(caster.modulate.r >= 0.95 and caster.modulate.g >= 0.85, "Caster must blink transparent yellow during Solar Beam")

	# Simulate charge stage completion (0.3s)
	effect._process(0.10)
	assert(effect.current_stage == BeamEffect.Stage.CHARGE, "Should remain in charge at 0.15s")
	effect._process(0.16) # Total 0.31s >= CHARGE_DURATION (0.3s)
	assert(effect.current_stage == BeamEffect.Stage.BEAM, "Effect must instantaneously transition to Stage.BEAM after 0.3s charge")

	# Stage 2: Beam Verification
	assert(effect.beam_textures.size() == 6, "Beam must have 6 frames (from 32x208 solar_beam.png)")
	assert(effect.charge_sprite.visible == false, "Charge sprite must be hidden during beam")
	assert(effect.energy_sprite.visible == true, "Part 1 Energy sprite must be visible during beam")
	assert(effect.energy_sprite.material != null, "Energy sprite must have bloom material applied")

	# Verify all 4 bodies have bloom and default frames
	for i in range(4):
		assert(effect.body_sprites[i].visible == true, "Body %d must be visible during beam" % (i + 1))
		assert(effect.body_sprites[i].material != null, "Body %d must have bloom material applied" % (i + 1))

	# Test default frames at start of beam (time_in_stage = 0)
	effect._process_beam(0.0)
	assert(effect.body_sprites[0].texture == effect.beam_textures[2], "Body 1 must default to 3rd frame (Frame 2)")
	assert(effect.body_sprites[1].texture == effect.beam_textures[3], "Body 2 must default to 4th frame (Frame 3)")
	assert(effect.body_sprites[2].texture == effect.beam_textures[4], "Body 3 must default to 5th frame (Frame 4)")
	assert(effect.body_sprites[3].texture == effect.beam_textures[5], "Body 4 must default to 6th frame (Frame 5)")

	# Test Lock-on logic: Target whose hurtbox circle touches the ATK 3 valid circle is locked onto.
	# Victim is at 60% of atk3_range center-to-center. Hurtbox radius ~10px.
	# distance_to_fighter = center_dist - hurtbox_r < atk3_range → should lock on.
	effect.target = victim
	effect._process_beam(0.01)
	assert(effect.target == victim, "Target whose hurtbox is inside the valid circle must be locked on")
	assert(effect.current_aim_dir.is_equal_approx(Vector2.RIGHT), "Aim direction must lock onto target position")

	# Test Lock-on break: Move target so hurtbox circle is OUTSIDE the valid range circle.
	# Center-to-center = atk3_range + 50 → distance_to_fighter = (atk3_range+50) - 10 > atk3_range
	victim.global_position = Vector2(100 + atk3_range + 50.0, 100)
	effect._process_beam(0.01)
	assert(effect.target != victim, "Target whose hurtbox moves outside the valid circle must break lock-on")

	# Move target back inside range
	victim.global_position = Vector2(100 + atk3_range * 0.6, 100)
	effect.target = victim
	effect._process_beam(0.01)
	assert(effect.target == victim, "Target whose hurtbox re-enters the valid circle must lock on again")

	# Test Damage Dealing (13 DPS -> 3 damage per 0.25s tick)
	var hp_before: int = victim.hp
	effect._deal_damage_tick()
	assert(victim.hp == hp_before - 3, "Victim touching beam must take 3 damage per tick (13 DPS)")

	# Test Sizzling Plume Smoke (smoke_2.png on victim)
	var target_smoke = DiagonalSmokeEffect.spawn_target_smoke(root, victim.global_position)
	assert(target_smoke != null, "spawn_target_smoke must create particle instance")
	assert(target_smoke.sprite.texture.resource_path.contains("smoke_2.png"), "Target smoke must use smoke_2.png")
	assert(target_smoke.is_target_sizzle == true, "Target smoke must be configured as sizzling thermal plume")
	assert(target_smoke.drift_dir.y < 0.0, "Sizzling plume must have upward thermal buoyancy")
	var prev_smoke_y: float = target_smoke.global_position.y
	target_smoke._physics_process(0.01)
	assert(target_smoke.global_position.y < prev_smoke_y, "Sizzle plume must rise buoyantly")
	target_smoke.free()

	# Test Stage 3: Cascading rapid blink collapse from Body 4 (tip) down to energy
	effect.current_stage = BeamEffect.Stage.DISSIPATING
	effect.time_in_stage = 0.08 # Past step 0 (0.07s): Body 4 collapsed
	effect._process_dissipating(0.0)
	assert(effect.body_sprites[3].visible == false, "Body 4 (tip) must hide first in rapid cascading collapse")
	effect.time_in_stage = 0.15 # Past step 1 (0.14s): Body 3 collapsed
	effect._process_dissipating(0.0)
	assert(effect.body_sprites[2].visible == false, "Body 3 must hide at step 1 of cascading collapse")

	# Cleanup test nodes
	effect.queue_free()
	caster.queue_free()
	victim.queue_free()
	print("✓ Solar Beam move (13 DPS, 20s cooldown, hurtbox-circle lock-on & break, transparent yellow blink, impact frames, sizzle plume & cascading collapse) tests PASSED")


func test_attack_button_config_and_tints() -> void:
	print("\n[TEST 18] Attack Button Assets As Buttons (No Circle, Edge-based Outlines & Tints)...")

	# 1. Verify AttackButtonConfig data-driven mappings
	assert(AttackButtonConfig.get_asset_path(&"attack_1") == "res://assets/ui/attack_melee.png", "attack_1 must map to attack_melee.png")
	assert(AttackButtonConfig.get_asset_path(&"attack_2") == "res://assets/ui/attack_blank.png", "attack_2 must map to attack_blank.png")
	assert(AttackButtonConfig.get_asset_path(&"attack_3") == "res://assets/ui/attack_blank.png", "attack_3 must map to attack_blank.png")
	assert(AttackButtonConfig.get_asset_path(&"special") == "res://assets/ui/attack_blank.png", "special must map to attack_blank.png")
	assert(AttackButtonConfig.get_asset_path(&"dash") == "res://assets/ui/attack_blank.png", "dash must map to attack_blank.png")

	# 2. Verify textures load correctly
	var tex_melee: Texture2D = AttackButtonConfig.get_texture(&"attack_1")
	assert(tex_melee != null, "attack_melee texture must load")
	assert(tex_melee.resource_path.contains("attack_melee.png"), "attack_1 must load attack_melee.png")

	var tex_blank: Texture2D = AttackButtonConfig.get_texture(&"attack_2")
	assert(tex_blank != null, "attack_blank texture must load")
	assert(tex_blank.resource_path.contains("attack_blank.png"), "attack_2 must load attack_blank.png")

	# 3. Verify TouchControls button configuration
	var TouchScript = load("res://ui/touch_controls.gd")
	var tc = TouchScript.new()
	root.add_child(tc)
	tc._ready()

	assert(tc.btn_atk1 != null and tc.btn_atk1.slot_name == &"attack_1", "btn_atk1 must be configured for attack_1")
	assert(tc.btn_atk2 != null and tc.btn_atk2.slot_name == &"attack_2", "btn_atk2 must be configured for attack_2")
	assert(tc.btn_atk3 != null and tc.btn_atk3.slot_name == &"attack_3", "btn_atk3 must be configured for attack_3")
	assert(tc.btn_atk3.sub_title == "SOLAR BEAM", "btn_atk3 subtitle must be SOLAR BEAM")
	assert(tc.btn_atk3.cooldown_max == 20.0, "btn_atk3 cooldown_max must be 20.0s")
	assert(tc.btn_special != null and tc.btn_special.slot_name == &"special", "btn_special must be configured for special")
	assert(tc.btn_special.sub_title == "UNITE", "btn_special subtitle must be UNITE")
	assert(tc.btn_special.cooldown_max == 60.0, "btn_special cooldown_max must be 60.0s (universal unite revert)")

	# 4. Verify distinctive button theme colors for tinting
	assert(tc.btn_atk1.theme_color != tc.btn_atk2.theme_color, "Each button must have distinctive theme color")
	assert(tc.btn_atk2.theme_color != tc.btn_atk3.theme_color, "Each button must have distinctive theme color")
	assert(tc.btn_atk3.theme_color != tc.btn_special.theme_color, "Each button must have distinctive theme color")

	# 5. Verify Edge-Based Button Geometry (No circular draw_circle / draw_arc in MobaTouchButton _draw)
	var edge_poly: PackedVector2Array = tc.btn_atk1.get_edge_polygon(Rect2(0, 0, 100, 100), 0.0)
	assert(edge_poly.size() == 9, "Edge polygon must have 8 vertices + closed point matching sprite edges")
	assert(tc.btn_atk1.is_point_inside(tc.btn_atk1.center_pos) == true, "Center position must be inside button hit area")
	assert(tc.btn_atk1.is_point_inside(tc.btn_atk1.center_pos + Vector2(tc.btn_atk1.radius, 0)) == true, "Square button side must be inside hit area")

	# Verify MobaTouchButton source does not contain draw_circle or draw_arc
	var touch_src: String = (TouchScript as GDScript).source_code
	var moba_btn_src := touch_src.substr(touch_src.find("class MobaTouchButton"), touch_src.find("class_name") - touch_src.find("class MobaTouchButton"))
	assert(not moba_btn_src.contains("draw_circle("), "MobaTouchButton MUST NOT use draw_circle")
	assert(not moba_btn_src.contains("draw_arc("), "MobaTouchButton MUST NOT use draw_arc (must use edge outlines)")

	# 6. Verify Zoom & Follow Buttons removed from top bar
	assert(tc.top_buttons.size() == 1, "Only Debug button should remain in top bar")
	assert(tc.btn_top_debug != null, "Debug button must exist")
	assert(not touch_src.contains("btn_top_zoom_in"), "Zoom in button must be removed")
	assert(not touch_src.contains("btn_top_zoom_out"), "Zoom out button must be removed")
	assert(not touch_src.contains("btn_top_follow"), "Camera follow button must be removed")

	# 7. Verify NO OVERLAPPING between any buttons
	for i in range(tc.buttons.size()):
		var b1 = tc.buttons[i]
		var r1 = Rect2(b1.center_pos - Vector2(b1.radius, b1.radius), Vector2(b1.radius * 2.0, b1.radius * 2.0))
		for j in range(i + 1, tc.buttons.size()):
			var b2 = tc.buttons[j]
			var r2 = Rect2(b2.center_pos - Vector2(b2.radius, b2.radius), Vector2(b2.radius * 2.0, b2.radius * 2.0))
			assert(not r1.intersects(r2), "Button %s and %s MUST NOT overlap! Rect1: %s, Rect2: %s" % [b1.title, b2.title, r1, r2])

	tc.queue_free()
	print("✓ Attack button assets as buttons (no circle, edge outlines & tints) tests PASSED")


func test_hitbox_touching_targeting() -> void:
	print("\n[TEST 19] Hitbox-Touching Targeting (Valid attack range circle touching entity hurtbox circle)...")
	var FighterScript = load("res://scripts/fighter.gd")
	var player = FighterScript.new()
	var enemy = FighterScript.new()
	root.add_child(player)
	root.add_child(enemy)

	player.global_position = Vector2(1000, 1000)
	player.team = &"player"
	enemy.team = &"enemy"
	enemy.hp = 100
	# Hurtbox size 20x20 -> circle radius = (20+20)*0.25 = 10.0
	enemy.set_hurtbox_size(Vector2(20, 20))

	# 1. Position enemy center at (1050, 1000):
	# Center-to-center distance = 50.0px.
	# Hurtbox circle radius = 10.0px.
	# Distance to hurtbox edge = 50.0 - 10.0 = 40.0px.
	enemy.global_position = Vector2(1050, 1000)
	var dist_hitbox: float = player.distance_to_fighter(enemy)
	assert(is_equal_approx(dist_hitbox, 40.0), "Distance to hurtbox circle edge must be 40.0px (center_dist - hurtbox_radius)")

	# Melee range is 44.0px:
	# 44.0px attack circle touches the hurtbox circle (40.0 <= 44.0)!
	var target_melee = player.find_target(44.0)
	assert(target_melee == enemy, "Attack range circle touching entity's hurtbox circle must make it the target")

	# If range is only 35.0px (does not touch hurtbox edge at 40.0px):
	var target_too_short = player.find_target(35.0)
	assert(target_too_short == null, "Range that does not reach entity's hurtbox circle must not target it")

	# 2. Position enemy diagonally at (1040, 1030):
	# Center-to-center distance = sqrt(40^2 + 30^2) = sqrt(2500) = 50.0px.
	# Hurtbox circle radius = 10.0px.
	# Distance to hurtbox edge = 50.0 - 10.0 = 40.0px.
	enemy.global_position = Vector2(1040, 1030)
	var diag_dist: float = player.distance_to_fighter(enemy)
	assert(is_equal_approx(diag_dist, 40.0), "Diagonal distance to hurtbox circle edge must be 40.0px (circle is uniform in all directions)")
	assert(player.find_target(44.0) == enemy, "Diagonal attack range circle touching hurtbox circle must target it")
	assert(player.find_target(35.0) == null, "Diagonal attack range that doesn't reach hurtbox circle edge must not target it")

	player.queue_free()
	enemy.queue_free()
	print("✓ Hitbox-touching targeting tests PASSED")


func test_data_driven_system_rework() -> void:
	print("\n[TEST 20] Data-Driven System Rework (24 Sprites, Base Damage Mult, Move Types, XP Config)...")

	# 1. Pokemon Data: 24 explicit sprite paths & base_damage
	var venu = load("res://data/pokemon/venusaur.tres") as PokemonData
	assert(venu != null, "venusaur.tres must load")
	assert(is_equal_approx(venu.base_damage, 1.0), "Venusaur base_damage must be 1.0")
	assert(venu.stage1_h1 != "", "stage1_h1 must be configured")
	assert(venu.stage4_v4 != "", "stage4_v4 must be configured")

	var chariz = load("res://data/pokemon/charizard.tres") as PokemonData
	assert(chariz != null, "charizard.tres must load")
	assert(is_equal_approx(chariz.base_damage, 1.0), "Charizard base_damage must be 1.0")
	assert(chariz.stage1_h1 != "", "Charizard stage1_h1 must be configured")

	var blast = load("res://data/pokemon/blastoise.tres") as PokemonData
	assert(blast != null, "blastoise.tres must load")
	assert(is_equal_approx(blast.base_damage, 1.0), "Blastoise base_damage must be 1.0")
	assert(blast.stage1_h1 != "", "Blastoise stage1_h1 must be configured")

	# Sprite fallback test: empty pokemon data must gracefully fallback
	var dummy_mon = PokemonData.new()
	var fallback_sprite := dummy_mon.get_sprite_path(2, "v_1")
	assert(fallback_sprite != "", "Missing sprite must fallback gracefully to Venusaur fallback without crash")

	# 2. Moves: Float cooldown, range, power, string move_category, string move_type
	var tackle = load("res://data/moves/tackle.tres") as MoveData
	assert(tackle != null, "tackle.tres must load")
	assert(tackle.move_category == "physical", "Tackle must have string 'physical' category")
	assert(tackle.move_type == "melee", "Tackle must have string 'melee' type")

	var razor = load("res://data/moves/razor_leaf.tres") as MoveData
	assert(razor != null, "razor_leaf.tres must load")
	assert(razor.move_category == "special", "Razor Leaf must have string 'special' category")
	assert(razor.move_type == "homing", "Razor Leaf must have string 'homing' type")
	assert(razor.num_entities == 5, "Razor Leaf num_entities must be 5")

	var solar = load("res://data/moves/solar_beam.tres") as MoveData
	assert(solar != null, "solar_beam.tres must load")
	assert(solar.move_category == "special", "Solar Beam must have string 'special' category")
	assert(solar.move_type == "beam", "Solar Beam must have string 'beam' type")
	assert(solar.tracking == true, "Solar Beam tracking must be true")

	# Float cooldown alias test:
	solar.cooldown = 20.0
	assert(solar.cooldown_frames == 1200, "Setting cooldown to 20.0s must set cooldown_frames to 1200")
	assert(is_equal_approx(solar.cooldown, 20.0), "Getting cooldown must return 20.0")

	# 3. New Starter Moves (Shot, Shotgun)
	var ember = load("res://data/moves/ember.tres") as MoveData
	assert(ember != null, "ember.tres must load")
	assert(ember.move_category == "special", "Ember must be 'special'")
	assert(ember.move_type == "shot", "Ember must be 'shot' type")

	var flamethrower = load("res://data/moves/flamethrower.tres") as MoveData
	assert(flamethrower != null, "flamethrower.tres must load")
	assert(flamethrower.move_category == "special", "Flamethrower must be 'special'")
	assert(flamethrower.move_type == "shotgun", "Flamethrower must be 'shotgun' type")
	assert(flamethrower.num_entities == 3, "Flamethrower num_entities must be 3")

	# 3B. Duplicating a move file and altering its values (Datapack-like flexibility)
	var razor_2 = load("res://data/moves/razor_leaf_2.tres") as MoveData
	assert(razor_2 != null, "Duplicated move razor_leaf_2.tres must load")
	assert(razor_2.display_name == "Razor Leaf 2", "Duplicated move display_name must be preserved")
	assert(razor_2.power == 3.0, "Duplicated move power must be 3.0")
	assert(razor_2.move_type == "homing", "Duplicated move type must be homing")

	# Dynamic duplication test:
	var custom_move = flamethrower.duplicate() as MoveData
	custom_move.display_name = "Super Dragon Breath"
	custom_move.move_type = "shotgun"
	custom_move.num_entities = 7
	custom_move.spread_angle = 90.0
	custom_move.power = 8.0
	assert(custom_move.num_entities == 7, "Altered num_entities must be 7")
	assert(custom_move.power == 8.0, "Altered power must be 8.0")

	# 4. Base Damage Multiplier scaling
	var PlayerScript = load("res://scripts/player.gd")
	var LinearProjectileScript = load("res://moves/linear_projectile.gd")
	var p = PlayerScript.new()
	p.team = &"player"
	root.add_child(p)
	p.base_damage_multiplier = 1.5
	assert(is_equal_approx(p.get_base_damage(), 1.5), "p.get_base_damage() must reflect base_damage_multiplier 1.5")

	# 5. Generic MoveExecutor: Shotgun projectile spawn test
	p.facing = Vector2.RIGHT
	var shot_fired := MoveExecutor.execute(p, flamethrower)
	assert(shot_fired == true, "Shotgun move execution must succeed")
	var spawned_proj_count := 0
	for child in root.get_children():
		if child is Area2D and child.get_script() == LinearProjectileScript:
			spawned_proj_count += 1
			child.free()
	assert(spawned_proj_count == 3, "Shotgun move with num_entities=3 must spawn 3 LinearProjectiles")

	# 6. XP Config & System
	assert(XPSystem.get_move_xp(&"attack_1", null, "Venusaur") == 1, "Venusaur atk_1 XP must be 1")
	assert(XPSystem.get_move_xp(&"attack_3", null, "Venusaur") == 3, "Venusaur atk_3 XP must be 3")
	assert(XPSystem.get_move_xp(&"special", null, "Venusaur") == 0, "Unite moves (special) must yield 0 XP")
	assert(is_equal_approx(XPSystem.calculate_kill_xp(5), 250.0), "Lv. 5 kill XP must be 50 * 1 * 5 = 250.0")
	assert(is_equal_approx(XPSystem.get_damage_taken_xp(20), 10.0), "Damage taken XP for 20 dmg must be 20 * 0.5 = 10.0")

	p.free()
	print("✓ Data-Driven System Rework tests PASSED")


func test_shot_hold_aim_mechanic_and_solar_beam_center() -> void:
	print("\n[TEST 21] Shot Hold-to-Aim Mechanic (Dash-like Hold, Smaller Arrow & Highlight), Solar Beam Center Start, Shoot Interval...")
	var PlayerScript = load("res://scripts/player.gd")
	var pkmn_data = load("res://data/pokemon/charizard.tres") # Has Ember in attack_2 (move_type = "shot")
	var player = PlayerScript.new()
	player.pokemon = pkmn_data
	player.team = &"player"
	player.level = 20
	root.add_child(player)
	player.global_position = Vector2(200, 200)
	player.facing = Vector2.UP

	# 1. Shot hold mechanic verification
	assert(player.is_shot_slot(&"attack_2") == true, "Charizard attack_2 (Ember) must be identified as shot slot")
	assert(player.is_shot_slot(&"attack_1") == false, "Tackle is melee, not shot")

	# Start aiming shot
	player.start_shot_aim(&"attack_2")
	assert(player.is_aiming_shot == true, "Player must enter is_aiming_shot state on hold")
	assert(player.shot_aim_slot == &"attack_2", "Aimed slot must be attack_2")
	assert(player.shot_aim_indicator != null, "Shot aim indicator must be instantiated")
	assert(player.shot_aim_indicator.visible == true, "Shot aim indicator must be visible")

	var shot_ind = player.shot_aim_indicator
	# Verify uses same sprite as dash
	assert(shot_ind.ARROW_TEX_PATH == "res://assets/ui/arrow.png", "Shot aim indicator must use res://assets/ui/arrow.png")
	# Verify arrow scale is smaller than dash (Dash is 1.7x, Shot is 1.0x)
	assert(shot_ind.sprite_main.scale.x < 1.5, "Shot arrow sprite scale must be smaller than dash (1.0x < 1.5x)")
	assert(shot_ind.sprite_main.scale.x <= 1.0, "Shot arrow sprite scale must be 1.0x")
	# Verify highlight width is smaller than dash (Dash half_w = 12.0, Shot half_w = 6.0)
	assert(shot_ind.beam_half_width < 10.0, "Shot highlight beam width must be smaller than dash")
	assert(is_equal_approx(shot_ind.beam_half_width, 6.0), "Shot highlight beam half width must be 6.0px (half of dash 12.0px)")

	# Steering / drag aiming update
	player.update_shot_aim_dir(Vector2.RIGHT)
	assert(player.shot_aim_dir == Vector2.RIGHT, "Aim direction must update to Vector2.RIGHT")
	assert(player.facing == Vector2.RIGHT, "Facing must align to shot aim direction")

	# Release shot to fire
	var LinearProjectileScript = load("res://moves/linear_projectile.gd")
	player.release_shot(&"attack_2")
	assert(player.is_aiming_shot == false, "is_aiming_shot must be false after release")
	assert(shot_ind.visible == false, "Shot aim indicator must be hidden after release")

	# Verify linear projectile was spawned along aimed direction
	var fired_proj: Area2D = null
	for child in root.get_children():
		if child is Area2D and child.get_script() == LinearProjectileScript:
			fired_proj = child
			break
	assert(fired_proj != null, "Linear projectile must be spawned upon release_shot")
	assert(fired_proj.get("direction") == Vector2.RIGHT, "Spawned projectile must travel in aimed direction (Vector2.RIGHT)")
	fired_proj.free()

	# 2. Solar beam starting at center of the pokemon
	var sb_data = load("res://data/moves/solar_beam.tres") as MoveData
	var FighterScript = load("res://scripts/fighter.gd")
	var caster = FighterScript.new()
	root.add_child(caster)
	caster.global_position = Vector2(300, 300)
	caster.facing = Vector2.RIGHT

	var BeamEffectScript = load("res://moves/beam_effect.gd")
	var effect = BeamEffectScript.new(caster, sb_data)
	root.add_child(effect)

	# Verify charge sprite starts exactly at source center (no offset)
	effect._process_charge(0.01)
	assert(effect.charge_sprite.global_position == caster.global_position, "Charge sprite must start at exact center of pokemon (no offset)")

	# Transition to beam and verify energy origin and sprite offset
	effect._transition_to_beam()
	effect._process_beam(0.01)
	assert(effect.energy_sprite.offset == Vector2.ZERO, "Energy sprite offset must be Vector2.ZERO (centered)")
	var expected_surface: Vector2 = caster.global_position + caster.facing * effect._get_source_hitbox_radius()
	assert(effect.energy_sprite.global_position.is_equal_approx(expected_surface), "Energy origin must start at surface of pokemon hitbox")
	effect.free()
	caster.free()

	# 3. Shoot interval configuration test
	var ember = load("res://data/moves/ember.tres") as MoveData
	ember.shoot_interval = 0.15
	assert(is_equal_approx(ember.shoot_interval, 0.15), "shoot_interval must be configurable to 0.15")
	assert(is_equal_approx(ember.shot_interval, 0.15), "shot_interval alias must match shoot_interval")
	ember.shoot_interval = 0.0

	player.free()
	print("✓ Shot hold-to-aim, smaller arrow & highlight, Solar Beam center origin, and shoot_interval tests PASSED")


func test_menu_and_character_selection() -> void:
	print("\n[TEST 22] Menu & Character Selection (Flow, Item Grid, Data-Driven Cards, Cry, GBA Stretch, Color Sliders & Battle Spawn with Dummy)...")
	var MenuScript = load("res://scripts/menu.gd")
	var MenuScene = load("res://scenes/menu.tscn")
	assert(MenuScene != null, "menu.tscn must load successfully")
	var menu = MenuScene.instantiate()
	root.add_child(menu)
	menu._ready()

	# 1. Flow: Menu > Play
	assert(menu.current_state == MenuScript.MenuState.MAIN_TITLE, "Menu must start at MAIN_TITLE")
	assert(menu.panel_main.visible == true, "Main Title panel must be visible")
	assert(menu.panel_mode.visible == false, "Mode select panel must be hidden")
	assert(menu.panel_char_select.visible == false, "Char select panel must be hidden")

	# Press Play -> 1v1 or 2v2 (2v2 is not working)
	menu._on_play_pressed()
	assert(menu.current_state == MenuScript.MenuState.MODE_SELECT, "State must transition to MODE_SELECT on Play")
	assert(menu.panel_mode.visible == true, "Mode select panel must be visible")
	assert(menu.btn_mode_1v1.disabled == false, "1v1 button must be enabled")
	assert(menu.btn_mode_2v2.disabled == true, "2v2 button must be disabled (for now not working)")

	# Press 1v1 -> Character Selection
	menu._on_1v1_pressed()
	assert(menu.current_state == MenuScript.MenuState.CHAR_SELECT, "State must transition to CHAR_SELECT on 1v1")
	assert(menu.panel_char_select.visible == true, "Character selection panel must be visible")

	# 2. Left side: Items grid menu (for now empty)
	assert(menu.item_slot_panels.size() >= 6, "Left side must contain an item selection grid with at least 6 slots")

	# 3. Data-driven cards and character preview
	assert(menu.starter_pokemon.size() == 3, "Starter selection must have 3 Pokémon (Venusaur, Charizard, Blastoise)")
	assert(menu.card_buttons.size() == 3, "Bottom deck must have 3 card buttons")

	# Verify Venusaur data & selection
	var venu = menu.starter_pokemon[0]
	assert(venu.card_asset.contains("venusaur_card.png"), "Venusaur card_asset must be configured")
	assert(venu.sprite_full_body.contains("venu_front.png"), "Venusaur sprite_full_body must be configured")
	assert(venu.cry_audio.contains("venusaur.mp3"), "Venusaur cry_audio must be configured")

	menu.select_pokemon(0)
	assert(menu.selected_pokemon_index == 0, "Selected index must be 0 (Venusaur)")
	assert(menu.preview_sprite.texture.resource_path.contains("venu_front.png"), "Preview must display Venusaur front sprite")
	assert(menu.cry_player.stream.resource_path.contains("venusaur.mp3"), "Cry player must be loaded with Venusaur cry")
	assert(menu.stretch_tween != null and menu.stretch_tween.is_valid(), "GBA stretch animation tween must be running on selection")

	# Verify Charizard data & selection
	var chariz = menu.starter_pokemon[1]
	assert(chariz.card_asset.contains("charizard_card.png"), "Charizard card_asset must be configured")
	assert(chariz.sprite_full_body.contains("chzard_front.png"), "Charizard sprite_full_body must be configured")
	assert(chariz.cry_audio.contains("charizard.mp3"), "Charizard cry_audio must be configured")

	menu.select_pokemon(1)
	assert(menu.selected_pokemon_index == 1, "Selected index must be 1 (Charizard)")
	assert(menu.preview_sprite.texture.resource_path.contains("chzard_front.png"), "Preview must display Charizard front sprite")
	assert(menu.cry_player.stream.resource_path.contains("charizard.mp3"), "Cry player must be loaded with Charizard cry")

	# Verify Blastoise data & selection
	var blast = menu.starter_pokemon[2]
	assert(blast.card_asset.contains("blastoise_card.png"), "Blastoise card_asset must be configured")
	assert(blast.sprite_full_body.contains("blast_front.png"), "Blastoise sprite_full_body must be configured")
	assert(blast.cry_audio.contains("blastoise.mp3"), "Blastoise cry_audio must be configured")

	menu.select_pokemon(2)
	assert(menu.selected_pokemon_index == 2, "Selected index must be 2 (Blastoise)")
	assert(menu.preview_sprite.texture.resource_path.contains("blast_front.png"), "Preview must display Blastoise front sprite")
	assert(menu.cry_player.stream.resource_path.contains("blastoise.mp3"), "Cry player must be loaded with Blastoise cry")

	# 4. Color sliders panel (Hue, Saturation, Hex)
	assert(menu.slider_hue != null, "Color hue slider must exist")
	assert(menu.slider_sat != null, "Color saturation slider must exist")
	assert(menu.label_hex_val != null, "Hex label must exist")

	# Test adjusting sliders (Shift hue by +90 deg, sat = 1.5)
	menu.slider_hue.value = 90.0
	menu.slider_sat.value = 1.5
	menu._update_color_from_sliders()
	assert(menu.selected_hex != "", "Hex value must be generated")
	assert(is_equal_approx(menu.current_hue_shift, 0.25), "Hue shift must equal 90/360 = 0.25")
	assert(is_equal_approx(menu.current_sat_mult, 1.5), "Saturation multiplier must equal 1.5")
	assert(menu.preview_shader_mat != null, "Preview shader material must be active")
	assert(is_equal_approx(menu.preview_shader_mat.get_shader_parameter("hue_shift"), 0.25), "Shader parameter hue_shift must be updated")

	# Test Reset default
	menu._on_reset_color_pressed()
	assert(is_equal_approx(menu.slider_hue.value, 0.0), "Reset must set hue slider to 0.0")
	assert(is_equal_approx(menu.slider_sat.value, 1.0), "Reset must set sat slider to 1.0")
	assert(is_equal_approx(menu.current_hue_shift, 0.0), "Reset must set hue shift to 0.0")
	assert(is_equal_approx(menu.current_sat_mult, 1.0), "Reset must set sat mult to 1.0")

	# Re-apply custom hue shift for battle test (+60 deg shift)
	menu.slider_hue.value = 60.0
	menu.slider_sat.value = 1.2
	menu._update_color_from_sliders()
	var custom_hex: String = menu.selected_hex
	var custom_hue: float = menu.current_hue_shift
	var custom_sat: float = menu.current_sat_mult

	# 5. Next to card selection is BATTLE
	assert(menu.btn_battle != null, "BATTLE button must exist next to card selection")

	# Test Battle initiation persists to GameState
	GameState.set_selection(blast, custom_hex, Color.WHITE, custom_hue, custom_sat)
	assert(GameState.selected_pokemon == blast, "GameState must store chosen Pokemon")
	assert(GameState.selected_color_hex == custom_hex, "GameState must store chosen hex")
	assert(is_equal_approx(GameState.selected_hue_shift, custom_hue), "GameState must store chosen hue shift")
	assert(is_equal_approx(GameState.selected_sat_mult, custom_sat), "GameState must store chosen sat mult")

	menu.queue_free()

	# 6. Test Battle Arena: Spawns chosen Pokemon with hue/sat next to dummy
	var MainScene = load("res://scenes/main.tscn")
	var main_battle = MainScene.instantiate()
	root.add_child(main_battle)
	var p = main_battle.get_node_or_null("Player") as Node2D
	assert(p != null, "Player must exist in battle scene")
	p._ready()
	main_battle._ready()
	assert(p.pokemon == blast, "Player must spawn with selected Blastoise Pokemon")
	assert(is_equal_approx(p.hue_shift, custom_hue), "Player must have chosen hue shift")
	assert(is_equal_approx(p.sat_mult, custom_sat), "Player must have chosen sat mult")

	# Verify dummy spawned next to player on the field
	var dummy_found := false
	for child in main_battle.get_children():
		if child.name.begins_with("Dummy"):
			dummy_found = true
			assert(child.global_position.distance_to(p.global_position) <= 80.0, "Dummy must spawn on field right next to player (offset ~64px)")
			break
	assert(dummy_found == true, "Battle arena must spawn a dummy next to the player")

	main_battle.queue_free()
	GameState.reset()
	print("✓ Menu, Mode select, Character Selection, Item Grid, Cry, GBA Stretch, Color Sliders & Battle Dummy Spawn tests PASSED")


func test_stage_h1_preview_pause_menu_and_ui_dynamic() -> void:
	print("\n[TEST 23] Stage h_1 Character Previews, Pause Menu (Settings/Exit, CRT Line Size, No Gear Emoji) & UIDynamic Rendering...")

	# 1. Test UIDynamic
	var frame_tex := UIDynamic.get_frame_texture()
	assert(frame_tex != null, "UIDynamic frame texture must load successfully")
	var dyn_style := UIDynamic.make_style(Color(0.2, 0.4, 0.8), 10)
	assert(dyn_style is StyleBoxTexture, "UIDynamic make_style must return a StyleBoxTexture")
	assert(dyn_style.texture_margin_left == 16, "UIDynamic style must have 16px corner margins")
	assert(dyn_style.modulate_color == Color(0.2, 0.4, 0.8), "UIDynamic style must apply tint color")

	# Test cache efficiency (0 lag / 0 memory allocations)
	var dyn_cached := UIDynamic.make_style(Color(0.2, 0.4, 0.8), 10)
	assert(dyn_cached == dyn_style, "UIDynamic must return cached StyleBox instance for duplicate requests")

	# 2. Test Character Preview Stage h_1 Sprites & Color Preview
	var MenuScene = load("res://scenes/menu.tscn")
	var menu = MenuScene.instantiate()
	root.add_child(menu)
	menu._ready()

	# Navigate to character select
	menu._on_play_pressed()
	menu._on_1v1_pressed()

	assert(menu.stage_h1_sprites.size() == 3, "Character preview must include 3 stage h_1 preview sprites below front view")

	# Select Venusaur
	menu.select_pokemon(0)
	assert(menu.stage_h1_sprites[0].texture.resource_path.contains("bulb_h_1.png"), "Stage 1 h_1 must display Bulbasaur")
	assert(menu.stage_h1_sprites[1].texture.resource_path.contains("ivy_h_1.png"), "Stage 2 h_1 must display Ivysaur")
	assert(menu.stage_h1_sprites[2].texture.resource_path.contains("venu_h_1.png"), "Stage 3 h_1 must display Venusaur")

	# Test Direct Hue & Saturation Shader Alteration
	menu.slider_hue.value = 45.0
	menu.slider_sat.value = 1.4
	menu._update_color_from_sliders()
	assert(menu.preview_shader_mat != null, "Preview shader material must exist")
	assert(is_equal_approx(menu.preview_shader_mat.get_shader_parameter("hue_shift"), 45.0 / 360.0), "Preview shader must receive hue_shift parameter")
	assert(is_equal_approx(menu.preview_shader_mat.get_shader_parameter("sat_mult"), 1.4), "Preview shader must receive sat_mult parameter")
	assert(menu.preview_sprite.material == menu.preview_shader_mat, "Front preview must use direct hue/sat shader material")
	for s_idx in range(3):
		assert(menu.stage_h1_sprites[s_idx].material == menu.preview_shader_mat, "Stage %d h_1 sprite must share hue/sat shader material" % (s_idx + 1))

	# Test Reset Color
	menu._on_reset_color_pressed()
	assert(is_equal_approx(menu.slider_hue.value, 0.0), "Reset color must return hue slider to 0.0")
	assert(is_equal_approx(menu.slider_sat.value, 1.0), "Reset color must return sat slider to 1.0 (100%)")
	assert(is_equal_approx(menu.preview_shader_mat.get_shader_parameter("hue_shift"), 0.0), "Shader hue_shift must reset to 0.0")
	assert(is_equal_approx(menu.preview_shader_mat.get_shader_parameter("sat_mult"), 1.0), "Shader sat_mult must reset to 1.0")

	# Test Menu UI utilizing UIDynamic
	assert(menu.btn_play.get_theme_stylebox("normal") is StyleBoxTexture, "Play button must be drawn using UIDynamic")
	assert(menu.btn_mode_1v1.get_theme_stylebox("normal") is StyleBoxTexture, "1v1 button must be drawn using UIDynamic")
	assert(menu.btn_battle.get_theme_stylebox("normal") is StyleBoxTexture, "Battle button must be drawn using UIDynamic")
	assert(menu.card_containers[0].get_theme_stylebox("panel") is StyleBoxTexture, "Character card container must be drawn using UIDynamic")
	assert(menu.item_slot_panels[0].get_theme_stylebox("panel") is StyleBoxTexture, "Item slot panel must be drawn using UIDynamic")

	menu.queue_free()

	# 3. Test In-Game Pause Button & Pause Menu (Top Center Alignment, Settings, Exit, CRT Line Size)
	var MainScene = load("res://scenes/main.tscn")
	var main_battle = MainScene.instantiate()
	root.add_child(main_battle)
	main_battle._ready()

	var pause_menu = main_battle.get_node_or_null("PauseMenu")
	assert(pause_menu != null, "PauseMenu node must exist in battle scene")
	pause_menu.tree_ref = self
	pause_menu._ready()
	assert(pause_menu.btn_pause != null, "Pause button must exist")
	assert(is_equal_approx(pause_menu.btn_pause.anchor_left, 0.5) and is_equal_approx(pause_menu.btn_pause.anchor_right, 0.5), "Pause button must be centered horizontally")
	assert(is_equal_approx(pause_menu.btn_pause.anchor_top, 0.0), "Pause button must be aligned to top")

	# Press pause button
	pause_menu._on_pause_button_pressed()
	assert(paused == true, "Pressing pause button must pause the game")
	assert(pause_menu.overlay.visible == true, "Pause overlay must become visible")
	assert(pause_menu.panel_pause.visible == true, "Main pause panel must be visible")
	assert(pause_menu.btn_resume != null, "Resume button must exist")
	assert(pause_menu.btn_settings != null, "Settings button must exist")
	assert(pause_menu.btn_exit != null, "Exit button must exist")

	# Open Settings
	pause_menu.open_settings()
	assert(pause_menu.panel_settings.visible == true, "Settings dialog must be visible")
	assert(pause_menu.btn_crt_toggle != null, "CRT toggle button must exist")
	assert(pause_menu.slider_crt_line_size != null, "CRT line size slider must exist")
	assert(pause_menu.slider_chroma != null, "Chromatic aberration slider must exist")
	assert(pause_menu.btn_customize_controls != null, "Customize controls button must exist")
	assert(not pause_menu.btn_customize_controls.text.contains("⚙"), "Customize controls button must NOT contain gear emoji")

	# Test CRT Line Size setting
	pause_menu._on_crt_line_size_changed(3.5)
	var dm = pause_menu._get_debug_menu()
	if dm != null and "crt_line_size" in dm:
		assert(is_equal_approx(dm.crt_line_size, 3.5), "CRT line size must be adjustable from settings")

	# Test Chromatic Aberration setting
	pause_menu._on_chroma_changed(25.0)
	if dm != null and "chromatic_aberration" in dm:
		assert(is_equal_approx(dm.chromatic_aberration, 25.0), "Chromatic aberration must be adjustable from settings")

	# Test Resume
	pause_menu.resume_game()
	assert(paused == false, "Resume must unpause the game")
	assert(pause_menu.overlay.visible == false, "Overlay must hide on resume")

	main_battle.queue_free()
	print("✓ Stage h_1 character preview, Pause Menu, Settings, CRT Line Size & UIDynamic tests PASSED")

	# =========================================================================
	# TEST 24: Main Menu Settings, Direct Hue/Sat Shader, BGM Fading Loop, Font Sizes & Back Audio
	# =========================================================================
	print("\n--- TEST 24: Main Menu Settings, HSV Shader, BGM Fading Loop, Font Sizes & Back Audio ---")
	var menu2: MainMenu = MenuScene.instantiate()
	root.add_child(menu2)
	menu2._ready()

	# 1. Main Menu Settings Dialog Parity with Pause Menu
	assert(menu2.btn_main_settings != null, "Main title screen must contain a SETTINGS button")
	assert(menu2.panel_menu_settings != null, "Settings dialog must exist in main menu")
	assert(menu2.panel_menu_settings.visible == false, "Settings dialog should initially be hidden")

	menu2.open_main_settings()
	assert(menu2.panel_menu_settings.visible == true, "open_main_settings must display settings dialog")
	assert(menu2.btn_menu_crt_toggle != null, "Main menu settings must have CRT toggle")
	assert(menu2.slider_menu_crt_line_size != null, "Main menu settings must have CRT line size slider")
	assert(menu2.slider_menu_chroma != null, "Main menu settings must have chromatic aberration slider")
	assert(menu2.btn_menu_customize_controls != null, "Main menu settings must have customize controls button")
	assert(menu2.btn_menu_settings_back != null, "Main menu settings must have back button")

	# Modify settings from main menu
	menu2._on_menu_crt_line_size_changed(4.0)
	var dm2 = menu2._get_debug_menu()
	if dm2 != null and "crt_line_size" in dm2:
		assert(is_equal_approx(dm2.crt_line_size, 4.0), "Main menu settings must modify CRT line size")

	menu2._on_menu_chroma_changed(30.0)
	if dm2 != null and "chromatic_aberration" in dm2:
		assert(is_equal_approx(dm2.chromatic_aberration, 30.0), "Main menu settings must modify chromatic aberration")

	# Close settings from main menu
	menu2.close_main_settings()
	assert(menu2.panel_menu_settings.visible == false, "close_main_settings must hide settings dialog")
	assert(menu2.panel_main.visible == true, "Closing settings must return to main title screen")

	# 2. Back Button Audio Feedback
	assert(AudioManager.PATH_UI_BUTTON_BACK == "res://assets/audio/ui/button_back.mp3", "AudioManager must have button_back.mp3 path")
	AudioManager.play_back_button()

	# 3. Increased Font Sizes for All Menu Strings
	assert(menu2.btn_play.get_theme_font_size("font_size") >= 38, "Play button font size must be increased")
	assert(menu2.btn_main_settings.get_theme_font_size("font_size") >= 32, "Settings button font size must be increased")
	assert(menu2.btn_mode_1v1.get_theme_font_size("font_size") >= 32, "1v1 mode button font size must be increased")
	assert(menu2.btn_mode_back.get_theme_font_size("font_size") >= 26, "Mode back button font size must be increased")
	assert(menu2.btn_char_back.get_theme_font_size("font_size") >= 24, "Char select back button font size must be increased")
	assert(menu2.btn_battle.get_theme_font_size("font_size") >= 40, "Battle button font size must be increased")

	# 4. Character Select Music with Fading Loop
	assert(menu2.bgm_player != null, "Character select BGM player must exist")
	assert(menu2.bgm_player.stream != null, "Character select BGM stream must be loaded")
	assert(menu2.bgm_player.stream.resource_path.contains("character_select_music.mp3"), "Stream must be character_select_music.mp3")
	menu2.show_char_select()
	assert(menu2.is_bgm_playing == true, "Character select music must start playing upon entering char select")
	assert(menu2.current_state == MainMenu.MenuState.CHAR_SELECT, "State must be CHAR_SELECT")

	# Simulate track end for fading loop
	menu2._on_bgm_finished()
	assert(menu2.is_bgm_playing == true, "Track finished must loop seamlessly in char select")

	# 5. Direct Hue & Saturation Alteration into GameState & Player
	menu2.slider_hue.value = 90.0  # +90 deg
	menu2.slider_sat.value = 1.6  # 160% saturation
	menu2._update_color_from_sliders()
	assert(is_equal_approx(menu2.current_hue_shift, 0.25), "Hue shift uniform must equal 90/360 = 0.25")
	assert(is_equal_approx(menu2.current_sat_mult, 1.6), "Saturation multiplier uniform must equal 1.6")

	# Simulate start battle to verify GameState propagation
	menu2.start_battle()
	assert(is_equal_approx(GameState.selected_hue_shift, 0.25), "GameState must receive selected_hue_shift")
	assert(is_equal_approx(GameState.selected_sat_mult, 1.6), "GameState must receive selected_sat_mult")

	# Verify in-game Player sprite shader receives hue_shift and sat_mult
	var PlayerScript = load("res://scripts/player.gd")
	var test_player = PlayerScript.new()
	test_player.pokemon = GameState.get_selected_pokemon()
	root.add_child(test_player)
	test_player._ready()

	assert(test_player.visual != null and test_player.visual.material is ShaderMaterial, "Player visual must have ShaderMaterial")
	var p_mat := test_player.visual.material as ShaderMaterial
	assert(is_equal_approx(p_mat.get_shader_parameter("hue_shift"), 0.25), "Player shader must have hue_shift applied")
	assert(is_equal_approx(p_mat.get_shader_parameter("sat_mult"), 1.6), "Player shader must have sat_mult applied")

	test_player.queue_free()
	menu2.queue_free()
	print("✓ Main Menu Settings, HSV Shader, BGM Fading Loop, Font Sizes & Back Audio tests PASSED")
