extends Control

const Backdrop := preload("res://scripts/pixel_backdrop.gd")
var environment := "forest"


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)


func _draw() -> void:
	Backdrop.paint(self, Rect2(Vector2.ZERO, size), environment)
