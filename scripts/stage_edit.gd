class_name StageEdit
extends Node2D

const THICK := 36.0
const MIN_SPAN := 64.0
const Y_MIN := 120.0
const Y_MAX := 640.0

var editing := false
var strips: Array[Dictionary] = []

var _selected := -1
var _drag := ""
var _drag_index := -1
var _grab := Vector2.ZERO
var _paint_from := Vector2.ZERO
var _paint_to := Vector2.ZERO


func _ready() -> void:
	z_index = -1
	strips = [
		{"x0": 70.0, "x1": 440.0, "y0": 312.0, "y1": 274.0, "tilt": true},
		{"x0": 840.0, "x1": 1230.0, "y0": 258.0, "y1": 294.0, "tilt": true},
		{"x0": 30.0, "x1": 1250.0, "y0": 552.0, "y1": 528.0, "tilt": true},
	]
	queue_redraw()


func support_at(x: float, feet_y: float) -> float:
	var below := INF
	var found := false
	var step_y := 0.0
	var step_gap := 9999.0
	var have_step := false
	for strip in strips:
		var top := _top(strip, x)
		if is_nan(top):
			continue
		if top >= feet_y - 18.0:
			if top < below:
				below = top
				found = true
		else:
			var gap := feet_y - top
			if gap < step_gap:
				step_gap = gap
				step_y = top
				have_step = true
	if found:
		return below
	if have_step and step_gap <= 48.0:
		return step_y
	return 980.0


func press(at: Vector2, erase: bool) -> bool:
	if not editing:
		return false
	if erase:
		var hit := _strip_at(at)
		if hit >= 0:
			strips.remove_at(hit)
			if _selected == hit:
				_selected = -1
			elif _selected > hit:
				_selected -= 1
		_drag = ""
		queue_redraw()
		return true
	var handle := _handle_at(at)
	if not handle.is_empty():
		_drag = str(handle["side"])
		_drag_index = int(handle["index"])
		_selected = _drag_index
		queue_redraw()
		return true
	var label := _label_at(at)
	if label >= 0:
		_selected = label
		_toggle_index(label)
		_drag = ""
		queue_redraw()
		return true
	var body := _strip_at(at)
	if body >= 0:
		_drag = "body"
		_drag_index = body
		_selected = body
		_grab = at
		queue_redraw()
		return true
	_drag = "paint"
	_paint_from = at
	_paint_to = at
	_drag_index = -1
	queue_redraw()
	return true


func drag(at: Vector2) -> void:
	if _drag == "paint":
		_paint_to = at
		queue_redraw()
		return
	if _drag_index < 0 or _drag_index >= strips.size():
		return
	var strip: Dictionary = strips[_drag_index]
	if _drag == "left" or _drag == "right":
		var y := clampf(at.y, Y_MIN, Y_MAX)
		if bool(strip["tilt"]):
			strip["y0" if _drag == "left" else "y1"] = y
		else:
			strip["y0"] = y
			strip["y1"] = y
	elif _drag == "body":
		var delta := at - _grab
		_grab = at
		var x0 := float(strip["x0"]) + delta.x
		var x1 := float(strip["x1"]) + delta.x
		if x0 < 0.0:
			x1 -= x0
			x0 = 0.0
		if x1 > 1280.0:
			x0 -= x1 - 1280.0
			x1 = 1280.0
		strip["x0"] = x0
		strip["x1"] = x1
		strip["y0"] = clampf(float(strip["y0"]) + delta.y, Y_MIN, Y_MAX)
		strip["y1"] = clampf(float(strip["y1"]) + delta.y, Y_MIN, Y_MAX)
	strips[_drag_index] = strip
	queue_redraw()


func release() -> void:
	if _drag == "paint":
		var x0 := minf(_paint_from.x, _paint_to.x)
		var x1 := maxf(_paint_from.x, _paint_to.x)
		if x1 - x0 >= MIN_SPAN:
			var y := clampf(_paint_from.y, Y_MIN, Y_MAX)
			strips.append({
				"x0": clampf(x0, 0.0, 1280.0),
				"x1": clampf(x1, 0.0, 1280.0),
				"y0": y,
				"y1": y,
				"tilt": false,
			})
			_selected = strips.size() - 1
		else:
			_selected = -1
	_drag = ""
	_drag_index = -1
	queue_redraw()


func toggle_tilt() -> void:
	if not editing or _selected < 0 or _selected >= strips.size():
		return
	_toggle_index(_selected)
	queue_redraw()


func _toggle_index(index: int) -> void:
	var strip: Dictionary = strips[index]
	strip["tilt"] = not bool(strip["tilt"])
	if not bool(strip["tilt"]):
		var mid := (float(strip["y0"]) + float(strip["y1"])) * 0.5
		strip["y0"] = mid
		strip["y1"] = mid
	strips[index] = strip


func _top(strip: Dictionary, x: float) -> float:
	var x0 := float(strip["x0"])
	var x1 := float(strip["x1"])
	if x < x0 or x > x1 or x1 - x0 < 1.0:
		return NAN
	return lerpf(float(strip["y0"]), float(strip["y1"]), (x - x0) / (x1 - x0))


func _quad(strip: Dictionary) -> PackedVector2Array:
	var y0 := float(strip["y0"])
	var y1 := float(strip["y1"])
	return PackedVector2Array([
		Vector2(float(strip["x0"]), y0),
		Vector2(float(strip["x1"]), y1),
		Vector2(float(strip["x1"]), y1 + THICK),
		Vector2(float(strip["x0"]), y0 + THICK),
	])


func _strip_at(at: Vector2) -> int:
	for i in range(strips.size() - 1, -1, -1):
		if Geometry2D.is_point_in_polygon(at, _quad(strips[i])):
			return i
	return -1


func _handle_at(at: Vector2) -> Dictionary:
	var best := {}
	var dist := 16.0
	for i in range(strips.size() - 1, -1, -1):
		if not bool(strips[i]["tilt"]):
			continue
		var left := Vector2(float(strips[i]["x0"]), float(strips[i]["y0"]))
		var right := Vector2(float(strips[i]["x1"]), float(strips[i]["y1"]))
		if left.distance_to(at) < dist:
			dist = left.distance_to(at)
			best = {"index": i, "side": "left"}
		if right.distance_to(at) < dist:
			dist = right.distance_to(at)
			best = {"index": i, "side": "right"}
	return best


func _label_rect(strip: Dictionary) -> Rect2:
	var mid_x := (float(strip["x0"]) + float(strip["x1"])) * 0.5
	var top := minf(float(strip["y0"]), float(strip["y1"]))
	return Rect2(mid_x - 40.0, top - 36.0, 80.0, 22.0)


func _label_at(at: Vector2) -> int:
	for i in range(strips.size() - 1, -1, -1):
		if _label_rect(strips[i]).has_point(at):
			return i
	return -1


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.07, 0.08, 0.12))
	for i in strips.size():
		_draw_strip(strips[i], i == _selected)
	if _drag == "paint":
		var ghost := {
			"x0": minf(_paint_from.x, _paint_to.x),
			"x1": maxf(_paint_from.x, _paint_to.x),
			"y0": _paint_from.y,
			"y1": _paint_from.y,
		}
		if float(ghost["x1"]) - float(ghost["x0"]) >= 8.0:
			draw_colored_polygon(_quad(ghost), Color(1, 1, 1, 0.35))


func _draw_strip(strip: Dictionary, selected: bool) -> void:
	var quad := _quad(strip)
	draw_colored_polygon(quad, Color(0.97, 0.96, 0.94))
	var ink := Color(0.85, 0.28, 0.2) if selected else Color(0.08, 0.08, 0.08)
	var loop := PackedVector2Array()
	for point in quad:
		loop.append(point)
	loop.append(quad[0])
	draw_polyline(loop, ink, 6.0 if selected else 5.0, true)
	if not editing:
		return
	if bool(strip["tilt"]):
		_draw_handle(Vector2(float(strip["x0"]), float(strip["y0"])))
		_draw_handle(Vector2(float(strip["x1"]), float(strip["y1"])))
	var font := ThemeDB.fallback_font
	var box := _label_rect(strip)
	draw_rect(box, Color(0.12, 0.12, 0.14, 0.92))
	if font == null:
		return
	var caption := "傾斜" if bool(strip["tilt"]) else "水平"
	var color := Color(1.0, 0.78, 0.35) if bool(strip["tilt"]) else Color(0.82, 0.84, 0.88)
	draw_string(font, box.position + Vector2(16, 16), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)


func _draw_handle(at: Vector2) -> void:
	draw_rect(Rect2(at - Vector2(7, 7), Vector2(14, 14)), Color(0.98, 0.84, 0.3))
	draw_rect(Rect2(at - Vector2(7, 7), Vector2(14, 14)), Color(0.08, 0.08, 0.08), false, 2.0)
