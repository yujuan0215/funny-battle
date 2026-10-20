class_name HostBody
extends CharacterBody2D

var on_stage := false
var flying := false
var cooldown := 0.0
var stage_time := 0.0

var _shape: CollisionShape2D
var _fly := Vector2.ZERO
var _fly_time := 0.0


func _ready() -> void:
	add_to_group("host_body")
	collision_layer = 2
	collision_mask = 0
	z_index = 8
	var rect := RectangleShape2D.new()
	rect.size = Vector2(34, 70)
	_shape = CollisionShape2D.new()
	_shape.shape = rect
	_shape.position = Vector2(0, -10)
	_shape.disabled = true
	add_child(_shape)
	visible = false
	position = Vector2(-2400, -2400)


func _process(delta: float) -> void:
	if cooldown > 0.0:
		cooldown = maxf(cooldown - delta, 0.0)
	if on_stage:
		stage_time += delta
		queue_redraw()
	if not flying:
		return
	_fly_time -= delta
	global_position += _fly * delta
	_fly.y += 1600.0 * delta
	rotation += delta * 7.0 * signf(_fly.x if _fly.x != 0.0 else 1.0)
	queue_redraw()
	if _fly_time <= 0.0:
		flying = false
		visible = false
		rotation = 0.0
		global_position = Vector2(-2400, -2400)


func appear(at: Vector2) -> bool:
	if on_stage or flying or cooldown > 0.0:
		return false
	global_position = at
	on_stage = true
	visible = true
	stage_time = 0.0
	rotation = 0.0
	_set_solid(true)
	queue_redraw()
	return true


func leave() -> void:
	if not on_stage:
		return
	on_stage = false
	visible = false
	stage_time = 0.0
	cooldown = 0.35
	rotation = 0.0
	_set_solid(false)
	global_position = Vector2(-2400, -2400)


func bonk(from_x: float) -> void:
	if not on_stage or flying:
		return
	on_stage = false
	flying = true
	visible = true
	stage_time = 0.0
	cooldown = 3.0
	_set_solid(false)
	var dir := signf(global_position.x - from_x)
	if dir == 0.0:
		dir = 1.0
	_fly = Vector2(dir * 760.0, -460.0)
	_fly_time = 0.48
	var director := get_tree().get_first_node_in_group("match")
	if director != null and director.has_method("host_record"):
		director.host_record("host", null, "hit", "被打中")


func _set_solid(enabled: bool) -> void:
	if _shape != null:
		_shape.disabled = not enabled


func _draw() -> void:
	var director := get_tree().get_first_node_in_group("match")
	if director != null and bool(director.get("gang_up")):
		draw_circle(Vector2(0, -16), 48, Color(0.9, 0.16, 0.1, 0.28))
	draw_rect(Rect2(-16, -34, 32, 58), Color(0.08, 0.08, 0.08))
	draw_rect(Rect2(-12, -30, 24, 50), Color(0.96, 0.96, 0.93))
	draw_circle(Vector2(0, -48), 16, Color(0.08, 0.08, 0.08))
	draw_circle(Vector2(0, -48), 12, Color(0.96, 0.9, 0.72))
	draw_rect(Rect2(2, -52, 5, 5), Color(0.08, 0.08, 0.08))
	draw_line(Vector2(10, -8), Vector2(26, 6), Color(0.08, 0.08, 0.08), 4.0)
