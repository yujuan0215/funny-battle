class_name FighterAI
extends Node

var fighter: Fighter
var _air_time := 0.0
var _recover_at := -1.0
var _loaf := 0.0


func setup(body: Fighter) -> void:
	fighter = body


func think(delta: float) -> void:
	if not fighter.alive:
		fighter.input_dir = 0.0
		return
	if fighter.hitstun > 0.0 or fighter.slip_time > 0.0 or fighter.launch_time > 0.0:
		return
	if fighter.pose_time > 0.0 or (fighter.script_time > 0.0 and fighter.script_kind != "not_you"):
		fighter.input_dir = 0.0
		return
	var other := fighter.opponent
	var battle := fighter.get_tree().get_first_node_in_group("match") as Battle
	var host := fighter.get_tree().get_first_node_in_group("host_body") as HostBody
	if battle != null and battle.gang_up and host != null and host.on_stage:
		_chase(host.global_position, delta, true)
		return
	if fighter.script_time > 0.0 and fighter.script_kind == "not_you":
		if fighter.personality == "serious":
			var dir := fighter.script_dir
			fighter.facing = dir if dir != 0.0 else fighter.facing
			fighter.input_dir = fighter.facing
			if _prop_in_front():
				fighter.try_attack()
			return
		if other != null:
			_chase(other.global_position, delta, false)
		return
	if other == null or not other.alive:
		fighter.input_dir = 0.0
		return
	if fighter.personality == "lazy" and fighter.is_on_floor():
		if _loaf > 0.0:
			_loaf -= delta
			fighter.input_dir = 0.0
			return
		if randf() < delta * 0.55:
			_loaf = randf_range(0.45, 1.05)
			fighter.input_dir = 0.0
			return
	_chase(other.global_position, delta, fighter.personality == "serious")


func _chase(target: Vector2, delta: float, committed: bool) -> void:
	var gap := target - fighter.global_position
	var distance := absf(gap.x)
	if distance > 6.0 and gap.x != 0.0:
		fighter.facing = signf(gap.x)
	if fighter.is_on_floor():
		_air_time = 0.0
		_recover_at = -1.0
		if distance > 68.0 or absf(gap.y) > 72.0:
			fighter.input_dir = signf(gap.x) if distance > 24.0 and gap.x != 0.0 else 0.0
			if gap.y < -70.0 and distance < 320.0 and (committed or randf() < 0.04):
				fighter.try_jump()
		else:
			fighter.input_dir = 0.0
			if committed or randf() < delta * 0.65:
				fighter.try_attack()
		return
	_air_time += delta
	fighter.input_dir = signf(gap.x) if distance > 40.0 and gap.x != 0.0 else 0.0
	if _recover_at < 0.0:
		_recover_at = 0.1 if committed else (0.4 if randf() < 0.28 else 999.0)
	if _air_time >= _recover_at and _air_time <= _recover_at + delta + 0.001:
		fighter.try_jump()


func _prop_in_front() -> bool:
	for group in ["sponsor", "host_body"]:
		var node := fighter.get_tree().get_first_node_in_group(group)
		if node == null or not (node is Node2D):
			continue
		if group == "host_body" and node is HostBody and not (node as HostBody).on_stage:
			continue
		var gap: Vector2 = (node as Node2D).global_position - fighter.global_position
		if absf(gap.y) > 80.0 or absf(gap.x) > 82.0:
			continue
		if gap.x == 0.0 or signf(gap.x) == signf(fighter.facing):
			return true
	return false
