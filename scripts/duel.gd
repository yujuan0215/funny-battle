extends Node2D

static var qte := false
static var brawl := false
static var brawl_count := 4
static var show_hp := true

const SHEET_PATH := "res://docs/攻擊模組 - 攻擊模組.csv"
const STAGE_MIN := 80.0
const STAGE_MAX := 1200.0
const SLOW := 0.3
const NORMAL := 1.0
var _pace := SLOW
const PREVIEW_NOTES := {
	"普通1": "距離 90 以內、對方站著就會出。打中而且人還在範圍內，才接普通2。",
	"普通2": "只有普通1打中才接。人如果已經被打出範圍，這段不會出現。",
	"普通3": "只有普通2打中才接。這段打完就停，不會再自動連下去。",
	"滑鏟": "對打不會自己出。只有朝對方跑、距離超過 140 時踩到香蕉，才沿著跑的方向滑鏟。",
	"遠距離普攻": "只有對方被時停定住，而且距離在 90 到 250。站著直接開火，槍口紅點那格才打中。比 90 更近會出拳，比 250 更遠會改蓄力。",
	"蓄力": "只有對方被時停定住，而且距離在 250 到 460。人站在原地蓄力，不用走近。比 250 更近會改成開火。",
	"遠距離追擊": "只有對方踩香蕉滑倒、人還在滑，而且距離在 140 到 400。跑完仍夠不到就是打空。",
	"下落": "上升先收膝，到最高點才把踢擊打出。下墜時水平 70 以內才打中。",
	"香蕉滑鏟": "朝對方跑、距離超過 140 時踩到。沿著跑的方向滑鏟，不會變成滑倒。",
	"香蕉滑倒": "距離不超過 140，或不是朝對方跑。人直接滑倒；站著踩則什麼都不會發生。",
	"彈簧": "踩到才彈。站著是小跳；跑著或出招時是大拋。大拋上升收膝，到最高點才踢出。",
	"時停": "放下先亮圈。圈收起來時還站在裡面的人才定住。另一人在 90 到 250 會開火，250 到 460 會蓄力。",
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
var _cool: Array[float] = [0.0, 0.0, 0.0]
var _rack
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
var _pace_button: Button
var _note: Label
var _phase_name: Label
var _bar_startup: ColorRect
var _bar_active: ColorRect
var _bar_recover: ColorRect
var _bar_head: ColorRect
var _cast_buttons: Dictionary = {}
const _STAGE := preload("res://scripts/stage_edit.gd")
const _RACK := preload("res://scripts/tool_rack.gd")
const TOOL_COOL: Array[float] = [1.6, 2.0, 2.4]

var _beam_was := false
var _stage
var _ground_button: Button
var _hp_button: Button
var _count_button: Button
var _extras: Array[Duelist] = []
var _goal: Duelist
var _brawl_over := false

@onready var left: Duelist = $Left
@onready var right: Duelist = $Right
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	_load_sheet()
	_stage = _STAGE.new()
	add_child(_stage)
	_build_hud()
	_title.text = "對峙"
	if not qte:
		_apply_pace()
		right.busy = 0.35
		right.script_open = false
	if brawl and not qte:
		_open_brawl()
	_apply_hp_flags()


func _draw() -> void:
	if _stage == null:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.07, 0.08, 0.12))
		draw_rect(Rect2(0, 548, 1280, 172), Color(0.16, 0.17, 0.22))
		draw_rect(Rect2(0, 548, 1280, 6), Color(0.86, 0.83, 0.74))
		draw_rect(Rect2(628, 548, 24, 10), Color(0.82, 0.22, 0.16))
	if qte:
		return
	for body in _bodies():
		_draw_beam(body)


func _beam_on(body: Duelist) -> bool:
	return body != null and body.firing_beam()


func _draw_beam(body: Duelist) -> void:
	if not _beam_on(body):
		return
	var other := _other(body)
	var facing := 1.0 if body.face_right else -1.0
	for tip in body.glove_tips():
		var end_x := other.position.x - facing * 36.0
		if (end_x - tip.x) * facing < 12.0:
			continue
		var origin := tip
		var dest := Vector2(end_x, tip.y)
		draw_line(origin, dest, Color(0.72, 0.05, 0.04, 0.95), 7.0)
		draw_line(origin, dest, Color(0.95, 0.16, 0.1), 4.0)
		draw_line(origin, dest, Color(1.0, 0.72, 0.62), 1.5)


func _process(delta: float) -> void:
	if _big_cd > 0.0:
		_big_cd = maxf(_big_cd - delta, 0.0)
	for i in _cool.size():
		_cool[i] = maxf(_cool[i] - delta, 0.0)
	if qte:
		_think(left, right)
		_think(right, left)
		_resolve_strikes()
	else:
		_resolve_modules()
		_resolve_falls()
		_check_props()
		if _preview:
			_tick_preview()
		elif brawl:
			_think_brawl()
		else:
			_think_open(left, right)
			_think_open(right, left)
	_tick_flash(delta)
	if not _sparks.is_empty():
		var kept: Array[Dictionary] = []
		for spark in _sparks:
			spark["t"] = float(spark["t"]) + delta * (_pace if not qte else 1.0)
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
		var fade := 40.0 * (_pace if not qte else 1.0)
		_shake = move_toward(_shake, 0.0, delta * fade)
	else:
		camera.offset = Vector2.ZERO
	var beam := false
	for body in _bodies():
		if _beam_on(body):
			beam = true
			break
	if beam or _beam_was:
		queue_redraw()
	_beam_was = beam
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
		elif not qte and event.keycode == KEY_H:
			_toggle_hp()
		elif not qte and not brawl and event.keycode == KEY_TAB:
			_set_preview(not _preview)
		elif event.keycode == KEY_G and _stage != null:
			_set_ground_edit(not _stage.editing)
		elif event.keycode == KEY_T and _stage != null and _stage.editing:
			_stage.toggle_tilt()
	elif _stage != null and _stage.editing and event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT and mouse.button_index != MOUSE_BUTTON_RIGHT:
			return
		if mouse.pressed:
			_stage.press(get_global_mouse_position(), mouse.button_index == MOUSE_BUTTON_RIGHT)
		else:
			_stage.release()
	elif _stage != null and _stage.editing and event is InputEventMouseMotion:
		_stage.drag(get_global_mouse_position())
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
	_stand(left)
	_stand(right)
	left.face_right = true
	right.face_right = false
	left.relax()
	right.relax()
	if not qte:
		_apply_pace()
		right.busy = 0.35
		right.script_open = false
	left.glow = 0
	right.glow = 0
	_brawl_over = false
	if brawl:
		_place_brawl()
	_cool.fill(0.0)
	left.seq = 0
	right.seq = 1
	_title.text = "對峙"
	if brawl and _goal != null:
		_title.text = "讓%s贏" % _goal.display_name


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
	if not brawl:
		return right if body == left else left
	var facing := 1.0 if body.face_right else -1.0
	var front: Duelist = null
	var front_d := 100000.0
	var any: Duelist = null
	var any_d := 100000.0
	for rival in _bodies():
		if rival == body or rival.out:
			continue
		var gap := rival.position.x - body.position.x
		var dist := absf(gap)
		if dist < any_d:
			any_d = dist
			any = rival
		if gap == 0.0 or signf(gap) == facing:
			if dist < front_d:
				front_d = dist
				front = rival
	if front != null:
		return front
	if any != null:
		return any
	return right if body == left else left


func _bodies() -> Array[Duelist]:
	var list: Array[Duelist] = [left, right]
	for body in _extras:
		if is_instance_valid(body):
			list.append(body)
	return list


func _think_brawl() -> void:
	if _brawl_over:
		return
	var living: Array[Duelist] = []
	for body in _bodies():
		if not body.out:
			living.append(body)
	if living.size() <= 1:
		_brawl_over = true
		if living.is_empty():
			_title.text = "平手"
		elif living[0].goal:
			_title.text = "%s贏了" % living[0].display_name
		else:
			_title.text = "%s贏了，目標沒成" % living[0].display_name
		return
	for body in living:
		_think_open(body, _other(body))


func _open_brawl() -> void:
	for body in _extras:
		if is_instance_valid(body):
			body.queue_free()
	_extras.clear()
	var count := clampi(brawl_count, 3, 4)
	brawl_count = count
	left.use_sheet("armor")
	left.display_name = "藍甲"
	left.bare = false
	left.goal = false
	right.use_sheet("yellow")
	right.display_name = "黃髮"
	right.bare = false
	right.goal = true
	_goal = right
	if count >= 4:
		var fourth := _make_brawler("bare", "卸甲")
		_extras.append(fourth)
	var silver := _make_brawler("silver", "銀髮")
	_extras.append(silver)
	_place_brawl()
	_title.text = "讓黃髮贏"
	if _count_button != null:
		_count_button.text = "改成三人" if count >= 4 else "改成四人"


func _make_brawler(sheet_id: String, who: String) -> Duelist:
	var body := Duelist.new()
	body.display_name = who
	body.position = Vector2(640, 548)
	add_child(body)
	body.use_sheet(sheet_id)
	body.show_hp = show_hp
	return body


func _place_brawl() -> void:
	var spots: Array[float] = []
	if brawl_count <= 3:
		spots.append(220.0)
		spots.append(640.0)
		spots.append(1060.0)
	else:
		spots.append(160.0)
		spots.append(480.0)
		spots.append(800.0)
		spots.append(1080.0)
	var roster := _bodies()
	for i in roster.size():
		if i >= spots.size():
			break
		var body := roster[i]
		body.position = Vector2(spots[i], 548)
		_stand(body)
		body.face_right = body.position.x < 640.0
		body.goal = body == _goal
		body.relax()
		body.show_hp = show_hp
		body.busy = 0.12 * float(i)
		body.script_open = false
		body.seq = i


func _apply_hp_flags() -> void:
	for body in _bodies():
		body.show_hp = show_hp
	if _hp_button != null:
		_hp_button.text = "血量開" if show_hp else "血量關"


func _toggle_hp() -> void:
	show_hp = not show_hp
	_apply_hp_flags()


func _toggle_brawl_count() -> void:
	brawl_count = 3 if brawl_count >= 4 else 4
	_open_brawl()
	_brawl_over = false
	_cool.fill(0.0)


func ground_height(x: float, feet_y: float = -1.0) -> float:
	if _stage == null:
		return 548.0
	return _stage.support_at(x, 548.0 if feet_y < 0.0 else feet_y)


func _stand(body: Duelist) -> void:
	var y := ground_height(body.position.x, body.position.y)
	body.ground_y = y
	body.position.y = y


func _prop_at(kind: String, x: float, feet_y: float = -1.0) -> Vector2:
	var y := ground_height(x, feet_y)
	if kind == "stop":
		return Vector2(x, y - 48.0)
	if kind == "spring":
		return Vector2(x, y - 18.0)
	return Vector2(x, y - 12.0)


func _set_ground_edit(on: bool) -> void:
	if _stage == null:
		return
	_stage.editing = on
	_stage.release()
	_stage.queue_redraw()
	if _ground_button != null:
		_ground_button.text = "離開地形" if on else "地形"
	_refresh_hint()


func _resolve_strikes() -> void:
	var swinging: Array[Duelist] = []
	for body in _bodies():
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
		_spark(defender.chest(), attacker.sheet)
		_shake = maxf(_shake, 5.0)
		return
	var hurt := "down" if attacker.anim in ["heavy", "slash", "gun", "mix"] else "hit"
	var push := 210.0 if hurt == "down" else 130.0
	var away := signf(gap) if gap != 0.0 else facing
	if not _hurt(defender, hurt, defender.position.x + away * push):
		return
	_spark(defender.chest(), attacker.sheet)
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


func _spark(at: Vector2, texture: Texture2D = null) -> void:
	var node := Sprite2D.new()
	node.texture = texture if texture != null else left.sheet
	node.centered = true
	node.region_enabled = true
	node.region_rect = Rect2(0, 6 * 64, 64, 64)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.scale = Vector2(4, 4)
	node.position = at
	node.z_index = 6
	add_child(node)
	_sparks.append({"node": node, "t": 0.0})


func pick_tool(index: int) -> void:
	_tool = clampi(index, 0, 2)
	_refresh_hint()


func _place(at: Vector2) -> void:
	if _tool >= 0 and _tool < _cool.size() and _cool[_tool] > 0.0:
		return
	if get_tree().get_nodes_in_group("duel_prop").size() >= 4:
		return
	var x := clampf(at.x, STAGE_MIN, STAGE_MAX)
	var prop := DuelProp.new()
	if _tool == 2 and _items.has("時停"):
		var row: Dictionary = _items["時停"]
		prop.kind = "stop"
		prop.wind = float(row["startup"])
		prop.radius = float(row["range"])
		prop.position = _prop_at("stop", x, at.y)
	elif _tool == 1 and _items.has("彈簧"):
		var row: Dictionary = _items["彈簧"]
		prop.kind = "spring"
		prop.radius = float(row["range"])
		prop.life = 3.2
		prop.position = _prop_at("spring", x, at.y)
	elif _items.has("香蕉"):
		var row: Dictionary = _items["香蕉"]
		prop.kind = "peel"
		prop.radius = float(row["range"])
		prop.life = 2.4
		prop.position = _prop_at("peel", x, at.y)
	else:
		return
	add_child(prop)
	prop.time_scale = _pace
	prop.add_to_group("duel_prop")
	if _tool >= 0 and _tool < _cool.size():
		_cool[_tool] = TOOL_COOL[_tool]


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
		for body in _bodies():
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
	var other := _other(body)
	var gap := other.position.x - body.position.x
	var toward := gap != 0.0 and signf(body.vx) == signf(gap)
	var far_line := 140.0
	if _moves.has("遠距離追擊"):
		far_line = float((_moves["遠距離追擊"] as Dictionary)["near"])
	if toward and absf(gap) > far_line and _moves.has("滑鏟"):
		prop.consume()
		_play_module(body, other, "滑鏟")
		_title.text = "滑鏟"
		return true
	body.begin_slip(dir, float(row["kb"]), float(row["recover"]))
	prop.consume()
	_title.text = "%s滑倒" % body.display_name
	if _preview and _preview_id == "香蕉滑倒":
		var apart := absf(body.position.x - other.position.x)
		if other.can_act() and _band(apart, "遠距離追擊"):
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
	for body in _bodies():
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
	for body in _bodies():
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
	for body in _bodies():
		var attacker := body as Duelist
		if not attacker.airborne or not attacker.big_launch or not attacker.fall_armed or attacker.fall_spent:
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
		if _band(dist, "遠距離普攻"):
			return "遠距離普攻"
		if _band(dist, "蓄力"):
			return "蓄力"
		if _moves.has("蓄力") and dist > float((_moves["蓄力"] as Dictionary)["far"]):
			return ""
	if _victim_locked(other):
		return ""
	if _band(dist, "普通1"):
		return "普通1"
	# 滑鏟只留給香蕉。自己出的話，和道具造成的鏟長一樣。
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
	if id == "蓄力":
		body.shot_frame = 2
	elif id == "遠距離普攻":
		body.shot_frame = 1
	else:
		body.shot_frame = -1
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
	if defender.out:
		return
	var gap := defender.position.x - attacker.position.x
	var facing := 1.0 if attacker.face_right else -1.0
	var away := signf(gap) if gap != 0.0 else facing
	var dest := clampf(defender.position.x + away * float(m["kb"]), STAGE_MIN, STAGE_MAX)
	var dmg := maxi(int(round(float(m["damage"]))), 0)
	var pose := "down" if dmg >= 3 or defender.hp - dmg <= 0 else "hit"
	if not defender.react(pose, dest, 0.0, 0.0, true, float(m["stun"])):
		return
	defender.hp = maxi(defender.hp - dmg, 0)
	if defender.hp <= 0:
		defender.out = true
		attacker.chain = ""
	defender.plan = PackedStringArray()
	var stop := float(m["hitstop"])
	attacker.hitstop = maxf(attacker.hitstop, stop)
	defender.hitstop = maxf(defender.hitstop, stop)
	_shake = maxf(_shake, lerpf(4.0, 14.0, clampf(stop / 0.10, 0.0, 1.0)))
	_spark(defender.chest(), attacker.sheet)
	var nxt := str(m["chain"])
	if defender.out or attacker.airborne or nxt == "":
		attacker.chain = ""
	else:
		attacker.chain = nxt
		attacker.leave_active(float(m["active"]))
	if defender.out:
		_title.text = "%s倒下" % defender.display_name
	else:
		_title.text = "擊倒" if pose == "down" else "打中"


func _move_title(id: String) -> String:
	match id:
		"普通1", "普通2", "普通3":
			return "普通攻擊"
		"滑鏟":
			return "滑鏟"
		"遠距離普攻":
			return "開火"
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
	_spark(right.chest(), left.sheet)
	_shake = maxf(_shake, 10.0)
	_title.text = "格開"


func _refresh_hint() -> void:
	if _hint == null:
		return
	var next := "點圖標選道具，再點地面放下    Tab 拆開看    H 血量    G 地形    Esc 回節目    R 重看"
	if qte:
		next = "卸甲的大招會先亮橙圈。金圈閃起時按 F 格開，太早按會落空。    Esc 回節目    R 重看"
	elif brawl:
		next = "讓黃髮贏。點地面放道具。H 開關血量。R 重開。Esc 回節目。"
	elif _stage != null and _stage.editing:
		next = "拖空白畫長條，拖長條可移動。點長條上的標籤或按 T，決定能不能傾斜；能傾斜才拖左右端改高低。右鍵刪。G 離開。"
	elif _preview:
		next = "選上面的招單獨看。Tab 回到對打。    Esc 回節目"
	if _hint.text != next:
		_hint.text = next
	if _rack == null:
		return
	var show := not qte and not _preview
	if _rack.visible != show:
		_rack.visible = show
	if show:
		_rack.sync(_tool, _cool, TOOL_COOL)


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

	var bars := HpStrip.new()
	bars.host = self
	bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bars)

	_title = Label.new()
	_title.position = Vector2(300, 78)
	_title.size = Vector2(680, 48)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_font_size_override("font_size", 36)
	_title.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
	root.add_child(_title)

	var hint := Label.new()
	hint.text = ""
	hint.position = Vector2(40, 600)
	hint.size = Vector2(1200, 32)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.75, 0.76, 0.8))
	root.add_child(hint)
	_hint = hint
	_ground_button = Button.new()
	_ground_button.text = "地形"
	_ground_button.position = Vector2(24, 620)
	_ground_button.size = Vector2(88, 32)
	_ground_button.focus_mode = Control.FOCUS_NONE
	_ground_button.pressed.connect(func() -> void:
		if _stage != null:
			_set_ground_edit(not _stage.editing)
	)
	root.add_child(_ground_button)
	if not qte:
		_rack = _RACK.new()
		_rack.host = self
		_rack.position = Vector2(520, 636)
		_rack.size = Vector2(240, 72)
		root.add_child(_rack)

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
	_build_cast(root)
	_build_preview(root)


func _build_cast(root: Control) -> void:
	if qte:
		return
	for side in ["left", "right"]:
		var width := 58.0
		var stride := 62.0
		var span := float(Duelist.ROSTER.size() - 1) * stride + width
		var origin := 24.0 if side == "left" else 1256.0 - span
		for i in Duelist.ROSTER.size():
			var entry: Dictionary = Duelist.ROSTER[i]
			var button := Button.new()
			button.text = str(entry["label"])
			button.position = Vector2(origin + float(i) * stride, 70)
			button.size = Vector2(width, 28)
			button.focus_mode = Control.FOCUS_NONE
			button.add_theme_font_size_override("font_size", 14)
			button.pressed.connect(_pick_cast.bind(side, str(entry["id"])))
			root.add_child(button)
			_cast_buttons["%s:%s" % [side, str(entry["id"])]] = button
	_mark_cast()


func _pick_cast(side: String, id: String) -> void:
	var body := left if side == "left" else right
	body.use_sheet(id)
	_mark_cast()
	if _preview and _preview_id != "":
		_preview_play(_preview_id)


func _mark_cast() -> void:
	for key in _cast_buttons:
		var button := _cast_buttons[key] as Button
		if button == null:
			continue
		var parts := str(key).split(":")
		var body := left if parts[0] == "left" else right
		button.modulate = Color(1, 0.92, 0.55) if parts.size() > 1 and parts[1] == body.sheet_id else Color(1, 1, 1)


func _apply_pace() -> void:
	if qte:
		return
	for body in _bodies():
		body.time_scale = _pace
	for node in get_tree().get_nodes_in_group("duel_prop"):
		var prop := node as DuelProp
		if prop != null:
			prop.time_scale = _pace
	if _pace_button != null:
		_pace_button.text = "慢速" if _pace < 0.9 else "原速"


func _toggle_pace() -> void:
	_pace = NORMAL if _pace < 0.9 else SLOW
	_apply_pace()


func _build_preview(root: Control) -> void:
	_watch_button = Button.new()
	_watch_button.text = "拆開看"
	_watch_button.position = Vector2(40, 118)
	_watch_button.size = Vector2(120, 36)
	_watch_button.focus_mode = Control.FOCUS_NONE
	_watch_button.visible = not qte and not brawl
	_watch_button.pressed.connect(func() -> void: _set_preview(not _preview))
	root.add_child(_watch_button)
	_pace_button = Button.new()
	_pace_button.text = "慢速"
	_pace_button.position = Vector2(168, 118)
	_pace_button.size = Vector2(100, 36)
	_pace_button.focus_mode = Control.FOCUS_NONE
	_pace_button.visible = not qte
	_pace_button.pressed.connect(_toggle_pace)
	root.add_child(_pace_button)
	_hp_button = Button.new()
	_hp_button.text = "血量開" if show_hp else "血量關"
	_hp_button.position = Vector2(276, 118)
	_hp_button.size = Vector2(110, 36)
	_hp_button.focus_mode = Control.FOCUS_NONE
	_hp_button.visible = not qte
	_hp_button.pressed.connect(_toggle_hp)
	root.add_child(_hp_button)
	_count_button = Button.new()
	_count_button.text = "改成三人"
	_count_button.position = Vector2(394, 118)
	_count_button.size = Vector2(120, 36)
	_count_button.focus_mode = Control.FOCUS_NONE
	_count_button.visible = brawl and not qte
	_count_button.pressed.connect(_toggle_brawl_count)
	root.add_child(_count_button)

	_preview_row = Control.new()
	_preview_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_row.visible = false
	root.add_child(_preview_row)
	var specs: Array[PackedStringArray] = [
		PackedStringArray(["普通1", "普通1"]),
		PackedStringArray(["普通2", "普通2"]),
		PackedStringArray(["普通3", "普通3"]),
		PackedStringArray(["滑鏟", "滑鏟"]),
		PackedStringArray(["開火", "遠距離普攻"]),
		PackedStringArray(["遠蓄力", "蓄力"]),
		PackedStringArray(["追擊", "遠距離追擊"]),
		PackedStringArray(["下落", "下落"]),
		PackedStringArray(["蕉滑鏟", "香蕉滑鏟"]),
		PackedStringArray(["蕉滑倒", "香蕉滑倒"]),
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
		"遠距離普攻":
			_park(180.0)
			_play_module(left, right, id)
		"蓄力":
			_park(320.0)
			_play_module(left, right, id)
		"遠距離追擊":
			_park(280.0)
			_play_module(left, right, id)
		"下落":
			_park(80.0)
			_launch_preview()
		"香蕉滑鏟":
			_park(320.0)
			_drop_demo("peel", left.position.x + 130.0)
			left.go("walk", right.position.x - 40.0, 0.7)
		"香蕉滑倒":
			_park(120.0)
			_drop_demo("peel", left.position.x + 70.0)
			left.go("walk", right.position.x - 10.0, 0.45)
		"彈簧":
			_park(220.0)
			_drop_demo("spring", left.position.x + 70.0)
			left.go("walk", right.position.x - 90.0, 0.45)
		"時停":
			_park(320.0)
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
	_stand(left)
	_stand(right)
	_apply_pace()


func _drop_demo(kind: String, x: float) -> void:
	var prop := DuelProp.new()
	prop.time_scale = _pace
	if kind == "stop" and _items.has("時停"):
		var row: Dictionary = _items["時停"]
		prop.kind = "stop"
		prop.wind = float(row["startup"])
		prop.radius = float(row["range"])
		prop.position = _prop_at("stop", x)
	elif kind == "spring" and _items.has("彈簧"):
		var row: Dictionary = _items["彈簧"]
		prop.kind = "spring"
		prop.radius = float(row["range"])
		prop.life = 4.0
		prop.position = _prop_at("spring", x)
	elif _items.has("香蕉"):
		var row: Dictionary = _items["香蕉"]
		prop.kind = "peel"
		prop.radius = float(row["range"])
		prop.life = 4.0
		prop.position = _prop_at("peel", x)
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
	if moving.airborne and moving.big_launch and not moving.fall_armed:
		phase = "上升"
	elif moving.airborne and moving.big_launch and _moves.has("下落"):
		shown = _moves["下落"]
		age = moving.fall_age
		var fall_active := float(shown["active"])
		phase = "有效" if age < fall_active else "後搖"
	elif moving.slipping:
		phase = "滑行"
	elif moving.frozen > 0.0 and not moving.use_module:
		phase = "定住"
	elif moving.use_module and not moving.sheet_move.is_empty():
		shown = moving.sheet_move
		age = moving.action_age
		if str(shown.get("id", "")) == "蓄力":
			shown = shown.duplicate()
			var shot := 2.0 / float(Duelist.CLIPS["heavy"]["fps"])
			shown["startup"] = float(shown["startup"]) + shot
			shown["recover"] = maxf(float(shown["recover"]) - shot, 0.0)
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


class HpStrip extends Control:
	var host: Node = null

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if host == null:
			return
		var raw: Array = host.call("_bodies")
		var bodies: Array[Duelist] = []
		for item in raw:
			var who := item as Duelist
			if who != null:
				bodies.append(who)
		if bodies.is_empty():
			return
		var font := get_theme_default_font()
		if font == null:
			font = ThemeDB.fallback_font
		var bars_on := bool(host.get("show_hp"))
		if bodies.size() <= 2:
			_draw_pair(font, bodies, bars_on)
		else:
			_draw_row(font, bodies, bars_on)

	func _draw_pair(font: Font, bodies: Array[Duelist], bars_on: bool) -> void:
		var bar_y := 30.0
		var bar_h := 18.0
		_draw_name(font, bodies[0], Rect2(28, 4, 360, 24), HORIZONTAL_ALIGNMENT_LEFT)
		if bars_on:
			_draw_bar(bodies[0], Rect2(28, bar_y, 588, bar_h), false, Color(0.93, 0.28, 0.52))
		if bodies.size() < 2:
			return
		_draw_name(font, bodies[1], Rect2(892, 4, 360, 24), HORIZONTAL_ALIGNMENT_RIGHT)
		if bars_on:
			_draw_bar(bodies[1], Rect2(664, bar_y, 588, bar_h), true, Color(0.30, 0.56, 0.96))

	func _draw_row(font: Font, bodies: Array[Duelist], bars_on: bool) -> void:
		var count := bodies.size()
		var margin := 20.0
		var gap := 14.0
		var width := (1280.0 - margin * 2.0 - gap * float(count - 1)) / float(count)
		for i in count:
			var body := bodies[i]
			var x := margin + float(i) * (width + gap)
			_draw_name(font, body, Rect2(x, 4, width, 24), HORIZONTAL_ALIGNMENT_CENTER)
			if bars_on:
				_draw_bar(body, Rect2(x, 30, width, 16), false, _sheet_color(body))

	func _draw_name(font: Font, body: Duelist, rect: Rect2, align: HorizontalAlignment) -> void:
		if font == null:
			return
		var text := ("目標 " + body.display_name) if body.goal else body.display_name
		var ink := Color(0.95, 0.78, 0.22) if body.goal else Color(0.94, 0.93, 0.88)
		if body.out:
			ink = Color(0.55, 0.55, 0.58)
		draw_string(font, rect.position + Vector2(0, 18), text, align, rect.size.x, 18, ink)

	func _draw_bar(body: Duelist, rect: Rect2, from_right: bool, ink: Color) -> void:
		draw_rect(rect, Color(0.10, 0.10, 0.13))
		var inner := Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4))
		var ratio := 0.0 if body.hp_max <= 0 else clampf(float(body.hp) / float(body.hp_max), 0.0, 1.0)
		var fill := Color(0.95, 0.78, 0.22) if body.goal else ink
		if body.out:
			fill = Color(0.28, 0.28, 0.32)
		var fill_w := inner.size.x * ratio
		if from_right:
			draw_rect(Rect2(inner.position.x + inner.size.x - fill_w, inner.position.y, fill_w, inner.size.y), fill)
		else:
			draw_rect(Rect2(inner.position, Vector2(fill_w, inner.size.y)), fill)
		draw_rect(rect, Color(0.86, 0.83, 0.74), false, 1.0)

	func _sheet_color(body: Duelist) -> Color:
		match body.sheet_id:
			"armor":
				return Color(0.30, 0.58, 0.95)
			"bare":
				return Color(0.93, 0.42, 0.30)
			"silver":
				return Color(0.75, 0.78, 0.84)
			"slime":
				return Color(0.42, 0.78, 0.36)
			"stick":
				return Color(0.90, 0.55, 0.28)
			_:
				return Color(0.86, 0.28, 0.24)
