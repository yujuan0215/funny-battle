class_name Battle
extends Node2D

const BLAST_LEFT := -160.0
const BLAST_RIGHT := 1440.0
const BLAST_TOP := -220.0
const BLAST_BOTTOM := 1040.0
const FEET := 40.0
const BANANA_SCENE := preload("res://scenes/banana.tscn")

var match_over := false
var started := false
var shake := 0.0
var gang_up := false
var crowd_angry_until := 0.0
var box_used: Array[bool] = [false, false]

var red: Fighter
var blue: Fighter
var host_body: HostBody
var sponsor: SponsorSign
var broadcast: Broadcast
var _respawning: Dictionary = {}
var _clock := 0.0
var _shout_time := 0.0
var _threat_times: Dictionary = {}

var _left_percent: Label
var _right_percent: Label
var _left_stocks: Label
var _right_stocks: Label
var _tool_buttons: Array[Button] = []
var _card_label: Label
var _status_label: Label
var _shout_label: Label
var _verdict_bar: ColorRect
var _verdict_label: Label
var _end_result: Label
var _start_layer: Control
var _end_layer: Control
var _end_title: Label
var _end_critics: Label
var _replay_box: VBoxContainer

@onready var camera: Camera2D = $Camera2D
@onready var host: HostController = $Host
@onready var main_platform: Platform = $Platforms/MainPlatform


func _ready() -> void:
	add_to_group("match")
	$Fragments.add_to_group("fragments_root")
	camera.position = Vector2(640, 360)
	camera.make_current()
	red = $Fighters/Red
	blue = $Fighters/Blue
	red.opponent = blue
	blue.opponent = red
	red.koed.connect(_on_ko)
	blue.koed.connect(_on_ko)
	red.incident.connect(func(kind: String) -> void: _on_threat(kind, red))
	blue.incident.connect(func(kind: String) -> void: _on_threat(kind, blue))
	_seat(red, -180.0, 1.0)
	_seat(blue, 180.0, -1.0)
	host_body = HostBody.new()
	host_body.position = Vector2(-2400, -2400)
	add_child(host_body)
	broadcast = Broadcast.new()
	add_child(broadcast)
	broadcast.setup()
	_spawn_sponsor()
	_spawn_shot()
	_build_hud()
	red.locked = true
	blue.locked = true


func _process(delta: float) -> void:
	_clock += delta
	if shake > 0.0:
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
		shake = move_toward(shake, 0.0, delta * 46.0)
	else:
		camera.offset = Vector2.ZERO
	if _shout_time > 0.0:
		_shout_time -= delta
		_shout_label.modulate.a = clampf(_shout_time / 0.28, 0.0, 1.0)
	_update_gang()
	if started and not match_over:
		broadcast.poll(self)
	_refresh_hud()


func _physics_process(_delta: float) -> void:
	if not started or match_over:
		return
	for fighter: Fighter in [red, blue]:
		if fighter == null or not fighter.alive:
			continue
		var point: Vector2 = fighter.global_position
		if point.x < BLAST_LEFT or point.x > BLAST_RIGHT or point.y < BLAST_TOP or point.y > BLAST_BOTTOM:
			if fighter.host_threat > 0.0:
				fighter.knockout()
			else:
				fighter.rescue()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()


func now() -> float:
	return _clock


func is_live() -> bool:
	return started and not match_over


func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)


func shout(text: String) -> void:
	_shout_label.text = text
	var ink := Color(0.85, 0.12, 0.1)
	if text == "達成" or text == "空的":
		ink = Color(0.05, 0.42, 0.16)
	_shout_label.add_theme_color_override("font_color", ink)
	_shout_label.modulate.a = 1.0
	_shout_time = 1.6 if text == "達成" or text == "失敗" else 0.95


func trailer() -> Variant:
	if red.stocks != blue.stocks:
		return red if red.stocks < blue.stocks else blue
	if absf(red.percent - blue.percent) < 25.0:
		return null
	return red if red.percent > blue.percent else blue


func recent_damage(fighter: Fighter) -> float:
	var sum := 0.0
	for event in fighter.damage_events:
		if now() - float(event["time"]) <= 15.0:
			sum += float(event["amount"])
	return sum


func host_record(kind: String, focus: Variant, style: String, detail: String, joke: String = "") -> void:
	if not is_live():
		return
	broadcast.record(self, kind, focus, style, detail, joke)


func note_photo(victim: Fighter) -> void:
	host_record("photo", victim, "hit", "擺拍時被打中")


func note_sponsor(fighter: Fighter) -> String:
	if not is_live() or sponsor == null:
		return ""
	var effect := broadcast.sponsor_punched(self, fighter)
	if effect == "banana":
		var item := BANANA_SCENE.instantiate() as StageItem
		$Items.add_child(item)
		item.global_position = sponsor.global_position + Vector2(fighter.facing * 48.0, -36.0)
	return effect


func open_box(index: int) -> void:
	if not is_live() or box_used[index]:
		return
	box_used[index] = true
	broadcast.roll_box(self)


func begin_match() -> void:
	if started:
		return
	started = true
	red.locked = false
	blue.locked = false
	broadcast.arm(self)
	_start_layer.visible = false


func _spawn_sponsor() -> void:
	if broadcast.card != 1:
		return
	sponsor = SponsorSign.new()
	add_child(sponsor)
	var surface := main_platform.top_world(0.0)
	sponsor.global_position = surface + Vector2(0, -48)


func _spawn_shot() -> void:
	if broadcast.card != 2:
		return
	add_child(ShotFrame.new())


func _update_gang() -> void:
	if host_body == null:
		return
	var stay := host_body.on_stage and host_body.stage_time >= 2.0
	var angry := _clock < crowd_angry_until
	var next := host_body.on_stage and (stay or angry)
	if next and not gang_up and started:
		shout("聯手")
	gang_up = next


func _on_threat(kind: String, fighter: Fighter) -> void:
	if kind == "ride" or not is_live():
		return
	var id := fighter.get_instance_id()
	var bucket: Array = _threat_times.get(id, [])
	bucket.append(_clock)
	_threat_times[id] = bucket
	var hits := 0
	for stamp in bucket:
		if _clock - float(stamp) <= 4.0:
			hits += 1
	if hits >= 2:
		crowd_angry_until = _clock + 4.0


func _seat(fighter: Fighter, local_x: float, face: float) -> void:
	var surface := main_platform.top_world(local_x)
	fighter.global_position = Vector2(surface.x, surface.y - FEET)
	fighter.spawn_point = fighter.global_position
	fighter.facing = face


func _on_ko(fighter: Fighter) -> void:
	if match_over:
		return
	broadcast.on_ko(self, fighter)
	if fighter.stocks <= 0:
		_finish(fighter)
		return
	if _respawning.get(fighter, false):
		return
	_respawning[fighter] = true
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree() or match_over or not is_instance_valid(fighter):
		return
	fighter.respawn()
	_respawning[fighter] = false


func _finish(loser: Fighter) -> void:
	match_over = true
	for fighter in [red, blue]:
		fighter.locked = true
	broadcast.resolve(self, loser)
	_show_result()


func _show_result() -> void:
	var word := broadcast.state_word(true)
	_end_result.text = word
	var ink := Color(0.28, 0.28, 0.28)
	if broadcast.card_ok:
		ink = Color(0.05, 0.42, 0.16)
	elif broadcast.card_fail:
		ink = Color(0.72, 0.1, 0.08)
	_end_result.add_theme_color_override("font_color", ink)
	_end_title.text = "%s\n%s" % [Broadcast.CARD_TITLE[broadcast.card], broadcast.task(self)]
	_end_critics.text = "陳裁判  %d  %s\n笑姐  %d  %s\n阿表  %d  %s\n\n%s" % [
		broadcast.scores[0], broadcast.comment(0),
		broadcast.scores[1], broadcast.comment(1),
		broadcast.scores[2], broadcast.comment(2),
		broadcast.secrets(),
	]
	for line in broadcast.replay_lines():
		var row := Label.new()
		row.text = line
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(1040, 0)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_font_size_override("font_size", 16)
		row.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08))
		_replay_box.add_child(row)
	_end_layer.visible = true


func _refresh_hud() -> void:
	_left_percent.text = "%d%%" % int(round(red.percent))
	_right_percent.text = "%d%%" % int(round(blue.percent))
	_left_stocks.text = _stock_marks(red.stocks)
	_right_stocks.text = _stock_marks(blue.stocks)
	_card_label.text = Broadcast.CARD_TITLE[broadcast.card]
	_status_label.text = _status_line()
	_paint_verdict()
	var ink := Color(0.08, 0.08, 0.08)
	if broadcast.card_fail:
		ink = Color(0.72, 0.1, 0.08)
	elif broadcast.card_ok:
		ink = Color(0.05, 0.42, 0.16)
	_card_label.add_theme_color_override("font_color", ink)
	for i in _tool_buttons.size():
		var button: Button = _tool_buttons[i]
		if i < 6:
			var remaining: float = host.cooldowns[i]
			var label := _tool_name(i)
			button.text = "%d %s" % [i + 1, label] if remaining <= 0.0 else "%d  %.1f" % [i + 1, remaining]
			_paint_button(button, i == host.tool, remaining <= 0.0)
		else:
			var used: bool = box_used[i - 6]
			var name := "密封甲" if i == 6 else "密封乙"
			button.text = "%d 已開" % [i + 1] if used else "%d %s" % [i + 1, name]
			_paint_button(button, false, not used)


func _status_line() -> String:
	var presence := "空白鍵上場"
	if host_body.on_stage:
		presence = "在場上 %.1f 秒" % host_body.stage_time
	elif host_body.flying:
		presence = "飛出去了"
	elif host_body.cooldown > 0.0:
		presence = "上場冷卻 %.1f" % host_body.cooldown
	var gang := "    他們在看你" if gang_up else ""
	return "%s\n%s%s" % [broadcast.scores_text(), presence, gang]


func _paint_verdict() -> void:
	var word := broadcast.state_word(match_over)
	_verdict_label.text = "%s    %s" % [word, broadcast.task(self)]
	var bg := Color(1, 1, 1, 0.94)
	var ink := Color(0.08, 0.08, 0.08)
	if broadcast.card_fail:
		bg = Color(0.75, 0.12, 0.08, 0.96)
		ink = Color.WHITE
	elif broadcast.card_ok:
		bg = Color(0.08, 0.48, 0.22, 0.96)
		ink = Color.WHITE
	elif match_over:
		bg = Color(0.22, 0.22, 0.22, 0.96)
		ink = Color.WHITE
	_verdict_bar.color = bg
	_verdict_label.add_theme_color_override("font_color", ink)


func _tool_name(index: int) -> String:
	match index:
		0:
			return "香蕉皮"
		1:
			return "炸彈"
		2:
			return "橫切"
		3:
			return host.mic_name()
		4:
			return "彈簧"
		5:
			return "定格燈"
		_:
			return ""


func _stock_marks(stocks: int) -> String:
	var marks := ""
	for i in 3:
		marks += "● " if i < stocks else "○ "
	return marks


func _build_hud() -> void:
	var layer: CanvasLayer = $HUD
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

	var left := _stat_column(red.display_name, red.tint, false)
	left.position = Vector2(20, 8)
	root.add_child(left)
	_left_percent = left.get_node("Percent")
	_left_stocks = left.get_node("Stocks")

	var right := _stat_column(blue.display_name, blue.tint, true)
	right.position = Vector2(1000, 8)
	root.add_child(right)
	_right_percent = right.get_node("Percent")
	_right_stocks = right.get_node("Stocks")

	_card_label = Label.new()
	_card_label.position = Vector2(280, 2)
	_card_label.size = Vector2(720, 30)
	_card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_label.add_theme_font_size_override("font_size", 22)
	root.add_child(_card_label)

	var x0 := (1280.0 - (4.0 * 148.0 + 3.0 * 8.0)) * 0.5
	for i in 8:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.position = Vector2(x0 + float(i % 4) * 156.0, 36.0 + float(i / 4) * 48.0)
		button.size = Vector2(148, 42)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.add_theme_font_size_override("font_size", 15)
		var tool_index := i
		button.pressed.connect(func() -> void: _on_tool_button(tool_index))
		root.add_child(button)
		_tool_buttons.append(button)

	var leaks := Label.new()
	leaks.text = "陳裁判：今晚少靠道具。    笑姐：我想看你們出糗。    阿表：數字要動。"
	leaks.position = Vector2(250, 128)
	leaks.size = Vector2(780, 22)
	leaks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leaks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leaks.add_theme_font_size_override("font_size", 14)
	leaks.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	root.add_child(leaks)

	_status_label = Label.new()
	_status_label.position = Vector2(250, 148)
	_status_label.size = Vector2(780, 40)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.add_theme_font_size_override("font_size", 16)
	root.add_child(_status_label)

	var hint := Label.new()
	hint.text = "點場上使用  ·  再按 4 換台詞  ·  空白鍵上場  ·  R 換一場"
	hint.position = Vector2(200, 608)
	hint.size = Vector2(880, 22)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))
	root.add_child(hint)

	_shout_label = Label.new()
	_shout_label.position = Vector2(340, 186)
	_shout_label.size = Vector2(600, 42)
	_shout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shout_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shout_label.add_theme_font_size_override("font_size", 32)
	_shout_label.add_theme_color_override("font_color", Color(0.85, 0.12, 0.1))
	root.add_child(_shout_label)

	_verdict_bar = ColorRect.new()
	_verdict_bar.position = Vector2(0, 636)
	_verdict_bar.size = Vector2(1280, 84)
	_verdict_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_verdict_bar.color = Color(1, 1, 1, 0.94)
	root.add_child(_verdict_bar)
	_verdict_label = Label.new()
	_verdict_label.position = Vector2(24, 636)
	_verdict_label.size = Vector2(1232, 84)
	_verdict_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verdict_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_verdict_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_verdict_label.add_theme_font_size_override("font_size", 28)
	root.add_child(_verdict_label)

	_start_layer = Control.new()
	_start_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_start_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_start_layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(1, 1, 1, 0.9)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_layer.add_child(dim)
	var intro := Label.new()
	intro.text = Broadcast.CARD_TITLE[broadcast.card]
	intro.position = Vector2(140, 78)
	intro.size = Vector2(1000, 48)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro.add_theme_font_size_override("font_size", 36)
	_start_layer.add_child(intro)
	var body := Label.new()
	body.text = Broadcast.CARD_BODY[broadcast.card]
	body.position = Vector2(160, 142)
	body.size = Vector2(960, 90)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_font_size_override("font_size", 22)
	_start_layer.add_child(body)
	var who := Label.new()
	who.text = "左邊是認真君，會一直追著打。右邊是摸魚君，走得慢，常常停下來。\n同一個工具，兩個人的反應不一樣。不插手的話，這張單完不成。"
	who.position = Vector2(160, 246)
	who.size = Vector2(960, 64)
	who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.add_theme_font_size_override("font_size", 18)
	_start_layer.add_child(who)
	var critic_line := Label.new()
	critic_line.text = "陳裁判：今晚少靠道具。\n笑姐：我想看你們出糗。\n阿表：數字要動。"
	critic_line.position = Vector2(160, 330)
	critic_line.size = Vector2(960, 84)
	critic_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	critic_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	critic_line.add_theme_font_size_override("font_size", 20)
	_start_layer.add_child(critic_line)
	var controls := Label.new()
	controls.text = "1 到 6 選工具，再點場上。再按一次 4 換台詞。7 和 8 各開一次密封箱。\n空白鍵把你放到滑鼠的位置，再按一次離場。被人打中會飛出去。R 換一場。"
	controls.position = Vector2(140, 430)
	controls.size = Vector2(1000, 64)
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.add_theme_font_size_override("font_size", 18)
	controls.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	_start_layer.add_child(controls)
	var start := Button.new()
	start.text = "開打"
	start.position = Vector2(180, 530)
	start.custom_minimum_size = Vector2(200, 56)
	start.size = Vector2(200, 56)
	start.focus_mode = Control.FOCUS_NONE
	start.pressed.connect(begin_match)
	_paint_button(start, true, true)
	_start_layer.add_child(start)
	var watch := Button.new()
	watch.text = "干擾決鬥"
	watch.position = Vector2(430, 530)
	watch.custom_minimum_size = Vector2(220, 56)
	watch.size = Vector2(220, 56)
	watch.focus_mode = Control.FOCUS_NONE
	watch.pressed.connect(func() -> void:
		preload("res://scripts/duel.gd").qte = false
		get_tree().change_scene_to_file("res://scenes/duel.tscn")
	)
	_paint_button(watch, false, true)
	_start_layer.add_child(watch)
	var flash := Button.new()
	flash.text = "閃光格檔"
	flash.position = Vector2(680, 530)
	flash.custom_minimum_size = Vector2(220, 56)
	flash.size = Vector2(220, 56)
	flash.focus_mode = Control.FOCUS_NONE
	flash.pressed.connect(func() -> void:
		preload("res://scripts/duel.gd").qte = true
		get_tree().change_scene_to_file("res://scenes/duel.tscn")
	)
	_paint_button(flash, false, true)
	_start_layer.add_child(flash)

	_end_layer = Control.new()
	_end_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_layer.visible = false
	_end_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_end_layer)
	var end_dim := ColorRect.new()
	end_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_dim.color = Color(1, 1, 1, 0.94)
	end_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_layer.add_child(end_dim)
	_end_result = Label.new()
	_end_result.position = Vector2(80, 8)
	_end_result.size = Vector2(1120, 68)
	_end_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_result.add_theme_font_size_override("font_size", 52)
	_end_layer.add_child(_end_result)
	_end_title = Label.new()
	_end_title.position = Vector2(80, 76)
	_end_title.size = Vector2(1120, 56)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_title.add_theme_font_size_override("font_size", 22)
	_end_layer.add_child(_end_title)
	_end_critics = Label.new()
	_end_critics.position = Vector2(80, 140)
	_end_critics.size = Vector2(1120, 160)
	_end_critics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_critics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_critics.add_theme_font_size_override("font_size", 16)
	_end_layer.add_child(_end_critics)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(70, 308)
	scroll.size = Vector2(1140, 292)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_end_layer.add_child(scroll)
	_replay_box = VBoxContainer.new()
	_replay_box.custom_minimum_size = Vector2(1080, 0)
	_replay_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_replay_box)
	var again := Button.new()
	again.text = "再來一局"
	again.position = Vector2(520, 620)
	again.custom_minimum_size = Vector2(240, 56)
	again.size = Vector2(240, 56)
	again.focus_mode = Control.FOCUS_NONE
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	_paint_button(again, true, true)
	_end_layer.add_child(again)


func _on_tool_button(index: int) -> void:
	if index >= 6:
		open_box(index - 6)
		return
	if index == HostController.Tool.MIC and host.tool == HostController.Tool.MIC:
		host.cycle_mic()
		return
	host.set_tool(index)


func _stat_column(title: String, tint: Color, align_right: bool) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(250, 120)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name := Label.new()
	name.name = "Name"
	name.text = title
	name.size = Vector2(250, 32)
	name.add_theme_font_size_override("font_size", 28)
	name.add_theme_color_override("font_color", tint.darkened(0.15))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if align_right else HORIZONTAL_ALIGNMENT_LEFT
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name)
	var percent := Label.new()
	percent.name = "Percent"
	percent.position = Vector2(0, 30)
	percent.size = Vector2(250, 58)
	percent.add_theme_font_size_override("font_size", 48)
	percent.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08))
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if align_right else HORIZONTAL_ALIGNMENT_LEFT
	percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(percent)
	var stocks := Label.new()
	stocks.name = "Stocks"
	stocks.position = Vector2(0, 88)
	stocks.size = Vector2(250, 28)
	stocks.add_theme_font_size_override("font_size", 22)
	stocks.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08))
	stocks.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if align_right else HORIZONTAL_ALIGNMENT_LEFT
	stocks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(stocks)
	return box


func _paint_button(button: Button, selected: bool, ready: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1) if selected else Color(1, 1, 1)
	style.border_color = Color(0.1, 0.1, 0.1)
	style.set_border_width_all(3)
	style.set_content_margin_all(4)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, style)
	var ink := Color.WHITE if selected else Color(0.1, 0.1, 0.1)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_color_override("font_disabled_color", ink)
	button.modulate.a = 1.0 if ready else 0.45
