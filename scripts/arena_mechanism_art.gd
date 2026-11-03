extends RefCounted
## Shared arena cues, aligned with the encounter's real bounds and locked floor.

static func barrier(canvas: CanvasItem, edge: float, floor_y: float, side: int, stone: Color, rim: Color) -> void:
	var x := edge - 36 if side < 0 else edge
	var top := floor_y - 104
	canvas.draw_rect(Rect2(x - 4, top - 4, 44, 112), Color("191922"))
	canvas.draw_rect(Rect2(x, top, 36, 104), stone)
	for row in 4:
		canvas.draw_rect(Rect2(x + 3, top + 5 + row * 25, 30, 3), stone.lightened(.22))
		canvas.draw_rect(Rect2(x + 3, top + 24 + row * 25, 30, 3), stone.darkened(.32))
		canvas.draw_rect(Rect2(x + (12 if row % 2 == 0 else 23), top + 8 + row * 25, 3, 16), stone.darkened(.3))
	canvas.draw_rect(Rect2(x - 5, top - 8, 46, 12), rim.darkened(.28))
	canvas.draw_rect(Rect2(x - 5, top - 8, 46, 4), rim)
	canvas.draw_rect(Rect2(edge - 4 if side < 0 else edge, top + 6, 4, 94), rim.darkened(.15))
	canvas.draw_rect(Rect2(x - 6, floor_y - 10, 48, 14), stone.lightened(.15))

static func slam(canvas: CanvasItem, x: float, floor_y: float, remaining: float, duration: float, impact: float) -> void:
	if remaining <= 0 and impact <= 0:
		return
	var red := Color("ed7758")
	var gold := Color("dfb778")
	var progress := clampf(1.0 - remaining / maxf(duration, .001), 0.0, 1.0)
	var drop := clampf((progress - .76) / .24, 0.0, 1.0)
	var head_y := floor_y - 255 + progress * 45 + drop * 184
	if remaining <= 0:
		head_y = floor_y - 26
	var head := Vector2(x, floor(head_y / 2) * 2)
	canvas.draw_rect(Rect2(x - 64, floor_y - 9, 128, 14), Color(red, .35))
	canvas.draw_rect(Rect2(x - 64, floor_y - 9, 128, 14), red, false, 3)
	for beat in 3:
		canvas.draw_rect(Rect2(x - 42 + beat * 36, floor_y - 42, 12, 12), red if progress >= float(beat) / 3 else red.darkened(.6))
	canvas.draw_dashed_line(Vector2(x, floor_y - 190), Vector2(x, floor_y - 12), Color(red, .6), 2, 10)
	# A visible shaft and outlined metal head remain legible against all palettes.
	canvas.draw_rect(Rect2(x - 7, floor_y - 355, 14, maxf(12, head.y - (floor_y - 355))), Color("24222d"))
	canvas.draw_rect(Rect2(x - 3, floor_y - 355, 6, maxf(12, head.y - (floor_y - 355))), gold.darkened(.35))
	canvas.draw_rect(Rect2(head + Vector2(-48, -20), Vector2(96, 48)), Color("201d29"))
	canvas.draw_rect(Rect2(head + Vector2(-44, -16), Vector2(88, 40)), Color("665b70"))
	canvas.draw_rect(Rect2(head + Vector2(-44, -16), Vector2(88, 40)), gold, false, 3)
	canvas.draw_rect(Rect2(head + Vector2(-38, -10), Vector2(76, 6)), Color("b7afbd"))
	canvas.draw_rect(Rect2(head + Vector2(-38, 14), Vector2(76, 7)), Color("37313f"))
	for side in [-1, 1]:
		canvas.draw_rect(Rect2(head + Vector2(side * 32 - 3, 1), Vector2(6, 6)), gold)
	if impact > 0:
		var spread := (1.0 - impact / .24) * 40
		for side in [-1, 1]:
			canvas.draw_rect(Rect2(x + side * (52 + spread) - 8, floor_y - 18, 16, 6), gold)
			canvas.draw_rect(Rect2(x + side * (40 + spread) - 3, floor_y - 35, 6, 10), red)
