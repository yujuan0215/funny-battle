class_name DuelProp
extends Node2D

const BANANA_WIDTH := 64.0
const Placement := preload("res://scripts/pixel_placement.gd")
const BANANA_TEXTURE := preload("res://assets/props/banana.png")
var kind := "peel"
var wind := -1.0
var radius := 48.0
var ripe := false
var spent := false
var life := 2.4
var armed := true
var time_scale := 1.0
var retreat := false
var launch_dir := -1.0
var arm_delay := 0.12
var _arm_left := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if kind == "stop":
		z_index = 6
	elif kind == "spring":
		z_index = 2
		if retreat:
			_arm_left = arm_delay
			armed = _arm_left <= 0.0
	else:
		z_index = 1


func _process(delta: float) -> void:
	delta *= time_scale
	if _arm_left > 0.0:
		_arm_left = maxf(_arm_left - delta, 0.0)
		armed = _arm_left <= 0.0
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


static func draw_spring(canvas: CanvasItem, _direction: float, tint := Color.WHITE, origin := Vector2.ZERO) -> void:
	Placement.draw_spring(canvas, origin, tint)


static func draw_banana(canvas: CanvasItem, origin: Vector2, tint := Color.WHITE) -> void:
	var drawn := BANANA_TEXTURE.get_size() * (BANANA_WIDTH / BANANA_TEXTURE.get_width())
	canvas.draw_texture_rect(BANANA_TEXTURE, Rect2((origin + Vector2(-drawn.x * 0.5, 12 - drawn.y)).round(), drawn), false, tint)


func _draw() -> void:
	if kind == "peel":
		var fade := 1.0 if life > 0.35 else clampf(life / 0.35, 0.0, 1.0)
		draw_banana(self, Vector2.ZERO, Color(1, 1, 1, fade))
	elif kind == "spring":
		var ink := Color(0.25, 0.94, 0.88) if retreat else Color(0.85, 0.88, 0.92)
		draw_spring(self, launch_dir if retreat else 0.0)
		if retreat:
			if not armed:
				Placement.ellipse(self, Vector2(0, -2), Vector2.ONE * 40, ink, 1.0 - _arm_left / maxf(arm_delay, 0.001))
	else:
		var pulse := 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.012))
		var ink := Color(0.55, 0.82, 1.0, 0.18 + 0.2 * pulse)
		Placement.ellipse(self, Vector2(0, 48), Vector2.ONE * radius, ink)
		Placement.ellipse(self, Vector2(0, 48), Vector2.ONE * radius * pulse, Color(0.75, 0.92, 1.0, 0.85))
		Placement.line(self, Vector2(0, 48 - radius), Vector2(0, 48 + radius * 0.35), Color(0.7, 0.9, 1.0, 0.5))
