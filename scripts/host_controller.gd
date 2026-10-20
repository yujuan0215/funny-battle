class_name HostController
extends Node2D

enum Tool { BANANA, BOMB, CUT, MIC, SPRING, LIGHT }

const COOLDOWN: Array[float] = [0.8, 1.15, 1.5, 2.0, 1.2, 1.4]
const MIC_LINES: Array[String] = ["使出絕招", "看鏡頭", "他不是你的對手"]
const BOMB_SCENE := preload("res://scenes/bomb.tscn")
const BANANA_SCENE := preload("res://scenes/banana.tscn")

var tool := Tool.BANANA
var mic_line := 0
var cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var dragging := false
var drag_start := Vector2.ZERO
var flash := 0.0

@onready var director: Battle = $".."
@onready var cut_line: Line2D = $"../CutLine"
@onready var items_root: Node2D = $"../Items"


func _process(delta: float) -> void:
	for i in cooldowns.size():
		cooldowns[i] = maxf(cooldowns[i] - delta, 0.0)
	if flash > 0.0:
		flash -= delta
		cut_line.modulate.a = clampf(flash / 0.18, 0.0, 1.0)
		if flash <= 0.0 and not dragging:
			cut_line.visible = false
	if dragging:
		cut_line.visible = true
		cut_line.points = PackedVector2Array([drag_start, get_global_mouse_position()])
	var cursor := Input.CURSOR_CROSS if tool == Tool.CUT else Input.CURSOR_POINTING_HAND
	Input.set_default_cursor_shape(cursor)


func set_tool(next: int) -> void:
	tool = next as Tool


func cycle_mic() -> void:
	mic_line = (mic_line + 1) % MIC_LINES.size()


func mic_name() -> String:
	return MIC_LINES[mic_line]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1:
				tool = Tool.BANANA
			KEY_2, KEY_KP_2:
				tool = Tool.BOMB
			KEY_3, KEY_KP_3:
				tool = Tool.CUT
			KEY_4, KEY_KP_4:
				if tool == Tool.MIC:
					cycle_mic()
				else:
					tool = Tool.MIC
			KEY_5, KEY_KP_5:
				tool = Tool.SPRING
			KEY_6, KEY_KP_6:
				tool = Tool.LIGHT
			KEY_7, KEY_KP_7:
				director.open_box(0)
			KEY_8, KEY_KP_8:
				director.open_box(1)
			KEY_SPACE:
				_toggle_host()
				return
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if not director.is_live():
		return
	if tool == Tool.CUT:
		if mouse.pressed:
			dragging = true
			drag_start = get_global_mouse_position()
			cut_line.default_color = Color(0.55, 0.55, 0.55) if cooldowns[Tool.CUT] > 0.0 else Color(0.92, 0.12, 0.1)
			cut_line.modulate.a = 1.0
			cut_line.visible = true
		elif dragging:
			_finish_cut()
	elif mouse.pressed and tool == Tool.MIC:
		_use_mic(get_global_mouse_position())
	elif mouse.pressed:
		_place(get_global_mouse_position())


func _input(event: InputEvent) -> void:
	if not dragging or not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed:
		_finish_cut()


func _toggle_host() -> void:
	if not director.is_live():
		return
	if director.host_body.on_stage:
		director.host_body.leave()
		return
	var spot: Variant = _snap(get_global_mouse_position())
	if spot == null:
		return
	director.host_body.appear((spot as Vector2) + Vector2(0, -25))


func _finish_cut() -> void:
	if not dragging:
		return
	dragging = false
	var finish := get_global_mouse_position()
	cut_line.points = PackedVector2Array([drag_start, finish])
	cut_line.visible = true
	flash = 0.2
	if not director.is_live() or cooldowns[Tool.CUT] > 0.0:
		return
	if drag_start.distance_to(finish) < 36.0:
		return
	var cut_any := false
	for node in get_tree().get_nodes_in_group("platforms"):
		if (node as Platform).try_cut(drag_start, finish):
			cut_any = true
	if cut_any:
		cooldowns[Tool.CUT] = COOLDOWN[Tool.CUT]
		director.add_shake(12.0)


func _use_mic(point: Vector2) -> void:
	if cooldowns[Tool.MIC] > 0.0:
		return
	var fighter := _nearest_fighter(point, 96.0)
	if fighter == null:
		return
	var detail := "%s，%s" % [MIC_LINES[mic_line], fighter.state_label()]
	var heard := fighter.hear_line(mic_line)
	if heard:
		fighter.mark_host_fault(2.2, "mic")
	director.host_record("mic", fighter, "hit" if heard else "ignore", detail, "mic%d" % mic_line)
	cooldowns[Tool.MIC] = COOLDOWN[Tool.MIC]


func _place(world_point: Vector2) -> void:
	if cooldowns[tool] > 0.0:
		return
	var spot: Variant = _snap(world_point)
	if spot == null:
		return
	var at := spot as Vector2
	if tool == Tool.LIGHT:
		var light := Spotlight.new()
		items_root.add_child(light)
		light.global_position = at
	elif tool == Tool.SPRING:
		var spring := SpringItem.new()
		items_root.add_child(spring)
		spring.global_position = at + Vector2(0, -spring.hover_height)
	else:
		var item: StageItem = (BOMB_SCENE if tool == Tool.BOMB else BANANA_SCENE).instantiate() as StageItem
		items_root.add_child(item)
		item.global_position = at + Vector2(0, -item.hover_height)
	cooldowns[tool] = COOLDOWN[tool]


func _snap(world_point: Vector2) -> Variant:
	var spot: Variant = null
	var best := 100000.0
	for node in get_tree().get_nodes_in_group("platforms"):
		var platform := node as Platform
		var snapped: Variant = platform.snap_placement(world_point)
		if snapped == null:
			continue
		var distance := absf((snapped as Vector2).y - world_point.y)
		if distance < best:
			best = distance
			spot = snapped
	return spot


func _nearest_fighter(point: Vector2, reach: float) -> Fighter:
	var best: Fighter = null
	var dist := reach
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as Fighter
		if fighter == null or not fighter.alive:
			continue
		var gap := fighter.global_position.distance_to(point)
		if gap < dist:
			dist = gap
			best = fighter
	return best
