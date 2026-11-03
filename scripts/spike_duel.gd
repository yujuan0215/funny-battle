extends "res://scripts/duel.gd"
## One additional arena, using the existing duel UI, actors and three props.

const SPIKE_STAGE := preload("res://scripts/spike_stage.gd")
const ArenaHud := preload("res://scripts/arena_hud.gd")
const Progress := preload("res://scripts/player_progress.gd")
const Campaign := preload("res://scripts/campaign_catalog.gd")
enum RoundState { BRIEFING, PLAYING, PAUSED, RESULT }
const SLIP_DISTANCE := 64.0
const BANANA_RADIUS := 20.0
const RUSH_WINDUP := 0.85
const RUSH_TIME := 1.0
const EDGE_HOLD := 0.4
const EDGE_MARGIN := 20.0
const HERO_HP := 8
const DEFAULT_PACE := 1.0
const HALF_PACE := 0.5
const FOCUS_PACE := 0.15
const RECOVER_TIME := 0.7
const BOSS_PATTERN: Array[String] = ["普通1", "衝刺", "遠距離普攻", "蓄力", "遠距離追擊", "衝刺"]
const INTRO_PATTERN: Array[String] = ["普通1", "衝刺"]
@export var beginner := true
@export_range(1, 6) var chapter_number := 1
const BattleAudio := preload("res://scripts/battle_audio.gd")
var _audio: Node
var _elapsed := 0.0
var _counter_hits := 0
var _ended := false
var _hero_wait := 0.0
var _boss_move: Dictionary = {}
var _boss_state := ""
var _rush_direction := -1.0
var _rush_target := 380.0
var _rush_previous_x := 780.0
var _rush_hit := false
var _banana_fall := false
var _boss_turn := 0
var _boss_action := ""
var _round_state: RoundState = RoundState.BRIEFING
var _hud: CanvasLayer
var _props_used := 0
var _last_hero_hit := "BOSS 的攻擊"
var _last_boss_hit := "主角的反擊"
var _intent_key := ""
var progress_path := ""
var _preferred_pace := DEFAULT_PACE
var _focus_slow := false
var _rescues_left := 0


func _ready() -> void:
	if progress_path.is_empty():
		progress_path = Progress.SAVE_PATH if beginner else Progress.LAB_SAVE_PATH
	qte = false
	brawl = false
	super._ready()
	remove_child(_stage)
	_stage.queue_free()
	_stage = SPIKE_STAGE.new()
	_stage.chapter_theme = ("forest_arena" if chapter_number == 1 else str(Campaign.chapter(chapter_number)["theme"])) if beginner else "test"
	add_child(_stage)
	_boss_move = (_moves["普通1"] as Dictionary).duplicate()
	_boss_move.merge({
		"startup": 0.85, "active": 0.12, "recover": 0.65,
		"range": 145.0, "damage": 2, "stun": 0.35, "kb": 20.0, "chain": "",
	}, true)
	if beginner:
		_items["時停"]["active"] = 3.0
	_hud = ArenaHud.new()
	add_child(_hud)
	_audio = BattleAudio.new()
	add_child(_audio)
	_hud.start_requested.connect(_start_round)
	_hud.next_requested.connect(_next_chapter)
	_hud.mute_requested.connect(func() -> void: _audio.toggle_mute())
	_hud.retry_requested.connect(_restart)
	_hud.leave_requested.connect(_leave_arena)
	_hud.pause_requested.connect(_pause_round)
	_hud.tool_selected.connect(pick_tool)
	_hud.pace_requested.connect(_toggle_battle_pace)
	spring_counter_fired.connect(_on_counter_shot)
	_reset_fighters()
	_hud.set_loadout(_allowed_tools())
	var tutorial := bool(get_tree().get_meta("arena_tutorial", false))
	if get_tree().has_meta("arena_tutorial"):
		get_tree().remove_meta("arena_tutorial")
	_hud.show_briefing(tutorial, str(Campaign.chapter(chapter_number)["name"]) if beginner else "尖刺試驗")
	if beginner:
		_hud.modal_reason.text = str(Campaign.chapter(chapter_number)["boss"])
		_hud.modal_detail.text = Campaign.opening(chapter_number)
		_hud.modal_detail.show()
	_hud.objective.text = "借力反擊" if beginner else "試驗場 · 擊敗 BOSS"
	camera.position = Vector2(705, 370)
	camera.zoom = Vector2.ONE * 1.25


func _level_number() -> int:
	return chapter_number if beginner else 3


func _allowed_tools() -> Array:
	return Campaign.chapter(chapter_number)["tools"] if beginner else [0, 1, 2]


func _rush_windup() -> float:
	return 1.4 if beginner else RUSH_WINDUP


func _rush_duration() -> float:
	return 1.4 if beginner else RUSH_TIME


func _edge_hold() -> float:
	return 0.9 if beginner else EDGE_HOLD


func _recover_duration() -> float:
	return 1.5 if beginner else RECOVER_TIME


func _banana_radius() -> float:
	return 32.0 if beginner else BANANA_RADIUS


func _reset_fighters() -> void:
	_ended = false
	_elapsed = 0.0
	_counter_hits = 0
	_hero_wait = 0.0
	_boss_state = ""
	_rush_direction = -1.0
	_rush_target = 380.0
	_rush_previous_x = 780.0
	_rush_hit = false
	_banana_fall = false
	_boss_turn = 0
	_boss_action = ""
	_round_state = RoundState.BRIEFING
	_props_used = 0
	_tool = int(_allowed_tools()[0])
	_rescues_left = 1 if beginner else 0
	_last_hero_hit = "BOSS 的攻擊"
	_last_boss_hit = "主角的反擊"
	_intent_key = ""
	_focus_slow = false
	_preferred_pace = DEFAULT_PACE
	_pace = _preferred_pace
	_spring_retreat = true
	_spring_practice = false
	left.display_name = "主角"
	right.display_name = "BOSS"
	left.hp_max = 6 if beginner else HERO_HP
	right.hp_max = 12 if beginner else 30
	left.scale = Vector2.ONE * 0.65
	right.scale = Vector2.ONE * 1.2
	left.use_sheet("bare")
	right.use_sheet("armor")
	# Leave enough bridge behind the hero for the first retreat spring.
	left.position = Vector2(600, 500)
	right.position = Vector2(840, 500)
	for body in [left, right]:
		body.set_process(false)
		body.ground_y = 500
		body.relax()
		body.glow = 0
		_stand(body)
	left.face_right = true
	right.face_right = false
	left.play("idle")
	right.play("idle")
	_apply_pace()
	_apply_hp_flags()
	_title.text = ""
	_hide_arena_chrome()
	_refresh_hint()
	_sync_health()
	if _hud != null:
		_hud.set_tools(_tool, _cool, _pace)
		_hud.set_intent("", ["boss"])
		_hud.set_timing(0, 0, _pace)
		_hud.tell("")
		_hud.set_rescue(_rescues_left > 0)


func _restart() -> void:
	super._restart()
	_reset_fighters()
	_start_round()


func _start_round() -> void:
	if _round_state == RoundState.RESULT:
		_restart()
		return
	var starting := _round_state == RoundState.BRIEFING
	_round_state = RoundState.PLAYING
	for body in [left, right]:
		body.set_process(true)
	for prop in get_tree().get_nodes_in_group("duel_prop"):
		prop.set_process(true)
	_hud.close_modal()
	if starting:
		_audio.cue("start")


func _apply_pace() -> void:
	super._apply_pace()
	for fx in get_tree().get_nodes_in_group("spring_shot_fx"):
		fx.pace = _pace
	if _hud != null:
		_hud.set_pace(_pace)
		_hud.set_tools(_tool, _cool, _pace)


func _tick_tool_cooldowns(delta: float) -> void:
	# Slowing the fight gives thinking time, not extra deployments per boss move.
	super._tick_tool_cooldowns(delta * _pace)


func _toggle_battle_pace() -> void:
	if _round_state != RoundState.PLAYING:
		return
	_preferred_pace = NORMAL if _preferred_pace < NORMAL else HALF_PACE
	_pace = FOCUS_PACE if _focus_slow else _preferred_pace
	_apply_pace()


func _pause_round() -> void:
	if _round_state == RoundState.PAUSED:
		_start_round()
		return
	if _round_state != RoundState.PLAYING:
		return
	_round_state = RoundState.PAUSED
	_focus_slow = false
	_pace = _preferred_pace
	_apply_pace()
	for body in [left, right]:
		body.set_process(false)
	for prop in get_tree().get_nodes_in_group("duel_prop"):
		prop.set_process(false)
	_hud.show_pause()


func _next_chapter() -> void:
	if beginner and chapter_number < 6:
		get_tree().change_scene_to_file(Campaign.chapter(chapter_number + 1)["scene"])
	else:
		_leave_arena()


func _leave_arena() -> void:
	get_tree().change_scene_to_file("res://scenes/levels.tscn" if beginner else "res://scenes/test_lab.tscn")


func pick_tool(index: int) -> void:
	if index not in _allowed_tools():
		if _hud != null:
			_hud.tell("", 1.2, ["lock"])
		return
	super.pick_tool(index)


func _sync_health() -> void:
	if _hud != null:
		_hud.set_health(left.hp, left.hp_max, right.hp, right.hp_max)


func _refresh_counter_hud() -> void:
	if _hud != null:
		_hud.set_tools(_tool, _cool, _pace)


func _counter_message(message: String, seconds: float = 2.0) -> void:
	super._counter_message(message, seconds)


func _on_counter_shot(shooter: Duelist, _target: Duelist, hit: bool) -> void:
	if _hud != null and shooter == left:
		if hit:
			_counter_hits += 1
			_audio.cue("counter")
		_hud.tell("命中" if hit else "落空", 1.0, ["check" if hit else "miss"], not hit)


func _process(delta: float) -> void:
	if _ended or _round_state != RoundState.PLAYING:
		return
	_elapsed += delta
	if not _preview and not _stage.editing:
		_keep_boss_on_bridge()
		_check_spikes()
		if _ended:
			return
	_hero_wait = maxf(0, _hero_wait - delta * _pace)
	super._process(delta)
	if _round_state != RoundState.PLAYING:
		return
	if _preview or _stage.editing:
		return
	_check_spikes()
	if left.out or right.out:
		_finish_round()
	else:
		var power_windup := right.use_module and str(right.sheet_move.get("id", "")) == "蓄力" and right.action_age < float(right.sheet_move.get("startup", 0))
		right.glow = 1 if (_boss_state == "windup" and right.use_module) or power_windup else 0
		if _boss_state == "charge" and right.use_module and right.action_age >= _rush_duration() and right.anim == "run":
			right._swap_anim("idle")
		if _boss_state == "windup" and right.use_module:
			_title.text = "蓄力"
		elif _boss_state == "charge" and right.anim == "run":
			_title.text = "衝刺"
		elif right.use_module and not right.sheet_move.is_empty():
			_title.text = _move_title(str(right.sheet_move["id"]))
		elif left.use_module and not left.sheet_move.is_empty():
			_title.text = _move_title(str(left.sheet_move["id"]))
		else:
			_title.text = ""
		_update_intent()
		_update_timing()


func _update_intent() -> void:
	var key := _boss_state + ":" + str(right.sheet_move.get("id", "")) + ":" + str(right.frozen > 0) + ":" + str(right.face_right)
	if key == _intent_key:
		return
	_intent_key = key
	var message := "接近"
	var direction := "right" if right.face_right else "left"
	var symbols := ["boss", direction]
	if right.frozen > 0:
		message = "定住"
		symbols = ["boss", "clock"]
	elif _boss_state == "windup":
		message = "衝撞準備"
		symbols = ["boss", "charge", "right" if _rush_direction > 0 else "left"]
	elif _boss_state == "charge":
		message = "衝撞"
		symbols = ["boss", "charge", "right" if _rush_direction > 0 else "left"]
	elif _boss_state in ["recover", "return", "interrupted"]:
		message = "空檔"
		symbols = ["boss", "clock"]
	elif right.use_module:
		var move := str(right.sheet_move.get("id", ""))
		message = _move_title(move)
		symbols = ["boss", "charge" if move == "蓄力" else "shot" if move == "遠距離普攻" else "strike", direction]
	_hud.set_intent(message, symbols)


func _update_timing() -> void:
	var remaining := 0.0
	var duration := 0.0
	var opening := _boss_state in ["recover", "return", "interrupted"]
	if right.frozen > 0:
		remaining = right.frozen
		duration = float((_items["時停"] as Dictionary)["active"])
		opening = true
	elif _boss_state == "windup" and right.use_module:
		duration = _rush_windup()
		remaining = maxf(0, duration - right.action_age)
	elif _boss_state == "recover":
		duration = _recover_duration()
		remaining = right.busy
		opening = true
	elif _boss_state == "attack" and right.use_module and not right.sheet_move.is_empty():
		duration = float(right.sheet_move.get("startup", 0))
		remaining = maxf(0, duration - right.action_age)
	_hud.set_timing(remaining, duration, _pace, opening)


func _placement_preview(at: Vector2) -> Dictionary:
	var bounds := _bridge_bounds()
	if at.x < bounds.x or at.x > bounds.y or at.y < 260 or at.y > SPIKE_STAGE.SPIKE_Y:
		return {}
	var floor_y := ground_height(at.x, at.y)
	if floor_y >= SPIKE_STAGE.SPIKE_Y:
		return {}
	var kind := ["peel", "spring", "stop"][_tool] as String
	var spot := _prop_at(kind, at.x, at.y)
	var radius := _banana_radius() if _tool == 0 else float((_items["後撤彈簧"] if _tool == 1 else _items["時停"])["range"])
	var affected: Array[Duelist] = []
	for body: Duelist in [left, right]:
		if body.out or body.airborne or absf(body.position.x - at.x) > radius:
			continue
		if _tool == 2 or absf(body.position.y - floor_y) < 28:
			affected.append(body)
	var available := _cool[_tool] <= 0 and get_tree().get_nodes_in_group("duel_prop").size() < 4
	return {"spot": spot, "floor": Vector2(at.x, floor_y), "radius": radius, "affected": affected, "available": available}


func _draw_spring_placement() -> void:
	# The arena uses one consistent preview for all three props below.
	pass


func _draw_placement_preview() -> void:
	var preview := _placement_preview(get_global_mouse_position())
	if preview.is_empty():
		return
	var ink := Placement.PixelSkin.HERO if preview["available"] else Placement.PixelSkin.DANGER
	var floor_at: Vector2 = preview["floor"]
	var spot: Vector2 = preview["spot"]
	var radius: float = preview["radius"]
	Placement.footprint(self, floor_at, radius, ink)
	var tint := Color(1, 1, 1, 0.85 if preview["available"] else 0.4)
	if _tool == 0:
		DuelProp.draw_banana(self, spot, tint)
	elif _tool == 2:
		ArenaHud.Icons.paint(self, "clock", spot + Vector2(0, -16), 36, tint)
	if not preview["available"]:
		ArenaHud.Icons.paint(self, "miss", spot + Vector2(0, -51), 15, ink)
	for body: Duelist in preview["affected"]:
		var side_ink := Placement.PixelSkin.HERO if body == left else Placement.PixelSkin.DANGER
		Placement.target(self, body.position + Vector2(0, -4), 24, side_ink)
	if _tool == 1:
		var body := _nearest_body(floor_at)
		var dir := _retreat_direction(body, _other(body))
		Placement.spring(self, spot, preview["available"])
		var tip := spot + Vector2(dir * 90, -38)
		Placement.arrow(self, spot, tip, ink)


func _draw() -> void:
	super._draw()
	if _hud == null or _round_state != RoundState.PLAYING:
		return
	_draw_placement_preview()
	for body: Duelist in [left, right]:
		var y := -(Duelist.FOOT * Duelist.SCALE + 128.0) * body.scale.y - 16.0
		var at := body.position + Vector2(0, y)
		var ink := Color(0.35, 0.94, 0.84) if body == left else Color(1.0, 0.48, 0.39)
		if body == left:
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -11), at + Vector2(7, -4), at + Vector2(0, 3), at + Vector2(-7, -4)]), ink)
		else:
			draw_colored_polygon(PackedVector2Array([at + Vector2(-8, -8), at + Vector2(8, -8), at + Vector2(0, 3)]), ink)
	if _boss_state in ["windup", "charge"]:
		var start := Vector2(right.position.x, 495)
		var end := Vector2(_rush_target, 495)
		var width := absf(end.x - start.x)
		if width > 8:
			draw_rect(Rect2(minf(start.x, end.x), 478, width, 22), Color(1.0, 0.3, 0.2, 0.16))
			draw_dashed_line(start, end, Color(0.08, 0.035, 0.04, 0.95), 8.0, 14.0)
			draw_dashed_line(start, end, Color(1, 0.45, 0.3, 0.9), 4.0, 14.0)
			draw_line(end, end + Vector2(-_rush_direction * 16, -12), Color(1, 0.5, 0.32), 4.0)
			draw_line(end, end + Vector2(-_rush_direction * 16, 12), Color(1, 0.5, 0.32), 4.0)


func _think_open(body: Duelist, other: Duelist) -> void:
	if _preview:
		super._think_open(body, other)
		return
	if _ended or _round_state != RoundState.PLAYING or _stage.editing or not body.can_act() or body.out or other.out:
		return
	body.just_landed = false
	if body.anim == "down":
		body.go("getup", body.position.x, body.clip_cycle("getup"))
		return
	var gap := other.position.x - body.position.x
	body.face_right = gap >= 0
	if body == left:
		_think_hero(other)
		return
	if body.chain != "":
		var next := body.chain
		body.chain = ""
		if not other.airborne and _chain_ok(body, other, next):
			_play_module(body, other, next)
			return
	match _boss_state:
		"windup":
			_boss_state = "charge"
			_rush_hit = false
			_rush_previous_x = body.position.x
			body.face_right = _rush_direction > 0
			body.sheet_move = {}
			body.start_module("run", _rush_target, _rush_duration() + _edge_hold(), _rush_duration(), -1.0, "")
		"charge", "interrupted":
			_start_return()
		"approach":
			_begin_boss_move()
		"attack":
			# Leave a readable opening after the full attack/chain so the
			# smaller fighter can close in and finish its own original combo.
			_boss_state = "recover"
			body.go("idle", body.position.x, _recover_duration())
		_:
			var distance := absf(gap)
			if beginner:
				_boss_action = INTRO_PATTERN[_boss_turn % INTRO_PATTERN.size()]
				_boss_turn += 1
			elif other.slipping and _band(distance, "遠距離追擊"):
				_boss_action = "遠距離追擊"
			elif other.frozen > 0 and _band(distance, "遠距離普攻"):
				_boss_action = "遠距離普攻"
			elif other.frozen > 0 and _band(distance, "蓄力"):
				_boss_action = "蓄力"
			else:
				_boss_action = BOSS_PATTERN[_boss_turn % BOSS_PATTERN.size()]
				_boss_turn += 1
			_begin_boss_move()


func _think_hero(other: Duelist) -> void:
	var gap := other.position.x - left.position.x
	var distance := absf(gap)
	if left.spring_shot_ready() and _spring_can_shoot(left, other):
		_play_module(left, other, "彈簧開火")
		_hero_wait = 1.0
		return
	if left.chain != "":
		var next := left.chain
		left.chain = ""
		if not other.airborne and _chain_ok(left, other, next):
			_play_module(left, other, next)
			return
	if _hero_wait <= 0 and other.frozen > 0:
		if _band(distance, "遠距離普攻"):
			_play_module(left, other, "遠距離普攻")
			_hero_wait = 1.0
			return
		if _band(distance, "蓄力"):
			_play_module(left, other, "蓄力")
			_hero_wait = 1.0
			return
	if _hero_wait <= 0 and other.slipping and not _banana_fall and _band(distance, "遠距離追擊"):
		_play_module(left, other, "遠距離追擊")
		_hero_wait = 1.0
		return
	if _boss_state in ["windup", "charge"] and not other.slipping:
		# Retreat inside the bridge instead of standing still or running into
		# the edge trap. A spring or enemy knockback can still knock us off.
		_step_fighter(left, left.position.x - signf(gap) * 48.0)
	elif distance > 88 and not other.airborne:
		_step_fighter(left, left.position.x + signf(gap) * minf(48, distance - 84))
	elif _hero_wait <= 0 and not other.airborne and (not beginner or other.slipping or other.frozen > 0):
		_play_module(left, other, "普通1")
		_hero_wait = 1.2
	else:
		left.go("idle", left.position.x, 0.2)


func _step_fighter(body: Duelist, target: float) -> void:
	var bounds := _bridge_bounds()
	var margin := minf(72.0 if body == left else EDGE_MARGIN, (bounds.y - bounds.x) * 0.45)
	var destination := clampf(target, bounds.x + margin, bounds.y - margin)
	if absf(destination - body.position.x) < 2:
		body.go("idle", body.position.x, 0.2)
		return
	body.face_right = destination > body.position.x
	body.go("walk", destination, 0.4)


func _begin_boss_move() -> void:
	var gap := left.position.x - right.position.x
	if _boss_action == "衝刺":
		var bounds := _bridge_bounds()
		_boss_state = "windup"
		_audio.cue("warn")
		_rush_direction = 1.0 if gap > 0 else -1.0
		_rush_target = bounds.y - EDGE_MARGIN if _rush_direction > 0 else bounds.x + EDGE_MARGIN
		right.face_right = _rush_direction > 0
		right.chain = ""
		right.sheet_move = {}
		right.start_module("power", right.position.x, _rush_windup(), 0.0, -1.0, "")
		return
	var move: Dictionary = _moves[_boss_action]
	var reach := 88.0 if _boss_action == "普通1" else float(move["range"])
	if _boss_action == "遠距離追擊":
		reach += float(move["travel_max"])
	if absf(gap) > reach:
		_boss_state = "approach"
		_step_fighter(right, right.position.x + signf(gap) * minf(56, absf(gap) - reach + 4))
		return
	_boss_state = "attack"
	_play_module(right, left, _boss_action)


func _play_module(body: Duelist, other: Duelist, id: String) -> void:
	super._play_module(body, other, id)
	if _preview or not body.use_module:
		return
	# Reuse the original modules and animations. Limit their travel to safe
	# bridge positions; external slips and hits on the hero remain dangerous.
	var bounds := _bridge_bounds()
	var margin := minf(72.0 if body == left else EDGE_MARGIN, (bounds.y - bounds.x) * 0.45)
	body._to = clampf(body._to, bounds.x + margin, bounds.y - margin)
	if body == right:
		body.sheet_move["kb"] = minf(float(body.sheet_move["kb"]), 18)


func _move_for(body: Duelist, id: String) -> Dictionary:
	var move := super._move_for(body, id).duplicate()
	if not beginner:
		return move
	if body == right:
		move["startup"] = maxf(float(move["startup"]), 0.9)
		move["damage"] = 1
		move["kb"] = 6
		move["chain"] = ""
	elif id in ["普通1", "普通2", "普通3"]:
		move["damage"] = 0
		move["chain"] = ""
	elif id in ["彈簧開火", "遠距離普攻", "蓄力", "遠距離追擊", "下落"]:
		move["damage"] = float(move["damage"]) * 2
	return move


func _bridge_bounds() -> Vector2:
	if _stage.strips.is_empty():
		return Vector2(360, 1050)
	var strip: Dictionary = _stage.strips[0]
	return Vector2(minf(float(strip["x0"]), float(strip["x1"])), maxf(float(strip["x0"]), float(strip["x1"])))


func _start_return() -> void:
	_boss_state = "return"
	_boss_action = ""
	_banana_fall = false
	var bounds := _bridge_bounds()
	var home := clampf(780, bounds.x + EDGE_MARGIN, bounds.y - EDGE_MARGIN)
	right.face_right = home > right.position.x
	right.go("walk", home, 1.2)


func _keep_boss_on_bridge() -> void:
	# Voluntary movement stops on the bridge. External displacement obeys
	# the same physical edges on both sides; the boss is never warped back.
	var bounds := _bridge_bounds()
	if right.position.x < bounds.x or right.position.x > bounds.y:
		_banana_fall = true


func _resolve_modules() -> void:
	super._resolve_modules()
	if _preview or _boss_state != "charge" or _rush_hit or right.out or left.out:
		return
	if not right.use_module or right.slipping or right.airborne or right.frozen > 0 or right.hitstop > 0:
		return
	var low := minf(_rush_previous_x, right.position.x) - 58.0
	var high := maxf(_rush_previous_x, right.position.x) + 58.0
	if right.action_age <= _rush_duration() and left.position.x >= low and left.position.x <= high and absf(left.position.y - right.position.y) < 100:
		_rush_hit = true
		_land_hit(right, left, _boss_move)
	_rush_previous_x = right.position.x


func _land_hit(attacker: Duelist, defender: Duelist, move: Dictionary) -> void:
	if _preview or defender != right:
		if defender == left:
			_last_hero_hit = "衝撞" if _boss_state == "charge" else _move_title(str(move.get("id", "普通1")))
			if beginner:
				move = move.duplicate()
				move["damage"] = mini(1, int(move["damage"]))
				move["kb"] = minf(6, float(move["kb"]))
				move["chain"] = ""
		super._land_hit(attacker, defender, move)
		if _audio != null:
			_audio.cue("hurt")
		_sync_health()
		return
	if defender.out:
		return
	# Heavy boss actions resist knockback, but every visible point of damage
	# counts toward an actual health victory, including the final point.
	var damage := maxi(int(round(float(move["damage"]))), 0)
	if damage == 0:
		attacker.chain = ""
		return
	defender.hp = maxi(0, defender.hp - damage)
	_last_boss_hit = _move_title(str(move.get("id", "普通1")))
	if defender.hp == 0:
		defender.out = true
		defender.react("down", defender.position.x, 0, 0, true, 0.4)
	attacker.chain = "" if defender.out else str(move.get("chain", ""))
	if attacker.chain != "":
		attacker.leave_active(float(move["active"]))
	attacker.hitstop = maxf(attacker.hitstop, 0.03)
	defender.hitstop = maxf(defender.hitstop, 0.03)
	_shake = maxf(_shake, 4)
	if _audio != null:
		_audio.cue("hit")
	_spark(defender.chest(), attacker.sheet)
	_sync_health()
	var id := str(move.get("id", ""))
	if id in ["蓄力", "遠距離普攻", "彈簧開火", "遠距離追擊", "下落"]:
		_hud.tell("−%d" % damage, 1.6, ["charge" if id == "蓄力" else "shot", "check"])


func _try_peel(body: Duelist, prop: DuelProp) -> bool:
	if _preview:
		return super._try_peel(body, prop)
	if body.out or body.slipping or body.airborne:
		return false
	var row: Dictionary = _items["香蕉"]
	var direction := signf(body.vx) if absf(body.vx) > 1 else (1.0 if body.face_right else -1.0)
	body.begin_slip(direction, SLIP_DISTANCE, float(row["recover"]))
	if body == right:
		var bounds := _bridge_bounds()
		_banana_fall = body._to < bounds.x or body._to > bounds.y
		_boss_state = "interrupted"
		body.glow = 0
		_hud.tell("BOSS", 2.0, ["banana", "slip", "spikes"] if _banana_fall else ["banana", "slip"])
	else:
		_hud.tell("我方滑倒", 2.0, ["banana", "slip"], true)
	prop.consume()
	return true


func _try_spring(body: Duelist, prop: DuelProp) -> bool:
	var launched := super._try_spring(body, prop)
	if launched and body == right and not _preview:
		_banana_fall = false
		_boss_state = "interrupted"
	elif launched and body == left and not _preview:
		pass
	return launched


func _resolve_stop(prop: DuelProp) -> void:
	super._resolve_stop(prop)
	if _hud == null or _preview:
		return
	if right.frozen > 0 and left.frozen > 0:
		_hud.tell("雙方定住", 2.0, ["heart", "clock", "boss"], true)
	elif right.frozen > 0:
		_hud.tell("定住", 2.0, ["boss", "clock", "charge"])
	elif left.frozen > 0:
		_hud.tell("我方定住", 2.0, ["heart", "clock"], true)
	else:
		_hud.tell("落空", 2.0, ["clock", "miss"], true)


func _place(at: Vector2) -> void:
	if _ended or _round_state != RoundState.PLAYING:
		return
	if _tool not in _allowed_tools():
		return
	if _placement_preview(at).is_empty():
		_hud.tell("場外" if beginner and chapter_number >= 2 else "橋外", 1.5, ["miss"] if beginner and chapter_number >= 2 else ["spikes", "miss"], true)
		return
	if _cool[_tool] > 0:
		_hud.tell("%.1f" % (_cool[_tool] / _pace), 1.0, ["clock"], true)
		return
	if get_tree().get_nodes_in_group("duel_prop").size() >= 4:
		_hud.tell("4 / 4", 1.5, ["miss"], true)
		return
	var before := get_child_count()
	super._place(at)
	if get_child_count() > before:
		var prop := get_child(get_child_count() - 1) as DuelProp
		if prop != null and prop.kind == "peel" and not _preview:
			prop.radius = _banana_radius()
		if beginner and prop != null:
			prop.life = maxf(prop.life, 4.5)
			_cool[_tool] *= 0.7
			_refresh_counter_hud()
		_props_used += 1
		_audio.cue("place")
		_hud.tell("", 0.5, [["banana", "check"], ["spring", "check"], ["clock", "check"]][_tool])


func _facing_hit(attacker: Duelist, defender: Duelist, reach: float) -> bool:
	if attacker.out or defender.out or absf(attacker.position.y - defender.position.y) > 100:
		return false
	return super._facing_hit(attacker, defender, reach)


func _check_spikes() -> void:
	for body in [left, right]:
		if not body.out and body.position.y >= SPIKE_STAGE.SPIKE_Y:
			if body == left and _rescues_left > 0:
				_rescue_hero()
				continue
			body.hp = 0
			body.out = true
	if left.out or right.out:
		_finish_round()


func _rescue_hero() -> void:
	_rescues_left -= 1
	var health := left.hp
	var bounds := _bridge_bounds()
	left.relax()
	left.position = Vector2((bounds.x + bounds.y) * 0.5, 500)
	_stand(left)
	left.hp = health
	left.face_toward(right.position.x)
	_hud.set_rescue(false)
	_hud.tell("救援", 2.5, ["shield", "check"])


func _finish_round() -> void:
	if _ended:
		return
	_ended = true
	_round_state = RoundState.RESULT
	for body in [left, right]:
		body.glow = 0
		body.set_process(false)
	for node in get_tree().get_nodes_in_group("duel_prop"):
		node.set_process(false)
	_title.text = "平手" if left.out and right.out else ("失敗" if left.out else "勝利")
	var won := right.out and not left.out
	var reason := ""
	if left.out and right.out:
		reason = "雙方倒下"
	elif won:
		reason = "落入尖刺" if right.position.y >= SPIKE_STAGE.SPIKE_Y else "%s擊倒" % _last_boss_hit
	else:
		reason = "落入尖刺" if left.position.y >= SPIKE_STAGE.SPIKE_Y else "%s擊倒" % _last_hero_hit
	var saved := won and Progress.mark_cleared(_level_number(), progress_path) == OK
	_sync_health()
	_hud.show_result(won, reason, _props_used, saved)
	_audio.cue("win" if won else "lose")
	_hud.modal_detail.text += "\n時間 %02d:%02d　·　反擊 %d 次　·　剩餘 HP %d" % [int(_elapsed) / 60, int(_elapsed) % 60, _counter_hits, left.hp]
	if beginner and won:
		_hud.offer_next(chapter_number < 6, "下一章：" + str(Campaign.chapter(mini(chapter_number + 1, 6))["name"]))
		if chapter_number == 6:
			_hud.modal_title.text = "機關島恢復運轉"
			_hud.modal_reason.text = "冒險完成"
	_refresh_hint()


func _input(event: InputEvent) -> void:
	# Space is a hold action even after clicking a focused tool button.
	# Handle it before GUI confirm so the button cannot swallow slow motion.
	if event is InputEventKey and event.keycode == KEY_SPACE:
		_unhandled_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SPACE:
		if _round_state == RoundState.PLAYING and not event.echo:
			_focus_slow = event.pressed
			_pace = FOCUS_PACE if _focus_slow else _preferred_pace
			_apply_pace()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_1, KEY_2, KEY_3]:
			if _round_state == RoundState.PLAYING:
				var slot := int(event.keycode - KEY_1)
				var allowed := _allowed_tools()
				if slot < allowed.size():
					pick_tool(int(allowed[slot]))
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			if _round_state == RoundState.BRIEFING or _round_state == RoundState.RESULT:
				_leave_arena()
			else:
				_pause_round()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_M:
			_audio.toggle_mute()
			_hud.tell("音效關閉" if BattleAudio.muted else "音效開啟", 1.5)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_R:
			_restart()
			get_viewport().set_input_as_handled()
			return
		if event.keycode in [KEY_TAB, KEY_G, KEY_P, KEY_T, KEY_H] or (event.keycode == KEY_2 and event.shift_pressed):
			get_viewport().set_input_as_handled()
			return
	if _round_state != RoundState.PLAYING:
		return
	super._unhandled_input(event)


func _refresh_hint() -> void:
	super._refresh_hint()
	if _hint != null:
		_hint.visible = false
		_hint.text = ""


func _hide_arena_chrome() -> void:
	# The inherited sandbox stays available in its own modes. This arena gets
	# one coherent player HUD instead of exposing editor and costume controls.
	if _rack != null:
		(_rack.get_parent() as Control).hide()
	for key in _cast_buttons.keys():
		var button := _cast_buttons[key] as Node
		if button != null:
			button.queue_free()
	_cast_buttons.clear()
	for node in [_watch_button, _pace_button, _hp_button, _count_button, _practice_button, _ground_button, _preview_row]:
		if node != null:
			node.queue_free()
	_watch_button = null
	_pace_button = null
	_hp_button = null
	_count_button = null
	_practice_button = null
	_ground_button = null
	_preview_row = null
	if _hint != null:
		_hint.visible = false
		_hint.text = ""


func _notification(what: int) -> void:
	if has_meta("automated_capture"):
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(_hud) and _round_state == RoundState.PLAYING:
		_pause_round()
