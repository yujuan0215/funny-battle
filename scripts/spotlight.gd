class_name Spotlight
extends Node2D

var life := 0.55

var _applied: Array[int] = []
var _logged := false


func _ready() -> void:
	z_index = 6


func _process(delta: float) -> void:
	life -= delta
	queue_redraw()
	if life <= 0.0 and not _logged:
		_logged = true
		var director := get_tree().get_first_node_in_group("match")
		if director != null and director.has_method("host_record"):
			director.host_record("light", null, "whiff", "光穿過去了")
		queue_free()
	elif life <= 0.0:
		queue_free()


func _physics_process(_delta: float) -> void:
	var fresh: Array[Fighter] = []
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as Fighter
		if fighter == null or not fighter.alive:
			continue
		if fighter.get_instance_id() in _applied:
			continue
		if global_position.distance_to(fighter.global_position) > 96.0:
			continue
		if not fighter.is_on_floor() or fighter.hitstun > 0.0 or fighter.slip_time > 0.0:
			continue
		_applied.append(fighter.get_instance_id())
		fresh.append(fighter)
	if fresh.is_empty():
		return
	var detail := fresh[0].state_label()
	for fighter in fresh:
		fighter.hold_pose(0.6)
	if fresh.size() > 1:
		detail = "兩個人都站在光裡"
	if _logged:
		return
	_logged = true
	var director := get_tree().get_first_node_in_group("match")
	if director != null and director.has_method("host_record"):
		director.host_record("light", fresh[0], "hit", detail)


func _draw() -> void:
	var alpha := clampf(life / 0.55, 0.0, 1.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-34, 6), Vector2(34, 6), Vector2(12, -108), Vector2(-12, -108),
	]), Color(0.98, 0.82, 0.12, 0.38 * alpha))
	draw_line(Vector2(0, 4), Vector2(0, -104), Color(0.85, 0.62, 0.05, alpha), 3.0)
