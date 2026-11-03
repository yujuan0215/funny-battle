extends SceneTree

const Progress := preload("res://scripts/player_progress.gd")
const SAVE := "res://.test-data/intro_campaign_test.json"
var checks := 0
var failures := 0
var shots := 0
var seen: Dictionary = {}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.test-data"))
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func scene(path: String):
	var game = load(path).instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.progress_path = SAVE
	root.add_child(game)
	return game


func step(game, fps: int = 60) -> void:
	game._process(1.0 / fps)
	if not game._ended:
		game.left._process(1.0 / fps)
		game.right._process(1.0 / fps)
	if not game.right.sheet_move.is_empty():
		seen[str(game.right.sheet_move["id"])] = true
	for prop in get_nodes_in_group("duel_prop"):
		if not prop.is_queued_for_deletion():
			prop._process(1.0 / fps)
		if prop.is_queued_for_deletion():
			prop.free()


func clean() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))


func _run() -> void:
	clean()
	var intro = scene("res://scenes/spikes.tscn")
	var challenge = scene("res://scenes/spikes_challenge.tscn")
	check(intro.beginner and not challenge.beginner, "Entry and challenge are distinct playable profiles")
	check(intro.left.hp == 6 and challenge.left.hp == 8, "Campaign hero is weaker than the boss and the preserved lab")
	check(intro.right.hp == 12 and challenge.right.hp == 30, "Entry needs fewer successful interventions")
	check(intro._rescues_left == 1 and intro._hud.rescue_icon.visible and challenge._rescues_left == 0, "Only the entry level has a visible one-use safety rope")
	check(intro._rush_windup() == 1.4 and challenge._rush_windup() == 0.85, "Entry provides a readable 1.4-second rush at default normal speed")
	check(intro._recover_duration() == 1.5 and challenge._recover_duration() == 0.7, "Entry provides a three-second recovery opening at normal speed")
	var move: Dictionary = intro._move_for(intro.right, "普通1")
	check(move["chain"] == "" and move["damage"] == 1 and move["startup"] >= 0.9, "Entry boss punches are telegraphed single hits")
	check(challenge._move_for(challenge.right, "普通1")["chain"] == "普通2", "The original boss combo remains in the challenge")
	check(intro._moves["普通1"]["startup"] == 0.12, "Difficulty tuning never mutates the shared move catalog")
	check(intro._move_for(intro.left, "彈簧開火")["damage"] == 4 and challenge._move_for(challenge.left, "彈簧開火")["damage"] == 2, "Successful spring counters are rewarding in entry while challenge damage is preserved")
	check(intro.camera.zoom.x == 1.25 and challenge.camera.zoom.x == 1.25, "Both spike levels use the larger battle framing")
	var half: Vector2 = root.get_visible_rect().size / intro.camera.zoom * 0.5
	var visible := Rect2(intro.camera.position - half, half * 2)
	check(visible.has_point(Vector2(360, 500)) and visible.has_point(Vector2(1050, 500)), "Zoom keeps both actual bridge edges in view")
	check(ProjectSettings.get_setting("display/window/size/window_width_override") == 1600, "Default play window is larger without changing the UI reference layout")
	challenge.free()
	check(not intro._hud.tool_buttons[2].visible, "Entry only exposes its two actual tools")
	intro.pick_tool(2)
	check(intro._tool != 2, "Time stop cannot be selected before its chapter")
	intro._start_round()
	intro.pick_tool(0)
	intro._place(Vector2(1000, 500))
	var prop = get_nodes_in_group("duel_prop").back()
	check(prop.radius == 32 and prop.life >= 4.5, "Entry banana timing and contact are more forgiving")
	check(is_equal_approx(intro._cool[0], 1.6 * 0.7), "Entry cooldown is shorter without altering challenge tuning")
	prop.free()
	intro._restart()
	for frame in 8 * 60:
		step(intro)
	check(not intro._ended and intro.left.hp >= 3, "A new player survives the first eight seconds without intervention")
	check(intro.right.hp == 12, "The hero does not automatically clear the entry level while the player watches")
	intro.left.position = Vector2(300, 580)
	var hp: int = intro.left.hp
	intro._check_spikes()
	check(not intro._ended and not intro.left.airborne and intro.left.hp == hp, "First pit mistake returns the hero alive without free healing")
	check(intro._rescues_left == 0 and not intro._hud.rescue_icon.visible and intro.left.position.y == 500, "The safety rope is visibly consumed and lands on the bridge")
	intro.left.position = Vector2(300, 580)
	intro._check_spikes()
	check(intro._ended and intro.left.out, "A second pit mistake still follows the normal loss rule")
	intro._restart()
	check(intro._rescues_left == 1 and intro.left.hp == 6, "Retry restores entry health and the one-use rope")
	intro.free()

	for fps in [30, 60, 120]:
		intro = scene("res://scenes/spikes.tscn")
		intro._start_round()
		intro.pick_tool(1)
		shots = 0
		var placements := 0
		seen.clear()
		intro.spring_counter_fired.connect(func(_a, _b, hit: bool) -> void:
			if hit:
				shots += 1
		)
		for frame in 100 * fps:
			if intro._ended:
				break
			if intro._cool[1] <= 0 and not intro.left.airborne and not intro.left.slipping and intro.left.frozen <= 0 and absf(intro.left.position.x - intro.right.position.x) < 180:
				intro._place(intro.left.position + Vector2(12 if intro.left.face_right else -12, 0))
				placements += 1
			step(intro, fps)
		check(intro._ended and intro.right.out and not intro.left.out, "An understandable spring-only strategy wins through real simulation at %d FPS" % fps)
		check(shots == 3 and placements <= 5, "Entry can be cleared with three real counters and some placement mistakes at %d FPS" % fps)
		check(not seen.has("普通2") and not seen.has("遠距離普攻") and not seen.has("遠距離追擊"), "Entry boss avoids combo, ranged and reactive punishments at %d FPS" % fps)
		check(Progress.is_cleared(1, SAVE) and not Progress.is_cleared(3, SAVE), "Entry clears only its own progress at %d FPS" % fps)
		intro.free()

	var second = scene("res://scenes/level_two.tscn")
	check(second.campaign_level == 2 and second._pace == second.SLOW, "Remote duel starts at main's slow default like the original second level")
	check(is_instance_valid(second._pause_button) and second._pause_button.shape == "pause", "Second level retains the upstream pause UI")
	check(second._items.size() == 3 and not second._spring_retreat_row.is_empty(), "Second level loads the upstream item rules rather than the old local spring toggle")
	var cap = scene("res://scenes/level_two.tscn")
	cap._tool = 0
	for n in 4:
		for k in cap._cool.size():
			cap._cool[k] = 0.0
		cap._place(Vector2(200.0 + n * 90.0, 548.0))
	check(get_nodes_in_group("duel_prop").size() == 4, "Level two accepts four props")
	cap._place(Vector2(900.0, 548.0))
	check(cap._counter_notice.contains("冷卻"), "Blocked placement during cooldown explains itself")
	for k in cap._cool.size():
		cap._cool[k] = 0.0
	cap._place(Vector2(900.0, 548.0))
	check(get_nodes_in_group("duel_prop").size() == 4 and cap._counter_notice.contains("已滿"), "A full field explains itself instead of ignoring the click")
	get_nodes_in_group("duel_prop")[0].armed = false
	for k in cap._cool.size():
		cap._cool[k] = 0.0
	cap._place(Vector2(900.0, 548.0))
	var fresh := 0
	for cap_prop in get_nodes_in_group("duel_prop"):
		if not cap_prop.is_queued_for_deletion() and cap_prop.position.x == 900.0:
			fresh += 1
	check(fresh == 1, "A used-up banana no longer blocks the next placement")
	for cap_prop in get_nodes_in_group("duel_prop"):
		cap_prop.free()
	cap.free()
	# Placed props must be recognised by the upstream rules (a global DuelProp class once shadowed the alias and made them inert).
	for tool in [0, 1]:
		var lab = scene("res://scenes/level_two.tscn")
		lab._tool = tool
		lab._place(Vector2(lab.left.position.x + (40.0 if tool == 0 else 0.0), lab.left.position.y))
		var reacted := false
		for i in 200:
			lab._process(1.0 / 60.0)
			lab.left._process(1.0 / 60.0)
			lab.right._process(1.0 / 60.0)
			for lab_prop in get_nodes_in_group("duel_prop"):
				if not lab_prop.is_queued_for_deletion():
					lab_prop._process(1.0 / 60.0)
			reacted = reacted or lab._title.text in ["滑鏟", "跳高"]
		check(reacted, "Level two banana slides and spring launches the fighter standing on it" + (" (banana)" if tool == 0 else " (spring)"))
		for lab_prop in get_nodes_in_group("duel_prop"):
			lab_prop.free()
		lab.free()
	check(second._spring_plan(second.left, -1)["shot"] and second._spring_plan(second.left, 1)["toward"], "Upstream spring direction plans survive the port")
	second._open_pause()
	check(paused and second._pause_panel.visible, "Upstream pause actually freezes the tree")
	second._return_to_battle()
	check(not paused and not second._pause_panel.visible, "Upstream resume restores the campaign")
	second.right.hp = 1
	second._land_hit(second.left, second.right, second._moves["普通1"])
	second._process(0)
	check(second.right.out and Progress.is_cleared(2, SAVE), "Second level victory uses a real hit and saves level two")
	check(second._success_panel.visible and second._next_button.visible, "Second level success offers the third-level challenge")
	second._dismiss_flow()
	second.free()
	var levels = scene("res://scenes/levels.tscn")
	check(levels._levels.size() == 6, "Adventure presents the six-chapter design")
	check(bool(levels._levels[0].get_meta("playable")), "The introductory outpost remains playable")
	for index in range(1, 6):
		check(bool(levels._levels[index].get_meta("playable")), "Demo chapter %d is playable" % (index + 1))
	levels._show_blueprint(preload("res://scripts/campaign_catalog.gd").chapter(6))
	check(is_instance_valid(levels._overlay), "The final boss blueprint can be inspected without entering unfinished gameplay")
	check(levels._levels[0].focus_mode == Control.FOCUS_NONE, "Blueprint inspection cannot tab into covered chapter buttons")
	levels._close_blueprint()
	check(levels._levels[0].focus_mode == Control.FOCUS_ALL, "Closing the blueprint restores map navigation")
	levels.free()
	var lab = scene("res://scenes/test_lab.tscn")
	check(lab.testing and lab._levels.size() == 6, "Both original arenas, three action trials and the terrain hub remain in the laboratory")
	check(Progress.SAVE_PATH != Progress.LAB_SAVE_PATH, "Experiment clears cannot unlock the adventure")
	lab.free()
	clean()
	print("Intro and campaign tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
