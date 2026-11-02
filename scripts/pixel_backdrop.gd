extends Control
## Deterministic pixel blockouts for chapter previews, with one approved seed backdrop.

@export var environment := "forest"
static var forest: Texture2D
static var chapter_textures: Dictionary = {}
const CHAPTER_BACKGROUNDS := {
	"valley": "res://assets/environments/valley-arena-color-v2.png",
	"clock": "res://assets/environments/clock-arena-color-v2.png",
	"ice": "res://assets/environments/ice-arena-color-v2.png",
	"forge": "res://assets/environments/forge-arena-color-v2.png",
	"tower": "res://assets/environments/tower-arena-color-v2.png",
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)


func _draw() -> void:
	paint(self, Rect2(Vector2.ZERO, size), environment)


static func paint(canvas: CanvasItem, rect: Rect2, theme: String, arena: bool = false) -> void:
	if CHAPTER_BACKGROUNDS.has(theme) and ResourceLoader.exists(CHAPTER_BACKGROUNDS[theme]):
		if not chapter_textures.has(theme):
			chapter_textures[theme] = load(CHAPTER_BACKGROUNDS[theme])
		var texture: Texture2D = chapter_textures[theme]
		var source := texture.get_size()
		if arena:
			source.y *= 0.8
		var factor := maxf(rect.size.x / source.x, rect.size.y / source.y)
		var crop := rect.size / factor
		canvas.draw_texture_rect_region(texture, rect, Rect2((source - crop) * 0.5, crop))
		if arena:
			var shades := {"valley": Color(0.015, 0.045, 0.025, 0.18), "clock": Color(0.05, 0.03, 0.015, 0.18), "ice": Color(0.01, 0.035, 0.045, 0.18), "forge": Color(0.05, 0.025, 0.01, 0.18), "tower": Color(0.04, 0.015, 0.055, 0.18)}
			canvas.draw_rect(rect, shades[theme])
		return
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
	if theme in ["valley", "clock", "ice", "forge", "tower"]:
		paint_chapter(canvas, rect, theme)
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


static func paint_chapter(c: CanvasItem, rect: Rect2, theme: String) -> void:
	var p := _palette(theme)
	c.draw_set_transform(rect.position, 0, rect.size / Vector2(320, 180))
	for y in range(0, 180, 4):
		c.draw_rect(Rect2(0, y, 320, 4), p[0].lerp(p[1], float(y) / 300))
	# Distant ridges and tiny stars use a quieter contrast than the actors.
	for i in 42:
		var x := fposmod(i * 67, 320)
		var y := fposmod(i * 43, 95)
		c.draw_rect(Rect2(x, y, 1, 1), Color(p[4], 0.25))
	for layer in 3:
		var ink: Color = p[1].lerp(p[0], 0.6 - layer * 0.16)
		for i in 14:
			var x := i * 28.0 - 16
			var h := 24 + fposmod(i * 19 + layer * 31, 43)
			var y := 92 + layer * 20 - h
			if theme in ["valley", "ice"]:
				c.draw_colored_polygon(PackedVector2Array([Vector2(x - 22, 180), Vector2(x + 4, y), Vector2(x + 12, y - 5), Vector2(x + 46, 180)]), ink)
				for cut in 4:
					c.draw_rect(Rect2(x + cut * 3, y + 20 + cut * 13, 10, 2), ink.lightened(0.045))
			else:
				c.draw_rect(Rect2(x, y, 20, 180 - y), ink)
				c.draw_rect(Rect2(x - 2, y, 24, 3), ink.lightened(0.07))
				for floor in range(3, 64, 13):
					for wx in [4, 12]:
						c.draw_rect(Rect2(x + wx, y + floor + 5, 3, 6), p[4].darkened(0.63))
	if theme == "valley":
		for x in [42, 263]:
			c.draw_rect(Rect2(x - 3, 42, 6, 118), p[3])
			c.draw_colored_polygon(PackedVector2Array([Vector2(x - 20, 155), Vector2(x - 9, 76), Vector2(x + 9, 76), Vector2(x + 20, 155)]), p[2].darkened(0.4))
			for y in [91, 113, 135]:
				c.draw_rect(Rect2(x - 8, y, 16, 2), p[0])
			c.draw_rect(Rect2(x - 25, 63, 50, 3), p[4].darkened(0.4))
			c.draw_rect(Rect2(x - 1, 39, 3, 50), p[4].darkened(0.4))
			c.draw_rect(Rect2(x - 24, 59, 16, 5), p[4].darkened(0.5))
			c.draw_rect(Rect2(x + 8, 66, 16, 5), p[4].darkened(0.5))
		for y in [58, 88]:
			c.draw_line(Vector2(0, y), Vector2(320, y + 16), Color(p[4], 0.15), 1)
	elif theme in ["clock", "tower"]:
		for x in [38, 281]:
			c.draw_rect(Rect2(x - 17, 24, 34, 155), p[3])
			for y in range(28, 173, 9):
				c.draw_rect(Rect2(x - 15, y, 30, 1), p[2].darkened(0.4))
				c.draw_rect(Rect2(x - 2 + (4 if y % 2 else -4), y, 1, 9), p[0])
			c.draw_rect(Rect2(x - 20, 23, 40, 4), p[2].darkened(0.2))
			c.draw_rect(Rect2(x - 20, 157, 40, 6), p[2].darkened(0.2))
		for x in [81, 241]:
			_gear(c, Vector2(x, 60), 17, p[4].darkened(0.6))
			c.draw_arc(Vector2(x, 60), 10, 0, TAU, 16, p[0], 3)
			c.draw_line(Vector2(x, 42), Vector2(x, 9), p[4].darkened(0.6), 1)
		if theme == "tower":
			c.draw_rect(Rect2(139, 18, 42, 118), p[3])
			for side in [-1, 1]:
				c.draw_rect(Rect2(160 + side * 25 - 7, 32, 14, 52), Color("4b355b"))
				c.draw_rect(Rect2(160 + side * 25 - 7, 32, 14, 3), p[4].darkened(0.25))
			c.draw_arc(Vector2(160, 70), 16, PI, TAU, 14, p[4].darkened(0.5), 3)
	else:
		for x in [32, 276]:
			c.draw_rect(Rect2(x - 17, 83, 38, 65), p[3])
			c.draw_rect(Rect2(x - 20, 81, 44, 4), p[2])
			for y in range(89, 145, 7):
				c.draw_rect(Rect2(x - 16, y, 36, 1), p[0])
			if theme == "forge":
				c.draw_rect(Rect2(x - 12, 97, 26, 26), p[4].darkened(0.25))
				for bar in range(0, 26, 5):
					c.draw_rect(Rect2(x - 12, 97 + bar, 26, 2), p[3])
				c.draw_rect(Rect2(x - 7, 37, 12, 46), p[2].darkened(0.3))
				for y in range(39, 80, 10):
					c.draw_rect(Rect2(x - 10, y, 18, 3), p[3])
			else:
				for box in range(3):
					c.draw_rect(Rect2(x - 14 + box * 10, 104 - box * 8, 15, 18), p[2].darkened(0.1 + box * 0.12))
					c.draw_rect(Rect2(x - 14 + box * 10, 104 - box * 8, 15, 2), p[4].darkened(0.2))
		if theme == "ice":
			for i in 28:
				c.draw_rect(Rect2(fposmod(i * 61, 320), fposmod(i * 37, 145), 1, 1), Color(p[4], 0.4))
	# Ground-facing scenery remains dark so telegraphs and props stay distinct.
	c.draw_rect(Rect2(0, 145, 320, 35), Color(p[0], 0.6))
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
