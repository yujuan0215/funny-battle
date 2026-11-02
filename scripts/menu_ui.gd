extends RefCounted

## Colors and type sizes for the start page and level select.
## Change these constants to restyle both screens.
const PixelSkin := preload("res://scripts/pixel_skin.gd")
const TITLE := PixelSkin.PAPER
const INK := PixelSkin.PAPER
const FILL := PixelSkin.WOOD_DARK
const HOVER := PixelSkin.WOOD
const HOVER_INK := PixelSkin.PAPER
const LOCKED := PixelSkin.MUTED
const STROKE := 4.0
const TITLE_SIZE := 72
const BUTTON_TEXT_SIZE := 36
const LEVEL_NUMBER_SIZE := 48

static var _font: FontFile


static func body_font() -> FontFile:
	return font()


static func font() -> FontFile:
	if _font == null:
		_font = load("res://assets/fonts/fusion-pixel-12px-proportional-zh_tw.ttf")
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_font.hinting = TextServer.HINTING_NONE
	return _font


static func pixel_size(value: int) -> int:
	return maxi(24, roundi(value / 12.0) * 12)


static func focus_when_visible(instance_id: int) -> void:
	# A scene can be left before its deferred initial focus runs.
	var control := instance_from_id(instance_id) as Control
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()


static func theme() -> Theme:
	var result := Theme.new()
	result.default_font = font()
	result.default_font_size = 24
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		result.set_stylebox(state, "Button", PixelSkin.box(state))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.set_color(key, "Button", INK)
	result.set_color("font_color", "Label", INK)
	result.set_color("font_shadow_color", "Label", PixelSkin.OUTLINE)
	result.set_constant("shadow_offset_x", "Label", 2)
	result.set_constant("shadow_offset_y", "Label", 2)
	result.set_stylebox("panel", "PanelContainer", PixelSkin.box("panel"))
	result.set_stylebox("panel", "TooltipPanel", PixelSkin.box("panel"))
	result.set_font_size("font_size", "TooltipLabel", 24)
	result.set_color("font_color", "TooltipLabel", INK)
	return result


static func add_background(host: Control) -> void:
	var bg := preload("res://scripts/pixel_backdrop.gd").new()
	bg.name = "Background"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.08, 0.1, 0.38)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(shade)


static func mount(host: Control) -> Control:
	host.theme = theme()
	host.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_background(host)
	var stage := Control.new()
	stage.name = "Stage"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(stage)
	return stage
