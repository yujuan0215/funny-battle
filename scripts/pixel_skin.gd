extends RefCounted
## Original, cached nine-patch art. All coordinates are on a two-pixel grid.

const OUTLINE := Color("241c27")
const WOOD := Color("69483f")
const WOOD_DARK := Color("493334")
const BRASS := Color("ab7950")
const GOLD := Color("dfb269")
const PAPER := Color("ffe5ae")
const MUTED := Color("c6b397")
const HERO := Color("8ace85")
const DANGER := Color("ed7758")
const IRON := Color("607e86")
static var _skins: Dictionary = {}
static var _compact: Dictionary = {}


static func box(state: String = "normal") -> StyleBoxTexture:
	if _skins.has(state):
		return _skins[state]
	var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var focus := state == "focus"
	var pressed := state == "pressed"
	var disabled := state == "disabled"
	var selected := state in ["selected", "hover"]
	var y := 4 if pressed else 0
	var fill := WOOD_DARK if state == "panel" or pressed else WOOD
	var edge := GOLD if selected else BRASS
	if disabled:
		fill = Color("454046")
		edge = IRON.darkened(0.3)
	if not focus:
		# A solid cast shadow, a clipped silhouette, then the carved recess.
		image.fill_rect(Rect2i(4, 6, 40, 42), OUTLINE)
		image.fill_rect(Rect2i(0, 10, 48, 34), OUTLINE)
		image.fill_rect(Rect2i(4, y, 40, 42 - y), OUTLINE)
		image.fill_rect(Rect2i(0, 4 + y, 48, 34 - y), OUTLINE)
		image.fill_rect(Rect2i(4, 4 + y, 40, 34 - y), edge)
		image.fill_rect(Rect2i(8, 8 + y, 32, 26 - y), fill)
		image.fill_rect(Rect2i(8, 8 + y, 32, 2), OUTLINE)
		image.fill_rect(Rect2i(8, 10 + y, 2, 24 - y), WOOD_DARK)
		image.fill_rect(Rect2i(10, 32, 28, 2), BRASS.darkened(0.2))
		image.fill_rect(Rect2i(8, 4 + y, 32, 2), GOLD if not disabled else IRON)
		image.fill_rect(Rect2i(4, 8 + y, 2, 26 - y), edge.lightened(0.15))
		# Copper corner plates and dark screw slots are the shared signature.
		for x in [4, 38]:
			for top in [6 + y, 32]:
				image.fill_rect(Rect2i(x, top, 6, 6), GOLD if selected else BRASS)
				image.fill_rect(Rect2i(x + 2, top + 2, 2, 2), OUTLINE)
	else:
		# Keyboard focus is a separate set of bright corner brackets.
		for x in [0, 40]:
			for top in [0, 36]:
				image.fill_rect(Rect2i(x, top, 8, 2), PAPER)
				image.fill_rect(Rect2i(x if x == 0 else 46, top, 2, 8), PAPER)
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP]:
		style.set_texture_margin(side, 12)
	style.set_texture_margin(SIDE_BOTTOM, 16)
	style.set_content_margin_all(16)
	style.content_margin_bottom = 20
	_skins[state] = style
	return style


static func button(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, box(state))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, PAPER)
	button.add_theme_color_override("font_disabled_color", MUTED.darkened(0.35))
	button.add_theme_color_override("font_shadow_color", OUTLINE)
	button.add_theme_constant_override("shadow_offset_x", 2)
	button.add_theme_constant_override("shadow_offset_y", 2)
	button.add_theme_constant_override("outline_size", 0)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func compact(state: String) -> StyleBoxTexture:
	if not _compact.has(state):
		var result := box(state).duplicate() as StyleBoxTexture
		result.set_content_margin_all(4)
		_compact[state] = result
	return _compact[state]
