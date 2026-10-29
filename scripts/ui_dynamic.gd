class_name UIDynamic
extends RefCounted

const FRAME_TEXTURE_PATH := "res://assets/ui/ui_dynamic/ui_frame_9patch.png"
const DYNAMIC_DIR := "res://assets/ui/ui_dynamic/"

# Render the 16 px source patches at 24 px for clearer mobile UI.
const SOURCE_PATCH_SIZE := 16
const PIXEL_SCALE := 1.5
const PATCH_SIZE := 24

static var _cached_frame: Texture2D = null
static var _stylebox_cache: Dictionary = {}


static func get_frame_texture() -> Texture2D:
	if _cached_frame != null:
		return _cached_frame

	if ResourceLoader.exists(FRAME_TEXTURE_PATH) or FileAccess.file_exists(FRAME_TEXTURE_PATH):
		_cached_frame = load(FRAME_TEXTURE_PATH)
		if _cached_frame != null:
			return _cached_frame

	_cached_frame = _build_frame_from_tiles()
	return _cached_frame


static func _build_frame_from_tiles() -> Texture2D:
	var tl_img: Image = _load_tile_image("ui_corner_top_left.png")
	var ct_img: Image = _load_tile_image("ui_corner_center_top.png")
	var tr_img: Image = _load_tile_image("ui_corner_top_right.png")
	var c_img: Image  = _load_tile_image("ui_corner_center.png")
	var cb_img: Image = _load_tile_image("ui_corner_center_bottom.png")
	var bl_img: Image = _load_tile_image("ui_corner_bottom_left.png")
	var br_img: Image = _load_tile_image("ui_corner_bottom_right.png")

	# Assemble 48x48 image
	var master := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	master.fill(Color(0, 0, 0, 0))

	# Rotate top center for left and right edges
	var cl_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var cr_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var col: Color = ct_img.get_pixel(x, y) if ct_img != null else Color(0.32, 0.41, 0.38, 1.0)
			# Counter-clockwise 90 deg for left (row becomes column 0)
			cl_img.set_pixel(y, 15 - x, col)
			# Clockwise 90 deg for right (row becomes column 15)
			cr_img.set_pixel(15 - y, x, col)

	if tl_img != null: master.blit_rect(tl_img, Rect2i(0, 0, 16, 16), Vector2i(0, 0))
	if ct_img != null: master.blit_rect(ct_img, Rect2i(0, 0, 16, 16), Vector2i(16, 0))
	if tr_img != null: master.blit_rect(tr_img, Rect2i(0, 0, 16, 16), Vector2i(32, 0))

	master.blit_rect(cl_img, Rect2i(0, 0, 16, 16), Vector2i(0, 16))
	if c_img != null: master.blit_rect(c_img, Rect2i(0, 0, 16, 16), Vector2i(16, 16))
	master.blit_rect(cr_img, Rect2i(0, 0, 16, 16), Vector2i(32, 16))

	if bl_img != null: master.blit_rect(bl_img, Rect2i(0, 0, 16, 16), Vector2i(0, 32))
	if cb_img != null: master.blit_rect(cb_img, Rect2i(0, 0, 16, 16), Vector2i(16, 32))
	if br_img != null: master.blit_rect(br_img, Rect2i(0, 0, 16, 16), Vector2i(32, 32))

	return ImageTexture.create_from_image(master)


static func _load_tile_image(filename: String) -> Image:
	var path := DYNAMIC_DIR + filename
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			return tex.get_image()
	return null


static func make_style(tint: Color = Color.WHITE, content_margin: int = 12) -> StyleBoxTexture:
	var key := "%s_%d" % [tint.to_html(true), content_margin]
	if _stylebox_cache.has(key):
		return _stylebox_cache[key]

	var sb := StyleBoxTexture.new()
	sb.texture = get_frame_texture()
	sb.texture_margin_left = 16
	sb.texture_margin_top = 16
	sb.texture_margin_right = 16
	sb.texture_margin_bottom = 16
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.modulate_color = tint
	sb.content_margin_left = content_margin
	sb.content_margin_top = content_margin
	sb.content_margin_right = content_margin
	sb.content_margin_bottom = content_margin

	_stylebox_cache[key] = sb
	return sb


static func make_nine_patch(tint: Color = Color.WHITE) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.texture = get_frame_texture()
	np.patch_margin_left = 16
	np.patch_margin_top = 16
	np.patch_margin_right = 16
	np.patch_margin_bottom = 16
	np.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	np.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	np.modulate = tint
	return np


static func apply_panel_style(panel: Control, tint: Color, margin: int = 12) -> void:
	if panel is PanelContainer or panel is Panel:
		panel.add_theme_stylebox_override(&"panel", make_style(tint, margin))


static func apply_button_style(
	btn: Button,
	normal_tint: Color,
	hover_tint: Color = Color.TRANSPARENT,
	pressed_tint: Color = Color.TRANSPARENT,
	disabled_tint: Color = Color.TRANSPARENT,
	margin: int = 10
) -> void:
	if hover_tint == Color.TRANSPARENT:
		hover_tint = normal_tint.lightened(0.20)
	if pressed_tint == Color.TRANSPARENT:
		pressed_tint = normal_tint.darkened(0.20)
	if disabled_tint == Color.TRANSPARENT:
		disabled_tint = Color(normal_tint.r * 0.4, normal_tint.g * 0.4, normal_tint.b * 0.4, 0.45)

	btn.add_theme_stylebox_override(&"normal", make_style(normal_tint, margin))
	btn.add_theme_stylebox_override(&"hover", make_style(hover_tint, margin))
	btn.add_theme_stylebox_override(&"pressed", make_style(pressed_tint, margin))
	btn.add_theme_stylebox_override(&"disabled", make_style(disabled_tint, margin))
	btn.add_theme_stylebox_override(&"focus", make_style(hover_tint, margin))
