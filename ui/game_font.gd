class_name GameFont
extends RefCounted

const BASE_FONT := preload("res://assets/pokemon-emerald-pro.ttf")

# Universal Font Size: All characters/letters share the exact same font size and type
const UNIVERSAL_FONT_SIZE := 46

# Healthbox Elements: Enlarged font sizes for mobile touchscreens
const SIZE_HEALTHBOX_PLAYER := 56
const SIZE_HEALTHBOX_ENEMY := 48

const SIZE_DEBUG := UNIVERSAL_FONT_SIZE
const SIZE_TITLE := UNIVERSAL_FONT_SIZE
const SIZE_NAME := UNIVERSAL_FONT_SIZE
const SIZE_TAG := UNIVERSAL_FONT_SIZE
const SIZE_VALUE := UNIVERSAL_FONT_SIZE
const SIZE_COOLDOWN := UNIVERSAL_FONT_SIZE
const SIZE_BUTTON := UNIVERSAL_FONT_SIZE

static var _bold_font: FontVariation


static func get_bold_font() -> Font:
	if _bold_font == null:
		_bold_font = FontVariation.new()
		_bold_font.base_font = BASE_FONT
		_bold_font.variation_embolden = 1.0
	return _bold_font


static func apply_label(lbl: Label, font_size: int = UNIVERSAL_FONT_SIZE, col: Color = Color.WHITE, with_outline: bool = false, outline_col: Color = Color.BLACK, outline_w: int = 2) -> void:
	if lbl == null:
		return
	lbl.add_theme_font_override(&"font", get_bold_font())
	lbl.add_theme_font_size_override(&"font_size", font_size)
	lbl.add_theme_color_override(&"font_color", col)
	if with_outline:
		lbl.add_theme_constant_override(&"outline_size", outline_w)
		lbl.add_theme_color_override(&"font_outline_color", outline_col)


static func apply_button(btn: Button, font_size: int = UNIVERSAL_FONT_SIZE, col: Color = Color.WHITE) -> void:
	if btn == null:
		return
	btn.add_theme_font_override(&"font", get_bold_font())
	btn.add_theme_font_size_override(&"font_size", font_size)
	btn.add_theme_color_override(&"font_color", col)
	btn.add_theme_color_override(&"font_focus_color", col)
	btn.add_theme_color_override(&"font_hover_color", Color(1.0, 1.0, 0.8))
	btn.add_theme_color_override(&"font_pressed_color", Color(0.8, 0.9, 1.0))


static func apply_line_edit(le: LineEdit, font_size: int = UNIVERSAL_FONT_SIZE, col: Color = Color.WHITE) -> void:
	if le == null:
		return
	le.add_theme_font_override(&"font", get_bold_font())
	le.add_theme_font_size_override(&"font_size", font_size)
	le.add_theme_color_override(&"font_color", col)
