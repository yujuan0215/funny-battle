class_name Duelist
extends Node2D

const CELL := 64
const SCALE := 4.0
const FOOT := 22.0
const CLIPS := {
	"idle": {"frames": [Vector2i(0, 0), Vector2i(1, 0)], "fps": 3.0, "loop": true},
	"walk": {"frames": [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)], "fps": 10.0, "loop": true},
	"run": {"frames": [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)], "fps": 16.0, "loop": true},
	"crouch": {"frames": [Vector2i(14, 0), Vector2i(15, 0)], "fps": 8.0, "loop": false},
	"jab": {"frames": [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)], "fps": 14.0, "loop": false},
	"kick": {"frames": [Vector2i(6, 2), Vector2i(7, 2)], "fps": 12.0, "loop": false},
	"slash": {"frames": [Vector2i(8, 2), Vector2i(9, 2)], "fps": 11.0, "loop": false},
	"hop": {"frames": [Vector2i(12, 2), Vector2i(13, 2)], "fps": 10.0, "loop": false},
	"hit": {"frames": [Vector2i(0, 1), Vector2i(1, 1)], "fps": 12.0, "loop": false},
	"down": {"frames": [Vector2i(7, 3)], "fps": 1.0, "loop": true},
	"getup": {"frames": [Vector2i(9, 3), Vector2i(10, 3), Vector2i(16, 0)], "fps": 8.0, "loop": false},
	"rapid": {"frames": [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)], "fps": 16.0, "loop": true},
	"heavy": {"frames": [Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4)], "fps": 11.0, "loop": false},
	"gun": {"frames": [Vector2i(10, 4), Vector2i(11, 4), Vector2i(12, 4)], "fps": 9.0, "loop": false},
	"power": {"frames": [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5)], "fps": 8.0, "loop": false},
	"strike": {"frames": [Vector2i(9, 5), Vector2i(10, 5), Vector2i(11, 5)], "fps": 12.0, "loop": false},
	"mix": {"frames": [Vector2i(8, 0), Vector2i(9, 0), Vector2i(10, 0), Vector2i(11, 0), Vector2i(12, 0), Vector2i(13, 0)], "fps": 13.0, "loop": false},
	"rise": {"frames": [Vector2i(0, 7), Vector2i(1, 7), Vector2i(2, 7)], "fps": 10.0, "loop": true},
}

const ROSTER: Array[Dictionary] = [
	{"id": "armor", "label": "藍甲", "path": "res://assets/chars/char_3/body.png"},
	{"id": "bare", "label": "卸甲", "path": "res://assets/chars/char_3/bare.png"},
	{"id": "yellow", "label": "黃髮", "path": "res://assets/chars/char_4/body.png"},
	{"id": "silver", "label": "銀髮", "path": "res://assets/chars/char_5/body.png"},
]

@export var display_name := "穿甲"
@export var bare := false
@export var face_right := false

var sheet: Texture2D
var sheet_id := "armor"

var _sprite: Sprite2D
var _frames: Array = CLIPS["idle"]["frames"]
var _loop := true
var _frame := 0
var _anim_len := 0.67
var _anim_age := 0.0
var anim := "idle"
var lock := 0.0
var busy := 0.0
var reacting := false
var script_open := true
var strike_ready := false
var seq := 0
var plan: PackedStringArray = PackedStringArray()
var glow := 0
var vx := 0.0
var _struck := false

const ATTACKS: Array[String] = ["jab", "kick", "slash", "hop", "rapid", "heavy", "gun", "mix", "strike"]

var _from := 0.0
var _to := 0.0
var _slide := 1.0
var _slide_dur := 0.01
var _prev_x := 0.0

var time_scale := 1.0
var ground_y := 0.0
var hitstop := 0.0
var frozen := 0.0
var airborne := false
var vy := 0.0
var air_vx := 0.0
var grav := 1600.0
var big_launch := false
var fall_armed := false
var fall_age := 0.0
var fall_spent := false
var just_landed := false
var land_big := false
var land_hit := false
var land_lag := 0.12
var slipping := false
var chain := ""
var sheet_move: Dictionary = {}
var use_module := false
var next_anim := ""
var swapped := false
var action_age := 0.0
var strike_at := -1.0
var shot_frame := -1
var hp := 10
var hp_max := 10
var out := false
var goal := false
var show_hp := true


func _ready() -> void:
	_sprite = Sprite2D.new()
	use_sheet("bare" if bare else "armor")
	_sprite.texture = sheet
	_sprite.centered = true
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0, 0, CELL, CELL)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(SCALE, SCALE)
	_sprite.position = Vector2(0, -FOOT * SCALE)
	# 原圖朝右。左邊的人保持原向，右邊的人左右翻轉，兩人才會面對面。
	_sprite.flip_h = not face_right
	_sprite.z_index = 1
	add_child(_sprite)
	_prev_x = position.x
	ground_y = position.y
	play("idle")


func use_sheet(id: String) -> void:
	for entry in ROSTER:
		if str(entry["id"]) != id:
			continue
		sheet_id = id
		bare = id == "bare"
		sheet = load(str(entry["path"]))
		if _sprite != null:
			_sprite.texture = sheet
		return


func firing_beam() -> bool:
	return use_module and anim == "heavy" and shot_frame >= 0 and _frame >= shot_frame and str(sheet_move.get("id", "")) == "蓄力"


func glove_tips() -> Array[Vector2]:
	var facing := 1.0 if face_right else -1.0
	var tips: Array[Vector2] = []
	# 蓄力最後一格，兩隻手套的前端。格子座標，原圖朝右。
	var gloves: Array[Vector2] = [Vector2(50, 31), Vector2(50, 40)]
	for glove in gloves:
		var x := position.x + (glove.x + 0.5 - 32.0) * SCALE * facing
		var y := position.y + (glove.y + 0.5 - 32.0) * SCALE - FOOT * SCALE
		tips.append(Vector2(x, y))
	return tips


func play(anim_name: String) -> void:
	var clip: Dictionary = CLIPS.get(anim_name, CLIPS["idle"])
	anim = anim_name if CLIPS.has(anim_name) else "idle"
	_frames = clip["frames"]
	_loop = bool(clip["loop"])
	_anim_len = clip_cycle(anim)
	_anim_age = 0.0
	_frame = 0
	_struck = false
	strike_ready = false
	z_index = 4 if airborne else (1 if anim_name in ["idle", "walk", "run", "crouch", "down", "getup"] else 3)
	_apply()


func clip_cycle(anim_name: String) -> float:
	var clip: Dictionary = CLIPS.get(anim_name, CLIPS["idle"])
	return maxf(float(clip["frames"].size()) / float(clip["fps"]), 0.05)


func commit_time(anim_name: String, requested: float) -> float:
	var cycle := clip_cycle(anim_name)
	var clip: Dictionary = CLIPS.get(anim_name, CLIPS["idle"])
	if not bool(clip["loop"]):
		return cycle
	var count := ceili(maxf(requested, 0.01) / cycle)
	return cycle * float(maxi(count, 1))


func can_act() -> bool:
	return not out and script_open and not reacting and not slipping and not airborne and frozen <= 0.0 and hitstop <= 0.0


func exposed() -> bool:
	return reacting or anim == "down" or anim == "getup" or anim == "hit"


func go(anim_name: String, target_x: float, move_time: float) -> bool:
	if not can_act():
		return false
	reacting = false
	lock = 0.0
	use_module = false
	strike_at = -1.0
	shot_frame = -1
	next_anim = ""
	_start(anim_name, target_x, commit_time(anim_name, move_time))
	return true


func react(anim_name: String, target_x: float, _move_time: float = 0.2, _hold: float = 0.5, refresh: bool = false, stun: float = -1.0) -> bool:
	if reacting and not refresh:
		return false
	_plant()
	slipping = false
	use_module = false
	next_anim = ""
	chain = ""
	sheet_move = {}
	var dur := clip_cycle(anim_name) if stun < 0.0 else stun
	reacting = true
	lock = dur
	_start(anim_name, target_x, dur)
	return true


func relax() -> void:
	lock = 0.0
	busy = 0.0
	reacting = false
	script_open = true
	plan = PackedStringArray()
	_slide = 1.0
	hitstop = 0.0
	frozen = 0.0
	slipping = false
	chain = ""
	sheet_move = {}
	use_module = false
	next_anim = ""
	swapped = false
	action_age = 0.0
	strike_at = -1.0
	shot_frame = -1
	just_landed = false
	hp = hp_max
	out = false
	fall_armed = false
	fall_age = 0.0
	fall_spent = false
	_plant()
	play("idle")
	if _sprite != null:
		_sprite.flip_h = not face_right


func start_module(anim_name: String, target_x: float, busy_time: float, move_time: float, hit_time: float, follow_anim: String) -> void:
	if frozen > 0.0 or airborne:
		return
	reacting = false
	slipping = false
	lock = 0.0
	use_module = true
	next_anim = follow_anim
	swapped = false
	action_age = 0.0
	strike_at = hit_time
	shot_frame = -1
	script_open = false
	busy = busy_time
	_move(anim_name, target_x, maxf(move_time, 0.04))
	if move_time <= 0.0:
		_from = position.x
		_to = position.x
		_slide = 1.0


func leave_active(active_left: float) -> void:
	busy = minf(busy, maxf(active_left, 0.04))


func begin_slip(dir: float, distance: float, time: float) -> void:
	if airborne:
		return
	chain = ""
	sheet_move = {}
	use_module = false
	next_anim = ""
	strike_at = -1.0
	shot_frame = -1
	reacting = false
	slipping = true
	lock = 0.0
	var dest := clampf(position.x + dir * distance, 80.0, 1200.0)
	script_open = false
	busy = time
	_move("down", dest, time)


func launch_arc(hx: float, hy: float, gravity: float, big: bool, recover: float) -> void:
	if ground_y == 0.0:
		ground_y = position.y
	airborne = true
	big_launch = big
	fall_armed = false
	fall_age = 0.0
	fall_spent = false
	grav = gravity
	vy = -absf(hy)
	air_vx = hx
	land_lag = recover
	slipping = false
	reacting = false
	use_module = false
	next_anim = ""
	chain = ""
	sheet_move = {}
	strike_at = -1.0
	shot_frame = -1
	strike_ready = false
	script_open = false
	busy = 0.0
	lock = 0.0
	if big:
		play("rise")
	else:
		play("hop")


func _start(anim_name: String, target_x: float, dur: float) -> void:
	script_open = false
	busy = dur
	_move(anim_name, target_x, dur)


func _move(anim_name: String, target_x: float, move_time: float) -> void:
	play(anim_name)
	_sprite.flip_h = not face_right
	_from = position.x
	_to = target_x
	_slide = 0.0
	_slide_dur = maxf(move_time, 0.04)


func _plant() -> void:
	airborne = false
	big_launch = false
	fall_armed = false
	fall_age = 0.0
	air_vx = 0.0
	vy = 0.0
	if ground_y != 0.0:
		position.y = ground_y


func _swap_anim(anim_name: String) -> void:
	var clip: Dictionary = CLIPS.get(anim_name, CLIPS["idle"])
	anim = anim_name if CLIPS.has(anim_name) else "idle"
	_frames = clip["frames"]
	_loop = bool(clip["loop"])
	_anim_len = clip_cycle(anim)
	_anim_age = 0.0
	_frame = 0
	z_index = 3
	_apply()


func _sample_ground() -> void:
	var host := get_parent()
	if host == null or not host.has_method("ground_height"):
		return
	ground_y = host.ground_height(position.x, position.y)


func chest() -> Vector2:
	return global_position + Vector2(0, -78)


func _process(delta: float) -> void:
	delta *= time_scale
	if not airborne:
		var feet := position.y
		_sample_ground()
		if ground_y > feet + 36.0:
			airborne = true
			vy = 80.0
			air_vx = 0.0
			big_launch = false
			fall_armed = false
			fall_spent = false
		else:
			position.y = ground_y
	if hitstop > 0.0:
		hitstop = maxf(hitstop - delta, 0.0)
		vx = 0.0
		_prev_x = position.x
		queue_redraw()
		return
	if frozen > 0.0:
		frozen = maxf(frozen - delta, 0.0)
		vx = 0.0
		_prev_x = position.x
		queue_redraw()
		return
	if airborne:
		_fly(delta)
		queue_redraw()
		return
	var before := _anim_age
	_anim_age += delta
	var just_opened := false
	if lock > 0.0:
		lock = maxf(lock - delta, 0.0)
	if busy > 0.0:
		busy = maxf(busy - delta, 0.0)
		if busy == 0.0:
			reacting = false
			slipping = false
			use_module = false
			if _loop and _anim_len > 0.0:
				var cycles := maxi(int(round(_anim_age / _anim_len)), 1)
				_anim_age = float(cycles) * _anim_len
			script_open = true
			just_opened = true
	elif _loop and _anim_len > 0.0 and not reacting:
		if int(_anim_age / _anim_len) > int(before / _anim_len):
			script_open = true
			just_opened = true
	# 循環只在整段交界交接，避免切進半格。
	if _loop and script_open and not just_opened and not reacting and busy <= 0.0 and _anim_len > 0.0:
		if fposmod(_anim_age, _anim_len) > 0.05:
			script_open = false
	if use_module:
		action_age += delta
		if not swapped and strike_at >= 0.0 and action_age >= strike_at:
			swapped = true
			if next_anim != "":
				_swap_anim(next_anim)
			if shot_frame < 0:
				_struck = true
				strike_ready = true
	elif anim in ATTACKS and not _struck and _anim_age >= _anim_len * 0.62:
		_struck = true
		strike_ready = true
	if _slide < 1.0:
		_slide = minf(_slide + delta / _slide_dur, 1.0)
		var k := _slide * _slide * (3.0 - 2.0 * _slide)
		position.x = lerpf(_from, _to, k)
	vx = (position.x - _prev_x) / maxf(delta, 0.001)
	_prev_x = position.x
	_sync_frame()
	_apply()
	if use_module and swapped and shot_frame >= 0 and not _struck and _frame >= shot_frame:
		_struck = true
		strike_ready = true
	queue_redraw()


func _fly(delta: float) -> void:
	var before := position.x
	vy += grav * delta
	position.y += vy * delta
	position.x = clampf(position.x + air_vx * delta, 80.0, 1200.0)
	vx = (position.x - before) / maxf(delta, 0.001)
	_prev_x = position.x
	# 大拋上升播被拋起的翻滾，過了最高點才換成下落。
	if big_launch and not fall_armed and vy >= 0.0 and position.y < ground_y:
		fall_armed = true
		fall_age = 0.0
		play("hop")
	if big_launch and fall_armed:
		fall_age += delta
	_anim_age += delta
	_sync_frame()
	_apply()
	_sample_ground()
	if position.y < ground_y or vy < 0.0:
		z_index = 4
		return
	var was_big := big_launch
	var did_hit := fall_spent
	position.y = ground_y
	airborne = false
	big_launch = false
	fall_armed = false
	fall_age = 0.0
	air_vx = 0.0
	vy = 0.0
	fall_spent = false
	just_landed = true
	land_big = was_big
	land_hit = did_hit
	busy = land_lag
	script_open = false
	use_module = false
	play("idle")


func _sync_frame() -> void:
	var count := _frames.size()
	if count <= 0 or _anim_len <= 0.0:
		return
	var index := int(_anim_age / (_anim_len / float(count)))
	_frame = index % count if _loop else mini(index, count - 1)


func _apply() -> void:
	var cell: Vector2i = _frames[_frame]
	_sprite.region_rect = Rect2(cell.x * CELL, cell.y * CELL, CELL, CELL)


func _draw() -> void:
	var lift := 0.0
	if airborne and ground_y != 0.0:
		lift = ground_y - position.y
	var points := PackedVector2Array()
	var shade := clampf(1.0 - lift / 180.0, 0.35, 1.0)
	for i in 14:
		var angle := TAU * float(i) / 14.0
		points.append(Vector2(cos(angle) * 36.0 * shade, sin(angle) * 10.0 * shade - 2.0 + lift))
	draw_colored_polygon(points, Color(0, 0, 0, 0.35))
	if frozen > 0.0:
		var pulse := 0.45 + 0.55 * absf(sin(Time.get_ticks_msec() * 0.02))
		draw_arc(Vector2(0, -92), 58.0, 0.0, TAU, 36, Color(0.62, 0.86, 1.0, 0.35 + 0.45 * pulse), 5.0)
	if glow <= 0:
		return
	var fast := glow == 2
	var glow_pulse := absf(sin(Time.get_ticks_msec() * 0.001 * (30.0 if fast else 7.0)))
	var ink := Color(1, 0.95, 0.55, 0.45 + 0.55 * glow_pulse) if fast else Color(1, 0.45, 0.16, 0.35 + 0.25 * glow_pulse)
	draw_arc(Vector2(0, -92), 62.0 if fast else 48.0, 0.0, TAU, 36, ink, 8.0 if fast else 4.0)
