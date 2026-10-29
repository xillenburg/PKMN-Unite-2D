class_name PauseMenu
extends CanvasLayer

signal paused_state_changed(is_paused: bool)

# Components
var tree_ref: SceneTree = null
var btn_pause: Button
var overlay: Control
var panel_pause: PanelContainer
var panel_settings: PanelContainer

# Pause dialog buttons
var btn_resume: Button
var btn_settings: Button
var btn_exit: Button

# Settings controls
var btn_crt_toggle: Button
var label_crt_line_size: Label
var slider_crt_line_size: HSlider
var label_chroma: Label
var slider_chroma: HSlider
var btn_customize_controls: Button
var btn_settings_back: Button


func _ready() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_pause_button()
	_build_overlay()
	_update_settings_readouts()


func _build_pause_button() -> void:
	btn_pause = Button.new()
	btn_pause.name = "PauseButton"
	btn_pause.text = "PAUSE"
	btn_pause.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_pause.custom_minimum_size = Vector2(130, 44)

	# Alignment Top, Center
	btn_pause.anchor_left = 0.5
	btn_pause.anchor_right = 0.5
	btn_pause.anchor_top = 0.0
	btn_pause.anchor_bottom = 0.0
	btn_pause.offset_left = -65
	btn_pause.offset_right = 65
	btn_pause.offset_top = 10
	btn_pause.offset_bottom = 54

	GameFont.apply_button(btn_pause, GameFont.UNIVERSAL_FONT_SIZE, Color.WHITE)
	UIDynamic.apply_button_style(btn_pause, Color(0.18, 0.28, 0.42, 0.95), Color(0.25, 0.40, 0.60, 1.0))
	btn_pause.pressed.connect(_on_pause_button_pressed)
	add_child(btn_pause)


func _build_overlay() -> void:
	overlay = Control.new()
	overlay.name = "PauseOverlay"
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.visible = false
	add_child(overlay)

	# Dimmed backdrop
	var dim := ColorRect.new()
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	# --- 1. Main Pause Dialog ---
	panel_pause = PanelContainer.new()
	panel_pause.name = "PauseDialog"
	panel_pause.custom_minimum_size = Vector2(420, 320)
	panel_pause.anchor_left = 0.5
	panel_pause.anchor_top = 0.5
	panel_pause.anchor_right = 0.5
	panel_pause.anchor_bottom = 0.5
	panel_pause.offset_left = -210
	panel_pause.offset_top = -160
	panel_pause.offset_right = 210
	panel_pause.offset_bottom = 160
	UIDynamic.apply_panel_style(panel_pause, Color(0.12, 0.18, 0.28, 0.98), 20)
	overlay.add_child(panel_pause)

	var pause_vbox := VBoxContainer.new()
	pause_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_vbox.add_theme_constant_override("separation", 16)
	panel_pause.add_child(pause_vbox)

	var title := Label.new()
	title.text = "GAME PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameFont.apply_label(title, GameFont.UNIVERSAL_FONT_SIZE + 8, Color(1.0, 0.88, 0.2), true, Color.BLACK, 2)
	pause_vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	pause_vbox.add_child(spacer)

	btn_resume = Button.new()
	btn_resume.text = "RESUME"
	btn_resume.custom_minimum_size = Vector2(0, 52)
	GameFont.apply_button(btn_resume, GameFont.UNIVERSAL_FONT_SIZE, Color.WHITE)
	UIDynamic.apply_button_style(btn_resume, Color(0.15, 0.55, 0.35, 1.0))
	btn_resume.pressed.connect(resume_game)
	pause_vbox.add_child(btn_resume)

	btn_settings = Button.new()
	btn_settings.text = "SETTINGS"
	btn_settings.custom_minimum_size = Vector2(0, 52)
	GameFont.apply_button(btn_settings, GameFont.UNIVERSAL_FONT_SIZE, Color.WHITE)
	UIDynamic.apply_button_style(btn_settings, Color(0.20, 0.38, 0.65, 1.0))
	btn_settings.pressed.connect(open_settings)
	pause_vbox.add_child(btn_settings)

	btn_exit = Button.new()
	btn_exit.text = "EXIT TO MENU"
	btn_exit.custom_minimum_size = Vector2(0, 52)
	GameFont.apply_button(btn_exit, GameFont.UNIVERSAL_FONT_SIZE, Color.WHITE)
	UIDynamic.apply_button_style(btn_exit, Color(0.70, 0.22, 0.22, 1.0))
	btn_exit.pressed.connect(exit_to_menu)
	pause_vbox.add_child(btn_exit)

	# --- 2. Settings Dialog ---
	panel_settings = PanelContainer.new()
	panel_settings.name = "SettingsDialog"
	panel_settings.custom_minimum_size = Vector2(560, 480)
	panel_settings.anchor_left = 0.5
	panel_settings.anchor_top = 0.5
	panel_settings.anchor_right = 0.5
	panel_settings.anchor_bottom = 0.5
	panel_settings.offset_left = -280
	panel_settings.offset_top = -240
	panel_settings.offset_right = 280
	panel_settings.offset_bottom = 240
	panel_settings.visible = false
	UIDynamic.apply_panel_style(panel_settings, Color(0.10, 0.16, 0.26, 0.98), 20)
	overlay.add_child(panel_settings)

	var set_vbox := VBoxContainer.new()
	set_vbox.add_theme_constant_override("separation", 14)
	panel_settings.add_child(set_vbox)

	var set_title := Label.new()
	set_title.text = "SETTINGS"
	set_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameFont.apply_label(set_title, GameFont.UNIVERSAL_FONT_SIZE + 6, Color(0.4, 0.85, 1.0), true, Color.BLACK, 2)
	set_vbox.add_child(set_title)

	# CRT Toggle
	btn_crt_toggle = Button.new()
	btn_crt_toggle.custom_minimum_size = Vector2(0, 48)
	GameFont.apply_button(btn_crt_toggle, GameFont.UNIVERSAL_FONT_SIZE, Color.WHITE)
	UIDynamic.apply_button_style(btn_crt_toggle, Color(0.18, 0.32, 0.50, 1.0))
	btn_crt_toggle.pressed.connect(_on_crt_toggle_pressed)
	set_vbox.add_child(btn_crt_toggle)

	# CRT Line Size Slider
	var crt_size_box := VBoxContainer.new()
	crt_size_box.add_theme_constant_override("separation", 4)
	set_vbox.add_child(crt_size_box)

	label_crt_line_size = Label.new()
	GameFont.apply_label(label_crt_line_size, GameFont.UNIVERSAL_FONT_SIZE - 2, Color.WHITE)
	crt_size_box.add_child(label_crt_line_size)

	slider_crt_line_size = HSlider.new()
	slider_crt_line_size.min_value = 1.0
	slider_crt_line_size.max_value = 8.0
	slider_crt_line_size.step = 0.5
	slider_crt_line_size.value = 2.0
	slider_crt_line_size.custom_minimum_size = Vector2(0, 36)
	slider_crt_line_size.value_changed.connect(_on_crt_line_size_changed)
	crt_size_box.add_child(slider_crt_line_size)

	# Chromatic Aberration Slider
	var chroma_box := VBoxContainer.new()
	chroma_box.add_theme_constant_override("separation", 4)
	set_vbox.add_child(chroma_box)

	label_chroma = Label.new()
	GameFont.apply_label(label_chroma, GameFont.UNIVERSAL_FONT_SIZE - 2, Color.WHITE)
	chroma_box.add_child(label_chroma)

	slider_chroma = HSlider.new()
	slider_chroma.min_value = 0.0
	slider_chroma.max_value = 100.0
	slider_chroma.step = 1.0
	slider_chroma.value = 10.0
	slider_chroma.custom_minimum_size = Vector2(0, 36)
	slider_chroma.value_changed.connect(_on_chroma_changed)
	chroma_box.add_child(slider_chroma)

	# Customize Controls Button (Without Gear Emoji)
	btn_customize_controls = Button.new()
	btn_customize_controls.text = "CUSTOMIZE CONTROLS (MOVE & RESIZE)"
	btn_customize_controls.custom_minimum_size = Vector2(0, 50)
	GameFont.apply_button(btn_customize_controls, GameFont.UNIVERSAL_FONT_SIZE, Color.WHITE)
	UIDynamic.apply_button_style(btn_customize_controls, Color(0.18, 0.42, 0.68, 1.0))
	btn_customize_controls.pressed.connect(_on_customize_controls_pressed)
	set_vbox.add_child(btn_customize_controls)

	# Settings Back Button
	btn_settings_back = Button.new()
	btn_settings_back.text = "BACK"
	btn_settings_back.custom_minimum_size = Vector2(0, 48)
	GameFont.apply_button(btn_settings_back, GameFont.UNIVERSAL_FONT_SIZE, Color.WHITE)
	UIDynamic.apply_button_style(btn_settings_back, Color(0.25, 0.35, 0.48, 1.0))
	btn_settings_back.pressed.connect(close_settings)
	set_vbox.add_child(btn_settings_back)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			if overlay.visible:
				if panel_settings.visible:
					close_settings()
				else:
					resume_game()
			else:
				pause_game()


func _on_pause_button_pressed() -> void:
	if overlay.visible:
		resume_game()
	else:
		pause_game()


func pause_game() -> void:
	var tree := _get_tree_safe()
	if tree != null:
		tree.paused = true
	overlay.visible = true
	panel_pause.visible = true
	panel_settings.visible = false
	_update_settings_readouts()
	paused_state_changed.emit(true)


func resume_game() -> void:
	var tree := _get_tree_safe()
	if tree != null:
		tree.paused = false
	overlay.visible = false
	panel_pause.visible = false
	panel_settings.visible = false
	paused_state_changed.emit(false)


func open_settings() -> void:
	panel_pause.visible = false
	panel_settings.visible = true
	_update_settings_readouts()


func close_settings() -> void:
	AudioManager.play_back_button()
	panel_settings.visible = false
	panel_pause.visible = true


func exit_to_menu() -> void:
	var tree := _get_tree_safe()
	if tree != null:
		tree.paused = false
		tree.change_scene_to_file("res://scenes/menu.tscn")
	overlay.visible = false


# =============================================================================
# SETTINGS INTERACTIONS
# =============================================================================
func _get_tree_safe() -> SceneTree:
	if tree_ref != null:
		return tree_ref
	if is_inside_tree() and get_tree() != null:
		return get_tree()
	if Engine.get_main_loop() != null:
		return Engine.get_main_loop() as SceneTree
	return null


func _get_debug_menu() -> Node:
	var tree := _get_tree_safe()
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null("DebugMenu")
	return null


func _update_settings_readouts() -> void:
	var dm := _get_debug_menu()
	var crt_on := true
	var line_size := 2.0
	var ca_val := 10.0

	if dm != null:
		if "show_crt" in dm:
			crt_on = dm.show_crt
		if "crt_line_size" in dm:
			line_size = dm.crt_line_size
		if "chromatic_aberration" in dm:
			ca_val = dm.chromatic_aberration

	if btn_crt_toggle != null:
		btn_crt_toggle.text = "CRT SCANLINES: " + ("ON" if crt_on else "OFF")
		var col := Color(0.15, 0.55, 0.35, 1.0) if crt_on else Color(0.4, 0.45, 0.55, 0.8)
		UIDynamic.apply_button_style(btn_crt_toggle, col)

	if label_crt_line_size != null:
		label_crt_line_size.text = "CRT LINE SIZE: %.1f px" % line_size
	if slider_crt_line_size != null and not is_equal_approx(slider_crt_line_size.value, line_size):
		slider_crt_line_size.set_value_no_signal(line_size)

	if label_chroma != null:
		label_chroma.text = "CHROMATIC ABERRATION: %d" % int(roundf(ca_val))
	if slider_chroma != null and not is_equal_approx(slider_chroma.value, ca_val):
		slider_chroma.set_value_no_signal(ca_val)


func _on_crt_toggle_pressed() -> void:
	var dm := _get_debug_menu()
	if dm != null and dm.has_method("set_crt_enabled"):
		var curr: bool = dm.show_crt if "show_crt" in dm else true
		dm.set_crt_enabled(not curr)
	_update_settings_readouts()


func _on_crt_line_size_changed(val: float) -> void:
	var dm := _get_debug_menu()
	if dm != null and dm.has_method("set_crt_line_size"):
		dm.set_crt_line_size(val)
	if label_crt_line_size != null:
		label_crt_line_size.text = "CRT LINE SIZE: %.1f px" % val


func _on_chroma_changed(val: float) -> void:
	var dm := _get_debug_menu()
	if dm != null and dm.has_method("set_chromatic_aberration"):
		dm.set_chromatic_aberration(val)
	if label_chroma != null:
		label_chroma.text = "CHROMATIC ABERRATION: %d" % int(roundf(val))


func _on_customize_controls_pressed() -> void:
	resume_game()
	var tc := get_tree().get_first_node_in_group(&"touch_controls")
	if tc != null and tc.has_method("start_customization"):
		tc.start_customization()
