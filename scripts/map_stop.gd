extends Button
## A landmark on the route, not a generic full-card button.

const MenuUi := preload("res://scripts/menu_ui.gd")
const PixelSkin := preload("res://scripts/pixel_skin.gd")
const Thumbnail := preload("res://scripts/chapter_thumbnail.gd")
const Icons := preload("res://scripts/arena_icons.gd")
const Catalog := preload("res://scripts/campaign_catalog.gd")
var chapter: Dictionary
var cleared := false


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for event in [mouse_entered, mouse_exited, button_down, button_up, focus_entered, focus_exited]:
		event.connect(queue_redraw)
	var art := Thumbnail.new()
	art.environment = chapter["theme"]
	art.position = Vector2(56, 12)
	art.size = Vector2(104, 64)
	art.self_modulate = Color.WHITE if chapter["playable"] else Color(0.7, 0.7, 0.7)
	add_child(art)
	var title := Label.new()
	title.text = chapter["name"]
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.position = Vector2(0, 96)
	title.size = Vector2(216, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", MenuUi.body_font())
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", PixelSkin.PAPER)
	title.add_theme_color_override("font_shadow_color", PixelSkin.OUTLINE)
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	add_child(title)
	if cleared:
		var badge := Control.new()
		badge.name = "ClearedBadge"
		add_child(badge)


func _draw() -> void:
	var at := Vector2(size.x * 0.5, 44)
	var frame := Rect2(at - Vector2(64, 44), Vector2(128, 96))
	var style := "pressed" if button_pressed else "hover" if is_hovered() else "selected" if chapter["playable"] else "normal"
	draw_style_box(PixelSkin.box(style), frame)
	if has_focus():
		draw_style_box(PixelSkin.box("focus"), frame.grow(4))
	Icons.paint(self, "check" if cleared else "play" if chapter["playable"] else "lock", at + Vector2(64, 34), 24, PixelSkin.HERO if cleared else PixelSkin.PAPER)
	draw_string(MenuUi.font(), at + Vector2(-82, 42), str(chapter["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, PixelSkin.PAPER)
	var tools: Array = chapter["tools"]
	for i in tools.size():
		Icons.paint(self, Catalog.TOOL_ICONS[tools[i]], Vector2(size.x * 0.5 + (i - (tools.size() - 1) * 0.5) * 32, 150), 24, PixelSkin.PAPER)
