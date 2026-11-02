extends RefCounted
## Deployment cues are stamped on the same two-pixel grid as the HUD borders.
## Only the drawing snaps; placement positions and trigger radii stay exact.

const PixelSkin := preload("res://scripts/pixel_skin.gd")
const SPRING := preload("res://assets/props/spring.png")
const GRID := 2.0


static func _paint_cells(canvas: CanvasItem, cells: Array[Vector2i], ink: Color) -> void:
	var outline := Color(PixelSkin.OUTLINE, ink.a)
	for cell in cells:
		canvas.draw_rect(Rect2(Vector2(cell) * GRID - Vector2.ONE * GRID, Vector2.ONE * GRID * 3), outline)
	for cell in cells:
		canvas.draw_rect(Rect2(Vector2(cell) * GRID, Vector2.ONE * GRID), ink)


static func line(canvas: CanvasItem, start: Vector2, end: Vector2, ink: Color, dashed: bool = false) -> void:
	var cell := Vector2i((start / GRID).round())
	var finish := Vector2i((end / GRID).round())
	var dx := absi(finish.x - cell.x)
	var dy := -absi(finish.y - cell.y)
	var sx := 1 if cell.x < finish.x else -1
	var sy := 1 if cell.y < finish.y else -1
	var error := dx + dy
	var index := 0
	var cells: Array[Vector2i] = []
	while true:
		if not dashed or index % 7 < 4:
			cells.append(cell)
		if cell == finish:
			break
		var twice := error * 2
		if twice >= dy:
			error += dy
			cell.x += sx
		if twice <= dx:
			error += dx
			cell.y += sy
		index += 1
	_paint_cells(canvas, cells, ink)


static func ellipse(canvas: CanvasItem, center: Vector2, radii: Vector2, ink: Color, fraction: float = 1.0) -> void:
	var cells: Array[Vector2i] = []
	var visited: Dictionary = {}
	var steps := maxi(12, ceili(TAU * maxf(radii.x, radii.y) / GRID))
	for i in range(ceili(steps * clampf(fraction, 0, 1)) + 1):
		var angle := TAU * i / steps - PI * 0.5
		var cell := Vector2i(((center + Vector2(cos(angle), sin(angle)) * radii) / GRID).round())
		if not visited.has(cell):
			visited[cell] = true
			cells.append(cell)
	_paint_cells(canvas, cells, ink)


static func footprint(canvas: CanvasItem, floor_at: Vector2, radius: float, ink: Color) -> void:
	ellipse(canvas, floor_at, Vector2(radius, 8), ink)
	for side in [-1, 1]:
		var edge := floor_at + Vector2(side * radius, 0)
		line(canvas, edge - Vector2(0, 4), edge + Vector2(0, 4), PixelSkin.PAPER)


static func target(canvas: CanvasItem, center: Vector2, radius: float, ink: Color) -> void:
	for x in [-1, 1]:
		for y in [-1, 1]:
			var corner := center + Vector2(x, y) * radius
			line(canvas, corner + Vector2(-x * 8, 0), corner, ink)
			line(canvas, corner, corner + Vector2(0, -y * 8), ink)


static func arrow(canvas: CanvasItem, start: Vector2, end: Vector2, ink: Color) -> void:
	line(canvas, start, end, ink, true)
	var direction := (end - start).normalized()
	var wing := direction.orthogonal() * 8
	line(canvas, end - direction * 12 + wing, end, ink)
	line(canvas, end, end - direction * 12 - wing, ink)


static func spring(canvas: CanvasItem, spot: Vector2, available: bool) -> void:
	draw_spring(canvas, spot, Color(1, 1, 1, 0.9 if available else 0.4))


static func draw_spring(canvas: CanvasItem, spot: Vector2, tint: Color) -> void:
	var extent := SPRING.get_size() * 2
	canvas.draw_texture_rect(SPRING, Rect2((spot + Vector2(-extent.x * 0.5, 18 - extent.y)).round(), extent), false, tint)
