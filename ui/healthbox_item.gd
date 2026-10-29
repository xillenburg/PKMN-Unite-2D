class_name HealthboxItem
extends Control

# Constants
const HEALTHBOX_TEX := preload("res://assets/ui/healthbox.png")
const FONT_PKMN := preload("res://assets/pokemon-emerald-pro.ttf")

# Dimensions: Mobile-enlarged dimensions for Player/Ally (860x268) and Enemy (680x216)
const BOX_WIDTH_PLAYER := 860.0
const BOX_HEIGHT_PLAYER := 268.0
const BOX_WIDTH_ENEMY := 680.0
const BOX_HEIGHT_ENEMY := 216.0

# Defaults
const BOX_WIDTH := 860.0
const BOX_HEIGHT := 268.0

# Older Gen Colors (#20211b UI Theme)
const COLOR_MAIN_DARK := Color("#20211b")
const COLOR_TEXT := Color("#20211b")
const COLOR_HP_LABEL := Color(0.85, 0.25, 0.12, 1.0)
const COLOR_EXP_LABEL := Color(0.18, 0.42, 0.72, 1.0)

const COLOR_BAR_BG := Color("#20211b")
const COLOR_HP_GREEN := Color(0.0, 0.8, 0.32, 1.0)     # > 50%
const COLOR_HP_YELLOW := Color(0.96, 0.68, 0.12, 1.0)   # 20% - 50%
const COLOR_HP_RED := Color(0.92, 0.22, 0.12, 1.0)      # < 20%
const COLOR_EXP_BLUE := Color(0.25, 0.78, 0.98, 1.0)    # Older Gen Cyan EXP

# GBA Stepped movement speed (pixels per frame - fast snappy sliding)
const GBA_MOVE_STEP := 32.0

# Sub-nodes
var box_bg: TextureRect
var name_label: Label
var level_label: Label
var hp_tag: Label
var hp_bg: ColorRect
var hp_fill: ColorRect
var hp_val_label: Label
var xp_tag: Label
var xp_bg: ColorRect
var xp_fill: ColorRect
var xp_val_label: Label
var blink_overlay: ColorRect
var blink_frames_left: int = 0
const COLOR_MILESTONE_BLINK := Color(0.55, 0.88, 1.0, 0.88)

# Linked fighter and side sizing
var fighter: Fighter
var target_position: Vector2 = Vector2.ZERO
var is_player_or_ally: bool = true
var box_width: float = 680.0
var box_height: float = 200.0
var current_hp_bar_max: float = 310.0
var current_xp_bar_max: float = 296.0


func _init(is_ally: bool = true) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_nodes()
	apply_dimensions(is_ally)


func _setup_nodes() -> void:
	# Box background
	box_bg = TextureRect.new()
	box_bg.texture = HEALTHBOX_TEX
	box_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	box_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box_bg)

	name_label = Label.new()
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameFont.apply_label(name_label, GameFont.UNIVERSAL_FONT_SIZE, COLOR_TEXT)
	add_child(name_label)

	level_label = Label.new()
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameFont.apply_label(level_label, GameFont.UNIVERSAL_FONT_SIZE, COLOR_TEXT)
	add_child(level_label)

	hp_tag = Label.new()
	hp_tag.text = "HP"
	hp_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameFont.apply_label(hp_tag, GameFont.UNIVERSAL_FONT_SIZE, COLOR_HP_LABEL)
	add_child(hp_tag)

	hp_bg = ColorRect.new()
	hp_bg.color = COLOR_BAR_BG
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_bg)

	hp_fill = ColorRect.new()
	hp_fill.color = COLOR_HP_GREEN
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_fill)

	hp_val_label = Label.new()
	hp_val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_val_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_val_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameFont.apply_label(hp_val_label, GameFont.UNIVERSAL_FONT_SIZE, COLOR_TEXT)
	add_child(hp_val_label)

	xp_tag = Label.new()
	xp_tag.text = "EXP"
	xp_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameFont.apply_label(xp_tag, GameFont.UNIVERSAL_FONT_SIZE, COLOR_EXP_LABEL)
	add_child(xp_tag)

	xp_bg = ColorRect.new()
	xp_bg.color = COLOR_BAR_BG
	xp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(xp_bg)

	xp_fill = ColorRect.new()
	xp_fill.color = COLOR_EXP_BLUE
	xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(xp_fill)

	xp_val_label = Label.new()
	xp_val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_val_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_val_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameFont.apply_label(xp_val_label, GameFont.UNIVERSAL_FONT_SIZE, COLOR_TEXT)
	add_child(xp_val_label)

	# Milestone Level-Up Blink Overlay (Rapid opaque light blue every 10 levels)
	blink_overlay = ColorRect.new()
	blink_overlay.color = COLOR_MILESTONE_BLINK
	blink_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blink_overlay.visible = false
	add_child(blink_overlay)


# Apply reintroduced and increased element padding
func apply_dimensions(is_ally: bool) -> void:
	is_player_or_ally = is_ally
	if is_ally:
		box_width = BOX_WIDTH_PLAYER
		box_height = BOX_HEIGHT_PLAYER
		current_hp_bar_max = 430.0
		current_xp_bar_max = 414.0

		custom_minimum_size = Vector2(box_width, box_height)
		size = Vector2(box_width, box_height)
		box_bg.custom_minimum_size = Vector2(box_width, box_height)
		box_bg.size = Vector2(box_width, box_height)

		# Apply enlarged font size for Player/Ally healthbox (56px)
		var fsize := GameFont.SIZE_HEALTHBOX_PLAYER
		GameFont.apply_label(name_label, fsize, COLOR_TEXT)
		GameFont.apply_label(level_label, fsize, COLOR_TEXT)
		GameFont.apply_label(hp_tag, fsize, COLOR_HP_LABEL)
		GameFont.apply_label(hp_val_label, fsize, COLOR_TEXT)
		GameFont.apply_label(xp_tag, fsize, COLOR_EXP_LABEL)
		GameFont.apply_label(xp_val_label, fsize, COLOR_TEXT)

		# Padded Row 1: Name & Level (y: 30..84, pad_x: 46, right: 814)
		name_label.position = Vector2(46, 30)
		name_label.size = Vector2(520, 54)
		level_label.position = Vector2(576, 30)
		level_label.size = Vector2(238, 54)

		# Padded Row 2: HP Row (y: 100..152, pad_x: 46, right: 814)
		hp_tag.position = Vector2(46, 100)
		hp_tag.size = Vector2(68, 50)
		hp_bg.position = Vector2(122, 114)
		hp_bg.size = Vector2(430, 24)
		hp_fill.position = Vector2(122, 114)
		hp_fill.size = Vector2(430, 24)
		hp_val_label.position = Vector2(560, 100)
		hp_val_label.size = Vector2(254, 50)

		# Padded Row 3: EXP Row (y: 166..216, pad_x: 46, right: 814)
		xp_tag.position = Vector2(46, 166)
		xp_tag.size = Vector2(86, 46)
		xp_bg.position = Vector2(140, 178)
		xp_bg.size = Vector2(414, 22)
		xp_fill.position = Vector2(140, 178)
		xp_fill.size = Vector2(0, 22)
		xp_val_label.position = Vector2(560, 166)
		xp_val_label.size = Vector2(254, 46)
		if blink_overlay != null:
			blink_overlay.size = Vector2(box_width, box_height)
	else:
		box_width = BOX_WIDTH_ENEMY
		box_height = BOX_HEIGHT_ENEMY
		current_hp_bar_max = 340.0
		current_xp_bar_max = 328.0

		custom_minimum_size = Vector2(box_width, box_height)
		size = Vector2(box_width, box_height)
		box_bg.custom_minimum_size = Vector2(box_width, box_height)
		box_bg.size = Vector2(box_width, box_height)
		if blink_overlay != null:
			blink_overlay.size = Vector2(box_width, box_height)

		# Apply enlarged font size for Enemy healthbox (48px)
		var fsize := GameFont.SIZE_HEALTHBOX_ENEMY
		GameFont.apply_label(name_label, fsize, COLOR_TEXT)
		GameFont.apply_label(level_label, fsize, COLOR_TEXT)
		GameFont.apply_label(hp_tag, fsize, COLOR_HP_LABEL)
		GameFont.apply_label(hp_val_label, fsize, COLOR_TEXT)
		GameFont.apply_label(xp_tag, fsize, COLOR_EXP_LABEL)
		GameFont.apply_label(xp_val_label, fsize, COLOR_TEXT)

		# Padded Row 1: Name & Level (y: 22..68, pad_x: 36, right: 644)
		name_label.position = Vector2(36, 22)
		name_label.size = Vector2(410, 46)
		level_label.position = Vector2(456, 22)
		level_label.size = Vector2(188, 46)

		# Padded Row 2: HP Row (y: 80..124, pad_x: 36, right: 644)
		hp_tag.position = Vector2(36, 80)
		hp_tag.size = Vector2(58, 42)
		hp_bg.position = Vector2(100, 92)
		hp_bg.size = Vector2(340, 20)
		hp_fill.position = Vector2(100, 92)
		hp_fill.size = Vector2(340, 20)
		hp_val_label.position = Vector2(448, 80)
		hp_val_label.size = Vector2(196, 42)

		# Padded Row 3: EXP Row (y: 134..176, pad_x: 36, right: 644)
		xp_tag.position = Vector2(36, 134)
		xp_tag.size = Vector2(74, 38)
		xp_bg.position = Vector2(118, 144)
		xp_bg.size = Vector2(328, 18)
		xp_fill.position = Vector2(118, 144)
		xp_fill.size = Vector2(0, 18)
		xp_val_label.position = Vector2(448, 134)
		xp_val_label.size = Vector2(196, 38)


func _apply_font(lbl: Label, font_size: int, col: Color) -> void:
	if FONT_PKMN != null:
		lbl.add_theme_font_override(&"font", FONT_PKMN)
		lbl.add_theme_font_size_override(&"font_size", font_size)
	lbl.add_theme_color_override(&"font_color", col)


func bind_fighter(f: Fighter) -> void:
	if fighter != null and is_instance_valid(fighter) and fighter.has_signal("leveled_up"):
		if fighter.leveled_up.is_connected(_on_fighter_leveled_up):
			fighter.leveled_up.disconnect(_on_fighter_leveled_up)

	fighter = f
	if fighter != null and is_instance_valid(fighter) and fighter.has_signal("leveled_up"):
		if not fighter.leveled_up.is_connected(_on_fighter_leveled_up):
			fighter.leveled_up.connect(_on_fighter_leveled_up)

	var is_ally: bool = (f != null and f.team == &"player")
	apply_dimensions(is_ally)
	sync_values()


func _process(_delta: float) -> void:
	if blink_frames_left > 0:
		blink_frames_left -= 1
		# Rapid opaque blink toggling every 2-3 frames
		if blink_overlay != null:
			blink_overlay.visible = (int(float(blink_frames_left) / 3.0)) % 2 == 0
	else:
		if blink_overlay != null and blink_overlay.visible:
			blink_overlay.visible = false


func start_milestone_blink() -> void:
	blink_frames_left = 36 # ~0.6s rapid blink
	if blink_overlay != null:
		blink_overlay.size = Vector2(box_width, box_height)
		blink_overlay.visible = true


func _on_fighter_leveled_up(new_lvl: int) -> void:
	if new_lvl % 10 == 0:
		start_milestone_blink()


func sync_values() -> void:
	if fighter == null or not is_instance_valid(fighter):
		return

	# Name & Level
	name_label.text = fighter.get_display_name()
	level_label.text = "Lv." + str(fighter.level)

	# HP bar
	var max_hp := maxi(fighter.max_hp, 1)
	var hp_pct := clampf(float(fighter.hp) / float(max_hp), 0.0, 1.0)
	var hp_bar_max := current_hp_bar_max
	hp_fill.size = Vector2(roundf(hp_bar_max * hp_pct), 22 if is_player_or_ally else 20)

	if hp_pct > 0.5:
		hp_fill.color = COLOR_HP_GREEN
	elif hp_pct > 0.2:
		hp_fill.color = COLOR_HP_YELLOW
	else:
		hp_fill.color = COLOR_HP_RED

	hp_val_label.text = "%d/%d" % [fighter.hp, max_hp]

	# EXP bar (supports float internally, displays whole integer without decimal on UI)
	var max_xp := maxi(fighter.get_max_xp(), 1)
	var xp_pct := clampf(fighter.xp / float(max_xp), 0.0, 1.0)
	var xp_bar_max := current_xp_bar_max
	xp_fill.size = Vector2(roundf(xp_bar_max * xp_pct), 20 if is_player_or_ally else 18)
	xp_val_label.text = "%d/%d" % [int(fighter.xp), max_xp]


func update_position(_delta: float) -> void:
	# GBA-themed stepped discrete movement (not buttery smooth float interpolation)
	if position == target_position:
		return

	var diff := target_position - position
	if diff.length() <= GBA_MOVE_STEP:
		position = target_position
	else:
		position = (position + diff.normalized() * GBA_MOVE_STEP).round()
