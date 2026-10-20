extends Node2D

static var qte := false

const SHEET_PATH := "res://docs/攻擊模組 - 攻擊模組.csv"
const STAGE_MIN := 80.0
const STAGE_MAX := 1200.0
const SLOW := 0.3
const PREVIEW_NOTES := {
	"普通1": "距離 90 以內、對方站著就會出。打中而且人還在範圍內，才接普通2。",
	"普通2": "只有普通1打中才接。人如果已經被打出範圍，這段不會出現。",
	"普通3": "只有普通2打中才接。這段打完就停，不會再自動連下去。",
	"滑鏟": "距離大約 120 到 250。靠近時大約每三次才鏟一次，其餘時間是走過去。",
	"蓄力": "只有對方被時停定住，而且距離在 120 以內。前搖很長，沒被定住就會被打斷。",
	"遠距離追擊": "只有對方踩香蕉、人還在滑，而且距離在 140 到 400。跑完仍夠不到就是打空。",
	"下落": "不是自己選的。彈簧把人大拋起來之後，下墜經過對方（水平 70 以內）才打中。",
	"香蕉": "放在地上。人要跑起來踩過才滑；站著踩沒事。滑行途中，另一人可以追擊。",
	"彈簧": "放在地上，踩到才彈。站著是小跳；跑著或出招時是大拋，下墜才可能打中。",
	"時停": "放下先亮圈。圈收起來時還站在裡面的人才定住。另一人若已在旁邊，會接著蓄力。",
}

var _sparks: Array[Dictionary] = []
var _moves: Dictionary = {}
var _items: Dictionary = {}
var _shake := 0.0
var _title: Label
var _hint: Label
var _prompt: Label
var _wash: ColorRect
var _tool := 0
var _phase := 0
var _flash_left := 0.0
var _spoiled := false
var _hold_release := false
var _big_cd := 1.4
var _preview := false
var _preview_id := ""
var _preview_buttons: Dictionary = {}
var _preview_row: Control
var _watch_button: Button
var _note: Label
var _phase_name: Label
var _bar_startup: ColorRect
var _bar_active: ColorRect
var _bar_recover: ColorRect
var _bar_head: ColorRect

@onready var left: Duelist = $Left
@onready var right: Duelist = $Right
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	_load_sheet()
	_build_hud()
	_title.text = "對峙"
	if not qte:
		left.time_scale = SLOW
		right.time_scale = SLOW
		right.busy = 0.35
		right.script_open = false


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.07, 0.08, 0.12))
	draw_rect(Rect2(0, 548, 1280, 172), Color(0.16, 0.17, 0.22))
	draw_rect(Rect2(0, 548, 1280, 6), Color(0.86, 0.83, 0.74))
	draw_rect(Rect2(628, 548, 24, 10), Color(0.82, 0.22, 0.16))


func _process(delta: float) -> void:
	if _big_cd > 0.0:
		_big_cd = maxf(_big_cd - delta, 0.0)
	if qte:
		_think(left, right)
		_think(right, left)
		_resolve_strikes()
	else:
		if _preview:
			_resolve_modules()
			_resolve_falls()
			_check_props()
			_tick_preview()
		else:
			_resolve_modules()
			_resolve_falls()
			_check_props()
			_think_open(left, right)
			_think_open(right, left)
	_tick_flash(delta)
	var kept: Array[Dictionary] = []
	for spark in _sparks:
		spark["t"] = float(spark["t"]) + delta * (SLOW if not qte else 1.0)
		var frame := int(float(spark["t"]) * 16.0)
		var node := spark["node"] as Sprite2D
		if frame >= 4 or node == null:
			if node != null:
				node.queue_free()
			continue
		node.region_rect = Rect2(frame * 64, 6 * 64, 64, 64)
		kept.append(spark)
	_sparks = kept
	if _shake > 0.0:
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		var fade := 40.0 * (SLOW if not qte else 1.0)
		_shake = move_toward(_shake, 0.0, delta * fade)
	else:
		camera.offset = Vector2.ZERO
	_refresh_hint()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_restart()
		elif event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		elif qte and event.keycode == KEY_F:
			_press_parry()
		elif not qte and event.keycode == KEY_1:
			_tool = 0
		elif not qte and event.keycode == KEY_2:
			_tool = 1
		elif not qte and event.keycode == KEY_3:
			_tool = 2
		elif not qte and event.keycode == KEY_TAB:
			_set_preview(not _preview)
	elif not qte and not _preview and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_place(get_global_mouse_position())


func _restart() -> void:
	_preview = false
	_preview_id = ""
	_show_preview(false)
	for node in get_tree().get_nodes_in_group("duel_prop"):
		node.queue_free()
	_phase = 0
	_flash_left = 0.0
	_spoiled = false
	_hold_release = false
	_big_cd = 1.4
	left.position = Vector2(260, 548)
	right.position = Vector2(1020, 548)
	left.face_right = true
	right.face_right = false
	left.relax()
	right.relax()
	if not qte:
		left.time_scale = SLOW
		right.time_scale = SLOW
		right.busy = 0.35
		right.script_open = false
	left.glow = 0
	right.glow = 0
	left.seq = 0
	right.seq = 1
	_title.text = "對峙"


func _think(body: Duelist, other: Duelist) -> void:
	if not body.can_act():
		return
	if body.anim == "down":
		_act(body, "getup", body.position.x)
		_title.text = "起身"
		return
	if qte and body == right and _hold_release:
		if _flash_left > 0.0:
			return
		_hold_release = false
		_phase = 0
		right.glow = 0
		body.plan = PackedStringArray()
		_lunge(body, other, "heavy")
		_title.text = "大招"
		return
	if qte and body == right and body.anim == "power":
		right.glow = 0
		_phase = 0
		if _spoiled:
			_spoiled = false
			_act(body, "idle", body.position.x)
			return
		_phase = 2
		_flash_left = 0.32
		_hold_release = true
		right.glow = 2
		return
	if body.plan.is_empty():
		_begin_plan(body, other)
	if body.plan.is_empty():
		return
	var step := body.plan[0]
	body.plan = body.plan.slice(1)
	_play_step(body, other, step)


func _begin_plan(body: Duelist, other: Duelist) -> void:
	var dist := absf(body.position.x - other.position.x)
	var plans := _plans(body, other, dist)
	body.plan = plans[body.seq % plans.size()]
	body.seq += 1
	_title.text = _plan_title(body.plan[0], other.exposed())


func _plans(body: Duelist, other: Duelist, dist: float) -> Array[PackedStringArray]:
	var armored := body == left
	if other.exposed():
		if dist > 260.0:
			if armored:
				return [["walk", "jab", "idle"], ["gun", "idle"]]
			return [["hop", "kick", "back"], ["gun", "back"]]
		if armored:
			return [["jab", "kick", "idle"], ["heavy", "back"], ["crouch", "strike", "idle"]]
		return [["kick", "back"], ["rapid", "idle"], ["slash", "hop", "back"]]
	if dist > 460.0:
		if armored:
			return [["walk", "walk"], ["gun", "walk"], ["walk", "idle"]]
		return [["gun", "walk"], ["walk", "walk"], ["run", "idle"]]
	if dist > 250.0:
		if armored:
			return [["walk", "jab"], ["walk", "idle", "slash"], ["gun"], ["power", "heavy"]]
		var mid: Array[PackedStringArray] = [["walk", "slash"], ["hop", "kick"], ["gun", "back"], ["run", "idle"]]
		if qte and _big_cd <= 0.0:
			mid.append(PackedStringArray(["power"]))
		return mid
	if armored:
		return [
			["jab", "jab", "kick", "idle"],
			["crouch", "mix", "back"],
			["power", "heavy", "idle"],
			["idle", "strike"],
			["slash", "back"],
		]
	var near: Array[PackedStringArray] = [
		["hop", "kick", "back"],
		["rapid", "jab", "idle"],
		["slash", "hop"],
		["back", "kick"],
		["idle", "strike", "back"],
		["power", "slash", "back"],
	]
	if qte and _big_cd <= 0.0:
		near.append(PackedStringArray(["power"]))
	return near


func _plan_title(step: String, pressing: bool) -> String:
	if pressing:
		return "追擊"
	match step:
		"crouch":
			return "下段"
		"power":
			return "蓄力"
		"gun":
			return "開火"
		"hop":
			return "跳攻"
		"rapid":
			return "連打"
		"back":
			return "拉開"
		"idle":
			return "對峙"
		"run":
			return "衝刺"
		_:
			return "對打"


func _play_step(body: Duelist, other: Duelist, step: String) -> void:
	if step == "back":
		var away := -1.0 if body.face_right else 1.0
		var dest := clampf(body.position.x + away * 150.0, 80.0, 1200.0)
		_act(body, "hop" if body == right else "walk", dest)
		return
	if step == "walk" or step == "run":
		_step_toward(body, other, step)
		return
	if step == "power" and qte and body == right:
		_big_cd = 3.4
		_spoiled = false
		_phase = 1
		right.glow = 1
		_title.text = "蓄力"
	if step in ["idle", "crouch", "power", "gun"]:
		_act(body, step, body.position.x)
		return
	_lunge(body, other, step)


func _step_toward(body: Duelist, other: Duelist, anim: String) -> void:
	var goal := _home(body, other, 140.0)
	var gap := goal - body.position.x
	if absf(gap) < 28.0:
		_act(body, "idle", body.position.x)
		return
	var chunk := 150.0 if anim == "run" else 78.0
	var dest := clampf(body.position.x + signf(gap) * minf(absf(gap), chunk), 80.0, 1200.0)
	_act(body, anim, dest)


func _lunge(body: Duelist, other: Duelist, move: String) -> void:
	_act(body, move, _home(body, other, 110.0))


func _act(body: Duelist, anim_name: String, x: float) -> void:
	body.go(anim_name, x, body.clip_cycle(anim_name))


func _home(body: Duelist, other: Duelist, gap: float) -> float:
	var side := 1.0 if body.face_right else -1.0
	return clampf(other.position.x - side * gap, 80.0, 1200.0)


func _other(body: Duelist) -> Duelist:
	return right if body == left else left


func _resolve_strikes() -> void:
	var swinging: Array[Duelist] = []
	for body in [left, right]:
		if body.strike_ready:
			body.strike_ready = false
			swinging.append(body)
	for attacker in swinging:
		_connect(attacker, _other(attacker))


func _connect(attacker: Duelist, defender: Duelist) -> void:
	var gap := defender.position.x - attacker.position.x
	var dist := absf(gap)
	var reach := 460.0 if attacker.anim == "gun" else 170.0
	if dist > reach:
		return
	var facing := 1.0 if attacker.face_right else -1.0
	if gap != 0.0 and signf(gap) != facing:
		return
	if defender.anim == "down" or (defender.reacting and defender.anim == "hit"):
		_spark(defender.chest())
		_shake = maxf(_shake, 5.0)
		return
	var hurt := "down" if attacker.anim in ["heavy", "slash", "gun", "mix"] else "hit"
	var push := 210.0 if hurt == "down" else 130.0
	var away := signf(gap) if gap != 0.0 else facing
	if not _hurt(defender, hurt, defender.position.x + away * push):
		return
	_spark(defender.chest())
	_shake = maxf(_shake, 11.0 if hurt == "down" else 6.0)
	_title.text = "擊倒" if hurt == "down" else "打中"


func _hurt(body: Duelist, anim_name: String, x: float) -> bool:
	if not body.react(anim_name, clampf(x, 80.0, 1200.0), 0.2, 0.5):
		return false
	body.plan = PackedStringArray()
	if body == right:
		_phase = 0
		_flash_left = 0.0
		_spoiled = false
		_hold_release = false
		right.glow = 0
	return true


func _spark(at: Vector2) -> void:
	var node := Sprite2D.new()
	node.texture = left.sheet
	node.centered = true
	node.region_enabled = true
	node.region_rect = Rect2(0, 6 * 64, 64, 64)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.scale = Vector2(4, 4)
	node.position = at
	node.z_index = 6
	add_child(node)
	_sparks.append({"node": node, "t": 0.0})


func _place(at: Vector2) -> void:
	if get_tree().get_nodes_in_group("duel_prop").size() >= 4:
		return
	var x := clampf(at.x, STAGE_MIN, STAGE_MAX)
	var prop := DuelProp.new()
	if _tool == 2 and _items.has("時停"):
		var row: Dictionary = _items["時停"]
		prop.kind = "stop"
		prop.wind = float(row["startup"])
		prop.radius = float(row["range"])
		prop.position = Vector2(x, 500)
	elif _tool == 1 and _items.has("彈簧"):
		var row: Dictionary = _items["彈簧"]
		prop.kind = "spring"
		prop.radius = float(row["range"])
		prop.life = 3.2
		prop.position = Vector2(x, 530)
	elif _items.has("香蕉"):
		var row: Dictionary = _items["香蕉"]
		prop.kind = "peel"
		prop.radius = float(row["range"])
		prop.life = 2.4
		prop.position = Vector2(x, 536)
	else:
		return
	add_child(prop)
	prop.time_scale = SLOW
	prop.add_to_group("duel_prop")


func _check_props() -> void:
	for node in get_tree().get_nodes_in_group("duel_prop"):
		var prop := node as DuelProp
		if prop == null:
			continue
		if prop.kind == "stop":
			if prop.ripe and not prop.spent:
				_resolve_stop(prop)
			continue
		if not prop.armed:
			continue
		for body in [left, right]:
			var who := body as Duelist
			if who.airborne or who.frozen > 0.0:
				continue
			if absf(who.position.x - prop.position.x) > prop.radius:
				continue
			if prop.kind == "peel" and _try_peel(who, prop):
				break
			if prop.kind == "spring" and _try_spring(who, prop):
				break


func _try_peel(body: Duelist, prop: DuelProp) -> bool:
	if not _items.has("香蕉") or body.slipping:
		return false
	var row: Dictionary = _items["香蕉"]
	if absf(body.vx) < float(row["speed_min"]):
		return false
	var dir := signf(body.vx)
	if dir == 0.0:
		dir = 1.0 if body.face_right else -1.0
	body.begin_slip(dir, float(row["kb"]), float(row["recover"]))
	prop.consume()
	_title.text = "%s滑倒" % body.display_name
	if _preview and _preview_id == "香蕉":
		var other := _other(body)
		var gap := absf(body.position.x - other.position.x)
		if other.can_act() and _band(gap, "遠距離追擊"):
			_play_module(other, body, "遠距離追擊")
	return true


func _try_spring(body: Duelist, prop: DuelProp) -> bool:
	if not _items.has("彈簧"):
		return false
	var row: Dictionary = _items["彈簧"]
	var fast := absf(body.vx) >= float(row["speed_min"]) or body.use_module
	var dir := signf(body.vx) if absf(body.vx) > 20.0 else (1.0 if body.face_right else -1.0)
	var lag := 0.12
	if fast and _moves.has("下落"):
		lag = float((_moves["下落"] as Dictionary)["recover"])
	if fast:
		body.launch_arc(dir * float(row["big_x"]), float(row["big_y"]), float(row["gravity"]), true, lag)
		_title.text = "大拋"
	else:
		body.launch_arc(dir * float(row["hop_x"]), float(row["hop_y"]), float(row["gravity"]), false, lag)
		_title.text = "小跳"
	prop.consume()
	return true


func _resolve_stop(prop: DuelProp) -> void:
	prop.spent = true
	if not _items.has("時停"):
		prop.queue_free()
		return
	var row: Dictionary = _items["時停"]
	var caught := 0
	for body in [left, right]:
		var who := body as Duelist
		if who.airborne or absf(who.position.x - prop.position.x) > prop.radius:
			continue
		who.frozen = maxf(who.frozen, float(row["active"]))
		who.chain = ""
		caught += 1
	_title.text = "定住" if caught > 0 else "落空"
	if _preview and _preview_id == "時停" and caught > 0 and left.can_act():
		_play_module(left, right, "蓄力")
	prop.queue_free()


func _resolve_modules() -> void:
	var swinging: Array[Dictionary] = []
	for body in [left, right]:
		var attacker := body as Duelist
		if not attacker.strike_ready or attacker.sheet_move.is_empty():
			continue
		attacker.strike_ready = false
		swinging.append({"body": attacker, "move": attacker.sheet_move.duplicate()})
	for swing in swinging:
		var attacker := swing["body"] as Duelist
		var m: Dictionary = swing["move"]
		var defender := _other(attacker)
		if not _facing_hit(attacker, defender, float(m["range"])):
			attacker.chain = ""
			_title.text = "打空"
			continue
		_land_hit(attacker, defender, m)


func _resolve_falls() -> void:
	if not _moves.has("下落"):
		return
	var m: Dictionary = _moves["下落"]
	for body in [left, right]:
		var attacker := body as Duelist
		if not attacker.airborne or not attacker.big_launch or attacker.vy <= 0.0 or attacker.fall_spent:
			continue
		var defender := _other(attacker)
		if absf(attacker.position.x - defender.position.x) > float(m["range"]):
			continue
		attacker.fall_spent = true
		_land_hit(attacker, defender, m)
		_title.text = "下落"


func _think_open(body: Duelist, other: Duelist) -> void:
	if body.just_landed:
		var big := body.land_big
		var hit := body.land_hit
		body.just_landed = false
		if not hit:
			_title.text = "大拋落空" if big else "小跳"
	if not body.can_act():
		return
	if body.anim == "down":
		body.face_right = other.position.x >= body.position.x
		body.go("getup", body.position.x, body.clip_cycle("getup"))
		_title.text = "起身"
		return
	if body.chain != "":
		var nxt := body.chain
		body.chain = ""
		if _chain_ok(body, other, nxt):
			_play_module(body, other, nxt)
			return
	var id := _pick(body, other)
	if id == "":
		_approach(body, other)
		return
	_play_module(body, other, id)


func _pick(body: Duelist, other: Duelist) -> String:
	if _moves.is_empty():
		return ""
	var dist := absf(body.position.x - other.position.x)
	if other.slipping and _band(dist, "遠距離追擊"):
		return "遠距離追擊"
	if other.frozen > 0.0:
		if _band(dist, "蓄力"):
			return "蓄力"
		return ""
	if _victim_locked(other):
		return ""
	if _band(dist, "普通1"):
		return "普通1"
	# 中距離不是每次都鏟，否則會一路滑過去，普通攻擊沒有出手的空檔。
	if _band(dist, "滑鏟"):
		body.seq += 1
		if body.seq % 3 == 0:
			return "滑鏟"
	return ""


func _band(dist: float, id: String) -> bool:
	if not _moves.has(id):
		return false
	var m: Dictionary = _moves[id]
	return dist >= float(m["near"]) and dist <= float(m["far"])


func _victim_locked(other: Duelist) -> bool:
	return other.reacting or other.slipping or other.airborne or other.anim in ["down", "getup"]


func _chain_ok(body: Duelist, other: Duelist, id: String) -> bool:
	if not _moves.has(id):
		return false
	var m: Dictionary = _moves[id]
	if other.frozen > 0.0 and str(m["start"]) == "follow":
		return true
	return absf(body.position.x - other.position.x) <= float(m["range"]) + 4.0


func _play_module(body: Duelist, other: Duelist, id: String) -> void:
	if not _moves.has(id):
		return
	var m: Dictionary = _moves[id]
	var gap := other.position.x - body.position.x
	var dist := absf(gap)
	var dir := signf(gap) if gap != 0.0 else (1.0 if body.face_right else -1.0)
	body.face_right = dir > 0.0
	var dest := body.position.x
	var move_time := 0.0
	var anim := str(m["anim"])
	var follow := ""
	var travel := str(m["travel"])
	if travel == "slide":
		var step := minf(float(m["travel_max"]), maxf(dist - 48.0, 0.0))
		dest = clampf(body.position.x + dir * step, STAGE_MIN, STAGE_MAX)
		move_time = float(m["startup"])
	elif travel == "chase":
		var step := minf(float(m["travel_max"]), maxf(dist - float(m["range"]), 0.0))
		dest = clampf(body.position.x + dir * step, STAGE_MIN, STAGE_MAX)
		move_time = float(m["startup"])
		anim = "run"
		follow = "strike"
	elif id == "蓄力":
		anim = "power"
		follow = "heavy"
	var busy := float(m["startup"]) + float(m["active"]) + float(m["recover"])
	body.chain = ""
	body.sheet_move = m.duplicate()
	body.start_module(anim, dest, busy, move_time, float(m["startup"]), follow)
	_title.text = _move_title(id)


func _approach(body: Duelist, other: Duelist) -> void:
	var gap := other.position.x - body.position.x
	var dist := absf(gap)
	if gap == 0.0 or dist <= 90.0:
		body.go("idle", body.position.x, 0.2)
		return
	var dir := signf(gap)
	body.face_right = dir > 0.0
	var step := minf(dist - 90.0, 90.0)
	var dest := clampf(body.position.x + dir * step, STAGE_MIN, STAGE_MAX)
	body.go("walk", dest, 0.3)


func _facing_hit(attacker: Duelist, defender: Duelist, reach: float) -> bool:
	var gap := defender.position.x - attacker.position.x
	if absf(gap) > reach:
		return false
	var facing := 1.0 if attacker.face_right else -1.0
	if gap != 0.0 and signf(gap) != facing:
		return false
	return true


func _land_hit(attacker: Duelist, defender: Duelist, m: Dictionary) -> void:
	var gap := defender.position.x - attacker.position.x
	var facing := 1.0 if attacker.face_right else -1.0
	var away := signf(gap) if gap != 0.0 else facing
	var dest := clampf(defender.position.x + away * float(m["kb"]), STAGE_MIN, STAGE_MAX)
	var pose := "down" if float(m["damage"]) >= 3.0 else "hit"
	if not defender.react(pose, dest, 0.0, 0.0, true, float(m["stun"])):
		return
	defender.plan = PackedStringArray()
	var stop := float(m["hitstop"])
	attacker.hitstop = maxf(attacker.hitstop, stop)
	defender.hitstop = maxf(defender.hitstop, stop)
	_shake = maxf(_shake, lerpf(4.0, 14.0, clampf(stop / 0.10, 0.0, 1.0)))
	_spark(defender.chest())
	var nxt := str(m["chain"])
	if nxt != "" and not attacker.airborne:
		attacker.chain = nxt
		attacker.leave_active(float(m["active"]))
	else:
		attacker.chain = ""
	_title.text = "擊倒" if pose == "down" else "打中"


func _move_title(id: String) -> String:
	match id:
		"普通1", "普通2", "普通3":
			return "普通攻擊"
		"滑鏟":
			return "滑鏟"
		"蓄力":
			return "蓄力"
		"遠距離追擊":
			return "追擊"
		"下落":
			return "下落"
		_:
			return "對打"


func _load_sheet() -> void:
	var file := FileAccess.open(SHEET_PATH, FileAccess.READ)
	if file == null:
		push_error("讀不到攻擊模組表")
		return
	var header := file.get_csv_line()
	var col := {}
	for i in header.size():
		var title := header[i].strip_edges().trim_prefix("\ufeff")
		col[title] = i
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.is_empty() or cells[0].strip_edges() == "":
			continue
		var row := {
			"kind": _cell(cells, col, "類型"),
			"id": _cell(cells, col, "模組"),
			"anim": _cell(cells, col, "動畫"),
			"startup": _num(cells, col, "前搖"),
			"active": _num(cells, col, "有效"),
			"recover": _num(cells, col, "後搖"),
			"range": _num(cells, col, "接觸範圍"),
			"damage": _num(cells, col, "傷害"),
			"stun": _num(cells, col, "受擊時長"),
			"kb": _num(cells, col, "擊退"),
			"hitstop": _num(cells, col, "頓幀"),
			"travel": _cell(cells, col, "位移"),
			"travel_max": _num(cells, col, "位移上限"),
			"start": _cell(cells, col, "啟動"),
			"chain": _cell(cells, col, "打中可接"),
			"near": _num(cells, col, "最近"),
			"far": _num(cells, col, "最遠"),
			"speed_min": _num(cells, col, "速度門檻"),
			"hop_x": _num(cells, col, "水平"),
			"hop_y": _num(cells, col, "向上"),
			"big_x": _num(cells, col, "大拋水平"),
			"big_y": _num(cells, col, "大拋向上"),
			"gravity": _num(cells, col, "重力"),
		}
		if str(row["id"]) == "":
			continue
		if str(row["kind"]) == "道具":
			_items[row["id"]] = row
		else:
			_moves[row["id"]] = row
	file.close()


func _cell(cells: PackedStringArray, col: Dictionary, name: String) -> String:
	if not col.has(name):
		return ""
	var i := int(col[name])
	if i < 0 or i >= cells.size():
		return ""
	return cells[i].strip_edges()


func _num(cells: PackedStringArray, col: Dictionary, name: String) -> float:
	var text := _cell(cells, col, name)
	if text == "":
		return 0.0
	return float(text)


func _tick_flash(delta: float) -> void:
	if _prompt == null:
		return
	if _phase == 2:
		_prompt.visible = true
		var pulse := 0.4 + 0.6 * absf(sin(Time.get_ticks_msec() * 0.03))
		_prompt.modulate.a = pulse
		_wash.color = Color(1, 0.94, 0.6, 0.05 + 0.12 * pulse)
		_flash_left -= delta
		if _flash_left <= 0.0:
			_phase = 0
			if right.glow == 2:
				right.glow = 0
	else:
		_prompt.visible = false
		_wash.color = Color(1, 1, 1, 0)


func _press_parry() -> void:
	if _phase == 1:
		_spoiled = true
		_phase = 0
		right.glow = 0
		_title.text = "太早"
		return
	if _phase != 2:
		return
	_phase = 0
	_flash_left = 0.0
	_hold_release = false
	right.glow = 0
	var away := 170.0 if right.position.x >= left.position.x else -170.0
	_hurt(right, "hit", right.position.x + away)
	if left.can_act():
		_act(left, "strike", left.position.x)
	_spark(right.chest())
	_shake = maxf(_shake, 10.0)
	_title.text = "格開"


func _refresh_hint() -> void:
	if _hint == null:
		return
	if qte:
		_hint.text = "卸甲的大招會先亮橙圈。金圈閃起時按 F 格開，太早按會落空。    Esc 回節目    R 重看"
	else:
		var labels: PackedStringArray = PackedStringArray(["1 香蕉", "2 彈簧", "3 時停"])
		var bits: PackedStringArray = PackedStringArray()
		for i in labels.size():
			if i == _tool:
				bits.append("【%s】" % labels[i])
			else:
				bits.append(labels[i])
		_hint.text = "%s    Tab 拆開看    點地面放下    Esc 回節目    R 重看" % "    ".join(bits)
		if _preview:
			_hint.text = "選上面的招單獨看。Tab 回到對打。    Esc 回節目"


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei UI", "Microsoft JhengHei", "Microsoft YaHei"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 20
	root.theme = theme
	layer.add_child(root)

	var left_name := _name_label(left.display_name, false, Color(0.93, 0.94, 0.97))
	root.add_child(left_name)
	var right_name := _name_label(right.display_name, true, Color(0.96, 0.78, 0.62))
	root.add_child(right_name)

	_title = Label.new()
	_title.position = Vector2(280, 78)
	_title.size = Vector2(720, 48)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_font_size_override("font_size", 36)
	_title.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
	root.add_child(_title)

	var hint := Label.new()
	hint.text = ""
	hint.position = Vector2(40, 672)
	hint.size = Vector2(1200, 32)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.75, 0.76, 0.8))
	root.add_child(hint)
	_hint = hint

	_wash = ColorRect.new()
	_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash.color = Color(1, 1, 1, 0)
	root.add_child(_wash)
	_prompt = Label.new()
	_prompt.text = "F"
	_prompt.position = Vector2(540, 210)
	_prompt.size = Vector2(200, 120)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_theme_font_size_override("font_size", 96)
	_prompt.add_theme_color_override("font_color", Color(1, 0.92, 0.45))
	root.add_child(_prompt)
	_build_preview(root)


func _build_preview(root: Control) -> void:
	_watch_button = Button.new()
	_watch_button.text = "拆開看"
	_watch_button.position = Vector2(40, 118)
	_watch_button.size = Vector2(120, 36)
	_watch_button.focus_mode = Control.FOCUS_NONE
	_watch_button.visible = not qte
	_watch_button.pressed.connect(func() -> void: _set_preview(not _preview))
	root.add_child(_watch_button)

	_preview_row = Control.new()
	_preview_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_row.visible = false
	root.add_child(_preview_row)
	var specs: Array[PackedStringArray] = [
		PackedStringArray(["普通1", "普通1"]),
		PackedStringArray(["普通2", "普通2"]),
		PackedStringArray(["普通3", "普通3"]),
		PackedStringArray(["滑鏟", "滑鏟"]),
		PackedStringArray(["蓄力", "蓄力"]),
		PackedStringArray(["追擊", "遠距離追擊"]),
		PackedStringArray(["下落", "下落"]),
		PackedStringArray(["香蕉", "香蕉"]),
		PackedStringArray(["彈簧", "彈簧"]),
		PackedStringArray(["時停", "時停"]),
	]
	for i in specs.size():
		var spec := specs[i]
		var column := i % 7
		var row := int(i / 7.0)
		var button := Button.new()
		button.text = spec[0]
		button.position = Vector2(244 + column * 114, row * 42)
		button.size = Vector2(108, 36)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_preview_play.bind(spec[1]))
		_preview_row.add_child(button)
		_preview_buttons[spec[1]] = button
	_preview_row.position = Vector2(0, 136)

	_note = Label.new()
	_note.visible = false
	_note.position = Vector2(80, 228)
	_note.size = Vector2(1120, 52)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.add_theme_font_size_override("font_size", 18)
	_note.add_theme_color_override("font_color", Color(0.9, 0.88, 0.78))
	root.add_child(_note)

	_phase_name = Label.new()
	_phase_name.visible = false
	_phase_name.position = Vector2(260, 572)
	_phase_name.size = Vector2(760, 28)
	_phase_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_name.add_theme_font_size_override("font_size", 18)
	_phase_name.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
	root.add_child(_phase_name)
	_bar_startup = _phase_block(root, Color(0.45, 0.38, 0.16))
	_bar_active = _phase_block(root, Color(0.42, 0.16, 0.12))
	_bar_recover = _phase_block(root, Color(0.18, 0.24, 0.34))
	_bar_head = _phase_block(root, Color(0.96, 0.94, 0.88))


func _phase_block(root: Control, ink: Color) -> ColorRect:
	var block := ColorRect.new()
	block.visible = false
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.color = ink
	root.add_child(block)
	return block


func _set_preview(on: bool) -> void:
	if on == _preview:
		return
	if not on:
		_restart()
		return
	_preview = true
	_preview_id = ""
	_show_preview(true)
	_park(160.0)
	_title.text = "選一招"
	_note.text = "每一招單獨重播。下面的條把前搖、有效、後搖拆開。"
	_mark_preview("")


func _show_preview(on: bool) -> void:
	if _preview_row != null:
		_preview_row.visible = on
	if _note != null:
		_note.visible = on
	for node in [_phase_name, _bar_startup, _bar_active, _bar_recover, _bar_head]:
		if node != null:
			node.visible = on
	if _watch_button != null:
		_watch_button.text = "回對打" if on else "拆開看"


func _mark_preview(id: String) -> void:
	for key in _preview_buttons:
		var button := _preview_buttons[key] as Button
		if button == null:
			continue
		button.modulate = Color(1, 0.92, 0.55) if str(key) == id else Color(1, 1, 1)


func _preview_play(id: String) -> void:
	if not _preview:
		_set_preview(true)
	_preview_id = id
	_mark_preview(id)
	_note.text = str(PREVIEW_NOTES.get(id, ""))
	match id:
		"普通1", "普通2", "普通3":
			_park(80.0)
			_play_module(left, right, id)
		"滑鏟":
			_park(180.0)
			_play_module(left, right, id)
		"蓄力":
			_park(100.0)
			_play_module(left, right, id)
		"遠距離追擊":
			_park(280.0)
			_play_module(left, right, id)
		"下落":
			_park(80.0)
			_launch_preview()
		"香蕉":
			_park(240.0)
			_drop_demo("peel", left.position.x + 80.0)
			left.go("walk", right.position.x - 90.0, 0.45)
		"彈簧":
			_park(220.0)
			_drop_demo("spring", left.position.x + 70.0)
			left.go("walk", right.position.x - 90.0, 0.45)
		"時停":
			_park(100.0)
			_drop_demo("stop", right.position.x)
	if _moves.has(id):
		_title.text = _move_title(id)
	else:
		_title.text = id


func _park(dist: float) -> void:
	for node in get_tree().get_nodes_in_group("duel_prop"):
		node.queue_free()
	left.position = Vector2(640.0 - dist * 0.5, 548)
	right.position = Vector2(640.0 + dist * 0.5, 548)
	left.face_right = true
	right.face_right = false
	left.relax()
	right.relax()
	left.time_scale = SLOW
	right.time_scale = SLOW


func _drop_demo(kind: String, x: float) -> void:
	var prop := DuelProp.new()
	prop.time_scale = SLOW
	if kind == "stop" and _items.has("時停"):
		var row: Dictionary = _items["時停"]
		prop.kind = "stop"
		prop.wind = float(row["startup"])
		prop.radius = float(row["range"])
		prop.position = Vector2(x, 500)
	elif kind == "spring" and _items.has("彈簧"):
		var row: Dictionary = _items["彈簧"]
		prop.kind = "spring"
		prop.radius = float(row["range"])
		prop.life = 4.0
		prop.position = Vector2(x, 530)
	elif _items.has("香蕉"):
		var row: Dictionary = _items["香蕉"]
		prop.kind = "peel"
		prop.radius = float(row["range"])
		prop.life = 4.0
		prop.position = Vector2(x, 536)
	else:
		return
	add_child(prop)
	prop.add_to_group("duel_prop")


func _launch_preview() -> void:
	if not _items.has("彈簧"):
		return
	var row: Dictionary = _items["彈簧"]
	var lag := 0.12
	if _moves.has("下落"):
		lag = float((_moves["下落"] as Dictionary)["recover"])
	left.face_right = true
	left.launch_arc(float(row["big_x"]), float(row["big_y"]), float(row["gravity"]), true, lag)
	_title.text = "大拋"


func _tick_preview() -> void:
	var moving := left
	if not left.use_module and not left.airborne and not left.slipping and (right.use_module or right.slipping):
		moving = right
	var phase := ""
	var age := 0.0
	var shown: Dictionary = {}
	if moving.airborne and moving.big_launch:
		phase = "上升" if moving.vy < 0.0 else "下墜"
		if _moves.has("下落"):
			shown = _moves["下落"]
			age = 0.0 if moving.vy < 0.0 else float(shown["active"]) * 0.5
	elif moving.slipping:
		phase = "滑行"
	elif moving.frozen > 0.0 and not moving.use_module:
		phase = "定住"
	elif moving.use_module and not moving.sheet_move.is_empty():
		shown = moving.sheet_move
		age = moving.action_age
		var startup := float(shown["startup"])
		var active := float(shown["active"])
		if age < startup:
			phase = "前搖"
		elif age < startup + active:
			phase = "有效"
		else:
			phase = "後搖"
	elif _moves.has(_preview_id):
		shown = _moves[_preview_id]
		age = float(shown["startup"]) + float(shown["active"]) + float(shown["recover"])
	if _phase_name != null:
		_phase_name.text = phase
	_paint_bar(shown, age, phase)


func _paint_bar(shown: Dictionary, age: float, phase: String) -> void:
	if _bar_startup == null:
		return
	var startup := float(shown["startup"]) if not shown.is_empty() else 0.0
	var active := float(shown["active"]) if not shown.is_empty() else 0.0
	var recover := float(shown["recover"]) if not shown.is_empty() else 0.0
	var total := maxf(startup + active + recover, 0.01)
	var width := 760.0
	var origin := 260.0
	_bar_startup.position = Vector2(origin, 608)
	_bar_startup.size = Vector2(width * startup / total, 16)
	_bar_active.position = Vector2(origin + _bar_startup.size.x, 608)
	_bar_active.size = Vector2(width * active / total, 16)
	_bar_recover.position = Vector2(_bar_active.position.x + _bar_active.size.x, 608)
	_bar_recover.size = Vector2(maxf(width - _bar_startup.size.x - _bar_active.size.x, 0.0), 16)
	_bar_head.position = Vector2(origin + width * clampf(age / total, 0.0, 1.0) - 2.0, 602)
	_bar_head.size = Vector2(4, 28)
	_bar_startup.color = Color(0.95, 0.78, 0.28) if phase == "前搖" else Color(0.45, 0.38, 0.16)
	_bar_active.color = Color(0.92, 0.32, 0.18) if phase == "有效" else Color(0.42, 0.16, 0.12)
	_bar_recover.color = Color(0.45, 0.62, 0.86) if phase == "後搖" else Color(0.18, 0.24, 0.34)


func _name_label(title: String, align_right: bool, ink: Color) -> Label:
	var label := Label.new()
	label.text = title
	label.position = Vector2(1000, 28) if align_right else Vector2(40, 28)
	label.size = Vector2(240, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if align_right else HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", ink)
	return label
