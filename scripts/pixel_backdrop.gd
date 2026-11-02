extends Control
## Deterministic pixel blockouts for chapter previews, with one approved seed backdrop.

@export var environment := "forest"
static var forest: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)


func _draw() -> void:
	paint(self, Rect2(Vector2.ZERO, size), environment)


static func paint(canvas: CanvasItem, rect: Rect2, theme: String) -> void:
	if theme.begins_with("forest"):
		if forest == null and ResourceLoader.exists("res://assets/environments/forest-outpost.png"):
			forest = load("res://assets/environments/forest-outpost.png")
		if forest != null:
			var source := forest.get_size()
			if theme == "forest_arena":
				source.y *= 0.7
			var factor := maxf(rect.size.x / source.x, rect.size.y / source.y)
			var crop := rect.size / factor
			canvas.draw_texture_rect_region(forest, rect, Rect2((source - crop) * 0.5, crop))
			if theme == "forest_arena":
				canvas.draw_rect(rect, Color(0.03, 0.08, 0.1, 0.25))
			return
	var palette := _palette(theme)
	canvas.draw_set_transform(rect.position, 0, rect.size / Vector2(320, 180))
	canvas.draw_rect(Rect2(0, 0, 320, 180), palette[0])
	for layer in 3:
		var color: Color = palette[1 + layer]
		var base := 74.0 + layer * 24
		for i in 12:
			var x := i * 32.0 - 20
			var h := 20.0 + fposmod(i * 23.0 + layer * 31, 54)
			if theme == "forest":
				canvas.draw_rect(Rect2(x + 12, base - h, 4, 180), color)
				for branch in 3:
					var y := base - h + branch * 10
					canvas.draw_colored_polygon(PackedVector2Array([Vector2(x + 14, y - 20), Vector2(x - 4 - branch * 3, y + 18), Vector2(x + 32 + branch * 3, y + 18)]), color)
			elif theme == "valley":
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 18, 180), Vector2(x, base - h), Vector2(x + 12, base - h), Vector2(x + 50, 180)]), color)
			elif theme == "clock" or theme == "tower":
				canvas.draw_rect(Rect2(x + 2, base - h, 20, 180), color)
				canvas.draw_rect(Rect2(x - 2, base - h, 28, 6), color)
				if i % 3 == 0:
					canvas.draw_rect(Rect2(x + 8, base - h - 20, 8, 20), color)
			elif theme == "ice":
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 8, 180), Vector2(x + 2, base - h), Vector2(x + 14, base - h - 8), Vector2(x + 36, 180)]), color)
			else:
				canvas.draw_rect(Rect2(x + 4, base - h, 12, 180), color)
				canvas.draw_rect(Rect2(x, base - h, 20, 6), color)
	var accent: Color = palette[4]
	match theme:
		"valley":
			for x in [64, 244]:
				canvas.draw_rect(Rect2(x - 4, 55, 8, 70), palette[3])
				canvas.draw_rect(Rect2(x - 30, 65, 60, 4), accent)
				canvas.draw_rect(Rect2(x - 2, 38, 4, 58), accent)
			for y in [98, 120, 142]:
				canvas.draw_rect(Rect2(118, y, 50, 2), accent.darkened(0.4))
		"clock":
			_gear(canvas, Vector2(76, 82), 28, accent)
			_gear(canvas, Vector2(246, 50), 36, accent.darkened(0.3))
		"ice":
			for i in 22:
				canvas.draw_rect(Rect2(fposmod(i * 53, 320), fposmod(i * 37, 140), 2, 2), accent)
			canvas.draw_rect(Rect2(0, 144, 320, 4), accent.darkened(0.4))
		"forge":
			for x in [36, 110, 254]:
				canvas.draw_rect(Rect2(x, 60, 14, 34), accent)
			canvas.draw_rect(Rect2(0, 148, 320, 8), accent)
		"tower":
			canvas.draw_rect(Rect2(132, 28, 56, 128), palette[3])
			canvas.draw_rect(Rect2(124, 28, 72, 12), accent)
			_gear(canvas, Vector2(160, 76), 22, accent)
			canvas.draw_rect(Rect2(154, 72, 12, 12), palette[0])
		_:
			for x in [58, 250]:
				canvas.draw_rect(Rect2(x, 100, 4, 24), palette[3])
				canvas.draw_rect(Rect2(x - 2, 104, 8, 8), accent)
	canvas.draw_rect(Rect2(0, 166, 320, 14), palette[0])
	canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


static func _gear(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var angle := TAU * i / 32
		var extent := radius if i % 4 < 2 else radius * 0.78
		points.append((center + Vector2(cos(angle), sin(angle)) * extent).snapped(Vector2(2, 2)))
	canvas.draw_colored_polygon(points, color)
	canvas.draw_rect(Rect2(center - Vector2(7, 7), Vector2(14, 14)), Color("182930"))


static func _palette(theme: String) -> Array[Color]:
	match theme:
		"valley": return [Color("142b43"), Color("23445c"), Color("366379"), Color("1c3547"), Color("d4ba7d")]
		"clock": return [Color("241e2b"), Color("473041"), Color("6a4d48"), Color("352e37"), Color("c79b62")]
		"ice": return [Color("132b40"), Color("24495d"), Color("437284"), Color("285366"), Color("a1d3cf")]
		"forge": return [Color("291e2c"), Color("4e2c36"), Color("703b3d"), Color("382630"), Color("df935b")]
		"tower": return [Color("191e35"), Color("30314e"), Color("51465c"), Color("292a43"), Color("cba876")]
		_: return [Color("13252b"), Color("203b3d"), Color("31514b"), Color("1a3035"), Color("e4b66a")]
