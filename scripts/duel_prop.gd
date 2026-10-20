class_name DuelProp
extends Node2D

signal burst(prop: DuelProp)

var kind := "peel"
var fuse := 0.85
var boom := -1.0
var spent := false
var life := 2.4
var armed := true


func _ready() -> void:
	z_index = 4 if kind == "bomb" else 1


func _process(delta: float) -> void:
	if kind == "peel":
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		queue_redraw()
		return
	if kind == "bomb" and not spent:
		fuse -= delta
		if fuse <= 0.0:
			spent = true
			boom = 0.22
			z_index = 7
			burst.emit(self)
	elif boom >= 0.0:
		boom -= delta
		if boom <= 0.0:
			queue_free()
			return
	queue_redraw()


func consume() -> void:
	armed = false
	life = minf(life, 0.8)


func _draw() -> void:
	if kind == "peel":
		var fade := 1.0 if life > 0.35 else clampf(life / 0.35, 0.0, 1.0)
		var peel := PackedVector2Array([
			Vector2(-28, 4), Vector2(24, -8), Vector2(18, 10), Vector2(-22, 14),
		])
		draw_colored_polygon(peel, Color(0.98, 0.84, 0.12, fade))
		draw_polyline(PackedVector2Array([peel[0], peel[1], peel[2], peel[3], peel[0]]), Color(0.08, 0.08, 0.08, fade), 3.0, true)
		return
	if boom >= 0.0:
		var t := 1.0 - boom / 0.22
		draw_arc(Vector2.ZERO, lerpf(20.0, 120.0, t), 0.0, TAU, 40, Color(1, 0.45, 0.12, 1.0 - t), 8.0)
		return
	var pulse := 1.0 + 0.12 * sin(fuse * 34.0)
	draw_circle(Vector2.ZERO, 20.0 * pulse, Color(0.08, 0.08, 0.08))
	var hot := Color(0.92, 0.18, 0.12).lerp(Color(1, 0.85, 0.2), clampf(1.0 - fuse / 0.85, 0.0, 1.0))
	draw_circle(Vector2.ZERO, 14.0 * pulse, hot)
	draw_line(Vector2(0, -16), Vector2(8, -30), Color(0.08, 0.08, 0.08), 3.0)
