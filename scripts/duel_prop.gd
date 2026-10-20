class_name DuelProp
extends Node2D

var kind := "peel"
var wind := -1.0
var radius := 48.0
var ripe := false
var spent := false
var life := 2.4
var armed := true
var time_scale := 1.0


func _ready() -> void:
	if kind == "stop":
		z_index = 6
	elif kind == "spring":
		z_index = 2
	else:
		z_index = 1


func _process(delta: float) -> void:
	delta *= time_scale
	if kind == "stop":
		if wind > 0.0:
			wind -= delta
			if wind <= 0.0:
				wind = 0.0
				ripe = true
		queue_redraw()
		return
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()


func consume() -> void:
	armed = false
	if kind == "peel":
		life = minf(life, 0.35)
		return
	queue_free()


func _draw() -> void:
	if kind == "peel":
		var fade := 1.0 if life > 0.35 else clampf(life / 0.35, 0.0, 1.0)
		var peel := PackedVector2Array([
			Vector2(-28, 4), Vector2(24, -8), Vector2(18, 10), Vector2(-22, 14),
		])
		draw_colored_polygon(peel, Color(0.98, 0.84, 0.12, fade))
		draw_polyline(PackedVector2Array([peel[0], peel[1], peel[2], peel[3], peel[0]]), Color(0.08, 0.08, 0.08, fade), 3.0, true)
		return
	if kind == "spring":
		var ink := Color(0.08, 0.08, 0.08)
		draw_line(Vector2(-26, 10), Vector2(-13, -12), ink, 5.0)
		draw_line(Vector2(-13, -12), Vector2(0, 10), ink, 5.0)
		draw_line(Vector2(0, 10), Vector2(13, -12), ink, 5.0)
		draw_line(Vector2(13, -12), Vector2(26, 10), ink, 5.0)
		draw_line(Vector2(-30, 12), Vector2(30, 12), Color(0.35, 0.38, 0.42), 4.0)
		return
	var pulse := 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.012))
	var ink := Color(0.55, 0.82, 1.0, 0.18 + 0.2 * pulse)
	draw_arc(Vector2(0, 48), radius, 0.0, TAU, 48, ink, 3.0)
	draw_arc(Vector2(0, 48), radius * pulse, PI, TAU, 24, Color(0.75, 0.92, 1.0, 0.85), 4.0)
	draw_line(Vector2(0, 48 - radius), Vector2(0, 48 + radius * 0.35), Color(0.7, 0.9, 1.0, 0.5), 2.0)
