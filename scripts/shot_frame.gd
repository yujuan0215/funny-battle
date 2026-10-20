class_name ShotFrame
extends Node2D

var _font: SystemFont


func _ready() -> void:
	z_index = 3
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft JhengHei UI", "Microsoft JhengHei", "Microsoft YaHei"])


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var alarm := 0
	var director := get_tree().get_first_node_in_group("match")
	if director != null:
		alarm = int(director.broadcast.shot_alarm)
	var fill := Color(0.85, 0.12, 0.08, 0.06)
	var ink := Color(0.75, 0.12, 0.08, 0.85)
	if alarm == 1:
		fill.a = 0.14
	elif alarm == 2:
		fill = Color(0.9, 0.08, 0.06, 0.28)
		ink = Color(0.75, 0.05, 0.04, 1.0)
	var area := Broadcast.SHOT
	draw_rect(area, fill)
	draw_rect(area, ink, false, 4.0)
	if _font != null:
		draw_string(_font, area.position + Vector2(12, 32), "鏡頭", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
