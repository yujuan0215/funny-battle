extends Control
## Shared pixel pictograms for the HUD, tool cards, deployment and help.

const BANANA := preload("res://assets/props/banana.png")
const SPRING := preload("res://assets/props/spring.png")
const STOPWATCH := preload("res://assets/ui/icon_stopwatch.png")
const Pixels := preload("res://scripts/pixel_glyphs.gd")
var symbols := PackedStringArray()
var glyph_size := 32.0
var ink := Color(0.88, 0.96, 0.98)
var cooldown := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_symbols(Array(symbols))


func set_symbols(items: Array) -> void:
	var updated := PackedStringArray(items)
	if updated == symbols and is_node_ready():
		return
	symbols = updated
	custom_minimum_size = Vector2(maxf(0, symbols.size() * (glyph_size + 12) - 12), glyph_size)
	visible = not symbols.is_empty()
	queue_redraw()


func _draw() -> void:
	var width := symbols.size() * (glyph_size + 12) - 12
	var start := (size.x - width) * 0.5
	for i in symbols.size():
		paint(self, symbols[i], Vector2(start + glyph_size * 0.5 + i * (glyph_size + 12), size.y * 0.5), glyph_size, ink)
	if cooldown > 0 and symbols.size() == 1:
		for i in 8:
			var at := Vector2(size.x * 0.5 - 24 + i * 6, size.y - 2).round()
			draw_rect(Rect2(at, Vector2(4, 4)), Color("ffe5ae") if i < ceili(cooldown * 8) else Color("493334"))


static func paint(canvas: CanvasItem, kind: String, center: Vector2, span: float, color: Color) -> void:
	if Pixels.paint(canvas, kind, center, span, color):
		return
	var r := span * 0.43
	var line := maxf(2.0, span * 0.07)
	match kind:
		"heart", "emptyheart":
			var heart := PackedVector2Array()
			for p in [Vector2(0, 0.9), Vector2(-0.9, 0), Vector2(-0.94, -0.44), Vector2(-0.58, -0.78), Vector2(-0.22, -0.76), Vector2(0, -0.4), Vector2(0.22, -0.76), Vector2(0.58, -0.78), Vector2(0.94, -0.44), Vector2(0.9, 0)]:
				heart.append(center + p * r)
			if kind == "heart":
				canvas.draw_colored_polygon(heart, color)
			else:
				heart.append(heart[0])
				canvas.draw_polyline(heart, color, line, true)
				canvas.draw_line(center + Vector2(-0.3, 0.05) * r, center + Vector2(0.3, 0.05) * r, color, line)
		"boss":
			canvas.draw_circle(center + Vector2(0, -r * 0.15), r * 0.72, color)
			canvas.draw_rect(Rect2(center + Vector2(-r * 0.45, r * 0.28), Vector2(r * 0.9, r * 0.48)), color)
			for side in [-1, 1]:
				canvas.draw_circle(center + Vector2(side * r * 0.28, -r * 0.2), r * 0.16, Color(0.06, 0.09, 0.14))
		"banana":
			_paint_texture(canvas, BANANA, center, span * 1.3, color, Rect2(), Color(1, 0.84, 0.18))
		"spring":
			_paint_texture(canvas, SPRING, center, span * 1.2, color, Rect2(0, 20, 70, 50))
		"mouse":
			canvas.draw_style_box(_mouse_box(color, line), Rect2(center - Vector2(r * 0.6, r), Vector2(r * 1.2, r * 2)))
			canvas.draw_line(center + Vector2(0, -r * 0.7), center + Vector2(0, -r * 0.15), color, line)
		"diamond":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -r), center + Vector2(r * 0.7, 0), center + Vector2(0, r), center + Vector2(-r * 0.7, 0)]), color)
		"shield":
			var shield := PackedVector2Array()
			for p in [Vector2(-0.75, -0.75), Vector2(0.75, -0.75), Vector2(0.65, 0.3), Vector2(0, 0.95), Vector2(-0.65, 0.3), Vector2(-0.75, -0.75)]:
				shield.append(center + p * r)
			canvas.draw_polyline(shield, color, line, true)
			canvas.draw_line(center + Vector2(0, -r * 0.35), center + Vector2(0, r * 0.35), color, line)
			canvas.draw_line(center + Vector2(-r * 0.35, 0), center + Vector2(r * 0.35, 0), color, line)
		"lock":
			canvas.draw_rect(Rect2(center + Vector2(-r * 0.7, -r * 0.1), Vector2(r * 1.4, r)), color, false, line)
			canvas.draw_arc(center + Vector2(0, -r * 0.1), r * 0.45, PI, TAU, 8, color, line)
		"flask":
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-0.4, -0.9) * r, center + Vector2(-0.15, -0.9) * r, center + Vector2(-0.15, -0.2) * r, center + Vector2(-0.8, 0.8) * r, center + Vector2(0.8, 0.8) * r, center + Vector2(0.15, -0.2) * r, center + Vector2(0.15, -0.9) * r, center + Vector2(0.4, -0.9) * r]), color, line)
			canvas.draw_line(center + Vector2(-r * 0.55, r * 0.4), center + Vector2(r * 0.55, r * 0.4), color, line)
		"sound":
			canvas.draw_rect(Rect2(center + Vector2(-r * 0.8, -r * 0.3), Vector2(r * 0.5, r * 0.6)), color)
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-r * 0.4, -r * 0.3), center + Vector2(r * 0.2, -r * 0.8), center + Vector2(r * 0.2, r * 0.8), center + Vector2(-r * 0.4, r * 0.3)]), color)
			canvas.draw_arc(center, r * 0.85, -PI / 3, PI / 3, 8, color, line)
		"sandbag":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-0.45, -0.9) * r, center + Vector2(0.45, -0.9) * r, center + Vector2(0.25, -0.5) * r, center + Vector2(0.8, 0.65) * r, center + Vector2(0.5, 0.9) * r, center + Vector2(-0.5, 0.9) * r, center + Vector2(-0.8, 0.65) * r, center + Vector2(-0.25, -0.5) * r]), color)
		"magnet":
			canvas.draw_arc(center, r * 0.65, 0, PI, 10, color, line * 2)
			for side in [-1, 1]:
				canvas.draw_line(center + Vector2(side * r * 0.65, 0), center + Vector2(side * r * 0.65, -r * 0.8), color, line * 2)
		"clock":
			_paint_texture(canvas, STOPWATCH, center, span, color)
		"charge":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0.2, -1) * r, center + Vector2(-0.7, 0.15) * r, center + Vector2(-0.05, 0.15) * r, center + Vector2(-0.2, 1) * r, center + Vector2(0.75, -0.2) * r, center + Vector2(0.1, -0.2) * r]), color)
		"shot":
			canvas.draw_line(center + Vector2(-r, 0), center + Vector2(r * 0.8, 0), color, line * 1.7)
			canvas.draw_circle(center + Vector2(r * 0.7, 0), r * 0.19, color)
			canvas.draw_line(center + Vector2(-r * 0.6, -r * 0.35), center + Vector2(-r * 0.1, -r * 0.35), color, line)
		"strike":
			canvas.draw_line(center + Vector2(-r * 0.7, r * 0.7), center + Vector2(r * 0.7, -r * 0.7), color, line)
			canvas.draw_line(center + Vector2(-r * 0.7, -r * 0.7), center + Vector2(r * 0.7, r * 0.7), color, line)
			for side in [-1, 1]:
				canvas.draw_line(center + Vector2(side * r * 0.2, r * 0.65), center + Vector2(side * r * 0.65, r * 0.2), color, line)
		"spikes":
			for i in 3:
				var x := center.x - r + i * r * 0.67
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(x, center.y + r * 0.65), Vector2(x + r * 0.34, center.y - r * 0.6), Vector2(x + r * 0.67, center.y + r * 0.65)]), color)
		"cup":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-0.6, -0.85) * r, center + Vector2(0.6, -0.85) * r, center + Vector2(0.4, 0.25) * r, center + Vector2(-0.4, 0.25) * r]), color)
			canvas.draw_line(center, center + Vector2(0, r * 0.8), color, line)
			canvas.draw_line(center + Vector2(-r * 0.5, r * 0.85), center + Vector2(r * 0.5, r * 0.85), color, line)
			for side in [-1, 1]:
				canvas.draw_arc(center + Vector2(side * r * 0.48, -r * 0.45), r * 0.43, -PI * 0.5, PI * 0.5, 16, color, line)
		"check":
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-r * 0.8, 0), center + Vector2(-r * 0.2, r * 0.6), center + Vector2(r * 0.85, -r * 0.6)]), color, line * 1.3, true)
		"miss":
			canvas.draw_line(center + Vector2(-r * 0.7, -r * 0.7), center + Vector2(r * 0.7, r * 0.7), color, line)
			canvas.draw_line(center + Vector2(-r * 0.7, r * 0.7), center + Vector2(r * 0.7, -r * 0.7), color, line)
		"pause":
			for side in [-1, 1]:
				canvas.draw_rect(Rect2(center + Vector2(side * r * 0.4 - r * 0.12, -r * 0.8), Vector2(r * 0.24, r * 1.6)), color)
		"play":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-0.55, -0.85) * r, center + Vector2(-0.55, 0.85) * r, center + Vector2(0.85, 0) * r]), color)
		"retry":
			canvas.draw_arc(center, r * 0.8, -PI * 0.85, PI * 0.7, 28, color, line, true)
			var tip := center + Vector2(-r * 0.7, -r * 0.5)
			canvas.draw_colored_polygon(PackedVector2Array([tip + Vector2(-r * 0.2, -r * 0.3), tip + Vector2(r * 0.5, -r * 0.1), tip + Vector2(-r * 0.1, r * 0.4)]), color)
		"book":
			canvas.draw_rect(Rect2(center - Vector2(r * 0.85, r * 0.65), Vector2(r * 1.7, r * 1.3)), color, false, line)
			canvas.draw_line(center + Vector2(0, -r * 0.65), center + Vector2(0, r * 0.65), color, line)
		"levels":
			for i in 4:
				var at := center + Vector2(-r * 0.85 + (i % 2) * r, -r * 0.85 + int(i / 2.0) * r)
				canvas.draw_rect(Rect2(at, Vector2.ONE * r * 0.7), color, false, line)
		"slip":
			canvas.draw_circle(center + Vector2(r * 0.25, -r * 0.6), r * 0.2, color)
			canvas.draw_polyline(PackedVector2Array([center + Vector2(r * 0.15, -r * 0.3), center + Vector2(-r * 0.25, r * 0.1), center + Vector2(r * 0.45, r * 0.75)]), color, line, true)
			canvas.draw_line(center + Vector2(-r * 0.25, r * 0.1), center + Vector2(-r * 0.85, r * 0.55), color, line)
		"back", "left", "right", "exit", "rush":
			var dir := -1.0 if kind in ["back", "left", "exit"] else 1.0
			var tip := center + Vector2(dir * r * 0.8, 0)
			canvas.draw_line(center + Vector2(-dir * r * 0.8, 0), tip, color, line)
			canvas.draw_polyline(PackedVector2Array([tip + Vector2(-dir * r * 0.5, -r * 0.5), tip, tip + Vector2(-dir * r * 0.5, r * 0.5)]), color, line, true)
		"or":
			canvas.draw_line(center + Vector2(-r * 0.3, r * 0.7), center + Vector2(r * 0.3, -r * 0.7), color, line)
		_:
			canvas.draw_arc(center, r * 0.65, 0, TAU, 24, color, line)


static func _mouse_box(color: Color, line: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = color
	box.set_border_width_all(int(ceil(line)))
	box.set_corner_radius_all(8)
	return box


static func _paint_texture(canvas: CanvasItem, texture: Texture2D, center: Vector2, span: float, ink: Color, region := Rect2(), tint := Color.WHITE) -> void:
	if region.size == Vector2.ZERO:
		region = Rect2(Vector2.ZERO, texture.get_size())
	var drawn := region.size * (span / maxf(region.size.x, region.size.y))
	var brightness := maxf(ink.r, maxf(ink.g, ink.b))
	var modulate := Color(tint.r * brightness, tint.g * brightness, tint.b * brightness, ink.a)
	canvas.draw_texture_rect_region(texture, Rect2(center - drawn * 0.5, drawn), region, modulate)
