extends Node2D

static var qte := false

var _sparks: Array[Dictionary] = []
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

@onready var left: Duelist = $Left
@onready var right: Duelist = $Right
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	_build_hud()
	_title.text = "對峙"


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.07, 0.08, 0.12))
	draw_rect(Rect2(0, 548, 1280, 172), Color(0.16, 0.17, 0.22))
	draw_rect(Rect2(0, 548, 1280, 6), Color(0.86, 0.83, 0.74))
	draw_rect(Rect2(628, 548, 24, 10), Color(0.82, 0.22, 0.16))


func _process(delta: float) -> void:
	if _big_cd > 0.0:
		_big_cd = maxf(_big_cd - delta, 0.0)
	if not qte:
		_check_peels()
	_think(left, right)
	_think(right, left)
	_resolve_strikes()
	_tick_flash(delta)
	var kept: Array[Dictionary] = []
	for spark in _sparks:
		spark["t"] = float(spark["t"]) + delta
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
		_shake = move_toward(_shake, 0.0, delta * 40.0)
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
	elif not qte and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_place(get_global_mouse_position())


func _restart() -> void:
	for node in get_tree().get_nodes_in_group("duel_prop"):
		node.queue_free()
	_phase = 0
	_flash_left = 0.0
	_spoiled = false
	_hold_release = false
	_big_cd = 1.4
	left.position = Vector2(260, 548)
	right.position = Vector2(1020, 548)
	left.relax()
	right.relax()
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
	var x := clampf(at.x, 80.0, 1200.0)
	if _tool == 1:
		for node in get_tree().get_nodes_in_group("duel_prop"):
			var live := node as DuelProp
			if live != null and live.kind == "bomb" and live.boom < 0.0:
				return
		var bomb := DuelProp.new()
		bomb.kind = "bomb"
		bomb.position = Vector2(x, 500)
		bomb.burst.connect(detonate)
		add_child(bomb)
		bomb.add_to_group("duel_prop")
		return
	var peel := DuelProp.new()
	peel.kind = "peel"
	peel.position = Vector2(x, 536)
	add_child(peel)
	peel.add_to_group("duel_prop")


func _check_peels() -> void:
	for node in get_tree().get_nodes_in_group("duel_prop"):
		var prop := node as DuelProp
		if prop == null or prop.kind != "peel" or not prop.armed:
			continue
		for body in [left, right]:
			var who := body as Duelist
			if who.lock > 0.0 or absf(who.position.x - prop.position.x) > 48.0:
				continue
			var dir := signf(who.vx)
			if absf(who.vx) < 30.0:
				dir = 1.0 if who.face_right else -1.0
			if not _hurt(who, "down", who.position.x + dir * 210.0):
				continue
			_title.text = "%s滑倒" % who.display_name
			prop.consume()
			break


func detonate(prop: DuelProp) -> void:
	_shake = maxf(_shake, 12.0)
	var anyone := false
	for body in [left, right]:
		var who := body as Duelist
		var dist := who.global_position.distance_to(prop.global_position)
		if dist > 190.0:
			continue
		var gap := who.position.x - prop.position.x
		var away := signf(gap) if gap != 0.0 else 1.0
		var pose := "down" if dist < 78.0 else "hit"
		var push := 230.0 if dist < 78.0 else 150.0
		if not _hurt(who, pose, who.position.x + away * push):
			continue
		anyone = true
		_spark(who.chest())
	_title.text = "爆炸" if anyone else "炸空了"


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
		var mark := "【1 香蕉皮】    2 炸彈" if _tool == 0 else "1 香蕉皮    【2 炸彈】"
		_hint.text = "%s    點地面放下    Esc 回節目    R 重看" % mark


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
