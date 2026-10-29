extends CanvasLayer

# Constants
const DUMMY_SCENE := preload("res://tests/dummy.tscn")
const DUMMY_ENEMY_SCENE := preload("res://tests/dummy_enemy.tscn")
const CRT_SHADER := preload("res://shaders/crt.gdshader")
const FONT_PKMN := preload("res://assets/pokemon-emerald-pro.ttf")
const GameFont := preload("res://ui/game_font.gd")
const SPAWN_OFFSET := Vector2(64, 0)

const OPTIONS := [
	{"label": "dummy (no attack back logic)", "action": &"_spawn_dummy"},
	{"label": "dummy_enemy (counter attacks)", "action": &"_spawn_dummy_enemy"},
	{"label": "hitbox show", "action": &"_toggle_hitbox_show"},
	{"label": "crt", "action": &"_toggle_crt"},
	{"label": "chromatic aberration", "action": &"_adjust_chromatic_aberration"},
	{"label": "customize controls", "action": &"_start_customize_controls"},
	{"label": "player level", "action": &"_debug_increase_player_level"},
	{"label": "close debug menu", "action": &"_toggle"},
]

# Signals
signal hitboxes_toggled(show: bool)
signal crt_toggled(show: bool)

# State
var selected := 0
var show_hitboxes := false
var show_crt := true
var crt_line_size: float = 2.0
var chromatic_aberration: float = 10.0

# Screen tint & CRT layers
var tint_layer: CanvasLayer
var tint_rect: ColorRect
var crt_layer: CanvasLayer
var crt_rect: ColorRect

const MAX_DUMMIES := 3

# UI Nodes (Mobile-Friendly Touch UI)
var tree_ref: SceneTree = null
var player_ref: Fighter = null
var dim_layer: Control
var panel: PanelContainer
var label: Label # Backward compatibility for legacy tests/readers
var btn_spawn_dummy: Button
var btn_spawn_dummy_enemy: Button
var btn_spawn_giant_dummy: Button
var btn_toggle_hitbox: Button
var btn_toggle_crt: Button
var btn_customize_controls: Button
var lvl_status_lbl: Label
var lvl_edit: LineEdit
var lvl_slider: HSlider
var btn_lvl_minus: Button
var btn_lvl_plus: Button
var btn_lvl_set: Button
var ca_edit: LineEdit
var ca_slider: HSlider
var btn_ca_minus: Button
var btn_ca_plus: Button
var btn_top_close: Button
var btn_bottom_close: Button

# GBA stepped tint sequence (discrete retro blend levels, 2 frames per step)
const GBA_TINT_STEPS: Array[float] = [0.0, 0.18, 0.38, 0.52, 0.38, 0.25, 0.12, 0.0]
const TINT_STEP_FRAMES := 2
var tint_step_idx := -1
var tint_frame_timer := 0
var open_frame := -100


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	# 1. Red Screen Tint layer (layer 80, rendered below CRT)
	tint_layer = CanvasLayer.new()
	tint_layer.layer = 80
	tint_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(tint_layer)

	tint_rect = ColorRect.new()
	tint_rect.anchors_preset = Control.PRESET_FULL_RECT
	tint_rect.anchor_right = 1.0
	tint_rect.anchor_bottom = 1.0
	tint_rect.color = Color(0.9, 0.05, 0.05, 0.0)
	tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint_layer.add_child(tint_rect)

	# 2. CRT Post-Processing Layer (layer 90, above game and tint so CRT affects all)
	crt_layer = CanvasLayer.new()
	crt_layer.layer = 90
	crt_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	crt_layer.visible = show_crt
	add_child(crt_layer)

	crt_rect = ColorRect.new()
	crt_rect.anchors_preset = Control.PRESET_FULL_RECT
	crt_rect.anchor_right = 1.0
	crt_rect.anchor_bottom = 1.0
	crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crt_mat := ShaderMaterial.new()
	crt_mat.shader = CRT_SHADER
	crt_mat.set_shader_parameter("crt_enabled", show_crt)
	crt_mat.set_shader_parameter("scanline_line_size", crt_line_size)
	crt_mat.set_shader_parameter("chromatic_aberration", chromatic_aberration)
	crt_rect.material = crt_mat
	crt_layer.add_child(crt_rect)
	_update_crt_layer_visibility()

	# 3. Mobile Touch Debug Menu UI (layer 100)
	_build_mobile_ui()
	_refresh()


func _make_style(bg_col: Color, _border_col: Color = Color.TRANSPARENT, radius: int = 6) -> StyleBox:
	return UIDynamic.make_style(bg_col, radius)


func _build_mobile_ui() -> void:
	# 1. Fullscreen translucent backdrop modal (child of CanvasLayer)
	dim_layer = Control.new()
	dim_layer.visible = false
	dim_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_layer.gui_input.connect(_on_dim_layer_gui_input)
	add_child(dim_layer)

	var dim_color := ColorRect.new()
	dim_color.color = Color(0.02, 0.04, 0.08, 0.78)
	dim_color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim_layer.add_child(dim_color)

	# 2. Centered Card Container (child of CanvasLayer directly, on top of dim_layer)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(1100, 820)
	panel.size = Vector2(1100, 820)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := _make_style(Color(0.06, 0.09, 0.16, 0.98), Color(0.35, 0.65, 0.95, 0.95), 8)
	panel_style.content_margin_left = 28
	panel_style.content_margin_top = 22
	panel_style.content_margin_right = 28
	panel_style.content_margin_bottom = 22
	panel.add_theme_stylebox_override(&"panel", panel_style)
	add_child(panel)

	# Main Vertical Layout
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override(&"separation", 16)
	panel.add_child(main_vbox)

	# 1. Header Bar: Title + Close Button
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override(&"separation", 16)
	main_vbox.add_child(header_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "DEBUG MENU"
	GameFont.apply_label(title_lbl, GameFont.UNIVERSAL_FONT_SIZE, Color(1.0, 1.0, 1.0, 1.0), true, Color(0.0, 0.0, 0.0, 0.9), 2)
	header_hbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "  (Mobile Touch Controls)"
	GameFont.apply_label(sub_lbl, GameFont.UNIVERSAL_FONT_SIZE, Color(0.4, 0.75, 1.0, 0.85))
	header_hbox.add_child(sub_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	btn_top_close = Button.new()
	btn_top_close.text = "✕ CLOSE"
	btn_top_close.custom_minimum_size = Vector2(170, 56)
	GameFont.apply_button(btn_top_close, GameFont.UNIVERSAL_FONT_SIZE, Color(1.0, 0.9, 0.9))
	var close_normal := _make_style(Color(0.65, 0.16, 0.16, 0.95), Color(1.0, 0.4, 0.4, 0.9), 6)
	var close_pressed := _make_style(Color(0.85, 0.22, 0.22, 1.0), Color.WHITE, 6)
	btn_top_close.add_theme_stylebox_override(&"normal", close_normal)
	btn_top_close.add_theme_stylebox_override(&"hover", close_pressed)
	btn_top_close.add_theme_stylebox_override(&"pressed", close_pressed)
	btn_top_close.pressed.connect(AudioManager.play_button_click)
	btn_top_close.pressed.connect(_toggle)
	header_hbox.add_child(btn_top_close)

	# Divider line
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.35, 0.65, 0.95, 0.35)
	main_vbox.add_child(divider)

	# 2. Scrollable Body
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override(&"separation", 14)
	scroll.add_child(content_vbox)

	# Row A: Spawn Dummy
	btn_spawn_dummy = _create_action_button("+ SPAWN PASSIVE DUMMY (NO ATTACK BACK)", Color(0.12, 0.20, 0.34, 0.95))
	btn_spawn_dummy.pressed.connect(_spawn_dummy)
	content_vbox.add_child(btn_spawn_dummy)

	# Row B: Spawn Counter Enemy Dummy
	btn_spawn_dummy_enemy = _create_action_button("+ SPAWN COUNTER ENEMY (ATTACKS BACK)", Color(0.18, 0.14, 0.32, 0.95))
	btn_spawn_dummy_enemy.pressed.connect(_spawn_dummy_enemy)
	content_vbox.add_child(btn_spawn_dummy_enemy)

	# Row B2: Spawn Giant Lv 100 Dummy
	btn_spawn_giant_dummy = _create_action_button("+ SPAWN GIANT LVL 100 DUMMY (3X SIZE, NO ATTACK)", Color(0.28, 0.16, 0.38, 0.95))
	btn_spawn_giant_dummy.pressed.connect(_spawn_giant_dummy)
	content_vbox.add_child(btn_spawn_giant_dummy)

	# Row C: Toggle Hitboxes
	btn_toggle_hitbox = _create_action_button("SHOW HITBOXES: OFF", Color(0.10, 0.16, 0.24, 0.95))
	btn_toggle_hitbox.pressed.connect(_toggle_hitbox_show)
	content_vbox.add_child(btn_toggle_hitbox)

	# Row F2: Player Level Control Card (Custom Value, Slider, -5 / +5 Steppers)
	var lvl_card := PanelContainer.new()
	var lvl_card_style := _make_style(Color(0.08, 0.14, 0.24, 0.95), Color(0.30, 0.65, 0.95, 0.8), 6)
	lvl_card.add_theme_stylebox_override(&"panel", lvl_card_style)
	content_vbox.add_child(lvl_card)

	var lvl_vbox := VBoxContainer.new()
	lvl_vbox.add_theme_constant_override(&"separation", 10)
	lvl_card.add_child(lvl_vbox)

	# Row 1: Title + Info Status + Direct Editable Custom Level LineEdit + Set Button
	var lvl_header := HBoxContainer.new()
	lvl_header.add_theme_constant_override(&"separation", 14)
	lvl_vbox.add_child(lvl_header)

	var lvl_title := Label.new()
	lvl_title.text = "PLAYER LEVEL (1 - 30):"
	GameFont.apply_label(lvl_title, GameFont.UNIVERSAL_FONT_SIZE, Color(1.0, 1.0, 1.0, 0.95))
	lvl_header.add_child(lvl_title)

	lvl_status_lbl = Label.new()
	lvl_status_lbl.text = "Lv. 1 / 30"
	GameFont.apply_label(lvl_status_lbl, GameFont.UNIVERSAL_FONT_SIZE, Color(0.4, 0.85, 1.0, 0.9))
	lvl_header.add_child(lvl_status_lbl)

	var lvl_spacer := Control.new()
	lvl_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lvl_header.add_child(lvl_spacer)

	lvl_edit = LineEdit.new()
	lvl_edit.text = "1"
	lvl_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_edit.custom_minimum_size = Vector2(110, 52)
	lvl_edit.max_length = 3
	GameFont.apply_line_edit(lvl_edit, GameFont.UNIVERSAL_FONT_SIZE, Color.WHITE)
	var lvl_edit_style := _make_style(Color(0.05, 0.08, 0.14, 1.0), Color(0.35, 0.75, 1.0, 0.9), 4)
	lvl_edit.add_theme_stylebox_override(&"normal", lvl_edit_style)
	lvl_edit.add_theme_stylebox_override(&"focus", lvl_edit_style)
	lvl_edit.text_submitted.connect(func(_t): _set_player_level_from_edit())
	lvl_header.add_child(lvl_edit)

	btn_lvl_set = Button.new()
	btn_lvl_set.text = "SET"
	btn_lvl_set.custom_minimum_size = Vector2(100, 52)
	GameFont.apply_button(btn_lvl_set, GameFont.UNIVERSAL_FONT_SIZE, Color.WHITE)
	var set_btn_style := _make_style(Color(0.18, 0.34, 0.54, 0.95), Color(0.4, 0.8, 1.0, 0.9), 4)
	var set_btn_pressed := _make_style(Color(0.28, 0.50, 0.78, 1.0), Color.WHITE, 4)
	btn_lvl_set.add_theme_stylebox_override(&"normal", set_btn_style)
	btn_lvl_set.add_theme_stylebox_override(&"hover", set_btn_pressed)
	btn_lvl_set.add_theme_stylebox_override(&"pressed", set_btn_pressed)
	btn_lvl_set.pressed.connect(_set_player_level_from_edit)
	lvl_header.add_child(btn_lvl_set)

	# Row 2: [-] -5 LVL Button + Slider (1-30) + [+] +5 LVL Button
	var lvl_controls := HBoxContainer.new()
	lvl_controls.add_theme_constant_override(&"separation", 14)
	lvl_vbox.add_child(lvl_controls)

	btn_lvl_minus = Button.new()
	btn_lvl_minus.text = "[-] -5 LVL"
	btn_lvl_minus.custom_minimum_size = Vector2(150, 56)
	GameFont.apply_button(btn_lvl_minus, GameFont.UNIVERSAL_FONT_SIZE, Color.WHITE)
	var lvl_btn_style := _make_style(Color(0.14, 0.22, 0.36, 0.95), Color(0.35, 0.65, 0.95, 0.8), 4)
	var lvl_btn_pressed := _make_style(Color(0.25, 0.40, 0.65, 1.0), Color.WHITE, 4)
	btn_lvl_minus.add_theme_stylebox_override(&"normal", lvl_btn_style)
	btn_lvl_minus.add_theme_stylebox_override(&"hover", lvl_btn_pressed)
	btn_lvl_minus.add_theme_stylebox_override(&"pressed", lvl_btn_pressed)
	btn_lvl_minus.pressed.connect(func(): _change_player_level(-5))
	lvl_controls.add_child(btn_lvl_minus)

	lvl_slider = HSlider.new()
	lvl_slider.min_value = 1.0
	lvl_slider.max_value = 30.0
	lvl_slider.step = 1.0
	lvl_slider.value = 1.0
	lvl_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lvl_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lvl_slider.custom_minimum_size = Vector2(260, 52)
	lvl_slider.value_changed.connect(_on_lvl_slider_value_changed)
	lvl_controls.add_child(lvl_slider)

	btn_lvl_plus = Button.new()
	btn_lvl_plus.text = "[+] +5 LVL"
	btn_lvl_plus.custom_minimum_size = Vector2(150, 56)
	GameFont.apply_button(btn_lvl_plus, GameFont.UNIVERSAL_FONT_SIZE, Color.WHITE)
	btn_lvl_plus.add_theme_stylebox_override(&"normal", lvl_btn_style)
	btn_lvl_plus.add_theme_stylebox_override(&"hover", lvl_btn_pressed)
	btn_lvl_plus.add_theme_stylebox_override(&"pressed", lvl_btn_pressed)
	btn_lvl_plus.pressed.connect(func(): _change_player_level(5))
	lvl_controls.add_child(btn_lvl_plus)

	# Bottom Close Button for Thumb Reach
	btn_bottom_close = Button.new()
	btn_bottom_close.text = "CLOSE DEBUG MENU"
	btn_bottom_close.custom_minimum_size = Vector2(0, 60)
	GameFont.apply_button(btn_bottom_close, GameFont.UNIVERSAL_FONT_SIZE, Color(0.9, 0.95, 1.0))
	var b_close_style := _make_style(Color(0.12, 0.16, 0.24, 0.95), Color(0.4, 0.55, 0.75, 0.8), 6)
	var b_close_pressed := _make_style(Color(0.25, 0.40, 0.65, 1.0), Color.WHITE, 6)
	btn_bottom_close.add_theme_stylebox_override(&"normal", b_close_style)
	btn_bottom_close.add_theme_stylebox_override(&"hover", b_close_pressed)
	btn_bottom_close.add_theme_stylebox_override(&"pressed", b_close_pressed)
	btn_bottom_close.pressed.connect(_toggle)
	content_vbox.add_child(btn_bottom_close)

	# Backward compatibility label node
	label = Label.new()
	label.visible = false
	panel.add_child(label)


func _create_action_button(text: String, bg_col: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 76)
	GameFont.apply_button(btn, GameFont.UNIVERSAL_FONT_SIZE, Color.WHITE)
	var n_style := _make_style(bg_col, Color(0.35, 0.65, 0.95, 0.75), 6)
	var p_style := _make_style(bg_col.lightened(0.2), Color.WHITE, 6)
	btn.add_theme_stylebox_override(&"normal", n_style)
	btn.add_theme_stylebox_override(&"hover", p_style)
	btn.add_theme_stylebox_override(&"focus", p_style)
	btn.add_theme_stylebox_override(&"pressed", p_style)
	btn.pressed.connect(AudioManager.play_button_click)
	return btn


func _position_dialog() -> void:
	var vp := get_viewport()
	var vp_size := Vector2(1920, 1080)
	if vp != null:
		var rect := vp.get_visible_rect()
		if rect.size.x > 0 and rect.size.y > 0:
			vp_size = rect.size

	if dim_layer != null:
		dim_layer.position = Vector2.ZERO
		dim_layer.size = vp_size
		if dim_layer.get_child_count() > 0:
			var bg = dim_layer.get_child(0) as Control
			if bg != null:
				bg.position = Vector2.ZERO
				bg.size = vp_size

	if panel != null:
		var w := minf(vp_size.x - 64.0, 1040.0)
		var h := minf(vp_size.y - 80.0, 780.0)
		panel.custom_minimum_size = Vector2(w, h)
		panel.size = Vector2(w, h)
		panel.position = Vector2((vp_size.x - w) * 0.5, (vp_size.y - h) * 0.5)


func _on_dim_layer_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventScreenTouch):
		return
	if not event.pressed:
		return
	# Ignore if just opened recently to prevent click-through from the button that opened it
	if Engine.get_process_frames() - open_frame < 5:
		return
	# Only close if the touch is OUTSIDE the panel dialog
	if panel != null and panel.get_global_rect().has_point(event.position):
		return
	_toggle()


# Per-frame update for GBA stepped tint
func _process(_delta: float) -> void:
	_update_red_tint()


func _update_red_tint() -> void:
	if tint_step_idx < 0:
		return

	tint_frame_timer -= 1
	if tint_frame_timer <= 0:
		tint_frame_timer = TINT_STEP_FRAMES
		tint_step_idx += 1
		if tint_step_idx >= GBA_TINT_STEPS.size():
			tint_step_idx = -1
			if tint_rect != null:
				tint_rect.color = Color(0.9, 0.05, 0.05, 0.0)
		else:
			if tint_rect != null:
				var alpha: float = GBA_TINT_STEPS[tint_step_idx]
				tint_rect.color = Color(0.9, 0.05, 0.05, alpha)


func flash_red_tint() -> void:
	tint_step_idx = 1
	tint_frame_timer = TINT_STEP_FRAMES
	if tint_rect != null:
		tint_rect.color = Color(0.9, 0.05, 0.05, GBA_TINT_STEPS[1])


# Input
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	if key.physical_keycode == KEY_F1:
		_toggle()
		get_viewport().set_input_as_handled()
	elif dim_layer != null and dim_layer.visible:
		if key.physical_keycode == KEY_ESCAPE:
			_toggle()
			get_viewport().set_input_as_handled()
		else:
			_navigate(key.physical_keycode)
			get_viewport().set_input_as_handled()


func _toggle() -> void:
	var is_open: bool = dim_layer != null and dim_layer.visible
	var new_open: bool = not is_open

	if new_open:
		open_frame = Engine.get_process_frames()

	if dim_layer != null:
		dim_layer.visible = new_open
	if panel != null:
		panel.visible = new_open
		if new_open:
			_position_dialog()

	if is_inside_tree() and get_tree() != null:
		get_tree().paused = new_open
	_refresh()


func _navigate(keycode: int) -> void:
	match keycode:
		KEY_UP:
			selected = wrapi(selected - 1, 0, OPTIONS.size())
		KEY_DOWN:
			selected = wrapi(selected + 1, 0, OPTIONS.size())
		KEY_LEFT:
			if OPTIONS[selected]["action"] == &"_debug_increase_player_level":
				_change_player_level(-5)
			else:
				_change_chromatic_aberration(-5.0)
		KEY_RIGHT:
			if OPTIONS[selected]["action"] == &"_debug_increase_player_level":
				_change_player_level(5)
			else:
				_change_chromatic_aberration(5.0)
		KEY_ENTER, KEY_KP_ENTER:
			call(OPTIONS[selected]["action"])
	_refresh()


func _refresh() -> void:
	var player := _find_player()
	var cur_lvl: int = player.level if player != null else 1

	if lvl_status_lbl != null:
		lvl_status_lbl.text = "Lv. %d / 30" % cur_lvl

	if lvl_slider != null and not is_equal_approx(lvl_slider.value, float(cur_lvl)):
		lvl_slider.set_value_no_signal(float(cur_lvl))

	if lvl_edit != null and not lvl_edit.has_focus():
		lvl_edit.text = str(cur_lvl)

	if btn_toggle_hitbox != null:
		btn_toggle_hitbox.text = "SHOW HITBOXES: " + ("ON" if show_hitboxes else "OFF")
		var hb_border := Color(0.2, 0.9, 0.4, 0.9) if show_hitboxes else Color(0.4, 0.5, 0.65, 0.7)
		var hb_bg := Color(0.08, 0.22, 0.14, 0.95) if show_hitboxes else Color(0.10, 0.14, 0.20, 0.95)
		btn_toggle_hitbox.add_theme_stylebox_override(&"normal", _make_style(hb_bg, hb_border, 6))

	if btn_toggle_crt != null:
		btn_toggle_crt.text = "CRT SCANLINES: " + ("ON" if show_crt else "OFF")
		var crt_border := Color(0.2, 0.9, 0.4, 0.9) if show_crt else Color(0.4, 0.5, 0.65, 0.7)
		var crt_bg := Color(0.08, 0.22, 0.14, 0.95) if show_crt else Color(0.10, 0.14, 0.20, 0.95)
		btn_toggle_crt.add_theme_stylebox_override(&"normal", _make_style(crt_bg, crt_border, 6))

	if ca_slider != null and not is_equal_approx(ca_slider.value, chromatic_aberration):
		ca_slider.set_value_no_signal(chromatic_aberration)

	if ca_edit != null and not ca_edit.has_focus():
		ca_edit.text = str(int(roundf(chromatic_aberration)))

	# Keep legacy label text synced for backward compatibility
	if label != null:
		var lines := PackedStringArray(["DEBUG MENU (Touch / Enter to select, F1 / Close to exit)"])
		for i in OPTIONS.size():
			var cursor := "> " if i == selected else "  "
			var text: String = OPTIONS[i]["label"]
			if OPTIONS[i]["action"] == &"_toggle_hitbox_show":
				text += ": " + ("ON" if show_hitboxes else "OFF")
			elif OPTIONS[i]["action"] == &"_toggle_crt":
				text += ": " + ("ON" if show_crt else "OFF")
			elif OPTIONS[i]["action"] == &"_adjust_chromatic_aberration":
				var val := int(roundf(chromatic_aberration))
				var bar_blocks := int(roundf(chromatic_aberration / 10.0))
				var bar := "[" + "|".repeat(bar_blocks) + ".".repeat(10 - bar_blocks) + "]"
				text += ": " + str(val) + "/100 " + bar
			elif OPTIONS[i]["action"] == &"_debug_increase_player_level":
				text += ": Lv. " + str(cur_lvl)
			lines.append(cursor + text)
		label.text = "\n".join(lines)


# Actions
func _get_tree_safe() -> SceneTree:
	if tree_ref != null:
		return tree_ref
	if is_inside_tree() and get_tree() != null:
		return get_tree()
	if Engine.get_main_loop() != null:
		return Engine.get_main_loop() as SceneTree
	return null


func _get_scene_root() -> Node:
	var tree := _get_tree_safe()
	if tree != null:
		if tree.current_scene != null:
			return tree.current_scene
		if tree.root != null:
			return tree.root
	return get_parent()


func _get_active_dummy_count() -> int:
	var count := 0
	var tree := _get_tree_safe()
	var fighters: Array = []
	if tree != null:
		fighters = tree.get_nodes_in_group(&"fighters")
	if fighters.is_empty():
		var scene_root := _get_scene_root()
		if scene_root != null:
			for child in scene_root.get_children():
				if child is Fighter:
					fighters.append(child)
	for node in fighters:
		var f := node as Fighter
		if f != null and is_instance_valid(f) and not f.is_defeated:
			if f is Dummy or f.name.to_lower().contains("dummy"):
				count += 1
	return count


func _spawn_dummy() -> void:
	if _get_active_dummy_count() >= MAX_DUMMIES:
		print("Spawn limit reached! Maximum ", MAX_DUMMIES, " active dummies allowed.")
		return
	var anchor := _find_player()
	if anchor == null:
		return
	var dummy := DUMMY_SCENE.instantiate() as Node2D
	dummy.add_to_group(&"fighters")
	var scene_root := _get_scene_root()
	if scene_root != null:
		scene_root.add_child(dummy, true)
	dummy.global_position = anchor.global_position + SPAWN_OFFSET
	print("Spawned passive dummy at ", dummy.global_position, " (Total active: ", _get_active_dummy_count(), "/", MAX_DUMMIES, ")")


func _spawn_dummy_enemy() -> void:
	if _get_active_dummy_count() >= MAX_DUMMIES:
		print("Spawn limit reached! Maximum ", MAX_DUMMIES, " active dummies allowed.")
		return
	var anchor := _find_player()
	if anchor == null:
		return
	var dummy := DUMMY_ENEMY_SCENE.instantiate() as Node2D
	dummy.add_to_group(&"fighters")
	var scene_root := _get_scene_root()
	if scene_root != null:
		scene_root.add_child(dummy, true)
	dummy.global_position = anchor.global_position + SPAWN_OFFSET
	print("Spawned counter dummy enemy at ", dummy.global_position, " (Total active: ", _get_active_dummy_count(), "/", MAX_DUMMIES, ")")


func _spawn_giant_dummy() -> void:
	if _get_active_dummy_count() >= MAX_DUMMIES:
		print("Spawn limit reached! Maximum ", MAX_DUMMIES, " active dummies allowed.")
		return
	var anchor := _find_player()
	if anchor == null:
		return
	var dummy := DUMMY_SCENE.instantiate() as Dummy
	dummy.add_to_group(&"fighters")
	var scene_root := _get_scene_root()
	if scene_root != null:
		scene_root.add_child(dummy, true)

	dummy.name = "GiantDummyLv100"
	dummy.level = 100
	dummy.counter_move = null # Non-countering
	dummy.max_hp = 1000
	dummy.hp = 1000
	dummy.scale = Vector2(3.0, 3.0) # 3x bigger
	dummy.set_hurtbox_size(Vector2(24, 24)) # 24x24 base scaled 3x = 72x72 effective hurtbox
	dummy.global_position = anchor.global_position + SPAWN_OFFSET
	print("Spawned giant non-countering Lv. 100 dummy (3x scale) at ", dummy.global_position, " (Total active: ", _get_active_dummy_count(), "/", MAX_DUMMIES, ")")


func _toggle_hitbox_show() -> void:
	show_hitboxes = not show_hitboxes
	hitboxes_toggled.emit(show_hitboxes)
	if is_inside_tree() and get_tree() != null:
		for node in get_tree().get_nodes_in_group(&"hitboxes"):
			if node is CanvasItem:
				node.queue_redraw()
		for node in get_tree().get_nodes_in_group(&"hurtboxes"):
			if node is CanvasItem:
				node.queue_redraw()
		for node in get_tree().get_nodes_in_group(&"fighters"):
			if node is CanvasItem:
				node.queue_redraw()
	_refresh()
	print("Hitbox show: ", show_hitboxes)


func set_crt_enabled(enabled: bool) -> void:
	show_crt = enabled
	if crt_rect != null and crt_rect.material != null:
		var mat := crt_rect.material as ShaderMaterial
		mat.set_shader_parameter("crt_enabled", show_crt)
	_update_crt_layer_visibility()
	crt_toggled.emit(show_crt)
	_refresh()


func set_crt_line_size(val: float) -> void:
	crt_line_size = clampf(val, 1.0, 10.0)
	if crt_rect != null and crt_rect.material != null:
		var mat := crt_rect.material as ShaderMaterial
		mat.set_shader_parameter("scanline_line_size", crt_line_size)
	_update_crt_layer_visibility()


func set_chromatic_aberration(val: float) -> void:
	chromatic_aberration = clampf(val, 0.0, 100.0)
	_apply_chromatic_aberration()
	_refresh()


func _toggle_crt() -> void:
	set_crt_enabled(not show_crt)


func _change_chromatic_aberration(diff: float) -> void:
	chromatic_aberration = clampf(chromatic_aberration + diff, 0.0, 100.0)
	_apply_chromatic_aberration()


func _adjust_chromatic_aberration() -> void:
	chromatic_aberration += 20.0
	if chromatic_aberration > 100.0:
		chromatic_aberration = 0.0
	_apply_chromatic_aberration()


func _on_ca_slider_value_changed(val: float) -> void:
	chromatic_aberration = clampf(val, 0.0, 100.0)
	_apply_chromatic_aberration()


func _on_ca_edit_submitted(new_text: String) -> void:
	if new_text.is_valid_float():
		var val := clampf(new_text.to_float(), 0.0, 100.0)
		chromatic_aberration = val
		_apply_chromatic_aberration()
	else:
		_refresh()


func _on_ca_edit_changed(new_text: String) -> void:
	if new_text.is_valid_float():
		var val := clampf(new_text.to_float(), 0.0, 100.0)
		chromatic_aberration = val
		if crt_rect != null and crt_rect.material != null:
			var mat := crt_rect.material as ShaderMaterial
			mat.set_shader_parameter("chromatic_aberration", chromatic_aberration)
		_update_crt_layer_visibility()
		if ca_slider != null:
			ca_slider.set_value_no_signal(chromatic_aberration)


func _apply_chromatic_aberration() -> void:
	if crt_rect != null and crt_rect.material != null:
		var mat := crt_rect.material as ShaderMaterial
		mat.set_shader_parameter("chromatic_aberration", chromatic_aberration)
	_update_crt_layer_visibility()
	_refresh()
	print("Chromatic aberration: ", chromatic_aberration)


func _update_crt_layer_visibility() -> void:
	if crt_layer != null:
		crt_layer.visible = show_crt or chromatic_aberration > 0.0


func _find_player() -> Fighter:
	if player_ref != null and is_instance_valid(player_ref):
		return player_ref
	var tree := _get_tree_safe()
	var fighters: Array = []
	if tree != null:
		fighters = tree.get_nodes_in_group(&"fighters")
	if fighters.is_empty():
		var scene_root := _get_scene_root()
		if scene_root != null:
			for child in scene_root.get_children():
				if child is Fighter:
					fighters.append(child)
	for node in fighters:
		var fighter := node as Fighter
		if fighter != null and fighter.team == &"player":
			return fighter
	return null


func _start_customize_controls() -> void:
	_toggle()
	if is_inside_tree() and get_tree() != null:
		var tc := get_tree().get_first_node_in_group(&"touch_controls")
		if tc != null and tc.has_method("start_customization"):
			tc.start_customization()


func _debug_increase_player_level() -> void:
	_change_player_level(5)


func _change_player_level(delta: int) -> void:
	AudioManager.play_button_click()
	var player := _find_player()
	if player != null:
		var cur: int = player.level
		var target: int = cur
		if delta > 0:
			if cur < 5:
				target = 5
			else:
				target = mini(30, (cur / 5 + 1) * 5)
		elif delta < 0:
			if cur <= 5:
				target = 1
			elif cur % 5 != 0:
				target = (cur / 5) * 5
			else:
				target = maxi(1, cur - 5)
		player.set_level(target)
	_refresh()


func _set_player_level(new_lvl: int) -> void:
	AudioManager.play_button_click()
	var player := _find_player()
	if player != null:
		player.set_level(new_lvl)
	_refresh()


func _set_player_level_from_edit() -> void:
	if lvl_edit == null:
		return
	var text := lvl_edit.text.strip_edges()
	if text.is_valid_int():
		_set_player_level(text.to_int())
	else:
		_refresh()


func _on_lvl_slider_value_changed(val: float) -> void:
	var target_lvl := int(roundf(val))
	var player := _find_player()
	if player != null and player.level != target_lvl:
		player.set_level(target_lvl)
	_refresh()
