class_name Fighter
extends CharacterBody2D

signal koed(fighter: Fighter)
signal incident(kind: String)

@export var display_name := "紅"
@export var tint := Color(0.89, 0.22, 0.2)
@export var spawn_point := Vector2.ZERO
@export var personality := "serious"

var percent := 0.0
var stocks := 3
var facing := 1.0
var input_dir := 0.0
var opponent: Fighter
var alive := true
var locked := false
var hitstun := 0.0
var slip_time := 0.0
var invincible := 0.0
var attack_cooldown := 0.0
var attack_active := 0.0
var host_threat := 0.0
var launch_time := 0.0
var pose_time := 0.0
var script_time := 0.0
var script_kind := ""
var script_dir := 0.0
var gravity_flip := 0.0
var pace := 1.0
var swing_id := 0
var dealt := 0.0
var damage_events: Array[Dictionary] = []
var last_attacker: Fighter = null
var last_attack_time := -100.0
var last_cause := ""

var _want_jump := false
var _jumped := false
var _squash_x := 1.0
var _squash_y := 1.0
var _spin := 0.0
var _hit_ids: Array[int] = []
var _on_chunk := false
var _swing_damage := 8.0
var _swing_kb := 210.0
var _swing_growth := 1.0
var _swing_angle := 76.0

const GRAVITY := 2100.0
const MOVE_SPEED := 320.0
const JUMP_VELOCITY := -980.0

@onready var visual: Node2D = $Visual
@onready var hitbox: Area2D = $Hitbox
@onready var ai: FighterAI = $AI


func _ready() -> void:
	pace = 0.55 if personality == "lazy" else 1.0
	add_to_group("fighters")
	collision_layer = 2
	collision_mask = 1
	floor_constant_speed = true
	floor_snap_length = 16.0
	floor_max_angle = deg_to_rad(55.0)
	platform_on_leave = PLATFORM_ON_LEAVE_ADD_VELOCITY
	platform_floor_layers = 1
	motion_mode = MOTION_MODE_GROUNDED
	hitbox.monitoring = false
	hitbox.collision_layer = 4
	hitbox.collision_mask = 2
	ai.setup(self)
	_build_visual()


func _physics_process(delta: float) -> void:
	if locked or not alive:
		return
	ai.think(delta)
	_tick(delta)
	if gravity_flip > 0.0:
		gravity_flip = maxf(gravity_flip - delta, 0.0)
	var g := -GRAVITY if gravity_flip > 0.0 and not is_on_floor() else GRAVITY
	if launch_time > 0.0:
		launch_time = maxf(launch_time - delta, 0.0)
		floor_snap_length = 0.0
		velocity.y += g * delta
		_decay_squash(delta)
		move_and_slide()
		_after_move()
		_scan_hits()
		_pose()
		input_dir = 0.0
		return
	floor_snap_length = 16.0
	if hitstun > 0.0:
		velocity.y += g * delta
	elif slip_time > 0.0:
		velocity.y += g * delta
		velocity.x = move_toward(velocity.x, 0.0, 70.0 * delta)
		var spin_dir := velocity.x if absf(velocity.x) > 1.0 else facing
		_spin += signf(spin_dir) * 16.0 * delta
	elif pose_time > 0.0 or (script_time > 0.0 and script_kind != "not_you"):
		if script_kind == "ult" and script_time > 0.0:
			_squash_x = 0.78
			_squash_y = 1.22
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
			velocity.y = 0.0
		else:
			velocity.y += g * delta
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	else:
		var speed := MOVE_SPEED * pace
		if script_kind == "not_you" and personality == "lazy":
			speed *= 0.45
		if is_on_floor():
			velocity.y = 0.0
			velocity.x = input_dir * speed
		else:
			velocity.y += g * delta
			velocity.x = move_toward(velocity.x, input_dir * speed * 0.15, 220.0 * delta)
		if _want_jump:
			velocity.y = JUMP_VELOCITY
			_want_jump = false
		_spin = lerp_angle(_spin, 0.0, clampf(8.0 * delta, 0.0, 1.0))
	_decay_squash(delta)
	move_and_slide()
	_after_move()
	_scan_hits()
	_pose()
	input_dir = 0.0


func try_jump() -> void:
	if hitstun > 0.0 or slip_time > 0.0 or launch_time > 0.0 or pose_time > 0.0 or _jumped:
		return
	if script_time > 0.0 and script_kind != "not_you":
		return
	_want_jump = true
	_jumped = true


func try_attack() -> bool:
	if attack_cooldown > 0.0 or hitstun > 0.0 or slip_time > 0.0 or launch_time > 0.0 or pose_time > 0.0 or not is_on_floor():
		return false
	if script_time > 0.0 and script_kind != "not_you":
		return false
	_begin_swing(8.0, 210.0, 1.0, 0.14, 76.0)
	return true


func force_attack() -> void:
	if not alive or locked:
		return
	if slip_time > 0.0 or launch_time > 0.0 or not is_on_floor() or pose_time > 0.0:
		_popup("打空")
		_squash_x = 1.35
		_squash_y = 0.7
		return
	_begin_swing(16.0, 460.0, 2.1, 0.22, 52.0)


func can_attack() -> bool:
	return attack_cooldown <= 0.0 and hitstun <= 0.0 and slip_time <= 0.0 and launch_time <= 0.0 and pose_time <= 0.0 and is_on_floor()


func hear_line(line: int) -> bool:
	if not alive:
		return false
	if personality == "serious" and line == 1:
		_popup("……")
		return false
	if line == 0:
		script_kind = "ult"
		script_time = 0.7
		_popup("絕招")
	elif line == 1:
		script_kind = "wave"
		script_time = 0.8
		_popup("揮手")
	else:
		script_kind = "not_you"
		script_time = 1.05
		if personality == "serious":
			script_dir = _distraction_dir()
			if script_dir != 0.0:
				facing = script_dir
			_popup("嗯？")
		else:
			script_dir = facing
			if opponent != null and opponent.global_position.x != global_position.x:
				script_dir = signf(opponent.global_position.x - global_position.x)
			_popup("哦")
	return true


func hold_pose(duration: float) -> void:
	if not alive:
		return
	pose_time = duration
	script_time = 0.0
	attack_active = 0.0
	hitbox.monitoring = false
	velocity.x = 0.0
	_popup("定")
	mark_host_fault(2.5, "light")


func flutter() -> void:
	_popup("頭髮")
	_squash_x = 1.25
	_squash_y = 0.62


func flip_gravity(duration: float) -> void:
	gravity_flip = duration
	mark_host_fault(2.0, "box")
	_popup("浮")


func launch(next: Vector2, cause: String) -> void:
	velocity = next
	launch_time = 0.28
	hitstun = 0.25
	slip_time = 0.0
	pose_time = 0.0
	script_time = 0.0
	attack_active = 0.0
	hitbox.monitoring = false
	last_cause = cause
	mark_host_fault(4.0, cause)


func hop_onto(feet_world: Vector2) -> void:
	pose_time = 0.0
	script_time = 0.0
	global_position = feet_world + Vector2(0, -40.0)
	velocity = Vector2(0, -640.0)
	launch_time = 0.24
	last_cause = "cut"
	mark_host_fault(1.6, "cut")


func slip(direction: float) -> void:
	if not alive or invincible > 0.0 or locked:
		return
	slip_time = 0.85
	launch_time = 0.0
	pose_time = 0.0
	script_time = 0.0
	hitstun = 0.0
	attack_active = 0.0
	hitbox.monitoring = false
	last_cause = "slip"
	var dir := direction if direction != 0.0 else facing
	velocity.x = dir * 920.0
	velocity.y = -160.0
	_squash_x = 1.4
	_squash_y = 0.62
	_popup("滑！")
	mark_host_fault(4.2, "slip")


func mark_host_fault(duration: float = 4.2, kind: String = "") -> void:
	if not alive:
		return
	host_threat = maxf(host_threat, duration)
	if kind != "":
		incident.emit(kind)


func note_damage(amount: float, at: float) -> void:
	dealt += amount
	damage_events.append({"time": at, "amount": amount})


func state_label() -> String:
	if script_time > 0.0 and script_kind == "wave":
		return "正在揮手"
	if script_time > 0.0 and script_kind == "ult":
		return "正在蓄力"
	if pose_time > 0.0:
		return "正在擺拍"
	if slip_time > 0.0:
		return "正在滑行"
	if attack_active > 0.0:
		return "正在出拳"
	if not is_on_floor():
		return "在空中"
	if absf(velocity.x) > 230.0:
		return "正在衝刺"
	if absf(velocity.x) > 40.0:
		return "慢慢走" if personality == "lazy" else "正在靠近"
	return "站著"


func rescue() -> void:
	global_position = spawn_point
	velocity = Vector2.ZERO
	hitstun = 0.0
	slip_time = 0.0
	launch_time = 0.0
	attack_active = 0.0
	hitbox.monitoring = false
	invincible = 0.7
	_popup("彈回")


func receive_hit(damage: float, angle_deg: float, base_kb: float, growth: float, direction: float, from_host: bool = false, cause: String = "") -> void:
	if not alive or invincible > 0.0 or locked:
		return
	var was_posing := pose_time > 0.0 and not from_host
	pose_time = 0.0
	script_time = 0.0
	launch_time = 0.0
	percent += damage
	var force := base_kb + percent * growth
	var angle := deg_to_rad(angle_deg)
	var dir := direction if direction != 0.0 else facing
	velocity = Vector2(cos(angle) * dir, -sin(angle)) * force
	hitstun = clampf(0.16 + force / 2400.0, 0.2, 0.75)
	slip_time = 0.0
	attack_active = 0.0
	hitbox.monitoring = false
	_squash_x = 1.45
	_squash_y = 0.55
	_popup("+%d" % int(round(damage)))
	var director := get_tree().get_first_node_in_group("match")
	if from_host:
		last_cause = cause if cause != "" else "bomb"
		mark_host_fault(4.2, last_cause)
	else:
		last_cause = "punch"
		last_attacker = opponent
		if director != null and director.has_method("now") and opponent != null:
			last_attack_time = float(director.now())
			opponent.note_damage(damage, last_attack_time)
		if was_posing and director != null and director.has_method("note_photo"):
			director.note_photo(self)
	if director != null and director.has_method("add_shake"):
		director.add_shake(clampf(force / 120.0, 4.0, 16.0))


func knockout() -> void:
	if not alive:
		return
	alive = false
	stocks = maxi(stocks - 1, 0)
	velocity = Vector2.ZERO
	visible = false
	hitbox.monitoring = false
	koed.emit(self)


func respawn() -> void:
	global_position = spawn_point
	velocity = Vector2.ZERO
	percent = 0.0
	alive = true
	visible = true
	invincible = 1.5
	hitstun = 0.0
	slip_time = 0.0
	launch_time = 0.0
	pose_time = 0.0
	script_time = 0.0
	_jumped = false
	_spin = 0.0
	_squash_x = 1.0
	_squash_y = 1.0
	visual.rotation = 0.0
	visual.modulate.a = 1.0


func _tick(delta: float) -> void:
	if invincible > 0.0:
		invincible -= delta
		visual.modulate.a = 0.35 if fmod(invincible, 0.16) < 0.08 else 1.0
		if invincible <= 0.0:
			visual.modulate.a = 1.0
	if attack_cooldown > 0.0:
		attack_cooldown -= delta
	if hitstun > 0.0:
		hitstun -= delta
	if slip_time > 0.0:
		slip_time -= delta
	if host_threat > 0.0:
		host_threat -= delta
	if pose_time > 0.0:
		pose_time = maxf(pose_time - delta, 0.0)
	if script_time > 0.0:
		var before := script_time
		script_time = maxf(script_time - delta, 0.0)
		if before > 0.0 and script_time == 0.0 and script_kind == "ult":
			var kind := personality
			script_kind = ""
			if kind == "serious":
				force_attack()
			else:
				_popup("收回")
	elif script_kind != "":
		script_kind = ""
	if attack_active > 0.0:
		attack_active -= delta
		hitbox.position.x = 40.0 * facing
		if attack_active <= 0.0:
			hitbox.monitoring = false


func _begin_swing(damage: float, kb: float, growth: float, active: float, angle: float) -> void:
	swing_id += 1
	_swing_damage = damage
	_swing_kb = kb
	_swing_growth = growth
	_swing_angle = angle
	attack_cooldown = 0.9 if damage >= 12.0 else 0.58
	attack_active = active
	_hit_ids.clear()
	hitbox.monitoring = true
	hitbox.position.x = 40.0 * facing
	_squash_x = 1.28
	_squash_y = 0.78
	if opponent != null:
		_try_hit(opponent)
	_try_host()


func _scan_hits() -> void:
	if attack_active <= 0.0:
		return
	for body in hitbox.get_overlapping_bodies():
		if body is Fighter:
			_try_hit(body)
		elif body is HostBody:
			_try_host()


func _try_hit(body: Node) -> void:
	if attack_active <= 0.0 or not (body is Fighter):
		return
	var other := body as Fighter
	if other == self or other.get_instance_id() in _hit_ids:
		return
	var gap := other.global_position - global_position
	if absf(gap.y) > 56.0 or absf(gap.x) > 78.0:
		return
	if gap.x != 0.0 and signf(gap.x) != signf(facing):
		return
	_hit_ids.append(other.get_instance_id())
	other.receive_hit(_swing_damage, _swing_angle, _swing_kb, _swing_growth, facing)


func _try_host() -> void:
	if attack_active <= 0.0:
		return
	var host := get_tree().get_first_node_in_group("host_body") as HostBody
	if host == null or not host.on_stage:
		return
	if host.get_instance_id() in _hit_ids:
		return
	var gap := host.global_position - global_position
	if absf(gap.y) > 88.0 or absf(gap.x) > 84.0:
		return
	if gap.x != 0.0 and signf(gap.x) != signf(facing):
		return
	_hit_ids.append(host.get_instance_id())
	host.bonk(global_position.x)


func _distraction_dir() -> float:
	var away := -facing
	if opponent != null and opponent.global_position.x != global_position.x:
		away = -signf(opponent.global_position.x - global_position.x)
	var best_dir := away
	var best_d := 640.0
	var host := get_tree().get_first_node_in_group("host_body") as HostBody
	if host != null and host.on_stage:
		var gap := host.global_position - global_position
		var dist := absf(gap.x)
		if dist < best_d:
			best_d = dist
			best_dir = signf(gap.x) if gap.x != 0.0 else away
	var board := get_tree().get_first_node_in_group("sponsor") as Node2D
	if board != null:
		var gap2 := board.global_position - global_position
		var dist2 := absf(gap2.x)
		if dist2 < best_d:
			best_dir = signf(gap2.x) if gap2.x != 0.0 else best_dir
	if best_dir == 0.0:
		return away if away != 0.0 else facing
	return best_dir


func _after_move() -> void:
	var on_chunk := false
	if is_on_floor():
		var ground := get_last_slide_collision()
		if ground != null and ground.get_collider() is StageFragment:
			on_chunk = true
			host_threat = maxf(host_threat, 1.8)
			if not _on_chunk:
				incident.emit("ride")
		if velocity.y >= 0.0:
			_jumped = false
	_on_chunk = on_chunk


func _decay_squash(delta: float) -> void:
	_squash_x = lerpf(_squash_x, 1.0, clampf(8.0 * delta, 0.0, 1.0))
	_squash_y = lerpf(_squash_y, 1.0, clampf(8.0 * delta, 0.0, 1.0))


func _pose() -> void:
	visual.scale = Vector2(_squash_x * facing, _squash_y)
	visual.rotation = _spin
	visual.position.x = 12.0 * facing if attack_active > 0.0 else 0.0


func _popup(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(-28, -96)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08))
	label.z_index = 10
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", -140.0, 0.45)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.45)
	tween.tween_callback(label.queue_free)


func _build_visual() -> void:
	var outline := Polygon2D.new()
	outline.polygon = PackedVector2Array([
		Vector2(-24, -44), Vector2(24, -44), Vector2(28, 38), Vector2(-28, 38)
	])
	outline.color = Color(0.08, 0.08, 0.08)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-18, -38), Vector2(18, -38), Vector2(22, 32), Vector2(-22, 32)
	])
	body.color = tint
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(-16, -68), Vector2(16, -68), Vector2(18, -38), Vector2(-18, -38)
	])
	head.color = tint.lightened(0.18)
	var eye := Polygon2D.new()
	if personality == "lazy":
		eye.polygon = PackedVector2Array([
			Vector2(2, -54), Vector2(11, -54), Vector2(11, -50), Vector2(2, -50)
		])
	else:
		eye.polygon = PackedVector2Array([
			Vector2(2, -58), Vector2(11, -58), Vector2(11, -48), Vector2(2, -48)
		])
	eye.color = Color.WHITE
	visual.add_child(outline)
	visual.add_child(body)
	visual.add_child(head)
	visual.add_child(eye)
