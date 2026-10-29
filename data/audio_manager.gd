class_name AudioManager
extends RefCounted

# =============================================================================
# AUDIO MANAGER & CATEGORIZED SOUND REGISTRY
# Provides data-driven audio routing, Android haptic integration, AudioStreamRandomizer
# hit sound variance, dedicated HitSFX audio bus limiting, hit sound debouncing,
# and graceful fallback playback when sound files do not yet exist on disk.
# =============================================================================

# Audio Buses
const BUS_MASTER := &"Master"
const BUS_SFX := &"SFX"
const BUS_HIT_SFX := &"HitSFX"

# Category: UI
const PATH_UI_BUTTON_CLICK := "res://assets/audio/ui/button_click.mp3"
const PATH_UI_BUTTON_BACK  := "res://assets/audio/ui/button_back.mp3"
const PATH_UI_ATK_BUTTON   := "res://assets/audio/ui/atk_button.mp3"
const PATH_UI_DASH_BUTTON  := "res://assets/audio/ui/dash_button.mp3"
const PATH_UI_UNITE_BUTTON := "res://assets/audio/ui/unite_button.mp3"

# Category: Combat
const PATH_COMBAT_HIT           := "res://assets/audio/combat/hit.mp3"
const PATH_COMBAT_INVALID_RANGE := "res://assets/audio/combat/invalid_range.mp3"
const PATH_COMBAT_HIT_RANDOMIZER := "res://assets/audio/combat/hit_randomizer.tres"

# Category: Moves
const PATH_MOVE_RAZOR_LEAF := "res://assets/audio/moves/razor_leaf.mp3"
const PATH_MOVE_DASH       := "res://assets/audio/moves/dash.mp3"
const PATH_MOVE_TACKLE     := "res://assets/audio/moves/tackle.mp3"
const PATH_MOVE_VINE_WHIP  := "res://assets/audio/moves/vine_whip.mp3"
const PATH_MOVE_SOLAR_BEAM := "res://assets/audio/moves/solar_beam.mp3"

# Category: Movement
const PATH_MOVEMENT_WALK          := "res://assets/audio/movement/walk.mp3"
const PATH_MOVEMENT_WALK_DIAGONAL := "res://assets/audio/movement/walk_diagonal.mp3"

# Category: Progression
const PATH_PROGRESSION_LEVEL_UP     := "res://assets/audio/progression/level_up.mp3"
const PATH_PROGRESSION_ATK_LEVEL_UP := "res://assets/audio/progression/atk_level_up.mp3"
const PATH_PROGRESSION_FAINT        := "res://assets/audio/progression/faint.mp3"
const PATH_PROGRESSION_EVOLUTION    := "res://assets/audio/progression/evolution.mp3"

# Hit audio debounce & randomizer settings
const HIT_DEBOUNCE_MS := 50
const HIT_RANDOM_PITCH := 1.10
const HIT_RANDOM_VOLUME_DB := 1.5

# Cached AudioStream instances
static var _stream_cache: Dictionary = {}
static var _ui_player: AudioStreamPlayer = null
static var _hit_ui_player: AudioStreamPlayer = null
static var _move_ui_player: AudioStreamPlayer = null
static var _walk_ui_player: AudioStreamPlayer = null
static var _progression_ui_player: AudioStreamPlayer = null
static var _hit_randomizer: AudioStreamRandomizer = null

# Hit sound debounce state tracking
static var _last_hit_sound_msec: int = -10000
static var _last_hit_sound_frame: int = -1
static var _last_attack_instance_id: int = 0

# Move sound single-playback tracking (Move sounds play strictly once on attack execution)
const MOVE_DEBOUNCE_MS := 80
static var _last_move_sound_msec: int = -10000
static var _last_move_sound_path: String = ""


# Ensures the dedicated HitSFX audio bus exists with an AudioEffectLimiter applied
static func ensure_hit_bus() -> void:
	var bus_idx := AudioServer.get_bus_index(BUS_HIT_SFX)
	if bus_idx == -1:
		bus_idx = AudioServer.bus_count
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, BUS_HIT_SFX)
		AudioServer.set_bus_send(bus_idx, BUS_SFX)

	# Verify AudioEffectLimiter exists on the HitSFX bus so audio never peaks above 0 dB
	var has_limiter := false
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		if AudioServer.get_bus_effect(bus_idx, i) is AudioEffectLimiter:
			has_limiter = true
			break
	if not has_limiter:
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db = -0.1
		limiter.threshold_db = 0.0
		AudioServer.add_bus_effect(bus_idx, limiter)


# Lazily creates or loads the AudioStreamRandomizer for combat hit sounds
static func get_hit_randomizer() -> AudioStreamRandomizer:
	if _hit_randomizer != null:
		return _hit_randomizer

	# 1. Attempt to load pre-configured hit_randomizer resource
	if ResourceLoader.exists(PATH_COMBAT_HIT_RANDOMIZER) or FileAccess.file_exists(PATH_COMBAT_HIT_RANDOMIZER):
		_hit_randomizer = load(PATH_COMBAT_HIT_RANDOMIZER) as AudioStreamRandomizer
		if _hit_randomizer != null:
			return _hit_randomizer

	# 2. Dynamically construct and configure AudioStreamRandomizer
	_hit_randomizer = AudioStreamRandomizer.new()
	_hit_randomizer.random_pitch = HIT_RANDOM_PITCH
	_hit_randomizer.random_volume_offset_db = HIT_RANDOM_VOLUME_DB

	var final_path := resolve_path(PATH_COMBAT_HIT)
	if final_path != "" and (ResourceLoader.exists(final_path) or FileAccess.file_exists(final_path)):
		var raw_stream := load(final_path) as AudioStream
		if raw_stream != null:
			_hit_randomizer.add_stream(0, raw_stream, 1.0)

	return _hit_randomizer


# Reset debounce state (useful for test suites or resets)
static func reset_hit_debounce() -> void:
	_last_hit_sound_msec = -10000
	_last_hit_sound_frame = -1
	_last_attack_instance_id = 0


# Helper to inspect whether a hit sound would be permitted right now
static func can_play_hit_sound(attack_instance: Variant = null) -> bool:
	if _last_hit_sound_msec < 0:
		return true
	var now := Time.get_ticks_msec()
	var current_frame := Engine.get_process_frames()
	var time_diff := now - _last_hit_sound_msec
	if time_diff < HIT_DEBOUNCE_MS:
		return false
	if current_frame > 0 and _last_hit_sound_frame == current_frame:
		return false
	if attack_instance != null and _last_attack_instance_id != 0:
		var inst_id := _get_attack_instance_id(attack_instance)
		if inst_id == _last_attack_instance_id and time_diff < HIT_DEBOUNCE_MS:
			return false
	return true


# Extract integer identity from an attack instance or object
static func _get_attack_instance_id(attack_instance: Variant) -> int:
	if attack_instance is Object:
		if is_instance_valid(attack_instance):
			return attack_instance.get_instance_id()
		return 0
	return hash(attack_instance)


# Resolve the audio file path (direct lookup for defined MP3 resources)
static func resolve_path(primary_path: String) -> String:
	if primary_path == "":
		return ""

	if ResourceLoader.exists(primary_path) or FileAccess.file_exists(primary_path):
		return primary_path

	return ""


# Universal playback function supporting Node2D emitters and global UI sounds
static func play_sound(path: String, caller: Node = null, volume_db: float = 0.0, bus_name: StringName = &"") -> bool:
	var final_path := resolve_path(path)
	if final_path == "":
		return false

	var is_hit := (path == PATH_COMBAT_HIT or final_path.contains("hit."))
	if bus_name == &"":
		bus_name = BUS_HIT_SFX if is_hit else BUS_SFX

	# Move sounds (e.g. Razor Leaf): generated strictly by making the attack, play only once
	var is_move_sound := final_path.contains("/moves/")
	if is_move_sound:
		var now := Time.get_ticks_msec()
		if _last_move_sound_path == final_path and (now - _last_move_sound_msec) < MOVE_DEBOUNCE_MS:
			return false
		_last_move_sound_msec = now
		_last_move_sound_path = final_path

	var stream: AudioStream = null
	if is_hit:
		stream = get_hit_randomizer()
	else:
		stream = _stream_cache.get(final_path, null)
		if stream == null:
			if ResourceLoader.exists(final_path):
				stream = load(final_path) as AudioStream
				if stream != null:
					_stream_cache[final_path] = stream

	if stream == null:
		return false

	# Play positional audio if caller is a Node2D
	# Dedicated audio players per category with max_polyphony ensure voices overlap cleanly without cutoff
	if caller is Node2D:
		var node_name := "SFXPlayer"
		if is_hit:
			node_name = "HitSFXPlayer"
		elif is_move_sound or final_path.contains("/moves/"):
			node_name = "MoveSFXPlayer"
		elif final_path.contains("/movement/") or path.contains("walk"):
			node_name = "WalkSFXPlayer"
		elif final_path.contains("/progression/"):
			node_name = "ProgressionSFXPlayer"

		var sfx_2d := caller.get_node_or_null(node_name) as AudioStreamPlayer2D
		if sfx_2d == null:
			sfx_2d = AudioStreamPlayer2D.new()
			sfx_2d.name = node_name
			sfx_2d.max_polyphony = 16
			caller.add_child(sfx_2d)

		sfx_2d.max_polyphony = 16
		if sfx_2d.bus != bus_name:
			sfx_2d.bus = bus_name

		# In Godot 4, setting player.stream calls set_stream() which halts all active voices!
		# If the stream is already set, NEVER re-assign it. Simply calling play() spawns a new overlapping polyphonic voice.
		# If a different stream is requested while currently playing, use an auxiliary player from the pool.
		if sfx_2d.stream != stream:
			if sfx_2d.playing:
				sfx_2d = _get_aux_2d_player(caller, node_name, stream, bus_name)
			else:
				sfx_2d.stream = stream

		if sfx_2d != null:
			sfx_2d.volume_db = volume_db
			if caller.is_inside_tree():
				sfx_2d.play()
		return true

	# Global / UI non-positional playback with segregated players per category
	var player_to_use: AudioStreamPlayer = null
	if is_hit:
		if _hit_ui_player == null or not is_instance_valid(_hit_ui_player):
			_hit_ui_player = AudioStreamPlayer.new()
			_hit_ui_player.name = "GlobalHitPlayer"
			_hit_ui_player.max_polyphony = 16
		player_to_use = _hit_ui_player
	elif is_move_sound or final_path.contains("/moves/"):
		if _move_ui_player == null or not is_instance_valid(_move_ui_player):
			_move_ui_player = AudioStreamPlayer.new()
			_move_ui_player.name = "GlobalMovePlayer"
			_move_ui_player.max_polyphony = 16
		player_to_use = _move_ui_player
	elif final_path.contains("/movement/") or path.contains("walk"):
		if _walk_ui_player == null or not is_instance_valid(_walk_ui_player):
			_walk_ui_player = AudioStreamPlayer.new()
			_walk_ui_player.name = "GlobalWalkPlayer"
			_walk_ui_player.max_polyphony = 16
		player_to_use = _walk_ui_player
	elif final_path.contains("/progression/"):
		if _progression_ui_player == null or not is_instance_valid(_progression_ui_player):
			_progression_ui_player = AudioStreamPlayer.new()
			_progression_ui_player.name = "GlobalProgressionPlayer"
			_progression_ui_player.max_polyphony = 16
		player_to_use = _progression_ui_player
	else:
		if _ui_player == null or not is_instance_valid(_ui_player):
			_ui_player = AudioStreamPlayer.new()
			_ui_player.name = "GlobalAudioPlayer"
			_ui_player.max_polyphony = 16
		player_to_use = _ui_player

	if player_to_use != null:
		if not player_to_use.is_inside_tree():
			var tree := Engine.get_main_loop() as SceneTree
			var root_node: Window = null
			if tree != null:
				root_node = tree.root
			elif caller != null and caller.is_inside_tree():
				root_node = caller.get_tree().root
			if root_node != null:
				root_node.add_child(player_to_use)

		player_to_use.max_polyphony = 16
		if player_to_use.bus != bus_name:
			player_to_use.bus = bus_name

		if player_to_use.stream != stream:
			if player_to_use.playing:
				player_to_use = _get_aux_global_player(player_to_use.name, stream, bus_name)
			else:
				player_to_use.stream = stream

		if player_to_use != null:
			player_to_use.volume_db = volume_db
			if player_to_use.is_inside_tree():
				player_to_use.play()
		return true

	return false


static var _aux_global_players: Dictionary = {}


static func _get_aux_2d_player(caller: Node2D, base_name: String, stream: AudioStream, bus_name: StringName) -> AudioStreamPlayer2D:
	for i in range(1, 5):
		var aux_name := base_name + "_" + str(i)
		var aux := caller.get_node_or_null(aux_name) as AudioStreamPlayer2D
		if aux == null:
			aux = AudioStreamPlayer2D.new()
			aux.name = aux_name
			aux.max_polyphony = 16
			aux.bus = bus_name
			aux.stream = stream
			caller.add_child(aux)
			return aux
		elif not aux.playing or aux.stream == stream:
			if aux.stream != stream:
				aux.stream = stream
			aux.bus = bus_name
			return aux
	var fallback := caller.get_node_or_null(base_name) as AudioStreamPlayer2D
	if fallback != null:
		if fallback.stream != stream:
			fallback.stream = stream
		return fallback
	return null


static func _get_aux_global_player(base_name: String, stream: AudioStream, bus_name: StringName) -> AudioStreamPlayer:
	var pool: Array = _aux_global_players.get(base_name, [])
	for p in pool:
		var player := p as AudioStreamPlayer
		if player != null and is_instance_valid(player):
			if not player.playing or player.stream == stream:
				if player.stream != stream:
					player.stream = stream
				player.bus = bus_name
				return player
	if pool.size() < 5:
		var new_p := AudioStreamPlayer.new()
		new_p.name = base_name + "_Aux_" + str(pool.size() + 1)
		new_p.max_polyphony = 16
		new_p.bus = bus_name
		new_p.stream = stream
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null:
			tree.root.add_child(new_p)
		pool.append(new_p)
		_aux_global_players[base_name] = pool
		return new_p
	var default_p := pool[0] as AudioStreamPlayer
	if default_p != null and is_instance_valid(default_p):
		if default_p.stream != stream:
			default_p.stream = stream
		default_p.bus = bus_name
		return default_p
	return null


# --- Categorized Helper Methods ---

# 1. UI: Generic button click (Debug menu, options, dialogs)
static func play_button_click() -> void:
	play_sound(PATH_UI_BUTTON_CLICK, null, -2.0, BUS_SFX)

# 1b. UI: Back button clicked
static func play_back_button() -> void:
	play_sound(PATH_UI_BUTTON_BACK, null, 0.0, BUS_SFX)

# 2. UI: Attack button clicked
static func play_atk_button() -> void:
	play_sound(PATH_UI_ATK_BUTTON, null, 0.0, BUS_SFX)

# 3. UI: Dash button clicked
static func play_dash_button() -> void:
	play_sound(PATH_UI_DASH_BUTTON, null, 0.0, BUS_SFX)

# 4. UI: Unite button clicked
static func play_unite_button() -> void:
	play_sound(PATH_UI_UNITE_BUTTON, null, 2.0, BUS_SFX)

# 5. Combat: Generic hit with debounce and dedicated audio bus routing
static func play_hit(caller: Node = null, attack_instance: Variant = null) -> bool:
	ensure_hit_bus()

	var now := Time.get_ticks_msec()
	var current_frame := Engine.get_process_frames()

	# Cooldown / debounce logic (50ms) & same-frame / attack instance check:
	# Simultaneous hits on multiple targets only trigger the sound once per frame/attack instance.
	if _last_hit_sound_msec >= 0:
		var time_diff := now - _last_hit_sound_msec

		# 1. Debounce if within 50ms cooldown window
		if time_diff < HIT_DEBOUNCE_MS:
			return false

		# 2. Debounce if on the exact same frame during active gameplay
		if current_frame > 0 and _last_hit_sound_frame == current_frame:
			return false

		# 3. Debounce if same attack instance hits multiple targets
		if attack_instance != null and _last_attack_instance_id != 0:
			var inst_id := _get_attack_instance_id(attack_instance)
			if inst_id == _last_attack_instance_id and time_diff < HIT_DEBOUNCE_MS:
				return false

	_last_hit_sound_msec = now
	_last_hit_sound_frame = current_frame
	if attack_instance != null:
		_last_attack_instance_id = _get_attack_instance_id(attack_instance)

	return play_sound(PATH_COMBAT_HIT, caller, 0.0, BUS_HIT_SFX)

# 6. Combat: Invalid melee range
static func play_invalid_range(caller: Node = null) -> void:
	play_sound(PATH_COMBAT_INVALID_RANGE, caller, -2.0, BUS_SFX)

# 7. Moves: Razor Leaf
static func play_razor_leaf(caller: Node = null) -> bool:
	return play_sound(PATH_MOVE_RAZOR_LEAF, caller, 0.0, BUS_SFX)

# 8. Moves: Dash
static func play_dash(caller: Node = null) -> bool:
	return play_sound(PATH_MOVE_DASH, caller, 0.0, BUS_SFX)

# 9. Moves: Tackle
static func play_tackle(caller: Node = null) -> bool:
	return play_sound(PATH_MOVE_TACKLE, caller, 0.0, BUS_SFX)

# 10. Moves: Vine Whip
static func play_vine_whip(caller: Node = null) -> bool:
	return play_sound(PATH_MOVE_VINE_WHIP, caller, 0.0, BUS_SFX)

# 11. Moves: Solar Beam
static func play_solar_beam(caller: Node = null) -> bool:
	return play_sound(PATH_MOVE_SOLAR_BEAM, caller, 0.0, BUS_SFX)

# 9. Movement: Walk (Cardinal or Non-main cardinal)
static func play_walk(caller: Node = null, is_diagonal: bool = false) -> bool:
	var path := PATH_MOVEMENT_WALK_DIAGONAL if is_diagonal else PATH_MOVEMENT_WALK
	return play_sound(path, caller, -6.0, BUS_SFX)

# 10. Progression: Level Up
static func play_level_up(caller: Node = null) -> bool:
	return play_sound(PATH_PROGRESSION_LEVEL_UP, caller, 2.0, BUS_SFX)

# 11. Progression: Attack Level Up
static func play_atk_level_up(caller: Node = null) -> bool:
	return play_sound(PATH_PROGRESSION_ATK_LEVEL_UP, caller, 2.0, BUS_SFX)

# 12. Progression: Faint
static func play_faint(caller: Node = null) -> bool:
	return play_sound(PATH_PROGRESSION_FAINT, caller, 0.0, BUS_SFX)

# 13. Progression: Evolution
static func play_evolution(caller: Node = null) -> bool:
	if not play_sound(PATH_PROGRESSION_EVOLUTION, caller, 3.0, BUS_SFX):
		# Graceful fallback to level up audio if evolution audio file not yet placed
		return play_level_up(caller)
	return true
