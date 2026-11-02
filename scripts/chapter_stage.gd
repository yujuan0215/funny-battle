extends "res://scripts/spike_stage.gd"
## Readable thematic arenas: mechanisms are drawn at their real interaction positions.
var arena: Node2D

func _ready() -> void:
	hazard_edges = false
	super._ready()

func support_at(_x: float, _feet_y: float) -> float:
	# Solid floor, including under the side barriers: no hidden fall trigger.
	return 500.0

func _draw_pit_and_bridge(view: Rect2) -> void:
	var colors := {"valley": Color("263d32"), "clock": Color("3b2c23"), "ice": Color("263c42"), "forge": Color("3a2921"), "tower": Color("2e203c")}
	var fill: Color = colors.get(chapter_theme, Color("302e39"))
	# A continuous, grounded arena foundation replaces the spike pit.
	draw_rect(Rect2(360, 500, 690, maxf(36, view.end.y - 500)), fill)
	for y in range(540, ceili(view.end.y), 30):
		draw_line(Vector2(360, y), Vector2(1050, y), fill.darkened(0.3), 3)
		for x in range(360 + (30 if y % 60 == 0 else 0), 1050, 60):
			draw_line(Vector2(x, y), Vector2(x, y + 30), fill.darkened(0.2), 2)
	for strip in strips:
		_draw_bridge(strip)
	for x in [360, 1050]:
		draw_rect(Rect2(x - 7, 458, 14, 42), fill.lightened(0.2))
		draw_rect(Rect2(x - 10, 458, 20, 6), fill.lightened(0.45))


func _draw() -> void:
	super._draw()
	if not is_instance_valid(arena):
		return
	var gold := Color("d9b577")
	var cyan := Color("b7d1ae") if chapter_theme == "valley" else Color("9ed8df")
	var red := Color("ed7758")
	var t: float = arena.world_time
	match chapter_theme:
		"valley":
			for side in [-1.0, 1.0]:
				var center := Vector2(385 if side < 0 else 1025, 350)
				var active: bool = arena.wind == side
				var metal := gold if active else cyan.darkened(0.5)
				draw_rect(Rect2(center + Vector2(-6, 22), Vector2(12, 128)), Color("344b55"))
				draw_arc(center, 47, 0, TAU, 24, metal.darkened(0.4), 4)
				for blade in 4:
					var angle: float = t * side * 4 + blade * PI / 2
					var end := (center + Vector2(cos(angle), sin(angle)) * 42).snapped(Vector2(3, 3))
					draw_line(center, end, metal, 7)
				draw_rect(Rect2(center - Vector2(8, 8), Vector2(16, 16)), metal.lightened(0.2))
			# Direction cues overlay the painted mills, without replacing the art.
			for i in 9:
				var x := 360 + fposmod(i * 89 + t * arena.wind * 90, 690)
				var y := 245 + (i % 3) * 40
				draw_line(Vector2(x, y), Vector2(x + arena.wind * 38, y), Color(cyan, 0.38), 2)
		"clock", "tower":
			if chapter_theme == "tower":
				for i in 3:
					ArenaHudIcon(self, "check" if i < arena.phase else "diamond", Vector2(673 + i * 32, 230), gold if i < arena.phase else red)
		"ice":
			draw_rect(Rect2(360, 496, 690, 8), cyan)
			for x in range(380, 1040, 54):
				draw_line(Vector2(x, 509), Vector2(x + 28, 503), Color(cyan, 0.4), 3)
			for i in 24:
				var at := Vector2(360 + fposmod(i * 71 + t * 9, 690), 220 + fposmod(i * 41 + t * 15, 250))
				draw_rect(Rect2(at.round(), Vector2(3, 3)), Color(cyan, 0.4))
		"forge":
			for i in 12:
				var at := Vector2(380 + fposmod(i * 79 + t * 7, 650), 490 - fposmod(i * 19 + t * 24, 210))
				draw_rect(Rect2(at.round(), Vector2(2, 3)), Color(red, 0.4))
	if arena.chapter_number >= 5:
		for y in [516, 526]:
			draw_line(Vector2(375, y), Vector2(1035, y), gold.darkened(0.45), 3)
		for x in range(384, 1030, 24):
			draw_line(Vector2(x, 513), Vector2(x, 529), Color("473939"), 4)
		var x: float = arena.crate_x
		draw_rect(Rect2(x - 24, 452, 48, 46), Color("45545b"))
		draw_rect(Rect2(x - 24, 452, 48, 46), cyan.darkened(0.3), false, 3)
		draw_line(Vector2(x - 20, 456), Vector2(x + 20, 494), cyan.darkened(0.25), 4)
		draw_line(Vector2(x + 20, 456), Vector2(x - 20, 494), cyan.darkened(0.25), 4)
		if arena.magnet_left > 0:
			ArenaHudIcon(self, "magnet", Vector2(arena.magnet_x, 475), cyan)
			draw_dashed_line(Vector2(x, 470), Vector2(arena.magnet_x, 470), Color(cyan, 0.6), 2, 8)
	for bag in arena.sandbags:
		var x: float = bag["x"]
		draw_rect(Rect2(x - 24, 479, 48, 20), Color("b99a6c"))
		draw_rect(Rect2(x - 19, 469, 38, 12), Color("d4b77e"))
		draw_line(Vector2(x - 16, 480), Vector2(x + 16, 480), Color("6b5143"), 3)
	if arena.slam_left > 0:
		var x: float = arena.slam_x
		var progress: float = 1 - arena.slam_left / arena.slam_duration
		draw_rect(Rect2(x - 64, 488, 128, 12), Color(red, 0.4))
		draw_rect(Rect2(x - 64, 488, 128, 12), red, false, 3)
		for i in 3:
			var at := Vector2(x - 36 + i * 36, 459)
			draw_rect(Rect2(at, Vector2(12, 12)), red if progress >= float(i) / 3 else red.darkened(0.6))
		var hammer := Vector2(x, 210 + progress * 90)
		draw_line(Vector2(x, 140), hammer, gold.darkened(0.5), 8)
		draw_rect(Rect2(hammer - Vector2(44, 12), Vector2(88, 38)), Color("5a5661"))
		draw_rect(Rect2(hammer - Vector2(44, 12), Vector2(88, 38)), gold, false, 3)
		draw_rect(Rect2(hammer - Vector2(38, 7), Vector2(76, 5)), Color("99929a"))
		draw_rect(Rect2(hammer + Vector2(-38, 16), Vector2(76, 7)), Color("373541"))
		for side in [-1, 1]:
			draw_rect(Rect2(hammer + Vector2(side * 32 - 2, 4), Vector2(5, 5)), gold)
		if arena.chapter_number == 6 and arena.phase == 2:
			for side in [-1, 1]:
				draw_rect(Rect2(x + side * 135 - 24, 491, 48, 6), Color(gold, 0.5))

func ArenaHudIcon(canvas: CanvasItem, symbol: String, at: Vector2, ink: Color) -> void:
	preload("res://scripts/arena_icons.gd").paint(canvas, symbol, at, 26, ink)
