extends Node2D
## Original pixel silhouettes around the existing animated cast.
var chapter := 2
const DARK := Color("24323c")
const METAL := Color("7c8d94")
const BRASS := Color("c5a36a")

func _ready() -> void:
	z_index = 0

func _draw() -> void:
	match chapter:
		2:
			for side in [-1, 1]:
				var wing := PackedVector2Array()
				for at in [Vector2(28, -112), Vector2(100, -170), Vector2(85, -112), Vector2(116, -96), Vector2(72, -65), Vector2(25, -72)]:
					wing.append(Vector2(at.x * side, at.y))
				draw_colored_polygon(wing, Color("263b33"))
				for i in 3:
					draw_line(Vector2(side * 30, -98 + i * 7), Vector2(side * (88 - i * 7), -145 + i * 25), Color("8eac91"), 4)
		3:
			for side in [-1, 1]:
				preload("res://scripts/pixel_backdrop.gd")._gear(self, Vector2(side * 54, -112), 29, BRASS.darkened(0.3))
				draw_rect(Rect2(side * 58 - 17, -90, 34, 42), DARK)
				draw_rect(Rect2(side * 58 - 13, -84, 26, 7), BRASS)
		4:
			draw_rect(Rect2(-89, -111, 178, 64), Color("355867"))
			draw_rect(Rect2(-97, -96, 194, 26), Color("598b9b"))
			for side in [-1, 1]:
				for i in 3:
					var at := Vector2(side * (63 + i * 11), -45 + i * 9)
					draw_line(at, at + Vector2(side * 19, 14), METAL, 7)
					draw_line(at + Vector2(side * 19, 14), at + Vector2(side * 27, 30), Color("91c4ca"), 5)
		5:
			draw_rect(Rect2(-80, -126, 160, 90), Color("3b2921"))
			for side in [-1, 1]:
				draw_rect(Rect2(side * 64 - 10, -150, 20, 70), METAL.darkened(0.35))
				draw_rect(Rect2(side * 64 - 14, -150, 28, 8), BRASS)
				draw_circle(Vector2(side * 57, -29), 24, Color("33251e"))
				draw_arc(Vector2(side * 57, -29), 18, 0, TAU, 12, BRASS, 5)
		6:
			draw_colored_polygon(PackedVector2Array([Vector2(-42, -150), Vector2(42, -150), Vector2(90, -7), Vector2(50, -18), Vector2(21, -2), Vector2(-20, -14), Vector2(-83, -4)]), Color("4b355b"))
			for side in [-1, 1]:
				draw_line(Vector2(side * 34, -144), Vector2(side * 65, -18), BRASS.darkened(0.25), 4)
			draw_colored_polygon(PackedVector2Array([Vector2(-33, -192), Vector2(-37, -218), Vector2(-13, -203), Vector2(0, -229), Vector2(14, -203), Vector2(37, -218), Vector2(33, -192)]), BRASS)
			draw_rect(Rect2(-30, -193, 60, 7), Color("e6cc8b"))
