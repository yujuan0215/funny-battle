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
}

@export var display_name := "穿甲"
@export var bare := false
@export var face_right := false

var sheet: Texture2D

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


func _ready() -> void:
	var path := "res://assets/char_3/bare.png" if bare else "res://assets/char_3/body.png"
	sheet = load(path)
	_sprite = Sprite2D.new()
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
	play("idle")


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
	z_index = 1 if anim_name in ["idle", "walk", "run", "crouch", "down", "getup"] else 3
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
	return script_open and not reacting


func exposed() -> bool:
	return reacting or anim == "down" or anim == "getup" or anim == "hit"


func go(anim_name: String, target_x: float, move_time: float) -> bool:
	if not can_act():
		return false
	reacting = false
	lock = 0.0
	_start(anim_name, target_x, commit_time(anim_name, move_time))
	return true


func react(anim_name: String, target_x: float, _move_time: float, _hold: float) -> bool:
	if reacting:
		return false
	var dur := clip_cycle(anim_name)
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
	play("idle")


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


func chest() -> Vector2:
	return global_position + Vector2(0, -78)


func _process(delta: float) -> void:
	var before := _anim_age
	_anim_age += delta
	var just_opened := false
	if lock > 0.0:
		lock = maxf(lock - delta, 0.0)
	if busy > 0.0:
		busy = maxf(busy - delta, 0.0)
		if busy == 0.0:
			reacting = false
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
	if anim in ATTACKS and not _struck and _anim_age >= _anim_len * 0.62:
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
	queue_redraw()


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
	var points := PackedVector2Array()
	for i in 14:
		var angle := TAU * float(i) / 14.0
		points.append(Vector2(cos(angle) * 36.0, sin(angle) * 10.0 - 2.0))
	draw_colored_polygon(points, Color(0, 0, 0, 0.35))
	if glow <= 0:
		return
	var fast := glow == 2
	var pulse := absf(sin(Time.get_ticks_msec() * 0.001 * (30.0 if fast else 7.0)))
	var ink := Color(1, 0.95, 0.55, 0.45 + 0.55 * pulse) if fast else Color(1, 0.45, 0.16, 0.35 + 0.25 * pulse)
	draw_arc(Vector2(0, -92), 62.0 if fast else 48.0, 0.0, TAU, 36, ink, 8.0 if fast else 4.0)
