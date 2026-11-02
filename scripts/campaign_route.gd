extends Control

const PixelSkin := preload("res://scripts/pixel_skin.gd")
const STOPS: Array[Vector2] = [Vector2(0.14, 0.23), Vector2(0.5, 0.23), Vector2(0.86, 0.23), Vector2(0.86, 0.72), Vector2(0.5, 0.72), Vector2(0.14, 0.72)]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	for index in range(STOPS.size() - 1):
		var from := STOPS[index] * size
		var to := STOPS[index + 1] * size
		var distance := from.distance_to(to)
		var stones := maxi(1, int(distance / 16))
		for i in range(stones + 1):
			var at := from.lerp(to, float(i) / stones).snapped(Vector2(4, 4))
			draw_rect(Rect2(at - Vector2(8, 4), Vector2(16, 12)), PixelSkin.OUTLINE)
			draw_rect(Rect2(at - Vector2(6, 4), Vector2(12, 6)), PixelSkin.BRASS.darkened(0.25 if i % 2 else 0.1))
