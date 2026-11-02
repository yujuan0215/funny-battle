extends Control

const PixelSkin := preload("res://scripts/pixel_skin.gd")
const MenuUi := preload("res://scripts/menu_ui.gd")
const Icons := preload("res://scripts/arena_icons.gd")

var host: Node = null
var tool := 0
var cool: Array[float] = [0.0, 0.0, 0.0]
var span: Array[float] = [1.0, 1.0, 1.0]
var _mark: Array[float] = [-1.0, -1.0, -1.0]
var _mark_tool := -1

const SLOT := 72.0
const GAP := 12.0



func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(SLOT * 3.0 + GAP * 2.0, SLOT)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	var index := int(mouse.position.x / (SLOT + GAP))
	if index < 0 or index > 2:
		return
	if host != null and host.has_method("pick_tool"):
		host.pick_tool(index)
	accept_event()


func sync(selected: int, remaining: Array[float], full: Array[float]) -> void:
	var changed := selected != _mark_tool
	for i in mini(remaining.size(), _mark.size()):
		if not is_equal_approx(_mark[i], remaining[i]):
			changed = true
			_mark[i] = remaining[i]
	if not changed:
		return
	_mark_tool = selected
	tool = selected
	cool = remaining
	span = full
	queue_redraw()


func _draw() -> void:
	for i in 3:
		var origin := Vector2(float(i) * (SLOT + GAP), 0.0)
		var box := Rect2(origin, Vector2(SLOT, SLOT))
		var hot := i == tool
		draw_style_box(PixelSkin.box("selected" if hot else "normal"), box)
		_draw_icon(i, origin + Vector2(SLOT, SLOT) * 0.5)
		var full := span[i] if i < span.size() else 1.0
		var left := cool[i] if i < cool.size() else 0.0
		if left > 0.0 and full > 0.0:
			_draw_cool(origin + Vector2(SLOT, SLOT) * 0.5, SLOT * 0.46, clampf(left / full, 0.0, 1.0))
		var font := MenuUi.font()
		if font != null:
			draw_string(font, origin + Vector2(10, 22), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PixelSkin.PAPER)


func _draw_icon(index: int, center: Vector2) -> void:
	Icons.paint(self, ["banana", "spring", "clock"][index], center - Vector2(0, 2), 36, PixelSkin.PAPER)


func _draw_cool(center: Vector2, radius: float, remain: float) -> void:
	for i in 8:
		draw_rect(Rect2(center + Vector2(-24 + i * 6, radius * 0.6), Vector2(4, 4)), PixelSkin.PAPER if i < ceili(remain * 8) else PixelSkin.OUTLINE)
