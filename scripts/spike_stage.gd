extends "res://scripts/stage_edit.gd"
## Same editable strips as the original stage, above a fixed spike pit.

const SPIKE_Y := 578.0
const PixelBackdrop := preload("res://scripts/pixel_backdrop.gd")
var chapter_theme := "test"


func _ready() -> void:
	super._ready()
	strips = [{"x0": 360.0, "x1": 1050.0, "y0": 500.0, "y1": 500.0, "tilt": false}]
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if editing:
		super._draw()
		return
	# Cover the expanded camera view too (4:3 and ultrawide have extra world space).
	var view := (get_canvas_transform().affine_inverse() * get_viewport_rect()).grow(96)
	if chapter_theme != "test":
		PixelBackdrop.paint(self, view, chapter_theme)
	else:
		_draw_test_background(view)
	_draw_pit_and_bridge(view)


func _draw_test_background(view: Rect2) -> void:
	for i in 32:
		var t := i / 31.0
		var color := Color(0.025, 0.045, 0.075).lerp(Color(0.10, 0.16, 0.19), sin(t * PI) * 0.7)
		draw_rect(Rect2(view.position + Vector2(0, view.size.y * i / 32), Vector2(view.size.x, view.size.y / 32 + 1)), color)
	# Distant broken supports provide depth without competing with the actors.
	for i in range(floori(view.position.x / 180), ceili(view.end.x / 180) + 1):
		var x := i * 180.0
		var top := 290 + sin(i * 2.3) * 80
		draw_rect(Rect2(x, top, 64, maxf(1, view.end.y - top)), Color(0.07, 0.11, 0.14, 0.65))
		draw_line(Vector2(x, top), Vector2(x + 64, top), Color(0.15, 0.24, 0.26, 0.35), 2)
	for y in [382, 422, 468]:
		draw_line(Vector2(view.position.x, y), Vector2(view.end.x, y), Color(0.20, 0.36, 0.37, 0.07), 18)


func _draw_pit_and_bridge(view: Rect2) -> void:
	draw_rect(Rect2(view.position.x, SPIKE_Y + 22, view.size.x, maxf(1, view.end.y - SPIKE_Y)), Color(0.025, 0.035, 0.05))
	for x in range(floori(view.position.x / 32) * 32, ceili(view.end.x / 32) * 32, 32):
		var points := PackedVector2Array([
			Vector2(x, SPIKE_Y + 24), Vector2(x + 16, SPIKE_Y), Vector2(x + 32, SPIKE_Y + 24),
		])
		draw_colored_polygon(points, Color(0.22, 0.29, 0.34))
		draw_line(points[0], points[1], Color(0.65, 0.42, 0.34), 2.0)
		draw_line(points[1] + Vector2(-4, 6), points[1], Color(1.0, 0.52, 0.33), 2.0)
	for strip in strips:
		_draw_bridge(strip)


func _draw_bridge(strip: Dictionary) -> void:
	var a := Vector2(float(strip["x0"]), float(strip["y0"]))
	var b := Vector2(float(strip["x1"]), float(strip["y1"]))
	draw_colored_polygon(_quad(strip), Color("624b3d") if chapter_theme.begins_with("forest") else Color(0.13, 0.19, 0.23))
	draw_line(a + Vector2(0, THICK), b + Vector2(0, THICK), Color(0.035, 0.06, 0.08), 6)
	for x in range(int(a.x) + 24, int(b.x), 48):
		var top := _top(strip, x)
		draw_line(Vector2(x, top + 7), Vector2(x, top + THICK - 3), Color(0.055, 0.09, 0.12), 2)
		draw_circle(Vector2(x - 9, top + 11), 2, Color(0.36, 0.46, 0.49))
	draw_line(a, b, Color("ba9863") if chapter_theme.begins_with("forest") else Color(0.55, 0.72, 0.72), 4)
	draw_line(a + Vector2(0, 5), b + Vector2(0, 5), Color(0.25, 0.42, 0.45), 2)
	# Lit edge caps communicate danger at both physical ends of the bridge.
	for at in [a, b]:
		draw_line(at + Vector2(0, -2), at + Vector2(0, THICK), Color(0.97, 0.60, 0.30), 4)
		draw_line(at + Vector2(-10, -2), at + Vector2(10, -2), Color(1.0, 0.78, 0.4), 4)
