extends Node2D

const SPRING_TILT := 0.62
const SPRING_SCALE := 0.85
const BANANA_WIDTH := 62.0
const SPRING_TEXTURE := preload("res://assets/props/spring.png")
const BANANA_TEXTURE := preload("res://assets/props/banana.png")

var kind := "peel"
var wind := -1.0
var radius := 48.0
var ripe := false
var spent := false
var life := 2.4
var armed := true
var time_scale := 1.0
var launch_dir := 0.0
var arm_delay := 0.0
var _arm_left := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if kind == "stop":
		z_index = 6
	elif kind == "spring":
		z_index = 2
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


static func draw_spring(ci: CanvasItem, dir: float, tint: Color = Color.WHITE, origin: Vector2 = Vector2.ZERO) -> void:
	# 整座彈簧繞著底部旋轉：往上時直立，往左/右時彈簧本體一起倒向該側。
	ci.draw_set_transform(origin + Vector2(0, 12), dir * SPRING_TILT, Vector2(SPRING_SCALE, SPRING_SCALE))
	var size := SPRING_TEXTURE.get_size()
	ci.draw_texture_rect(SPRING_TEXTURE, Rect2(Vector2(-size.x * 0.5, -size.y + 8.0), size), false, tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	if kind == "peel":
		var fade := 1.0 if life > 0.35 else clampf(life / 0.35, 0.0, 1.0)
		var size := BANANA_TEXTURE.get_size()
		var scale := BANANA_WIDTH / size.x
		var drawn := size * scale
		draw_texture_rect(BANANA_TEXTURE, Rect2(Vector2(-drawn.x * 0.5, 12.0 - drawn.y), drawn), false, Color(1, 1, 1, fade))
	elif kind == "spring":
		draw_spring(self, launch_dir)
		if not armed:
			draw_arc(Vector2(0, -2), 40, -PI, -PI + PI * (1.0 - _arm_left / maxf(arm_delay, 0.001)), 20, Color(0.3, 1.0, 0.9), 2.0)
	else:
		var pulse := 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.012))
		var ink := Color(0.55, 0.82, 1.0, 0.18 + 0.2 * pulse)
		draw_arc(Vector2(0, 48), radius, 0.0, TAU, 48, ink, 3.0)
		draw_arc(Vector2(0, 48), radius * pulse, PI, TAU, 24, Color(0.75, 0.92, 1.0, 0.85), 4.0)
		draw_line(Vector2(0, 48 - radius), Vector2(0, 48 + radius * 0.35), Color(0.7, 0.9, 1.0, 0.5), 2.0)
