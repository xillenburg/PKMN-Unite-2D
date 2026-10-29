class_name MainMenu
extends Control

# Navigation states
enum MenuState {
	MAIN_TITLE,
	MODE_SELECT,
	CHAR_SELECT
}

var current_state: MenuState = MenuState.MAIN_TITLE

# Data
var starter_pokemon: Array[PokemonData] = []
var selected_pokemon_index: int = 0
var selected_color: Color = Color.WHITE
var selected_hex: String = "#ffffff"
var current_hue_shift: float = 0.0 # -0.5 to +0.5 (-180 deg to +180 deg)
var current_sat_mult: float = 1.0  # 0.0 to 2.0 (0% to 200%)

# Audio
const PATH_CHAR_SELECT_BGM := "res://assets/audio/music/character_select_music.mp3"
var cry_player: AudioStreamPlayer
var ui_sfx_player: AudioStreamPlayer
var bgm_player: AudioStreamPlayer
var bgm_tween: Tween
var is_bgm_playing: bool = false

# Shader Material for Direct Hue & Saturation alteration
const FLASH_SHADER := preload("res://shaders/flash.gdshader")
var preview_shader_mat: ShaderMaterial

# Screens / Panels
var panel_main: Control
var panel_menu_settings: PanelContainer
var panel_mode: Control
var panel_char_select: Control

# Main Menu Settings Components
var btn_main_settings: Button
var btn_menu_crt_toggle: Button
var label_menu_crt_line_size: Label
var slider_menu_crt_line_size: HSlider
var label_menu_chroma: Label
var slider_menu_chroma: HSlider
var btn_menu_customize_controls: Button
var label_menu_controls_hint: Label
var btn_menu_settings_back: Button

# Character Selection Screen Components
var preview_sprite: TextureRect
var preview_pedestal: Control
var label_pokemon_name: Label
var label_pokemon_sub: Label
var stage_h1_sprites: Array[TextureRect] = []
var stage_h1_labels: Array[Label] = []
var stages_h1_deck: HBoxContainer
var card_buttons: Array[Button] = []
var card_containers: Array[PanelContainer] = []
var item_slot_panels: Array[Panel] = []

# Color Customizer Components
var slider_hue: HSlider
var slider_sat: HSlider
var label_hue_val: Label
var label_sat_val: Label
var label_hex_val: Label
var color_swatch: ColorRect
var btn_reset_color: Button

# Battle & Navigation Buttons
var btn_play: Button
var btn_mode_1v1: Button
var btn_mode_2v2: Button
var btn_mode_back: Button
var btn_char_back: Button
var btn_battle: Button

# Animation Tween
var stretch_tween: Tween


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	_setup_audio()
	_setup_shader()
	_load_starter_pokemon()
	_build_ui()
	show_main_menu()


func _setup_audio() -> void:
	cry_player = AudioStreamPlayer.new()
	cry_player.name = "CryPlayer"
	cry_player.bus = AudioManager.BUS_SFX
	add_child(cry_player)

	ui_sfx_player = AudioStreamPlayer.new()
	ui_sfx_player.name = "UISFXPlayer"
	ui_sfx_player.bus = AudioManager.BUS_SFX
	add_child(ui_sfx_player)

	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.bus = AudioManager.BUS_SFX
	bgm_player.finished.connect(_on_bgm_finished)
	add_child(bgm_player)
	if ResourceLoader.exists(PATH_CHAR_SELECT_BGM) or FileAccess.file_exists(PATH_CHAR_SELECT_BGM):
		bgm_player.stream = load(PATH_CHAR_SELECT_BGM)


func _setup_shader() -> void:
	preview_shader_mat = ShaderMaterial.new()
	preview_shader_mat.shader = FLASH_SHADER
	preview_shader_mat.set_shader_parameter("hue_shift", 0.0)
	preview_shader_mat.set_shader_parameter("sat_mult", 1.0)


func _load_starter_pokemon() -> void:
	var paths := [
		"res://data/pokemon/venusaur.tres",
		"res://data/pokemon/charizard.tres",
		"res://data/pokemon/blastoise.tres"
	]
	starter_pokemon.clear()
	for p in paths:
		if ResourceLoader.exists(p) or FileAccess.file_exists(p):
			var data := load(p) as PokemonData
			if data != null:
				starter_pokemon.append(data)


# =============================================================================
# UI BUILDER
# =============================================================================
func _build_ui() -> void:
	# Fullscreen dark background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.05, 0.08, 0.14, 1.0) # Deep midnight navy
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	_build_main_menu_panel()
	_build_menu_settings_panel()
	_build_mode_select_panel()
	_build_char_select_panel()


# -----------------------------------------------------------------------------
# 1. MAIN TITLE SCREEN
# -----------------------------------------------------------------------------
func _build_main_menu_panel() -> void:
	panel_main = Control.new()
	panel_main.name = "PanelMainMenu"
	panel_main.anchor_right = 1.0
	panel_main.anchor_bottom = 1.0
	add_child(panel_main)

	var center_vbox := VBoxContainer.new()
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.anchor_left = 0.5
	center_vbox.anchor_top = 0.5
	center_vbox.anchor_right = 0.5
	center_vbox.anchor_bottom = 0.5
	center_vbox.offset_left = -408
	center_vbox.offset_top = -300
	center_vbox.offset_right = 408
	center_vbox.offset_bottom = 300
	center_vbox.add_theme_constant_override("separation", 30)
	panel_main.add_child(center_vbox)

	# Title
	var title := Label.new()
	title.text = "POKÉMON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 116)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.15))
	title.add_theme_color_override("font_shadow_color", Color(0.1, 0.15, 0.3, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 5)
	title.add_theme_constant_override("shadow_offset_y", 5)
	center_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "ADVANCED BATTLE ARENA"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 46)
	subtitle.add_theme_color_override("font_color", Color(0.3, 0.82, 1.0))
	center_vbox.add_child(subtitle)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	center_vbox.add_child(spacer)

	# PLAY Button
	btn_play = Button.new()
	btn_play.text = "PLAY  ▶"
	btn_play.custom_minimum_size = Vector2(456, 96)
	btn_play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_play.add_theme_font_size_override("font_size", 48)
	btn_play.add_theme_stylebox_override("normal", _make_style(Color(0.12, 0.35, 0.65), Color(0.35, 0.75, 1.0), 12))
	btn_play.add_theme_stylebox_override("hover", _make_style(Color(0.18, 0.48, 0.85), Color(1.0, 0.84, 0.2), 12))
	btn_play.add_theme_stylebox_override("pressed", _make_style(Color(0.10, 0.25, 0.50), Color(0.2, 0.6, 0.9), 12))
	btn_play.pressed.connect(_on_play_pressed)
	center_vbox.add_child(btn_play)

	# SETTINGS Button
	btn_main_settings = Button.new()
	btn_main_settings.name = "BtnMainSettings"
	btn_main_settings.text = "SETTINGS"
	btn_main_settings.custom_minimum_size = Vector2(456, 86)
	btn_main_settings.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_main_settings.add_theme_font_size_override("font_size", 42)
	btn_main_settings.add_theme_stylebox_override("normal", _make_style(Color(0.20, 0.38, 0.65), Color(0.3, 0.7, 0.95), 12))
	btn_main_settings.add_theme_stylebox_override("hover", _make_style(Color(0.26, 0.48, 0.80), Color(1.0, 0.85, 0.2), 12))
	btn_main_settings.add_theme_stylebox_override("pressed", _make_style(Color(0.14, 0.28, 0.50), Color(0.2, 0.5, 0.8), 12))
	btn_main_settings.pressed.connect(open_main_settings)
	center_vbox.add_child(btn_main_settings)


# -----------------------------------------------------------------------------
# 1b. MAIN MENU SETTINGS DIALOG
# -----------------------------------------------------------------------------
func _build_menu_settings_panel() -> void:
	panel_menu_settings = PanelContainer.new()
	panel_menu_settings.name = "PanelMenuSettings"
	panel_menu_settings.custom_minimum_size = Vector2(620, 560)
	panel_menu_settings.anchor_left = 0.5
	panel_menu_settings.anchor_top = 0.5
	panel_menu_settings.anchor_right = 0.5
	panel_menu_settings.anchor_bottom = 0.5
	panel_menu_settings.offset_left = -310
	panel_menu_settings.offset_top = -280
	panel_menu_settings.offset_right = 310
	panel_menu_settings.offset_bottom = 280
	panel_menu_settings.visible = false
	UIDynamic.apply_panel_style(panel_menu_settings, Color(0.10, 0.16, 0.26, 0.98), 20)
	add_child(panel_menu_settings)

	var set_vbox := VBoxContainer.new()
	set_vbox.add_theme_constant_override("separation", 16)
	panel_menu_settings.add_child(set_vbox)

	var set_title := Label.new()
	set_title.text = "SETTINGS"
	set_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameFont.apply_label(set_title, 38, Color(0.4, 0.85, 1.0), true, Color.BLACK, 2)
	set_vbox.add_child(set_title)

	# CRT Toggle
	btn_menu_crt_toggle = Button.new()
	btn_menu_crt_toggle.custom_minimum_size = Vector2(0, 54)
	btn_menu_crt_toggle.add_theme_font_size_override("font_size", 26)
	btn_menu_crt_toggle.pressed.connect(_on_menu_crt_toggle_pressed)
	set_vbox.add_child(btn_menu_crt_toggle)

	# CRT Line Size Slider
	var crt_size_box := VBoxContainer.new()
	crt_size_box.add_theme_constant_override("separation", 6)
	set_vbox.add_child(crt_size_box)

	label_menu_crt_line_size = Label.new()
	GameFont.apply_label(label_menu_crt_line_size, 24, Color.WHITE)
	crt_size_box.add_child(label_menu_crt_line_size)

	slider_menu_crt_line_size = HSlider.new()
	slider_menu_crt_line_size.min_value = 1.0
	slider_menu_crt_line_size.max_value = 8.0
	slider_menu_crt_line_size.step = 0.5
	slider_menu_crt_line_size.value = 2.0
	slider_menu_crt_line_size.custom_minimum_size = Vector2(0, 36)
	slider_menu_crt_line_size.value_changed.connect(_on_menu_crt_line_size_changed)
	crt_size_box.add_child(slider_menu_crt_line_size)

	# Chromatic Aberration Slider
	var chroma_box := VBoxContainer.new()
	chroma_box.add_theme_constant_override("separation", 6)
	set_vbox.add_child(chroma_box)

	label_menu_chroma = Label.new()
	GameFont.apply_label(label_menu_chroma, 24, Color.WHITE)
	chroma_box.add_child(label_menu_chroma)

	slider_menu_chroma = HSlider.new()
	slider_menu_chroma.min_value = 0.0
	slider_menu_chroma.max_value = 100.0
	slider_menu_chroma.step = 1.0
	slider_menu_chroma.value = 10.0
	slider_menu_chroma.custom_minimum_size = Vector2(0, 36)
	slider_menu_chroma.value_changed.connect(_on_menu_chroma_changed)
	chroma_box.add_child(slider_menu_chroma)

	# Customize Controls Button (Without Gear Emoji)
	btn_menu_customize_controls = Button.new()
	btn_menu_customize_controls.text = "CUSTOMIZE CONTROLS (MOVE & RESIZE)"
	btn_menu_customize_controls.custom_minimum_size = Vector2(0, 52)
	btn_menu_customize_controls.add_theme_font_size_override("font_size", 24)
	UIDynamic.apply_button_style(btn_menu_customize_controls, Color(0.18, 0.42, 0.68, 1.0))
	btn_menu_customize_controls.pressed.connect(_on_menu_customize_controls_pressed)
	set_vbox.add_child(btn_menu_customize_controls)

	label_menu_controls_hint = Label.new()
	label_menu_controls_hint.text = "(Customize button layout during active battle via Pause Menu)"
	label_menu_controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_menu_controls_hint.add_theme_font_size_override("font_size", 18)
	label_menu_controls_hint.add_theme_color_override("font_color", Color(0.65, 0.75, 0.90, 0.75))
	set_vbox.add_child(label_menu_controls_hint)

	# Settings Back Button
	btn_menu_settings_back = Button.new()
	btn_menu_settings_back.text = "◀  BACK"
	btn_menu_settings_back.custom_minimum_size = Vector2(0, 54)
	btn_menu_settings_back.add_theme_font_size_override("font_size", 28)
	UIDynamic.apply_button_style(btn_menu_settings_back, Color(0.25, 0.35, 0.48, 1.0))
	btn_menu_settings_back.pressed.connect(close_main_settings)
	set_vbox.add_child(btn_menu_settings_back)


# -----------------------------------------------------------------------------
# 2. MODE SELECT SCREEN (1v1 vs 2v2)
# -----------------------------------------------------------------------------
func _build_mode_select_panel() -> void:
	panel_mode = Control.new()
	panel_mode.name = "PanelModeSelect"
	panel_mode.anchor_right = 1.0
	panel_mode.anchor_bottom = 1.0
	panel_mode.visible = false
	add_child(panel_mode)

	var center_vbox := VBoxContainer.new()
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.anchor_left = 0.5
	center_vbox.anchor_top = 0.5
	center_vbox.anchor_right = 0.5
	center_vbox.anchor_bottom = 0.5
	center_vbox.offset_left = -280
	center_vbox.offset_top = -240
	center_vbox.offset_right = 280
	center_vbox.offset_bottom = 240
	center_vbox.add_theme_constant_override("separation", 24)
	panel_mode.add_child(center_vbox)

	var mode_title := Label.new()
	mode_title.text = "SELECT BATTLE MODE"
	mode_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_title.add_theme_font_size_override("font_size", 46)
	mode_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	center_vbox.add_child(mode_title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	center_vbox.add_child(spacer)

	# 1v1 Button (Working)
	btn_mode_1v1 = Button.new()
	btn_mode_1v1.text = "1v1 BATTLE"
	btn_mode_1v1.custom_minimum_size = Vector2(400, 84)
	btn_mode_1v1.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_mode_1v1.add_theme_font_size_override("font_size", 34)
	btn_mode_1v1.add_theme_stylebox_override("normal", _make_style(Color(0.12, 0.35, 0.65), Color(0.3, 0.8, 1.0), 10))
	btn_mode_1v1.add_theme_stylebox_override("hover", _make_style(Color(0.18, 0.48, 0.85), Color(1.0, 0.85, 0.2), 10))
	btn_mode_1v1.add_theme_stylebox_override("pressed", _make_style(Color(0.08, 0.25, 0.50), Color(0.2, 0.6, 0.9), 10))
	btn_mode_1v1.pressed.connect(_on_1v1_pressed)
	center_vbox.add_child(btn_mode_1v1)

	# 2v2 Button (For now not working / disabled)
	btn_mode_2v2 = Button.new()
	btn_mode_2v2.text = "2v2 BATTLE (COMING SOON)"
	btn_mode_2v2.custom_minimum_size = Vector2(400, 84)
	btn_mode_2v2.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_mode_2v2.disabled = true
	btn_mode_2v2.add_theme_font_size_override("font_size", 28)
	btn_mode_2v2.add_theme_color_override("font_disabled_color", Color(0.55, 0.60, 0.70, 0.6))
	btn_mode_2v2.add_theme_stylebox_override("disabled", _make_style(Color(0.12, 0.16, 0.22, 0.6), Color(0.25, 0.30, 0.40, 0.4), 10))
	center_vbox.add_child(btn_mode_2v2)

	# Back button
	btn_mode_back = Button.new()
	btn_mode_back.text = "◀  BACK"
	btn_mode_back.custom_minimum_size = Vector2(240, 56)
	btn_mode_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_mode_back.add_theme_font_size_override("font_size", 28)
	btn_mode_back.add_theme_stylebox_override("normal", _make_style(Color(0.15, 0.20, 0.30), Color(0.35, 0.45, 0.60), 8))
	btn_mode_back.add_theme_stylebox_override("hover", _make_style(Color(0.22, 0.30, 0.45), Color(0.6, 0.7, 0.9), 8))
	btn_mode_back.pressed.connect(_on_mode_back_pressed)
	center_vbox.add_child(btn_mode_back)


# -----------------------------------------------------------------------------
# 3. CHARACTER SELECTION SCREEN
# -----------------------------------------------------------------------------
func _build_char_select_panel() -> void:
	panel_char_select = Control.new()
	panel_char_select.name = "PanelCharSelect"
	panel_char_select.anchor_right = 1.0
	panel_char_select.anchor_bottom = 1.0
	panel_char_select.visible = false
	add_child(panel_char_select)

	# Header Bar
	var header_bar := PanelContainer.new()
	header_bar.custom_minimum_size = Vector2(0, 72)
	header_bar.anchor_right = 1.0
	header_bar.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.12, 0.20, 0.95), Color(0.2, 0.35, 0.55), 0))
	panel_char_select.add_child(header_bar)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 24)
	header_bar.add_child(header_hbox)

	btn_char_back = Button.new()
	btn_char_back.text = "◀  BACK"
	btn_char_back.custom_minimum_size = Vector2(140, 50)
	btn_char_back.add_theme_font_size_override("font_size", 26)
	btn_char_back.add_theme_stylebox_override("normal", _make_style(Color(0.15, 0.22, 0.35), Color(0.3, 0.5, 0.75), 8))
	btn_char_back.add_theme_stylebox_override("hover", _make_style(Color(0.25, 0.35, 0.55), Color(1.0, 0.85, 0.2), 8))
	btn_char_back.pressed.connect(_on_char_back_pressed)
	header_hbox.add_child(btn_char_back)

	var header_title := Label.new()
	header_title.text = "CHARACTER SELECTION"
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_title.add_theme_font_size_override("font_size", 38)
	header_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	header_hbox.add_child(header_title)

	var header_spacer := Control.new()
	header_spacer.custom_minimum_size = Vector2(140, 50)
	header_hbox.add_child(header_spacer)

	# Main 3-Column Content Layout (Left: Items Grid, Middle: Preview, Right: Color Sliders)
	var content_hbox := HBoxContainer.new()
	content_hbox.anchor_left = 0.02
	content_hbox.anchor_top = 0.08
	content_hbox.anchor_right = 0.98
	content_hbox.anchor_bottom = 0.76
	content_hbox.add_theme_constant_override("separation", 24)
	panel_char_select.add_child(content_hbox)

	_build_items_grid(content_hbox)
	_build_character_preview(content_hbox)
	_build_color_customizer(content_hbox)

	# Bottom Deck: Cards Selection + BATTLE button
	_build_bottom_card_deck()


# Left Side: Grid Menu for Item Selection (Empty for future)
func _build_items_grid(parent: HBoxContainer) -> void:
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(360, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.12, 0.22, 0.85), Color(0.25, 0.40, 0.65), 10))
	parent.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 14)
	left_panel.add_child(left_vbox)

	var items_title := Label.new()
	items_title.text = "HELD ITEMS"
	items_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	items_title.add_theme_font_size_override("font_size", 30)
	items_title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	left_vbox.add_child(items_title)

	var items_sub := Label.new()
	items_sub.text = "(Future Item Loadouts)"
	items_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	items_sub.add_theme_font_size_override("font_size", 22)
	items_sub.add_theme_color_override("font_color", Color(0.6, 0.7, 0.85, 0.7))
	left_vbox.add_child(items_sub)

	# Grid Container: 2 columns x 3 rows = 6 empty item slots
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	left_vbox.add_child(grid)

	item_slot_panels.clear()
	for i in range(6):
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(130, 110)
		slot.add_theme_stylebox_override("panel", _make_style(Color(0.05, 0.08, 0.15, 0.8), Color(0.3, 0.45, 0.65, 0.6), 8))
		grid.add_child(slot)
		item_slot_panels.append(slot)

		var slot_lbl := Label.new()
		slot_lbl.text = "[ EMPTY ]"
		slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_lbl.anchor_right = 1.0
		slot_lbl.anchor_bottom = 1.0
		slot_lbl.add_theme_font_size_override("font_size", 20)
		slot_lbl.add_theme_color_override("font_color", Color(0.45, 0.55, 0.70, 0.5))
		slot.add_child(slot_lbl)


# Middle: Character Preview (Front Sprite, Stretch Animation, Pedestal, Stage h_1 Sprites)
func _build_character_preview(parent: HBoxContainer) -> void:
	var center_panel := PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_panel.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.10, 0.18, 0.85), Color(0.2, 0.35, 0.55), 10))
	parent.add_child(center_panel)

	var center_vbox := VBoxContainer.new()
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 8)
	center_panel.add_child(center_vbox)

	label_pokemon_name = Label.new()
	label_pokemon_name.text = "VENUSAUR"
	label_pokemon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_pokemon_name.add_theme_font_size_override("font_size", 52)
	label_pokemon_name.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	label_pokemon_name.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	label_pokemon_name.add_theme_constant_override("shadow_offset_x", 3)
	label_pokemon_name.add_theme_constant_override("shadow_offset_y", 3)
	center_vbox.add_child(label_pokemon_name)

	label_pokemon_sub = Label.new()
	label_pokemon_sub.text = "Seed Pokémon • Grass / Poison"
	label_pokemon_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_pokemon_sub.add_theme_font_size_override("font_size", 26)
	label_pokemon_sub.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	center_vbox.add_child(label_pokemon_sub)

	# Preview Viewport Container
	var preview_stage := Control.new()
	preview_stage.custom_minimum_size = Vector2(360, 320)
	preview_stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_vbox.add_child(preview_stage)

	# Battle Pedestal Shadow
	preview_pedestal = Control.new()
	preview_pedestal.custom_minimum_size = Vector2(280, 50)
	preview_pedestal.anchor_left = 0.5
	preview_pedestal.anchor_top = 0.82
	preview_pedestal.anchor_right = 0.5
	preview_pedestal.anchor_bottom = 0.82
	preview_pedestal.offset_left = -140
	preview_pedestal.offset_top = -25
	preview_pedestal.offset_right = 140
	preview_pedestal.offset_bottom = 25
	preview_stage.add_child(preview_pedestal)

	var pedestal_rect := ColorRect.new()
	pedestal_rect.color = Color(0.12, 0.22, 0.38, 0.8)
	pedestal_rect.anchor_right = 1.0
	pedestal_rect.anchor_bottom = 1.0
	pedestal_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_pedestal.add_child(pedestal_rect)

	# Front View Sprite
	preview_sprite = TextureRect.new()
	preview_sprite.name = "PokemonFrontPreview"
	preview_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_sprite.custom_minimum_size = Vector2(240, 240)
	preview_sprite.anchor_left = 0.5
	preview_sprite.anchor_top = 0.5
	preview_sprite.anchor_right = 0.5
	preview_sprite.anchor_bottom = 0.5
	preview_sprite.offset_left = -120
	preview_sprite.offset_top = -140
	preview_sprite.offset_right = 120
	preview_sprite.offset_bottom = 100
	preview_sprite.pivot_offset = Vector2(120, 180) # Squash and stretch relative to foot base
	if preview_shader_mat != null:
		preview_sprite.material = preview_shader_mat
	preview_stage.add_child(preview_sprite)

	# Evolution Stages Deck (Stage 1, 2, 3 h_1 horizontal walk view)
	stages_h1_deck = HBoxContainer.new()
	stages_h1_deck.name = "StagesH1Deck"
	stages_h1_deck.alignment = BoxContainer.ALIGNMENT_CENTER
	stages_h1_deck.add_theme_constant_override("separation", 16)
	center_vbox.add_child(stages_h1_deck)

	stage_h1_sprites.clear()
	stage_h1_labels.clear()

	for stage_num in range(1, 4):
		var slot_card := PanelContainer.new()
		slot_card.custom_minimum_size = Vector2(104, 110)
		slot_card.add_theme_stylebox_override("panel", _make_style(Color(0.12, 0.18, 0.28, 0.90), Color.TRANSPARENT, 6))
		stages_h1_deck.add_child(slot_card)

		var slot_vbox := VBoxContainer.new()
		slot_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_vbox.add_theme_constant_override("separation", 4)
		slot_card.add_child(slot_vbox)

		var lbl := Label.new()
		lbl.text = "STAGE %d" % stage_num
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		GameFont.apply_label(lbl, 22, Color(0.75, 0.90, 1.0), true, Color.BLACK, 1)
		slot_vbox.add_child(lbl)
		stage_h1_labels.append(lbl)

		var stage_sprite := TextureRect.new()
		stage_sprite.name = "Stage%dH1Preview" % stage_num
		stage_sprite.custom_minimum_size = Vector2(64, 64)
		stage_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stage_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		stage_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if preview_shader_mat != null:
			stage_sprite.material = preview_shader_mat
		slot_vbox.add_child(stage_sprite)
		stage_h1_sprites.append(stage_sprite)


# Right Side: Direct Hue & Saturation Color Customizer
func _build_color_customizer(parent: HBoxContainer) -> void:
	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(420, 0)
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.12, 0.22, 0.85), Color(0.25, 0.40, 0.65), 10))
	parent.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 16)
	right_panel.add_child(right_vbox)

	var color_title := Label.new()
	color_title.text = "COLOR CUSTOMIZER"
	color_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	color_title.add_theme_font_size_override("font_size", 30)
	color_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	right_vbox.add_child(color_title)

	var color_sub := Label.new()
	color_sub.text = "Direct Pokémon Hue & Saturation Shift"
	color_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	color_sub.add_theme_font_size_override("font_size", 22)
	color_sub.add_theme_color_override("font_color", Color(0.65, 0.75, 0.9, 0.7))
	right_vbox.add_child(color_sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	right_vbox.add_child(spacer)

	# 1. Color (Hue) Slider: -180 deg to +180 deg
	var hue_header_hbox := HBoxContainer.new()
	right_vbox.add_child(hue_header_hbox)

	var lbl_hue := Label.new()
	lbl_hue.text = "HUE SHIFT:"
	lbl_hue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_hue.add_theme_font_size_override("font_size", 24)
	lbl_hue.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	hue_header_hbox.add_child(lbl_hue)

	label_hue_val = Label.new()
	label_hue_val.text = "0° (Default)"
	label_hue_val.add_theme_font_size_override("font_size", 24)
	label_hue_val.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	hue_header_hbox.add_child(label_hue_val)

	slider_hue = HSlider.new()
	slider_hue.min_value = -180.0
	slider_hue.max_value = 180.0
	slider_hue.step = 1.0
	slider_hue.value = 0.0
	slider_hue.custom_minimum_size = Vector2(0, 32)
	slider_hue.value_changed.connect(_on_slider_value_changed)
	right_vbox.add_child(slider_hue)

	# 2. Saturation Slider: 0% to 200% (0.0 to 2.0 multiplier)
	var sat_header_hbox := HBoxContainer.new()
	right_vbox.add_child(sat_header_hbox)

	var lbl_sat := Label.new()
	lbl_sat.text = "SATURATION:"
	lbl_sat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_sat.add_theme_font_size_override("font_size", 24)
	lbl_sat.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	sat_header_hbox.add_child(lbl_sat)

	label_sat_val = Label.new()
	label_sat_val.text = "100% (Default)"
	label_sat_val.add_theme_font_size_override("font_size", 24)
	label_sat_val.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	sat_header_hbox.add_child(label_sat_val)

	slider_sat = HSlider.new()
	slider_sat.min_value = 0.0
	slider_sat.max_value = 2.0
	slider_sat.step = 0.01
	slider_sat.value = 1.0 # Default 1.0 = normal/original saturation
	slider_sat.custom_minimum_size = Vector2(0, 32)
	slider_sat.value_changed.connect(_on_slider_value_changed)
	right_vbox.add_child(slider_sat)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	right_vbox.add_child(spacer2)

	# Hex Swatch & Display
	var hex_panel := PanelContainer.new()
	hex_panel.add_theme_stylebox_override("panel", _make_style(Color(0.04, 0.07, 0.12, 0.9), Color(0.25, 0.35, 0.5), 6))
	right_vbox.add_child(hex_panel)

	var hex_hbox := HBoxContainer.new()
	hex_hbox.add_theme_constant_override("separation", 16)
	hex_panel.add_child(hex_hbox)

	color_swatch = ColorRect.new()
	color_swatch.custom_minimum_size = Vector2(68, 48)
	color_swatch.color = Color.WHITE
	hex_hbox.add_child(color_swatch)

	var hex_vbox := VBoxContainer.new()
	hex_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hex_hbox.add_child(hex_vbox)

	var lbl_hex_desc := Label.new()
	lbl_hex_desc.text = "SAMPLE HEX:"
	lbl_hex_desc.add_theme_font_size_override("font_size", 20)
	lbl_hex_desc.add_theme_color_override("font_color", Color(0.5, 0.65, 0.8))
	hex_vbox.add_child(lbl_hex_desc)

	label_hex_val = Label.new()
	label_hex_val.text = "#FFFFFF"
	label_hex_val.add_theme_font_size_override("font_size", 30)
	label_hex_val.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	hex_vbox.add_child(label_hex_val)

	# Reset Button
	btn_reset_color = Button.new()
	btn_reset_color.text = "RESET DEFAULT COLOR"
	btn_reset_color.custom_minimum_size = Vector2(0, 52)
	btn_reset_color.add_theme_font_size_override("font_size", 24)
	btn_reset_color.add_theme_stylebox_override("normal", _make_style(Color(0.12, 0.18, 0.28), Color(0.3, 0.45, 0.65), 8))
	btn_reset_color.add_theme_stylebox_override("hover", _make_style(Color(0.18, 0.26, 0.38), Color(1.0, 0.85, 0.2), 8))
	btn_reset_color.pressed.connect(_on_reset_color_pressed)
	right_vbox.add_child(btn_reset_color)


# Bottom Deck: Card Selection & BATTLE button
func _build_bottom_card_deck() -> void:
	var deck_panel := PanelContainer.new()
	deck_panel.anchor_left = 0.02
	deck_panel.anchor_top = 0.78
	deck_panel.anchor_right = 0.98
	deck_panel.anchor_bottom = 0.98
	deck_panel.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.12, 0.20, 0.92), Color(0.25, 0.45, 0.70), 10))
	panel_char_select.add_child(deck_panel)

	var deck_hbox := HBoxContainer.new()
	deck_hbox.add_theme_constant_override("separation", 24)
	deck_panel.add_child(deck_hbox)

	# Card Selection Section
	var cards_vbox := VBoxContainer.new()
	cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_vbox.add_theme_constant_override("separation", 8)
	deck_hbox.add_child(cards_vbox)

	var cards_title := Label.new()
	cards_title.text = "SELECT FIGHTER (KANTO STARTERS)"
	cards_title.add_theme_font_size_override("font_size", 26)
	cards_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	cards_vbox.add_child(cards_title)

	var cards_hbox := HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 20)
	cards_vbox.add_child(cards_hbox)

	card_buttons.clear()
	card_containers.clear()

	for i in range(starter_pokemon.size()):
		var pkmn := starter_pokemon[i]
		var card_box := PanelContainer.new()
		card_box.custom_minimum_size = Vector2(115, 140)
		card_box.add_theme_stylebox_override("panel", _make_style(Color(0.05, 0.08, 0.14), Color(0.25, 0.35, 0.55), 6))
		cards_hbox.add_child(card_box)
		card_containers.append(card_box)

		var card_btn := Button.new()
		card_btn.name = "CardButton_%d" % i
		card_btn.custom_minimum_size = Vector2(110, 132)
		card_btn.flat = true
		card_btn.expand_icon = true

		var card_tex_path := pkmn.get_card_asset_path()
		if ResourceLoader.exists(card_tex_path) or FileAccess.file_exists(card_tex_path):
			card_btn.icon = load(card_tex_path)

		var captured_idx := i
		card_btn.pressed.connect(func(): select_pokemon(captured_idx))
		card_box.add_child(card_btn)
		card_buttons.append(card_btn)

	# Vertical Divider
	var v_div := VSeparator.new()
	deck_hbox.add_child(v_div)

	# BATTLE Button (Next to cards)
	var battle_vbox := VBoxContainer.new()
	battle_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	deck_hbox.add_child(battle_vbox)

	btn_battle = Button.new()
	btn_battle.name = "BtnBattle"
	btn_battle.text = "BATTLE  ▶"
	btn_battle.custom_minimum_size = Vector2(300, 100)
	btn_battle.add_theme_font_size_override("font_size", 44)
	btn_battle.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	btn_battle.add_theme_stylebox_override("normal", _make_style(Color(0.85, 0.38, 0.10), Color(1.0, 0.75, 0.2), 10))
	btn_battle.add_theme_stylebox_override("hover", _make_style(Color(0.95, 0.48, 0.15), Color(1.0, 0.92, 0.4), 10))
	btn_battle.add_theme_stylebox_override("pressed", _make_style(Color(0.70, 0.28, 0.08), Color(0.9, 0.6, 0.1), 10))
	btn_battle.pressed.connect(_on_battle_pressed)
	battle_vbox.add_child(btn_battle)


# =============================================================================
# STATE MANAGEMENT & NAVIGATION
# =============================================================================
func show_main_menu() -> void:
	current_state = MenuState.MAIN_TITLE
	_stop_bgm(0.8)
	panel_main.visible = true
	panel_menu_settings.visible = false
	panel_mode.visible = false
	panel_char_select.visible = false


func show_mode_select() -> void:
	current_state = MenuState.MODE_SELECT
	_stop_bgm(0.8)
	panel_main.visible = false
	panel_menu_settings.visible = false
	panel_mode.visible = true
	panel_char_select.visible = false


func show_char_select() -> void:
	current_state = MenuState.CHAR_SELECT
	panel_main.visible = false
	panel_menu_settings.visible = false
	panel_mode.visible = false
	panel_char_select.visible = true
	_start_bgm()
	select_pokemon(selected_pokemon_index)


func _on_play_pressed() -> void:
	AudioManager.play_atk_button()
	show_mode_select()


func _on_1v1_pressed() -> void:
	AudioManager.play_atk_button()
	show_char_select()


func _on_mode_back_pressed() -> void:
	AudioManager.play_back_button()
	show_main_menu()


func _on_char_back_pressed() -> void:
	AudioManager.play_back_button()
	show_mode_select()


# =============================================================================
# MAIN MENU SETTINGS INTERACTIONS
# =============================================================================
func open_main_settings() -> void:
	AudioManager.play_button_click()
	panel_main.visible = false
	panel_menu_settings.visible = true
	_update_menu_settings_readouts()


func close_main_settings() -> void:
	AudioManager.play_back_button()
	panel_menu_settings.visible = false
	panel_main.visible = true


func _get_debug_menu() -> Node:
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		return get_tree().root.get_node_or_null("DebugMenu")
	return null


func _update_menu_settings_readouts() -> void:
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

	if btn_menu_crt_toggle != null:
		btn_menu_crt_toggle.text = "CRT SCANLINES: " + ("ON" if crt_on else "OFF")
		var col := Color(0.15, 0.55, 0.35, 1.0) if crt_on else Color(0.4, 0.45, 0.55, 0.8)
		UIDynamic.apply_button_style(btn_menu_crt_toggle, col)

	if label_menu_crt_line_size != null:
		label_menu_crt_line_size.text = "CRT LINE SIZE: %.1f px" % line_size
	if slider_menu_crt_line_size != null and not is_equal_approx(slider_menu_crt_line_size.value, line_size):
		slider_menu_crt_line_size.set_value_no_signal(line_size)

	if label_menu_chroma != null:
		label_menu_chroma.text = "CHROMATIC ABERRATION: %d" % int(roundf(ca_val))
	if slider_menu_chroma != null and not is_equal_approx(slider_menu_chroma.value, ca_val):
		slider_menu_chroma.set_value_no_signal(ca_val)


func _on_menu_crt_toggle_pressed() -> void:
	var dm := _get_debug_menu()
	if dm != null and dm.has_method("set_crt_enabled"):
		var curr: bool = dm.show_crt if "show_crt" in dm else true
		dm.set_crt_enabled(not curr)
	_update_menu_settings_readouts()


func _on_menu_crt_line_size_changed(val: float) -> void:
	var dm := _get_debug_menu()
	if dm != null and dm.has_method("set_crt_line_size"):
		dm.set_crt_line_size(val)
	if label_menu_crt_line_size != null:
		label_menu_crt_line_size.text = "CRT LINE SIZE: %.1f px" % val


func _on_menu_chroma_changed(val: float) -> void:
	var dm := _get_debug_menu()
	if dm != null and dm.has_method("set_chromatic_aberration"):
		dm.set_chromatic_aberration(val)
	if label_menu_chroma != null:
		label_menu_chroma.text = "CHROMATIC ABERRATION: %d" % int(roundf(val))


func _on_menu_customize_controls_pressed() -> void:
	if label_menu_controls_hint != null:
		label_menu_controls_hint.text = "Start a 1v1 Battle and tap PAUSE to customize control layout!"


# =============================================================================
# BGM FADING LOOP FOR CHARACTER SELECT
# =============================================================================
func _start_bgm() -> void:
	if bgm_player == null or bgm_player.stream == null:
		return
	is_bgm_playing = true
	if bgm_tween != null and bgm_tween.is_valid():
		bgm_tween.kill()

	if is_inside_tree() and bgm_player.is_inside_tree():
		if not bgm_player.playing:
			bgm_player.volume_db = -40.0
			bgm_player.play()

		bgm_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		bgm_tween.tween_property(bgm_player, "volume_db", -2.0, 1.2)


func _stop_bgm(duration: float = 0.8) -> void:
	is_bgm_playing = false
	if bgm_player == null:
		return
	if bgm_tween != null and bgm_tween.is_valid():
		bgm_tween.kill()

	if is_inside_tree() and bgm_player.is_inside_tree() and bgm_player.playing:
		bgm_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		bgm_tween.tween_property(bgm_player, "volume_db", -40.0, duration)
		bgm_tween.tween_callback(func():
			if is_instance_valid(bgm_player) and current_state != MenuState.CHAR_SELECT:
				bgm_player.stop()
		)
	elif bgm_player.is_inside_tree():
		bgm_player.stop()


func _on_bgm_finished() -> void:
	if current_state == MenuState.CHAR_SELECT and bgm_player != null and bgm_player.stream != null:
		is_bgm_playing = true
		if is_inside_tree() and bgm_player.is_inside_tree():
			bgm_player.volume_db = -20.0
			bgm_player.play()
			if bgm_tween != null and bgm_tween.is_valid():
				bgm_tween.kill()
			bgm_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			bgm_tween.tween_property(bgm_player, "volume_db", -2.0, 1.0)


# =============================================================================
# CHARACTER SELECTION & PREVIEW
# =============================================================================
func select_pokemon(idx: int) -> void:
	if starter_pokemon.is_empty():
		return
	selected_pokemon_index = clampi(idx, 0, starter_pokemon.size() - 1)
	var pkmn := starter_pokemon[selected_pokemon_index]

	# 1. Update Labels
	if label_pokemon_name != null:
		label_pokemon_name.text = pkmn.display_name.to_upper()
	if label_pokemon_sub != null:
		var type_map := {
			"venusaur": "Seed Pokémon • Grass / Poison",
			"charizard": "Flame Pokémon • Fire / Flying",
			"blastoise": "Shellfish Pokémon • Water"
		}
		label_pokemon_sub.text = type_map.get(pkmn.display_name.to_lower(), "Kanto Starter Pokémon")

	# 2. Update Preview Texture & Stage h_1 Sprites
	var front_path := pkmn.get_front_sprite_path()
	if preview_sprite != null and (ResourceLoader.exists(front_path) or FileAccess.file_exists(front_path)):
		preview_sprite.texture = load(front_path)
		preview_sprite.modulate = Color.WHITE

	for stage_num in range(1, 4):
		if stage_num - 1 < stage_h1_sprites.size():
			var s_rect := stage_h1_sprites[stage_num - 1]
			var h1_path := pkmn.get_sprite_path(stage_num, "h_1")
			if h1_path != "" and (ResourceLoader.exists(h1_path) or FileAccess.file_exists(h1_path)):
				s_rect.texture = load(h1_path)
			elif preview_sprite != null:
				s_rect.texture = preview_sprite.texture
			s_rect.self_modulate = Color.WHITE

			if stage_num - 1 < stage_h1_labels.size():
				var s_name := pkmn.get_stage_name(stage_num) if pkmn.has_method("get_stage_name") else ""
				if s_name != "":
					stage_h1_labels[stage_num - 1].text = s_name.to_upper()
				else:
					stage_h1_labels[stage_num - 1].text = "STAGE %d" % stage_num

	# Re-apply direct hue & saturation readout for this Pokemon
	_update_color_from_sliders()

	# 3. Highlight Selected Card
	for i in range(card_containers.size()):
		var container := card_containers[i]
		if i == selected_pokemon_index:
			container.add_theme_stylebox_override("panel", _make_style(Color(1.0, 0.82, 0.25, 1.0), Color.TRANSPARENT, 6))
		else:
			container.add_theme_stylebox_override("panel", _make_style(Color(0.12, 0.18, 0.28, 0.85), Color.TRANSPARENT, 6))

	# 4. GBA-Style Stretch Animation & Cry
	play_gba_stretch_animation()
	play_pokemon_cry()


func play_gba_stretch_animation() -> void:
	if preview_sprite == null:
		return
	if stretch_tween != null and stretch_tween.is_valid():
		stretch_tween.kill()

	preview_sprite.scale = Vector2.ONE

	stretch_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	stretch_tween.tween_property(preview_sprite, "scale", Vector2(1.22, 0.78), 0.07)
	stretch_tween.tween_property(preview_sprite, "scale", Vector2(0.85, 1.25), 0.12)
	stretch_tween.tween_property(preview_sprite, "scale", Vector2(1.08, 0.94), 0.08)
	stretch_tween.tween_property(preview_sprite, "scale", Vector2(1.0, 1.0), 0.08)

	for s_rect in stage_h1_sprites:
		if s_rect != null and is_instance_valid(s_rect):
			s_rect.pivot_offset = s_rect.size * 0.5
			var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(s_rect, "scale", Vector2(1.15, 0.85), 0.08)
			t.tween_property(s_rect, "scale", Vector2(0.90, 1.15), 0.10)
			t.tween_property(s_rect, "scale", Vector2(1.0, 1.0), 0.08)


func play_pokemon_cry() -> void:
	if starter_pokemon.is_empty():
		return
	var pkmn := starter_pokemon[selected_pokemon_index]
	var cry_path := pkmn.get_cry_audio_path()
	if cry_path != "" and (ResourceLoader.exists(cry_path) or FileAccess.file_exists(cry_path)):
		var stream := load(cry_path) as AudioStream
		if stream != null and cry_player != null:
			cry_player.stream = stream
			if is_inside_tree() and cry_player.is_inside_tree():
				cry_player.play()


# =============================================================================
# COLOR CUSTOMIZATION (DIRECT HUE & SATURATION ALTERATION)
# =============================================================================
func _on_slider_value_changed(_val: float) -> void:
	_update_color_from_sliders()


func _update_color_from_sliders() -> void:
	var h_deg: float = slider_hue.value if slider_hue != null else 0.0
	var s_val: float = slider_sat.value if slider_sat != null else 1.0

	current_hue_shift = h_deg / 360.0
	current_sat_mult = s_val

	if preview_shader_mat != null:
		preview_shader_mat.set_shader_parameter("hue_shift", current_hue_shift)
		preview_shader_mat.set_shader_parameter("sat_mult", current_sat_mult)

	# Update Labels
	if label_hue_val != null:
		if absf(h_deg) < 0.01:
			label_hue_val.text = "0° (Default)"
		else:
			label_hue_val.text = "%+d°" % int(roundf(h_deg))
	if label_sat_val != null:
		if is_equal_approx(s_val, 1.0):
			label_sat_val.text = "100% (Default)"
		elif is_zero_approx(s_val):
			label_sat_val.text = "0% (Mono)"
		else:
			label_sat_val.text = "%d%%" % int(roundf(s_val * 100.0))

	# Compute representative sample color swatch & hex code
	var base_hue := 0.40 # Venusaur default (teal-green)
	if not starter_pokemon.is_empty() and selected_pokemon_index < starter_pokemon.size():
		var p_name := starter_pokemon[selected_pokemon_index].display_name.to_lower()
		if p_name.contains("char"):
			base_hue = 0.08 # Charizard orange
		elif p_name.contains("blast"):
			base_hue = 0.58 # Blastoise blue

	var sample_h := wrapf(base_hue + current_hue_shift, 0.0, 1.0)
	var sample_s := clampf(0.85 * current_sat_mult, 0.0, 1.0)
	var sample_col := Color.from_hsv(sample_h, sample_s, 1.0)
	selected_color = sample_col
	selected_hex = "#" + sample_col.to_html(false).to_lower()

	if label_hex_val != null:
		label_hex_val.text = selected_hex.to_upper()
	if color_swatch != null:
		color_swatch.color = sample_col


func _on_reset_color_pressed() -> void:
	AudioManager.play_button_click()
	if slider_hue != null:
		slider_hue.value = 0.0
	if slider_sat != null:
		slider_sat.value = 1.0
	_update_color_from_sliders()


# =============================================================================
# BATTLE START
# =============================================================================
func _on_battle_pressed() -> void:
	start_battle()


func start_battle() -> void:
	AudioManager.play_atk_button()
	_stop_bgm(0.5)
	var chosen_mon: PokemonData = null
	if not starter_pokemon.is_empty():
		chosen_mon = starter_pokemon[selected_pokemon_index]

	# Persist selection and direct hue & sat shift to GameState
	GameState.set_selection(chosen_mon, selected_hex, Color.WHITE, current_hue_shift, current_sat_mult)

	# Transition to battlefield
	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	elif Engine.get_main_loop() is SceneTree:
		(Engine.get_main_loop() as SceneTree).change_scene_to_file("res://scenes/main.tscn")


# =============================================================================
# HELPER STYLING (UTILIZING RES://ASSETS/UI/UI_DYNAMIC)
# =============================================================================
func _make_style(bg_col: Color, _border_col: Color = Color.TRANSPARENT, margin: int = 8) -> StyleBox:
	return UIDynamic.make_style(bg_col, margin)
