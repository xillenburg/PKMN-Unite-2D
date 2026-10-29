class_name TouchControls
extends CanvasLayer

const GameFont := preload("res://ui/game_font.gd")
const AttackButtonConfig := preload("res://data/attack_button_config.gd")

# =============================================================================
# SUB-CLASS: TouchJoystick
# Dynamic / floating joystick that appears anywhere touched and disappears when released
# =============================================================================
class TouchJoystick extends Control:
	var is_active: bool = false
	var touch_id: int = -1
	var base_pos: Vector2 = Vector2.ZERO
	var current_pos: Vector2 = Vector2.ZERO
	var max_radius: float = 115.0
	var deadzone: float = 16.0
	var knob_radius: float = 38.0
	var output: Vector2 = Vector2.ZERO

	var pad_texture: Texture2D = preload("res://assets/ui/joystick_pad.png")
	var ball_texture: Texture2D = preload("res://assets/ui/joystick_ball.png")

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		visible = false # Hidden when not in use
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func activate(tid: int, pos: Vector2) -> void:
		is_active = true
		touch_id = tid
		base_pos = pos
		current_pos = pos
		output = Vector2.ZERO
		visible = true
		queue_redraw()

	func drag(pos: Vector2) -> void:
		if not is_active:
			return
		var diff := pos - base_pos
		var dist := diff.length()
		if dist > max_radius:
			current_pos = base_pos + diff.normalized() * max_radius
		else:
			current_pos = pos

		var current_dist := (current_pos - base_pos).length()
		if current_dist > deadzone:
			var normalized_dist := (current_dist - deadzone) / (max_radius - deadzone)
			output = (current_pos - base_pos).normalized() * clampf(normalized_dist, 0.0, 1.0)
		else:
			output = Vector2.ZERO
		queue_redraw()

	func deactivate() -> void:
		is_active = false
		touch_id = -1
		output = Vector2.ZERO
		visible = false # Disappears when not used
		queue_redraw()

	func _draw() -> void:
		if not is_active:
			return

		# 1. Base pad rendered using joystick_pad.png (scaled to pad radius)
		if pad_texture != null:
			var pad_size := Vector2(max_radius * 2.0, max_radius * 2.0)
			var pad_rect := Rect2(base_pos - pad_size * 0.5, pad_size)
			draw_texture_rect(pad_texture, pad_rect, false)

		# 2. Knob / Thumbstick rendered using joystick_ball.png (scaled to knob radius)
		# Note: The procedural line connecting pad and knob has been removed as requested.
		if ball_texture != null:
			var ball_size := Vector2(knob_radius * 2.0, knob_radius * 2.0)
			var ball_rect := Rect2(current_pos - ball_size * 0.5, ball_size)
			draw_texture_rect(ball_texture, ball_rect, false)


# =============================================================================
# SUB-CLASS: TopBarButton
# Responsive rectangular touch buttons at the top of the screen
# =============================================================================
class TopBarButton extends Control:
	signal pressed(action: StringName)

	var action_name: StringName = &""
	var title: String = ""
	var btn_rect: Rect2 = Rect2():
		set(value):
			btn_rect = value
			position = value.position
			size = value.size
	var is_pressed: bool = false
	var touch_id: int = -1
	var is_selected_in_customizer: bool = false
	var border_color: Color = Color(0.35, 0.75, 1.0, 0.9)
	var bg_color: Color = Color(0.06, 0.10, 0.18, 0.92)
	var pressed_bg_color: Color = Color(0.14, 0.25, 0.42, 0.96)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func is_point_inside(pt: Vector2) -> bool:
		return btn_rect.has_point(pt)

	func on_touch_down(tid: int, _pt: Vector2) -> bool:
		if is_pressed:
			return false
		is_pressed = true
		touch_id = tid
		Input.vibrate_handheld(15)
		queue_redraw()
		pressed.emit(action_name)
		return true

	func on_touch_up() -> void:
		is_pressed = false
		touch_id = -1
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					on_touch_down(0, mb.position)
				else:
					on_touch_up()
				accept_event()
		elif event is InputEventScreenTouch:
			var st := event as InputEventScreenTouch
			if st.pressed:
				on_touch_down(st.index, st.position)
			else:
				on_touch_up()
			accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if is_pressed:
			r = Rect2(Vector2(1, 1), size - Vector2(2, 2))

		# Background
		var bg := bg_color if not is_pressed else pressed_bg_color
		draw_rect(r, bg, true)

		# Border
		var b_col := Color.WHITE if is_pressed else border_color
		draw_rect(r, b_col, false, 3.0)

		if is_selected_in_customizer:
			draw_rect(Rect2(Vector2(-4, -4), size + Vector2(8, 8)), Color(0.2, 0.85, 1.0, 0.95), false, 3.0)

		# Centered Title (Universal 32px Font)
		var font := GameFont.get_bold_font()
		if font != null:
			var font_size := GameFont.UNIVERSAL_FONT_SIZE
			var str_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var text_pos := Vector2((size.x - str_size.x) * 0.5, (size.y + str_size.y) * 0.5 - 4)
			draw_string_outline(font, text_pos, title, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 3, Color.BLACK)
			draw_string(font, text_pos, title, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)


# =============================================================================
# SUB-CLASS: MobaTouchButton
# Pressable circular button with circular cooldown sweep & timer on the circle
# =============================================================================
class MobaTouchButton extends Control:
	signal pressed(slot: StringName)
	signal released(slot: StringName)

	var slot_name: StringName = &"attack_1"
	var center_pos: Vector2 = Vector2.ZERO
	var radius: float = 75.0 # Increased size
	var title: String = "ATK 1"
	var sub_title: String = "TACKLE"
	var theme_color: Color = Color(0.95, 0.55, 0.15)
	var cooldown_max: float = 1.0
	var cooldown_remaining: float = 0.0
	var is_pressed: bool = false
	var touch_id: int = -1
	var is_selected_in_customizer: bool = false
	var is_locked: bool = false
	var unlock_level: int = 1
	var is_upgrade_pulsating: bool = false
	var pulse_time: float = 0.0
	var upgrade_level: int = 0
	var confirm_stage: int = 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta: float) -> void:
		if is_upgrade_pulsating:
			pulse_time += delta
			queue_redraw()

	func is_point_inside(pt: Vector2) -> bool:
		var half_s := radius * 1.05
		return Rect2(center_pos - Vector2(half_s, half_s), Vector2(half_s * 2.0, half_s * 2.0)).has_point(pt)

	func get_edge_polygon(rect: Rect2, margin: float = 0.0) -> PackedVector2Array:
		var r := Rect2(rect.position - Vector2(margin, margin), rect.size + Vector2(margin * 2.0, margin * 2.0))
		var corner := r.size.x * (2.0 / 16.0) # 2px corner bevel of 16px sprite
		return PackedVector2Array([
			Vector2(r.position.x + corner, r.position.y),
			Vector2(r.end.x - corner, r.position.y),
			Vector2(r.end.x, r.position.y + corner),
			Vector2(r.end.x, r.end.y - corner),
			Vector2(r.end.x - corner, r.end.y),
			Vector2(r.position.x + corner, r.end.y),
			Vector2(r.position.x, r.end.y - corner),
			Vector2(r.position.x, r.position.y + corner),
			Vector2(r.position.x + corner, r.position.y)
		])

	func get_upgrade_outline_color(lvl: int) -> Color:
		if lvl <= 0:
			return Color.TRANSPARENT
		if lvl == 1:
			return Color(1.0, 1.0, 1.0, 1.0) # White for a leveled up move (+1 DMG)
		# Increasingly becomes blue when upgraded again (+2 sky blue, +3 azure blue, +4+ deep electric blue)
		var t: float = clampf(float(lvl - 1) / 3.0, 0.0, 1.0)
		var target_blue := Color(0.12, 0.50, 1.0, 1.0)
		return Color.WHITE.lerp(target_blue, t)

	func on_touch_down(tid: int, _pt: Vector2) -> bool:
		if is_pressed:
			return false
		if is_upgrade_pulsating:
			is_pressed = true
			touch_id = tid
			queue_redraw()
			pressed.emit(slot_name)
			return true
		if is_locked:
			return false # Locked until reaching required level
		if cooldown_remaining > 0.0:
			return false # On cooldown, cannot activate
		is_pressed = true
		touch_id = tid
		queue_redraw()
		pressed.emit(slot_name)
		return true

	func on_touch_up() -> void:
		if is_pressed:
			is_pressed = false
			touch_id = -1
			queue_redraw()
			released.emit(slot_name)

	func update_cooldown(player: Fighter) -> void:
		if player == null or not is_instance_valid(player):
			return

		if player.has_method("is_slot_unlocked"):
			is_locked = not player.is_slot_unlocked(slot_name)
			unlock_level = player.get_slot_unlock_level(slot_name)

		if player.has_method("get_move_bonus_damage"):
			upgrade_level = player.get_move_bonus_damage(slot_name)

		if slot_name == &"dash":
			var cd_val: int = player.get("dash_cooldown") if "dash_cooldown" in player else 0
			cooldown_remaining = float(cd_val) / 60.0
			cooldown_max = 1.5 # 1.5s move
		else:
			var cds: Dictionary = player.get("slot_cooldowns") if "slot_cooldowns" in player else {}
			var cd_frames: int = cds.get(slot_name, 0)
			cooldown_remaining = float(cd_frames) / 60.0
			var m = player.get_move_in_slot(slot_name) if player.has_method("get_move_in_slot") else null
			if m != null and m.cooldown_frames > 0:
				cooldown_max = float(m.cooldown_frames) / 60.0
			elif slot_name == &"special":
				cooldown_max = 60.0
			else:
				cooldown_max = 2.0

		queue_redraw()

	func _draw() -> void:
		var on_cd := (cooldown_remaining > 0.0)
		var press_mult: float = 0.94 if is_pressed else 1.0
		var side: float = radius * 2.0 * press_mult
		var btn_rect := Rect2(center_pos - Vector2(side, side) * 0.5, Vector2(side, side))
		var btn_tex: Texture2D = AttackButtonConfig.get_texture(slot_name)

		# 1. Outer drop shadow following sprite edges (shifted down by 4px)
		var shadow_poly := get_edge_polygon(btn_rect, 2.0)
		for i in range(shadow_poly.size()):
			shadow_poly[i] += Vector2(0, 4)
		draw_colored_polygon(shadow_poly, Color(0.0, 0.0, 0.0, 0.45))

		# 2. Main Attack Button Sprite as the button itself (scaled properly)
		if btn_tex != null:
			var icon_modulate: Color
			if is_locked:
				icon_modulate = theme_color.darkened(0.60) * Color(1.0, 1.0, 1.0, 0.40)
			elif on_cd:
				icon_modulate = theme_color.darkened(0.35) * Color(1.0, 1.0, 1.0, 0.55)
			elif is_pressed:
				icon_modulate = Color.WHITE
			else:
				icon_modulate = theme_color.lightened(0.20)

			draw_texture_rect(btn_tex, btn_rect, false, icon_modulate)

		# 3. Cooldown Overlay along sprite edges
		if on_cd and not is_locked:
			var ratio := clampf(cooldown_remaining / max(cooldown_max, 0.001), 0.0, 1.0)
			var cd_poly := get_edge_polygon(btn_rect, 0.0)
			draw_colored_polygon(cd_poly, Color(0.02, 0.04, 0.08, 0.72 * ratio + 0.15))

			# Sweep line indicator along edges
			var start_angle := -PI * 0.5
			var sweep_angle := ratio * TAU
			var sweep_edge_angle := start_angle + sweep_angle
			var edge_dist := side * 0.65
			var edge_pt := center_pos + Vector2(cos(sweep_edge_angle), sin(sweep_edge_angle)) * edge_dist
			draw_line(center_pos, edge_pt, Color(1.0, 1.0, 1.0, 0.85), 3.0)

		# 4. Outlines based on button edges
		var border_col: Color
		if is_locked:
			border_col = Color(0.35, 0.40, 0.48, 0.65)
		elif is_pressed:
			border_col = Color.WHITE
		elif on_cd:
			border_col = Color(0.40, 0.45, 0.55, 0.70)
		elif upgrade_level > 0:
			border_col = get_upgrade_outline_color(upgrade_level)
		else:
			border_col = theme_color

		var border_w := 4.5 if is_pressed else (2.5 if (on_cd or is_locked) else 4.0)
		draw_polyline(get_edge_polygon(btn_rect, 0.0), border_col, border_w)
		if not on_cd and not is_pressed and not is_locked:
			draw_polyline(get_edge_polygon(btn_rect, -4.0), Color(1.0, 1.0, 1.0, 0.35), 1.5)

		# 4a. Attack Level Outline (Thickened prominent white-to-blue outline along edges)
		if upgrade_level > 0 and not is_locked:
			var up_col := get_upgrade_outline_color(upgrade_level)
			draw_polyline(get_edge_polygon(btn_rect, 4.5), up_col, 6.0)
			draw_polyline(get_edge_polygon(btn_rect, 1.5), up_col, 3.5)

		# 4b. Level Up Choice: Pulsating & Highlighted Opaque White / Confirmation Stages along edges
		if is_upgrade_pulsating:
			var pulse := (sin(pulse_time * 8.0) + 1.0) * 0.5
			var pulse_expand := lerpf(4.0, 14.0, pulse)
			if confirm_stage == 1:
				# Stage 1: Amber/gold selection ring (CONFIRM layer)
				draw_polyline(get_edge_polygon(btn_rect, pulse_expand), Color(1.0, 0.85, 0.2, 0.95), 4.5)
				draw_polyline(get_edge_polygon(btn_rect, 2.0), Color(1.0, 0.90, 0.4), 3.5)
				draw_colored_polygon(get_edge_polygon(btn_rect, 0.0), Color(1.0, 0.85, 0.2, 0.22 + pulse * 0.15))
			elif confirm_stage == 2:
				# Stage 2: Vibrant electric cyan final confirmation double ring (+ 1 DMG layer)
				draw_polyline(get_edge_polygon(btn_rect, pulse_expand + 2.0), Color(0.2, 0.95, 1.0, 0.98), 5.5)
				draw_polyline(get_edge_polygon(btn_rect, 2.0), Color.WHITE, 4.5)
				draw_colored_polygon(get_edge_polygon(btn_rect, 0.0), Color(0.2, 0.90, 1.0, 0.30 + pulse * 0.20))
			else:
				# Stage 0: Outer pulsating bright opaque white ring (LVL UP layer)
				draw_polyline(get_edge_polygon(btn_rect, pulse_expand), Color(1.0, 1.0, 1.0, 0.95), 4.5)
				draw_polyline(get_edge_polygon(btn_rect, 2.0), Color.WHITE, 3.5)
				draw_colored_polygon(get_edge_polygon(btn_rect, 0.0), Color(1.0, 1.0, 1.0, 0.22 + pulse * 0.15))

		# Customization Selection Outline along edges
		if is_selected_in_customizer:
			draw_polyline(get_edge_polygon(btn_rect, 8.0), Color(0.2, 0.85, 1.0, 0.95), 4.0)
			draw_polyline(get_edge_polygon(btn_rect, 14.0), Color.WHITE, 2.0)

		# 5. Centered Typography & Live Timers (Universal Font)
		var font := GameFont.get_bold_font()
		if font == null:
			return

		var font_size := GameFont.UNIVERSAL_FONT_SIZE

		if is_upgrade_pulsating:
			# 3 Distinct Layers for Attack Leveling:
			# Layer 1: "LVL UP" (Base pulsating state)
			# Layer 2: "CONFIRM" (1st tap selection)
			# Layer 3: "+ 1 DMG" (2nd tap confirmation)
			var up_str := "LVL UP"
			if confirm_stage == 1:
				up_str = "CONFIRM"
			elif confirm_stage == 2:
				up_str = "+ 1 DMG"
			var u_w := font.get_string_size(up_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
			var u_pos := center_pos + Vector2(-u_w * 0.5, font_size * 0.35)
			draw_string_outline(font, u_pos, up_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 4, Color.BLACK)
			draw_string(font, u_pos, up_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
		elif is_locked:
			var lock_str := "LV.%d" % unlock_level
			var t_w := font.get_string_size(lock_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
			var t_pos := center_pos + Vector2(-t_w * 0.5, 10)
			draw_string_outline(font, t_pos, lock_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 4, Color.BLACK)
			draw_string(font, t_pos, lock_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.75, 0.75, 0.80, 0.85))
		elif on_cd:
			# Cooldown timer prominently in center of circle
			var timer_str: String
			if cooldown_remaining >= 10.0:
				timer_str = "%ds" % int(ceilf(cooldown_remaining))
			else:
				timer_str = "%.1fs" % cooldown_remaining

			var t_w := font.get_string_size(timer_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
			var t_pos := center_pos + Vector2(-t_w * 0.5, 10)
			draw_string_outline(font, t_pos, timer_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 4, Color.BLACK)
			draw_string(font, t_pos, timer_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1.0, 0.95, 0.7))
		else:
			# Ready state: Button Title in center of circle
			var t_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
			var t_pos := center_pos + Vector2(-t_w * 0.5, 10)
			draw_string_outline(font, t_pos, title, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 4, Color.BLACK)
			draw_string(font, t_pos, title, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)


# =============================================================================
# MAIN TOUCH CONTROLS CONTAINER
# =============================================================================
# Local Phone Persistence Config
const CONFIG_PATH := "user://touch_controls_config.json"

var joystick: TouchJoystick
var buttons: Array[MobaTouchButton] = []
var top_buttons: Array[TopBarButton] = []
var player: Fighter

# Customization Mode State
var is_customizing: bool = false
var selected_button: Control = null
var is_dragging_custom_button: bool = false
var drag_touch_id: int = -1
var drag_offset: Vector2 = Vector2.ZERO

# Customizer UI nodes
var customizer_banner: PanelContainer
var customizer_panel: PanelContainer
var custom_selected_lbl: Label
var custom_size_lbl: Label
var custom_slider: HSlider
var btn_size_minus: Button
var btn_size_plus: Button
var btn_custom_save: Button
var btn_custom_reset: Button

# MOBA Circular Buttons (Enlarged)
var btn_atk1: MobaTouchButton
var btn_atk2: MobaTouchButton
var btn_atk3: MobaTouchButton
var btn_special: MobaTouchButton
var btn_dash: MobaTouchButton

# 3-Tap Attack Upgrade Confirmation State (Prevents spam accidental upgrades)
var upgrade_selected_slot: StringName = &""
var upgrade_confirm_stage: int = 0
var upgrade_confirm_timer: float = 0.0
var last_upgrade_tap_time: int = -10000
var upgrade_prompt_banner: PanelContainer
var upgrade_prompt_lbl: Label

# Top Bar Buttons
var btn_top_debug: TopBarButton


func _ready() -> void:
	layer = 65 # UI layer above world, below HUD/CRT
	add_to_group(&"touch_controls")

	# Lock to horizontal orientation with sensor auto-rotation on horizontal
	if DisplayServer.has_method("screen_set_orientation"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)

	# 1. Create Joystick
	joystick = TouchJoystick.new()
	add_child(joystick)

	# 2. Create Top Bar Buttons
	_setup_top_buttons()

	# 3. Create Pokemon UNITE MOBA Button Cluster (Non-overlapping ergonomic layout)
	_setup_buttons()
	_update_layout()
	load_custom_config()
	_build_customizer_ui()
	_build_upgrade_prompt_ui()

	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_on_viewport_size_changed)


func _setup_top_buttons() -> void:
	# Debug Menu Button
	btn_top_debug = TopBarButton.new()
	btn_top_debug.action_name = &"debug"
	btn_top_debug.title = "DEBUG"
	btn_top_debug.btn_rect = Rect2(Vector2(24, 16), Vector2(180, 60))
	btn_top_debug.pressed.connect(_on_top_button_pressed)
	add_child(btn_top_debug)
	top_buttons.append(btn_top_debug)


func _setup_buttons() -> void:
	# Attack 1 (Basic Attack - Tackle): Primary thumb button (radius 84, side 168px)
	btn_atk1 = MobaTouchButton.new()
	btn_atk1.slot_name = &"attack_1"
	btn_atk1.radius = 84.0
	btn_atk1.title = "ATK 1"
	btn_atk1.sub_title = "TACKLE"
	btn_atk1.theme_color = Color(0.96, 0.58, 0.15)
	btn_atk1.pressed.connect(_on_button_pressed)
	add_child(btn_atk1)
	buttons.append(btn_atk1)

	# Attack 2 (Move 1 - Razor Leaf): Grass green button (radius 68, side 136px)
	btn_atk2 = MobaTouchButton.new()
	btn_atk2.slot_name = &"attack_2"
	btn_atk2.radius = 68.0
	btn_atk2.title = "ATK 2"
	btn_atk2.sub_title = "RAZOR LEAF"
	btn_atk2.theme_color = Color(0.22, 0.78, 0.35)
	btn_atk2.cooldown_max = 2.0
	btn_atk2.pressed.connect(_on_button_pressed)
	add_child(btn_atk2)
	buttons.append(btn_atk2)

	# Attack 3 (Move 2 - Solar Beam): Purple button (radius 68, side 136px)
	btn_atk3 = MobaTouchButton.new()
	btn_atk3.slot_name = &"attack_3"
	btn_atk3.radius = 68.0
	btn_atk3.title = "ATK 3"
	btn_atk3.sub_title = "SOLAR BEAM"
	btn_atk3.theme_color = Color(0.72, 0.32, 0.95)
	btn_atk3.cooldown_max = 20.0
	btn_atk3.pressed.connect(_on_button_pressed)
	add_child(btn_atk3)
	buttons.append(btn_atk3)

	# Special (Unite Move - Universal 60s): Golden button (radius 64, side 128px)
	btn_special = MobaTouchButton.new()
	btn_special.slot_name = &"special"
	btn_special.radius = 64.0
	btn_special.title = "UNITE"
	btn_special.sub_title = "UNITE"
	btn_special.theme_color = Color(1.0, 0.82, 0.18)
	btn_special.cooldown_max = 60.0
	btn_special.pressed.connect(_on_button_pressed)
	add_child(btn_special)
	buttons.append(btn_special)

	# Dash (Battle Item - Dash): Electric Cyan button (radius 58, side 116px)
	btn_dash = MobaTouchButton.new()
	btn_dash.slot_name = &"dash"
	btn_dash.radius = 58.0
	btn_dash.title = "DASH"
	btn_dash.sub_title = "DASH"
	btn_dash.theme_color = Color(0.18, 0.74, 0.96)
	btn_dash.cooldown_max = 1.5
	btn_dash.pressed.connect(_on_button_pressed)
	btn_dash.released.connect(_on_button_released)
	add_child(btn_dash)
	buttons.append(btn_dash)


func _get_vp_size() -> Vector2:
	var vp := get_viewport()
	if vp != null:
		var rect := vp.get_visible_rect()
		if rect.size.x > 0 and rect.size.y > 0:
			return rect.size
	return Vector2(1920, 1080)


func _on_viewport_size_changed() -> void:
	_update_layout()
	_position_customizer_ui()


func _update_layout() -> void:
	var vp_size := _get_vp_size()

	# Dynamic scale factor based on screen height (1080p base, gracefully scales up/down)
	var s := clampf(vp_size.y / 1080.0, 0.75, 1.4)

	# Dynamic Top Bar Touch Button: Debug Menu only
	var top_h := 88.0 * s
	var top_y := 18.0 * s
	if btn_top_debug != null and not btn_top_debug.has_meta(&"has_custom_pos"):
		var w := 200.0 * s
		btn_top_debug.btn_rect = Rect2(Vector2(24.0 * s, top_y), Vector2(w, top_h))

	# Upgrade Prompt Banner (centered horizontally below top buttons)
	if upgrade_prompt_banner != null:
		var banner_w := minf(vp_size.x - 48.0, 1100.0 * s)
		var banner_h := 68.0 * s
		upgrade_prompt_banner.custom_minimum_size = Vector2(banner_w, banner_h)
		upgrade_prompt_banner.size = Vector2(banner_w, banner_h)
		upgrade_prompt_banner.position = Vector2((vp_size.x - banner_w) * 0.5, top_y + top_h + 16.0 * s)

	# Reorganized MOBA button fan layout: ergonomic, fully visible, zero overlap
	if btn_atk1 != null and not btn_atk1.has_meta(&"has_custom_pos"):
		btn_atk1.radius = 84.0 * s
		btn_atk1.center_pos = vp_size - Vector2(175, 175) * s

	if btn_atk2 != null and not btn_atk2.has_meta(&"has_custom_pos"):
		btn_atk2.radius = 68.0 * s
		btn_atk2.center_pos = vp_size - Vector2(365, 160) * s

	if btn_atk3 != null and not btn_atk3.has_meta(&"has_custom_pos"):
		btn_atk3.radius = 68.0 * s
		btn_atk3.center_pos = vp_size - Vector2(310, 335) * s

	if btn_special != null and not btn_special.has_meta(&"has_custom_pos"):
		btn_special.radius = 64.0 * s
		btn_special.center_pos = vp_size - Vector2(145, 365) * s

	if btn_dash != null and not btn_dash.has_meta(&"has_custom_pos"):
		btn_dash.radius = 58.0 * s
		btn_dash.center_pos = vp_size - Vector2(525, 160) * s

	if joystick != null:
		joystick.max_radius = 140.0 * s
		joystick.deadzone = 20.0 * s
		joystick.knob_radius = 48.0 * s

	for b in buttons:
		b.queue_redraw()
	for tb in top_buttons:
		tb.queue_redraw()


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_find_player()

	if player != null:
		var upgrades_count: int = player.get("pending_attack_upgrades") if "pending_attack_upgrades" in player else 0
		var has_upgrades: bool = upgrades_count > 0
		for b in buttons:
			if b.slot_name in [&"attack_1", &"attack_2", &"attack_3"]:
				b.is_upgrade_pulsating = has_upgrades
			else:
				b.is_upgrade_pulsating = false
			b.update_cooldown(player)

	# 3-tap confirmation timeout check
	if upgrade_confirm_stage > 0:
		upgrade_confirm_timer -= delta
		if upgrade_confirm_timer <= 0.0:
			upgrade_confirm_stage = 0
			upgrade_selected_slot = &""
			_update_upgrade_confirm_visuals()


func _update_upgrade_confirm_visuals() -> void:
	var has_upgrades := false
	if player != null and is_instance_valid(player):
		var upgrades_count: int = player.get("pending_attack_upgrades") if "pending_attack_upgrades" in player else 0
		has_upgrades = (upgrades_count > 0)

	for b in buttons:
		if b.slot_name in [&"attack_1", &"attack_2", &"attack_3"]:
			b.is_upgrade_pulsating = has_upgrades
			if b.slot_name == upgrade_selected_slot:
				b.confirm_stage = upgrade_confirm_stage
			else:
				b.confirm_stage = 0
			if player != null:
				b.update_cooldown(player)
		b.queue_redraw()


func _find_player() -> void:
	for node in get_tree().get_nodes_in_group(&"fighters"):
		var f := node as Fighter
		if f != null and f.team == &"player":
			player = f
			break


func _on_top_button_pressed(action: StringName) -> void:
	AudioManager.play_button_click()
	match action:
		&"debug":
			var dm = get_node_or_null("/root/DebugMenu")
			if dm != null and dm.has_method("_toggle"):
				dm._toggle()


func _on_button_pressed(slot: StringName) -> void:
	if player == null or not is_instance_valid(player):
		_find_player()
	if player == null:
		return

	# Handle attack level up upgrade choice with 3 distinct layers:
	# Layer 1: "LVL UP" (Base pulsating state) -> Tap 1 selects attack, enters Stage 1 ("CONFIRM")
	# Layer 2: "CONFIRM" (Stage 1) -> Tap 2 enters Stage 2 ("+ 1 DMG")
	# Layer 3: "+ 1 DMG" (Stage 2) -> Tap 3 confirms & levels up attack!
	# Repeat flow as long as more points are stored (hidden value)
	if ("pending_attack_upgrades" in player) and player.pending_attack_upgrades > 0 and slot in [&"attack_1", &"attack_2", &"attack_3"]:
		var now := Time.get_ticks_msec()
		if (now - last_upgrade_tap_time) < 150:
			return
		last_upgrade_tap_time = now

		if upgrade_selected_slot != slot:
			upgrade_selected_slot = slot
			upgrade_confirm_stage = 1
			upgrade_confirm_timer = 5.0
			AudioManager.play_button_click()
			HapticManager.play_level_up_confirm_1()
			_update_upgrade_confirm_visuals()
			return
		elif upgrade_confirm_stage == 1:
			upgrade_confirm_stage = 2
			upgrade_confirm_timer = 5.0
			AudioManager.play_button_click()
			HapticManager.play_level_up_confirm_2()
			_update_upgrade_confirm_visuals()
			return
		elif upgrade_confirm_stage == 2:
			upgrade_confirm_stage = 0
			upgrade_selected_slot = &""
			player.upgrade_attack(slot)
			# Seamlessly repeats the flow if more points remain stored
			_update_upgrade_confirm_visuals()
			return

	# Normal Attack, Dash, and Unite button presses (audio feedback, button haptics removed)
	# Moves with their own move sound (like Razor Leaf) generate sound strictly on execution (play only once)
	var move_has_sound := false
	if player != null and player.has_method("get_move_in_slot"):
		var m = player.get_move_in_slot(slot)
		if m != null and m.sound_path != "":
			move_has_sound = true

	match slot:
		&"attack_1", &"attack_2", &"attack_3":
			if not move_has_sound:
				AudioManager.play_atk_button()
		&"dash":
			AudioManager.play_dash_button()
		&"special":
			if not move_has_sound:
				AudioManager.play_unite_button()

	if slot == &"dash":
		if player.has_method("start_dash_aim"):
			player.call("start_dash_aim")
		elif player.has_method("_start_dash"):
			var facing_dir: Vector2 = player.get("facing") if "facing" in player else Vector2.DOWN
			player.call("_start_dash", facing_dir)
	else:
		if player.has_method("is_shot_slot") and player.call("is_shot_slot", slot):
			if player.has_method("start_shot_aim"):
				player.call("start_shot_aim", slot)
				return
		if player.has_method("_use_slot"):
			player.call("_use_slot", slot)


func _on_button_released(slot: StringName) -> void:
	if player == null or not is_instance_valid(player):
		_find_player()
	if player == null:
		return

	if slot == &"dash":
		if player.has_method("release_dash"):
			player.call("release_dash")
	else:
		if player.has_method("is_shot_slot") and player.call("is_shot_slot", slot):
			if player.has_method("release_shot"):
				player.call("release_shot", slot)


# =============================================================================
# INPUT HANDLING
# Supports Multi-touch on Android and Mouse Emulation on Desktop
# =============================================================================
func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.has_method("is_emulated") and event.is_emulated():
		return

	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_handle_touch(st.index, st.position, st.pressed)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_handle_drag(sd.index, sd.position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_touch(0, mb.position, mb.pressed)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_handle_drag(0, mm.position)


func _handle_touch(touch_id: int, pos: Vector2, pressed: bool) -> void:
	if is_customizing:
		_handle_customizing_touch(touch_id, pos, pressed)
		return

	if pressed:
		# 1. Check top bar buttons first
		for tb in top_buttons:
			if tb.is_point_inside(pos):
				tb.on_touch_down(touch_id, pos)
				get_viewport().set_input_as_handled()
				return

		# 2. Check MOBA circular buttons
		for b in buttons:
			if b.is_point_inside(pos):
				b.on_touch_down(touch_id, pos)
				get_viewport().set_input_as_handled()
				return

		# 3. Touch is not on any button -> spawn dynamic joystick under finger anywhere on screen
		if not joystick.is_active:
			joystick.activate(touch_id, pos)
	else:
		# Release top buttons
		for tb in top_buttons:
			if tb.touch_id == touch_id:
				tb.on_touch_up()

		# Release MOBA buttons
		for b in buttons:
			if b.touch_id == touch_id:
				b.on_touch_up()

		# Release joystick touch
		if joystick.is_active and joystick.touch_id == touch_id:
			joystick.deactivate()


func _handle_customizing_touch(touch_id: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		if customizer_panel != null and customizer_panel.visible and customizer_panel.get_global_rect().has_point(pos):
			return
		if customizer_banner != null and customizer_banner.visible and customizer_banner.get_global_rect().has_point(pos):
			return

		for b in buttons:
			if b.is_point_inside(pos):
				_select_button(b)
				is_dragging_custom_button = true
				drag_touch_id = touch_id
				drag_offset = b.center_pos - pos
				get_viewport().set_input_as_handled()
				return

		for tb in top_buttons:
			if tb.is_point_inside(pos):
				_select_button(tb)
				is_dragging_custom_button = true
				drag_touch_id = touch_id
				drag_offset = tb.btn_rect.position - pos
				get_viewport().set_input_as_handled()
				return
	else:
		if drag_touch_id == touch_id:
			is_dragging_custom_button = false
			drag_touch_id = -1


func _handle_drag(touch_id: int, pos: Vector2) -> void:
	if is_customizing:
		if is_dragging_custom_button and drag_touch_id == touch_id and selected_button != null:
			var vp_size := _get_vp_size()
			if selected_button is MobaTouchButton:
				var mb := selected_button as MobaTouchButton
				var new_pos := pos + drag_offset
				new_pos.x = clampf(new_pos.x, mb.radius, vp_size.x - mb.radius)
				new_pos.y = clampf(new_pos.y, mb.radius, vp_size.y - mb.radius)
				mb.center_pos = new_pos
				mb.set_meta(&"has_custom_pos", true)
				mb.queue_redraw()
			elif selected_button is TopBarButton:
				var tb := selected_button as TopBarButton
				var new_pos := pos + drag_offset
				new_pos.x = clampf(new_pos.x, 0.0, vp_size.x - tb.size.x)
				new_pos.y = clampf(new_pos.y, 0.0, vp_size.y - tb.size.y)
				tb.btn_rect.position = new_pos
				tb.set_meta(&"has_custom_pos", true)
				tb.queue_redraw()
		return

	if joystick.is_active and joystick.touch_id == touch_id:
		joystick.drag(pos)

	# Drag-aiming for Dash or Shot buttons
	if player != null and is_instance_valid(player):
		for b in buttons:
			if b.is_pressed and b.touch_id == touch_id:
				var drag_vec := pos - b.center_pos
				if drag_vec.length() > 15.0:
					var aim_dir := drag_vec.normalized()
					if b.slot_name == &"dash":
						if player.has_method("update_dash_aim_dir"):
							player.call("update_dash_aim_dir", aim_dir)
					elif player.has_method("is_shot_slot") and player.call("is_shot_slot", b.slot_name):
						if player.has_method("update_shot_aim_dir"):
							player.call("update_shot_aim_dir", aim_dir)


# Customization Methods
func _make_style(bg_col: Color, border_col: Color, radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = border_col
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = 16
	sb.content_margin_top = 10
	sb.content_margin_right = 16
	sb.content_margin_bottom = 10
	return sb


func _build_upgrade_prompt_ui() -> void:
	# Notification banner for new attack level points removed per user request
	pass


func _build_customizer_ui() -> void:
	# 1. Top Mode Banner
	customizer_banner = PanelContainer.new()
	customizer_banner.visible = false
	customizer_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var banner_style := _make_style(Color(0.04, 0.08, 0.16, 0.95), Color(0.2, 0.75, 1.0, 0.95), 8)
	customizer_banner.add_theme_stylebox_override(&"panel", banner_style)
	add_child(customizer_banner)

	var banner_lbl := Label.new()
	banner_lbl.text = "CUSTOMIZE CONTROLS: Tap button to select, drag anywhere to move"
	banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameFont.apply_label(banner_lbl, GameFont.UNIVERSAL_FONT_SIZE, Color.WHITE, true, Color.BLACK, 2)
	customizer_banner.add_child(banner_lbl)

	# 2. Floating Customizer Dock Panel
	customizer_panel = PanelContainer.new()
	customizer_panel.visible = false
	customizer_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := _make_style(Color(0.06, 0.10, 0.18, 0.98), Color(0.35, 0.75, 1.0, 0.95), 8)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	customizer_panel.add_theme_stylebox_override(&"panel", panel_style)
	add_child(customizer_panel)

	var panel_vbox := VBoxContainer.new()
	panel_vbox.add_theme_constant_override(&"separation", 12)
	customizer_panel.add_child(panel_vbox)

	# Row 1: Selected button label
	custom_selected_lbl = Label.new()
	custom_selected_lbl.text = "SELECT A BUTTON"
	custom_selected_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameFont.apply_label(custom_selected_lbl, GameFont.UNIVERSAL_FONT_SIZE, Color(0.35, 0.85, 1.0, 1.0), true, Color.BLACK, 2)
	panel_vbox.add_child(custom_selected_lbl)

	# Row 2: Size slider + steppers
	var size_hbox := HBoxContainer.new()
	size_hbox.add_theme_constant_override(&"separation", 12)
	panel_vbox.add_child(size_hbox)

	custom_size_lbl = Label.new()
	custom_size_lbl.text = "SIZE: 94px"
	custom_size_lbl.custom_minimum_size = Vector2(170, 48)
	custom_size_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GameFont.apply_label(custom_size_lbl, GameFont.UNIVERSAL_FONT_SIZE, Color.WHITE)
	size_hbox.add_child(custom_size_lbl)

	btn_size_minus = Button.new()
	btn_size_minus.text = "[-] -5"
	btn_size_minus.custom_minimum_size = Vector2(90, 52)
	GameFont.apply_button(btn_size_minus, GameFont.UNIVERSAL_FONT_SIZE, Color.WHITE)
	var btn_step_style := _make_style(Color(0.14, 0.22, 0.36, 0.95), Color(0.35, 0.65, 0.95, 0.8), 4)
	btn_size_minus.add_theme_stylebox_override(&"normal", btn_step_style)
	btn_size_minus.pressed.connect(func(): _change_selected_size(-5.0))
	size_hbox.add_child(btn_size_minus)

	custom_slider = HSlider.new()
	custom_slider.min_value = 40.0
	custom_slider.max_value = 150.0
	custom_slider.step = 1.0
	custom_slider.value = 94.0
	custom_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_slider.custom_minimum_size = Vector2(260, 48)
	custom_slider.value_changed.connect(_on_size_slider_changed)
	size_hbox.add_child(custom_slider)

	btn_size_plus = Button.new()
	btn_size_plus.text = "[+] +5"
	btn_size_plus.custom_minimum_size = Vector2(90, 52)
	GameFont.apply_button(btn_size_plus, GameFont.UNIVERSAL_FONT_SIZE, Color.WHITE)
	btn_size_plus.add_theme_stylebox_override(&"normal", btn_step_style)
	btn_size_plus.pressed.connect(func(): _change_selected_size(5.0))
	size_hbox.add_child(btn_size_plus)

	# Row 3: Action buttons (Reset & Save)
	var actions_hbox := HBoxContainer.new()
	actions_hbox.add_theme_constant_override(&"separation", 16)
	panel_vbox.add_child(actions_hbox)

	btn_custom_reset = Button.new()
	btn_custom_reset.text = "RESET DEFAULT"
	btn_custom_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_custom_reset.custom_minimum_size = Vector2(0, 54)
	GameFont.apply_button(btn_custom_reset, GameFont.UNIVERSAL_FONT_SIZE, Color(1.0, 0.85, 0.85))
	var reset_style := _make_style(Color(0.35, 0.15, 0.15, 0.95), Color(0.85, 0.35, 0.35, 0.8), 4)
	btn_custom_reset.add_theme_stylebox_override(&"normal", reset_style)
	btn_custom_reset.pressed.connect(reset_to_default_layout)
	actions_hbox.add_child(btn_custom_reset)

	btn_custom_save = Button.new()
	btn_custom_save.text = "SAVE & EXIT"
	btn_custom_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_custom_save.custom_minimum_size = Vector2(0, 54)
	GameFont.apply_button(btn_custom_save, GameFont.UNIVERSAL_FONT_SIZE, Color.WHITE)
	var save_style := _make_style(Color(0.12, 0.42, 0.22, 0.95), Color(0.25, 0.85, 0.45, 0.9), 4)
	btn_custom_save.add_theme_stylebox_override(&"normal", save_style)
	btn_custom_save.pressed.connect(func():
		save_custom_config()
		exit_customization()
	)
	actions_hbox.add_child(btn_custom_save)


func _position_customizer_ui() -> void:
	var vp_size := _get_vp_size()
	if customizer_banner != null:
		var banner_w := minf(vp_size.x - 48.0, 940.0)
		customizer_banner.custom_minimum_size = Vector2(banner_w, 56.0)
		customizer_banner.size = Vector2(banner_w, 56.0)
		customizer_banner.position = Vector2((vp_size.x - banner_w) * 0.5, 14.0)

	if customizer_panel != null:
		var panel_w := minf(vp_size.x - 48.0, 800.0)
		var panel_h := 190.0
		customizer_panel.custom_minimum_size = Vector2(panel_w, panel_h)
		customizer_panel.size = Vector2(panel_w, panel_h)
		customizer_panel.position = Vector2((vp_size.x - panel_w) * 0.5, 84.0)


func start_customization() -> void:
	if customizer_panel == null:
		_build_customizer_ui()
	is_customizing = true
	if customizer_banner != null:
		customizer_banner.visible = true
	if customizer_panel != null:
		customizer_panel.visible = true
	_position_customizer_ui()
	if btn_atk1 != null:
		_select_button(btn_atk1)
	print("Touch Controls customization mode started")


func exit_customization() -> void:
	is_customizing = false
	is_dragging_custom_button = false
	drag_touch_id = -1
	if customizer_banner != null:
		customizer_banner.visible = false
	if customizer_panel != null:
		customizer_panel.visible = false
	for b in buttons:
		b.is_selected_in_customizer = false
		b.queue_redraw()
	for tb in top_buttons:
		tb.is_selected_in_customizer = false
		tb.queue_redraw()
	selected_button = null
	print("Touch Controls customization mode exited")


func _select_button(btn: Control) -> void:
	selected_button = btn
	for b in buttons:
		b.is_selected_in_customizer = (b == btn)
		b.queue_redraw()
	for tb in top_buttons:
		tb.is_selected_in_customizer = (tb == btn)
		tb.queue_redraw()

	if btn is MobaTouchButton:
		var mb := btn as MobaTouchButton
		if custom_selected_lbl != null:
			custom_selected_lbl.text = "SELECTED: " + mb.title + " (" + mb.sub_title + ")"
		if custom_slider != null:
			custom_slider.set_value_no_signal(mb.radius)
		if custom_size_lbl != null:
			custom_size_lbl.text = "SIZE: %dpx" % int(roundf(mb.radius))
	elif btn is TopBarButton:
		var tb := btn as TopBarButton
		if custom_selected_lbl != null:
			custom_selected_lbl.text = "SELECTED: " + tb.title
		if custom_slider != null:
			custom_slider.set_value_no_signal(tb.size.x)
		if custom_size_lbl != null:
			custom_size_lbl.text = "WIDTH: %dpx" % int(roundf(tb.size.x))


func _on_size_slider_changed(val: float) -> void:
	if selected_button == null:
		return
	if selected_button is MobaTouchButton:
		var mb := selected_button as MobaTouchButton
		mb.radius = val
		mb.set_meta(&"has_custom_pos", true)
		mb.queue_redraw()
		if custom_size_lbl != null:
			custom_size_lbl.text = "SIZE: %dpx" % int(roundf(val))
	elif selected_button is TopBarButton:
		var tb := selected_button as TopBarButton
		tb.btn_rect.size.x = val
		tb.set_meta(&"has_custom_pos", true)
		tb.queue_redraw()
		if custom_size_lbl != null:
			custom_size_lbl.text = "WIDTH: %dpx" % int(roundf(val))


func _change_selected_size(diff: float) -> void:
	if custom_slider != null:
		var new_val := clampf(custom_slider.value + diff, custom_slider.min_value, custom_slider.max_value)
		custom_slider.value = new_val


func save_custom_config() -> void:
	var cfg := {}
	var btn_dict := {}
	var vp_size := _get_vp_size()
	for b in buttons:
		btn_dict[String(b.slot_name)] = {
			"x": b.center_pos.x,
			"y": b.center_pos.y,
			"pct_x": b.center_pos.x / maxf(vp_size.x, 1.0),
			"pct_y": b.center_pos.y / maxf(vp_size.y, 1.0),
			"radius": b.radius
		}
	cfg["buttons"] = btn_dict

	var f := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(cfg, "\t"))
		f.close()
		print("Successfully saved touch controls configuration to ", CONFIG_PATH)
	else:
		push_error("Failed to write controls config to " + CONFIG_PATH)


func load_custom_config() -> bool:
	if not FileAccess.file_exists(CONFIG_PATH):
		return false
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(txt) != OK:
		return false
	var data: Dictionary = json.data
	if not data.has("buttons"):
		return false
	var btn_dict: Dictionary = data["buttons"]
	var vp_size := _get_vp_size()
	for b in buttons:
		var key := String(b.slot_name)
		if btn_dict.has(key):
			var info: Dictionary = btn_dict[key]
			if info.has("x") and info.has("y"):
				b.center_pos = Vector2(float(info["x"]), float(info["y"]))
			elif info.has("pct_x") and info.has("pct_y"):
				b.center_pos = Vector2(float(info["pct_x"]) * vp_size.x, float(info["pct_y"]) * vp_size.y)
			if info.has("radius"):
				b.radius = float(info["radius"])
			b.set_meta(&"has_custom_pos", true)
			b.queue_redraw()
	print("Successfully loaded touch controls configuration from ", CONFIG_PATH)
	return true


func reset_to_default_layout() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		DirAccess.remove_absolute(CONFIG_PATH)
	for b in buttons:
		if b.has_meta(&"has_custom_pos"):
			b.remove_meta(&"has_custom_pos")
	for tb in top_buttons:
		if tb.has_meta(&"has_custom_pos"):
			tb.remove_meta(&"has_custom_pos")
	_update_layout()
	if selected_button != null:
		_select_button(selected_button)
	print("Touch controls reset to default layout")


# Movement vector for player.gd to query
func get_joystick_vector() -> Vector2:
	if joystick != null and joystick.is_active:
		return joystick.output
	return Vector2.ZERO
