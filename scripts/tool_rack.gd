extends Control

var host: Node = null
var tool := 0
var cool: Array[float] = [0.0, 0.0, 0.0]
var span: Array[float] = [1.0, 1.0, 1.0]
var _mark: Array[float] = [-1.0, -1.0, -1.0]
var _mark_tool := -1

const SLOT := 72.0
const GAP := 12.0


func _ready() -> void:
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
		draw_rect(box, Color(0.14, 0.15, 0.2), true)
		draw_rect(box, Color(0.96, 0.9, 0.55) if hot else Color(0.45, 0.46, 0.52), false, 3.0)
		_draw_icon(i, origin + Vector2(SLOT, SLOT) * 0.5)
		var full := span[i] if i < span.size() else 1.0
		var left := cool[i] if i < cool.size() else 0.0
		if left > 0.0 and full > 0.0:
			_draw_cool(origin + Vector2(SLOT, SLOT) * 0.5, SLOT * 0.46, clampf(left / full, 0.0, 1.0))
		var font := ThemeDB.fallback_font
		if font != null:
			draw_string(font, origin + Vector2(6, 20), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.9, 0.92))


func _draw_icon(index: int, center: Vector2) -> void:
	if index == 0:
		var peel := PackedVector2Array([
			center + Vector2(-18, 4),
			center + Vector2(16, -8),
			center + Vector2(12, 8),
			center + Vector2(-14, 12),
		])
		draw_colored_polygon(peel, Color(0.98, 0.84, 0.12))
		draw_polyline(PackedVector2Array([peel[0], peel[1], peel[2], peel[3], peel[0]]), Color(0.1, 0.1, 0.1), 2.0, true)
		return
	if index == 1:
		var ink := Color(0.86, 0.88, 0.92)
		draw_line(center + Vector2(-16, 8), center + Vector2(-8, -10), ink, 3.0)
		draw_line(center + Vector2(-8, -10), center + Vector2(0, 8), ink, 3.0)
		draw_line(center + Vector2(0, 8), center + Vector2(8, -10), ink, 3.0)
		draw_line(center + Vector2(8, -10), center + Vector2(16, 8), ink, 3.0)
		draw_line(center + Vector2(-18, 12), center + Vector2(18, 12), Color(0.45, 0.48, 0.54), 3.0)
		return
	draw_arc(center, 16.0, 0.0, TAU, 24, Color(0.55, 0.82, 1.0, 0.9), 3.0)
	draw_arc(center, 8.0, PI, TAU, 12, Color(0.8, 0.93, 1.0), 3.0)


func _draw_cool(center: Vector2, radius: float, remain: float) -> void:
	var steps := maxi(int(round(24.0 * remain)), 3)
	var start := -PI * 0.5
	var sweep := TAU * remain
	var wedge := PackedVector2Array()
	wedge.append(center)
	for i in steps + 1:
		var ang := start + sweep * float(i) / float(steps)
		wedge.append(center + Vector2(cos(ang), sin(ang)) * radius)
	draw_colored_polygon(wedge, Color(0.04, 0.05, 0.08, 0.72))
	draw_arc(center, radius, start, start + sweep, steps, Color(1, 1, 1, 0.55), 2.0)
