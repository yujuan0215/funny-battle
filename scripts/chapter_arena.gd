extends "res://scripts/spike_duel.gd"
## Playable campaign variants. No simulated damage: every hit goes through the duel.
const ChapterStage := preload("res://scripts/chapter_stage.gd")
const PHASE_NAMES := ["衝撞鎧甲", "發條心臟", "借力終幕"]
var phase := 0
var checkpoint := 0
var wind := 1.0
var world_time := 0.0
var sandbags: Array[Dictionary] = []
var crate_x := 920.0
var magnet_x := -1.0
var magnet_left := 0.0
var crate_ready := true
var slam_left := 0.0
var slam_x := 600.0
var slam_duration := 2.2
var _slam_hit := false
var _last_wind := 0
var _mechanic_hits := 0
var _wind_lifted := false
var _environment_damage := false
var _wind_crash := false
var _wind_impacts := 0


func _ready() -> void:
	_cool.assign([0.0, 0.0, 0.0, 0.0, 0.0])
	super._ready()
	remove_child(_stage)
	_stage.queue_free()
	_stage = ChapterStage.new()
	_stage.chapter_theme = str(Campaign.chapter(chapter_number)["theme"])
	_stage.arena = self
	add_child(_stage)
	var shell := preload("res://scripts/boss_shell.gd").new()
	shell.chapter = chapter_number
	right.add_child(shell)
	_hud.objective.text = "%02d · %s" % [chapter_number, Campaign.chapter(chapter_number)["boss"]]
	_hud.set_tools(_tool, _cool, _pace)
	if chapter_number == 2:
		_hud.tool_buttons[1].tooltip_text = "彈簧：主角後撤；BOSS 向上彈起"
	_hud.win_conditions.set_symbols(["emptyheart"])
	_hud.win_conditions.hide()
	_hud.win_conditions.tooltip_text = "利用本關機關擊敗 BOSS"


func _reset_fighters() -> void:
	sandbags.clear()
	world_time = 0
	magnet_left = 0
	magnet_x = -1
	crate_x = 920
	crate_ready = true
	slam_left = 0
	_slam_hit = false
	_mechanic_hits = 0
	_last_wind = 0
	_wind_lifted = false
	_wind_crash = false
	_wind_impacts = 0
	_environment_damage = false
	phase = checkpoint if chapter_number == 6 else 0
	super._reset_fighters()
	right.hp_max = 36 if chapter_number == 6 else 12 if chapter_number == 2 else 16
	right.hp = right.hp_max - phase * 12
	left.hp_max = 6
	left.hp = left.hp_max
	_rescues_left = 0
	_hud.set_rescue(false)
	for body in [left, right]:
		body.motion_bounds = _bridge_bounds() + Vector2(20, -20)
	right.display_name = str(Campaign.chapter(chapter_number)["boss"])
	right.use_sheet(["armor", "armor", "silver", "yellow", "silver", "armor", "armor"][chapter_number])
	right.modulate = [Color.WHITE, Color.WHITE, Color("bdd8b9"), Color("e6c18a"), Color("b7e5e2"), Color("d2ac8d"), Color("cbb0e7")][chapter_number]
	right.scale = Vector2(1.05, 0.85) if chapter_number == 4 else Vector2.ONE * (1.3 if chapter_number == 6 else 1.1)
	_sync_health()


func _start_round() -> void:
	super._start_round()
	if chapter_number == 6:
		_hud.objective.text = "機關王 %d / 3 · %s" % [phase + 1, PHASE_NAMES[phase]]



func pick_tool(index: int) -> void:
	if index not in _allowed_tools():
		return
	_tool = index
	_refresh_counter_hud()


func _process(delta: float) -> void:
	if _round_state != RoundState.PLAYING or _ended:
		return
	var dt := delta * _pace
	world_time += dt
	wind = 1.0 if int(world_time / 6.0) % 2 == 0 else -1.0
	if chapter_number == 2 and _last_wind != int(wind):
		_last_wind = int(wind)
		_hud.objective.text = "風向 →" if wind > 0 else "風向 ←"
	_tick_wind(dt)
	if _ended:
		return
	_tick_sandbags(dt)
	_tick_crate(dt)
	if slam_left > 0 and right.frozen <= 0:
		slam_left = maxf(0, slam_left - dt)
		if slam_left <= 0:
			_resolve_slam()
	if _round_state != RoundState.PLAYING:
		return
	super._process(delta)
	if _round_state != RoundState.PLAYING:
		return
	if chapter_number == 2 and _wind_lifted:
		_hud.set_intent("風推", ["right" if wind > 0 else "left"])
		_hud.set_timing(0, 0, _pace)
	if slam_left > 0:
		_hud.set_intent("三拍重錘" if phase < 2 else "終幕鎖定", ["boss", "charge"])
		_hud.set_timing(slam_left, slam_duration, _pace)
	if is_instance_valid(_stage):
		_stage.queue_redraw()


func _rush_windup() -> float:
	return 1.5 if chapter_number == 2 else 1.3


func _rush_duration() -> float:
	if chapter_number == 2:
		return 1.1 if _rush_direction == wind else 1.8
	return 1.1 if chapter_number == 4 else 1.4


func _recover_duration() -> float:
	return 2.2 if chapter_number == 2 and _rush_direction != wind else 1.7


func _begin_boss_move() -> void:
	if chapter_number == 3 or (chapter_number == 6 and phase >= 1):
		if _boss_action == "衝刺" or phase == 2:
			_begin_slam()
			return
	if chapter_number in [4, 5] or (chapter_number == 6 and phase == 0):
		_boss_action = "衝刺"
	super._begin_boss_move()


func _think_hero(other: Duelist) -> void:
	# During a locked slam, only a player intervention creates the escape.
	# Natural auto-walking does not quietly solve the new mechanic.
	if slam_left > 0 and not left.spring_shot_ready():
		left.go("idle", left.position.x, 0.2)
		return
	super._think_hero(other)


func _begin_slam() -> void:
	_boss_state = "attack"
	slam_duration = 2.6 if chapter_number == 6 and phase == 2 else 2.2
	slam_left = slam_duration
	slam_x = left.position.x
	_slam_hit = false
	right.sheet_move = {}
	right.start_module("power", right.position.x, slam_duration + 0.2, 0, -1, "")
	_audio.cue("warn")


func _resolve_slam() -> void:
	if right.out or _ended:
		return
	_slam_hit = true
	_shake = 8
	_audio.cue("hit")
	var previous_phase := phase
	var avoided := absf(left.position.x - slam_x) > 64 or left.airborne
	if avoided:
		_mechanic_damage(4, "重錘落空 · 核心反傷")
		_counter_hits += 1
		_audio.cue("counter")
	else:
		_land_hit(right, left, _boss_move)
		_hud.tell("受擊", 1, ["miss"], true)
	if phase != previous_phase or _ended:
		return
	_boss_state = "recover"
	right.use_module = false
	right.script_open = true
	right.go("idle", right.position.x, _recover_duration())


func _try_spring(body: Duelist, prop: DuelProp) -> bool:
	if chapter_number == 2 and body == right:
		if body.out or prop.is_queued_for_deletion():
			return false
		# The boss is too heavy to retreat-shoot: spring supplies lift,
		# and the actual wind physics must carry him into a side rotor.
		body.launch_arc(wind * 100.0, 700.0, 1400.0, false, 0.2)
		body.clear_spring_shot()
		prop.consume()
		_wind_lifted = true
		_boss_state = "interrupted"
		_audio.cue("spring")
		return true
	var launched := super._try_spring(body, prop)
	if not launched:
		return false
	_audio.cue("spring")
	if chapter_number == 2:
		# Tailwind lengthens a real airborne path, headwind shortens it.
		body.air_vx *= 1.18 if signf(body.air_vx) == wind else 0.8
	if chapter_number == 4 and body == left:
		body.air_vx *= 1.12
	return true


func _placement_preview(at: Vector2) -> Dictionary:
	if _tool <= 2:
		return super._placement_preview(at)
	var bounds := _bridge_bounds()
	if at.x < bounds.x or at.x > bounds.y or at.y < 260 or at.y > SPIKE_STAGE.SPIKE_Y:
		return {}
	return {"floor": Vector2(at.x, 500), "spot": Vector2(at.x, 490), "radius": 36.0 if _tool == 3 else 100.0, "affected": [], "available": _cool[_tool] <= 0}


func _draw_placement_preview() -> void:
	if chapter_number == 2 and _tool == 1:
		var at := get_global_mouse_position()
		var data := _placement_preview(at)
		if not data.is_empty() and _nearest_body(data["floor"]) == right:
			var spot: Vector2 = data["spot"]
			var ink := Color("8ace85") if data["available"] else Color("ed7758")
			DuelProp.draw_spring(self, 0, Color(1, 1, 1, 0.6), spot)
			var tip := spot + Vector2(0, -130)
			draw_dashed_line(spot, tip, ink, 2, 8)
			draw_line(tip, tip + Vector2(-10, 14), ink, 2)
			draw_line(tip, tip + Vector2(10, 14), ink, 2)
			draw_dashed_line(tip, tip + Vector2(wind * 90, 0), ink, 2, 8)
			return
	if _tool <= 2:
		super._draw_placement_preview()
		return
	var data := _placement_preview(get_global_mouse_position())
	if data.is_empty():
		return
	var ink := Color("8ace85") if data["available"] else Color("ed7758")
	ArenaHud.Icons.paint(self, "sandbag" if _tool == 3 else "magnet", data["spot"] + Vector2(0, -20), 32, ink)
	draw_dashed_line(data["floor"] + Vector2(-36, 0), data["floor"] + Vector2(36, 0), ink, 2, 6)
	if _tool == 4:
		draw_dashed_line(Vector2(crate_x, 474), data["floor"] - Vector2(0, 26), ink, 2, 8)


func _place(at: Vector2) -> void:
	if _tool <= 2:
		super._place(at)
		return
	if _round_state != RoundState.PLAYING or _tool not in _allowed_tools():
		return
	var preview := _placement_preview(at)
	if preview.is_empty():
		_hud.tell("場外", 1.5, ["miss"], true)
		return
	if _cool[_tool] > 0:
		_hud.tell("冷卻中", 1, ["clock"], true)
		return
	if _tool == 3:
		if sandbags.size() >= 2:
			_hud.tell("沙袋已滿", 1.5, ["miss"], true)
			return
		sandbags.append({"x": at.x, "life": 6.0})
		_cool[3] = 1.8
	else:
		magnet_x = at.x
		magnet_left = 4.0
		crate_ready = true
		_cool[4] = 2.8
	_props_used += 1
	_audio.cue("place")
	_refresh_counter_hud()


func _tick_sandbags(dt: float) -> void:
	for i in range(sandbags.size() - 1, -1, -1):
		var bag: Dictionary = sandbags[i]
		bag["life"] -= dt
		if bag["life"] <= 0:
			sandbags.remove_at(i)
			continue
		if absf(left.position.x - float(bag["x"])) < 34 and left.slipping:
			var health := left.hp
			left.relax()
			left.hp = health
			_hud.tell("止滑", 1, ["sandbag", "check"])
		if _boss_state == "charge" and not right.airborne and absf(right.position.x - float(bag["x"])) < 52:
			sandbags.remove_at(i)
			_interrupt_boss()
			_mechanic_damage(4, "撞上沙袋 · 破甲")


func _tick_crate(dt: float) -> void:
	if chapter_number < 5 or magnet_left <= 0:
		return
	magnet_left = maxf(0, magnet_left - dt)
	var previous := crate_x
	crate_x = move_toward(crate_x, clampf(magnet_x, 390, 1020), dt * 260)
	if crate_ready and absf(crate_x - previous) > 0.01 and not right.airborne and right.position.x >= minf(previous, crate_x) - 44 and right.position.x <= maxf(previous, crate_x) + 44:
		crate_ready = false
		_interrupt_boss()
		_mechanic_damage(6, "鐵箱撞擊 · 爐心破甲")
		_audio.cue("counter")


func _interrupt_boss() -> void:
	slam_left = 0
	_boss_state = "interrupted"
	right.react("hit", right.position.x, 0, 0, true, 1.4)
	_shake = 6


func _mechanic_damage(amount: int, _message: String) -> void:
	var move := _move_for(left, "彈簧開火").duplicate()
	move["damage"] = amount
	move["chain"] = ""
	_environment_damage = true
	_land_hit(left, right, move)
	_environment_damage = false
	_mechanic_hits += 1
	_hud.tell("−%d" % amount, 1.2, ["check"])


func _land_hit(attacker: Duelist, defender: Duelist, move: Dictionary) -> void:
	if chapter_number == 2 and defender == right and not _environment_damage:
		attacker.chain = ""
		return
	if chapter_number == 6 and defender == right:
		var boundary := (2 - phase) * 12
		move = move.duplicate()
		move["damage"] = minf(float(move["damage"]), right.hp - boundary)
	super._land_hit(attacker, defender, move)
	if chapter_number == 6 and defender == right and phase < 2 and right.hp <= (2 - phase) * 12:
		_advance_phase()


func _advance_phase() -> void:
	phase += 1
	checkpoint = phase
	slam_left = 0
	_boss_state = "recover"
	_boss_action = ""
	_boss_turn = 0
	var boss_hp := right.hp
	# Keep the hero's movement and any in-flight counter intact. The boss
	# gets a short recovery while the next pattern takes over automatically.
	right.ground_y = 500
	right.relax()
	right.hp = boss_hp
	right.glow = 0
	right.face_toward(left.position.x)
	right.go("idle", right.position.x, 1.0)
	left.hp = mini(left.hp_max, maxi(left.hp, 3))
	_cool.fill(0)
	for prop in get_tree().get_nodes_in_group("duel_prop"):
		prop.queue_free()
	magnet_left = 0
	crate_x = 920
	sandbags.clear()
	_sync_health()
	_hud.objective.text = "機關王 %d / 3 · %s" % [phase + 1, PHASE_NAMES[phase]]
	_audio.cue("phase")


func _check_spikes() -> void:
	# Chapters 2–6 have a solid floor. Only real combat HP can end a round;
	# crossing the former pit height never damages a boss or skips a phase.
	if left.out or right.out:
		_finish_round()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		_audio.toggle_mute()
		_hud.tell("音效關閉" if BattleAudio.muted else "音效開啟", 1.5)
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _retreat_direction(body: Duelist, target: Duelist) -> float:
	if chapter_number == 2 and body == right:
		return 0.0
	var direction := super._retreat_direction(body, target)
	var bounds := _bridge_bounds()
	# A marked rebound at the edge keeps the chapter's primary taught tool safe.
	# The arrow preview uses this same direction before the player clicks.
	var spring: Dictionary = _items["後撤彈簧"]
	var distance := float(spring["hop_x"]) * 2.0 * float(spring["hop_y"]) / maxf(1, float(spring["gravity"]))
	distance *= 1.18 if chapter_number == 2 else 1.12 if chapter_number == 4 else 1.0
	distance += 24.0 # Include discrete frame integration and the landing margin.
	if body == left and (body.position.x + direction * distance < bounds.x + 12 or body.position.x + direction * distance > bounds.y - 12):
		return -direction
	return direction


func _move_for(body: Duelist, id: String) -> Dictionary:
	var move := super._move_for(body, id)
	if chapter_number >= 3 and body == left and id == "彈簧開火":
		move["damage"] = 2
	return move


func _on_counter_shot(shooter: Duelist, target: Duelist, hit: bool) -> void:
	if chapter_number == 2 and shooter == left and hit:
		_hud.tell("護甲", 0.8, ["shield"])
		return
	super._on_counter_shot(shooter, target, hit)


func _tick_wind(dt: float) -> void:
	if chapter_number != 2 or not _wind_lifted or right.out:
		return
	if not right.airborne:
		_wind_lifted = false
		return
	# Slow motion, pause, and freeze affect wind and the airborne body equally.
	if right.frozen > 0 or right.hitstop > 0:
		return
	right.air_vx = move_toward(right.air_vx, wind * 560.0, 900.0 * dt)
	var in_rotor := right.position.x <= 425 if wind < 0 else right.position.x >= 985
	if right.position.y <= 430 and in_rotor:
		_wind_crash = true
		_wind_lifted = false
		_wind_impacts += 1
		_counter_hits += 1
		_mechanic_damage(3, "風車撞擊")
		_last_boss_hit = "風車撞擊"
		_shake = 6
		_audio.cue("hit")
		if right.out:
			_finish_round()
		else:
			# One collision per lift. The rotor knocks the surviving boss
			# back toward the arena; he lands and resumes the normal pattern.
			right.launch_arc(-wind * 220.0, 180.0, 1600.0, false, 0.3)
			_boss_state = "interrupted"
