class_name StageFragment
extends CharacterBody2D

## Falling platform chunk. A CharacterBody2D so the robots can stand on it while it drops.

var spin := 0.0
var shape := PackedVector2Array()

const GRAVITY := 1700.0


func setup(poly: PackedVector2Array, xform: Transform2D) -> void:
	global_transform = xform
	collision_layer = 1
	collision_mask = 0
	motion_mode = MOTION_MODE_FLOATING
	z_index = 2
	var fill := Polygon2D.new()
	fill.color = Color.WHITE
	fill.polygon = poly
	var outline := Line2D.new()
	outline.width = 6.0
	outline.default_color = Color(0.08, 0.08, 0.08)
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	outline.antialiased = true
	var points := poly.duplicate()
	points.append(poly[0])
	outline.points = points
	var collision := CollisionPolygon2D.new()
	collision.name = "Shape"
	collision.polygon = poly
	shape = poly
	add_child(fill)
	add_child(outline)
	add_child(collision)
	velocity = Vector2(randf_range(-40.0, 40.0), 90.0)
	spin = randf_range(-0.45, 0.45)


func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	rotation += spin * delta
	move_and_slide()
	if global_position.y > 1200.0:
		_dump_riders()
		queue_free()


func _dump_riders() -> void:
	var riders: Array[Node] = []
	for child in get_children():
		if child is StageItem:
			riders.append(child)
	var scene := get_tree().current_scene
	for rider in riders:
		var item := rider as StageItem
		var kept_position := item.global_position
		if scene != null:
			item.reparent(scene)
		item.global_position = kept_position
		item.riding = false
		if item is BombItem:
			item.explode()
		else:
			item.fall()
