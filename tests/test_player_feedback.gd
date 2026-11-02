extends SceneTree

const Arena := preload("res://scenes/spikes_challenge.tscn")
const Progress := preload("res://scripts/player_progress.gd")
const TEST_SAVE := "user://player_feedback_test.json"
const LOSS_SAVE := "user://player_feedback_loss_test.json"
var checks := 0
var failures := 0
var shots := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func clean(path: String) -> void:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func arena(start: bool = true, path: String = TEST_SAVE):
	var game = Arena.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.progress_path = path
	root.add_child(game)
	if start:
		game._start_round()
	return game


func simulate(game, seconds: float, fps: int = 60) -> void:
	for frame in int(ceil(seconds * fps)):
		game._process(1.0 / fps)
		if game._round_state == game.RoundState.PLAYING:
			game.left._process(1.0 / fps)
			game.right._process(1.0 / fps)
		for prop in get_nodes_in_group("duel_prop"):
			if not prop.is_queued_for_deletion() and prop.is_processing():
				prop._process(1.0 / fps)
			if prop.is_queued_for_deletion():
				prop.free()


func _run() -> void:
	clean(TEST_SAVE)
	clean(LOSS_SAVE)
	var game = arena(false)
	check(game._hud.overlay.visible and game._round_state == game.RoundState.BRIEFING, "A safe briefing explains the objective before combat")
	check("emptyheart" in game._hud.win_conditions.symbols and "spikes" in game._hud.win_conditions.symbols, "Both actual win conditions have persistent pictograms")
	check(not game.left.is_processing() and not game.right.is_processing(), "Actors cannot attack during the briefing")
	check(game._hud.tool_buttons[0].focus_mode == Control.FOCUS_NONE, "Modal focus excludes covered battle controls")
	check(game._hud.primary.focus_neighbor_right == game._hud._modal_buttons.get_child(2).get_path(), "Briefing navigation skips the hidden retry button")
	game._place(game.left.position)
	check(get_nodes_in_group("duel_prop").is_empty() and game._props_used == 0, "Briefing blocks world placement")
	game._hud.primary.pressed.emit()
	check(game._round_state == game.RoundState.PLAYING and not game._hud.overlay.visible, "Start button begins real combat")
	check(game._pace == 0.5 and game.left.time_scale == 0.5 and game.left.is_processing(), "Battle starts in readable half speed without holding a key")
	check(game._hud.pace_button.text == "×0.5", "Current pace remains visible without an explanatory paragraph")
	check(game._hud.tool_buttons[0].focus_mode == Control.FOCUS_ALL, "Closing the modal restores battle control focus")
	check(not game._rack.get_parent().visible and game._cast_buttons.is_empty(), "Sandbox/editor controls stay hidden")
	game._hud.pause_requested.emit()
	var before: Vector2 = game.left.position
	simulate(game, 2)
	check(game._round_state == game.RoundState.PAUSED and game.left.position == before, "Pause freezes actors and battle decisions")
	game._place(game.left.position)
	check(game._props_used == 0, "Pause cannot spend a prop")
	game._hud.primary.pressed.emit()
	check(game._round_state == game.RoundState.PLAYING and game.left.position == before, "Continue preserves the battle state")
	var slow := InputEventKey.new()
	slow.keycode = KEY_SPACE
	slow.pressed = true
	game._unhandled_input(slow)
	check(game._pace == 0.15 and game.left.time_scale == 0.15, "Holding Space adds thinking time beyond default half speed")
	slow.pressed = false
	game._unhandled_input(slow)
	check(game._pace == 0.5 and game.right.time_scale == 0.5, "Releasing Space returns to the chosen half speed")
	# Route through the actual viewport GUI: focused buttons also accept Space.
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game._hud.tool_buttons[1].grab_focus()
	await process_frame
	slow.pressed = true
	root.push_input(slow)
	check(game._pace == 0.15, "Focused tool buttons cannot swallow the Space hold action")
	slow.pressed = false
	root.push_input(slow)
	check(game._pace == 0.5, "Space release reaches the arena while a tool button has GUI focus")
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game._hud.pace_button.pressed.emit()
	check(game._pace == 1.0 and game.right.time_scale == 1.0, "Pace control offers real-time combat when desired")
	slow.pressed = true
	game._input(slow)
	slow.pressed = false
	game._input(slow)
	check(game._pace == 1.0, "Focus release restores the selected pace, rather than always forcing half speed")
	game._hud.pace_button.pressed.emit()
	game._place(Vector2(200, 500))
	check(game._props_used == 0 and game._hud.feedback.text == "橋外" and "miss" in game._hud._feedback_icons.symbols, "Invalid ground gives a warning pictogram without spending cooldown")
	for i in 3:
		game._hud.tool_buttons[i].pressed.emit()
		check(game._tool == i, "HUD tool %d selects the corresponding mechanic" % i)
	game._hud.tool_buttons[1].pressed.emit()
	game._place(game.left.position)
	check(game._props_used == 1 and "spring" in game._hud._feedback_icons.symbols and "check" in game._hud._feedback_icons.symbols, "Accepted placement confirms the action with matching pictograms")
	game._tick_tool_cooldowns(0.4)
	check(is_equal_approx(game._cool[1], 1.8), "Half speed slows cooldowns in step with combat so it cannot create extra deployments")
	game._refresh_counter_hud()
	check(game._hud._cool_labels[1].text == "3.6", "Cooldown numbers show wall-clock seconds at the selected battle pace")
	game._place(game.left.position)
	check(game._props_used == 1 and "clock" in game._hud._feedback_icons.symbols and float(game._hud.feedback.text) > 0, "Cooldown rejection shows a timer without counting a phantom action")
	var partial_cool: Array[float] = [0.0, 0.04, 0.0]
	game._hud.set_tools(1, partial_cool)
	check(game._hud._cool_labels[1].text == "0.1" and game._hud._tool_icons[1].cooldown > 0, "A positive fractional cooldown never appears ready")
	var ready_cool: Array[float] = [0.0, 0.0, 0.0]
	game._hud.set_tools(1, ready_cool)
	check(game._hud._cool_labels[1].text.is_empty() and game._hud._tool_icons[1].cooldown == 0, "Cooldown completion clears its ring and number even within the same rounded tenth")
	game._restart()
	check(game._props_used == 0 and game._round_state == game.RoundState.PLAYING, "Retry immediately resets a playable round")
	game._boss_action = "衝刺"
	game._begin_boss_move()
	game._update_intent()
	game._update_timing()
	check(game._hud.intent.text == "衝撞準備" and "left" in game._hud._intent_icons.symbols, "Rush intent combines a short cue and locked-direction arrow")
	check(game._hud.intent_bar.visible and game._hud.intent_timer.text == "1.7s", "Rush warning shows the real-time decision window at half speed")
	game.right.action_age = game.RUSH_WINDUP * 0.5
	game._update_timing()
	check(is_equal_approx(game._hud.intent_bar.value, 0.5), "Warning gauge follows the actual attack startup")
	game._boss_state = "recover"
	game.right.busy = game.RECOVER_TIME
	game._update_intent()
	game._update_timing()
	check(game._hud.intent.text == "空檔" and game._hud.intent_timer.text == "1.4s", "A complete attack leaves a readable 1.4-second counter window")
	game._restart()
	game._update_intent()
	check("left" in game._hud._intent_icons.symbols, "Boss approach arrows follow its actual facing instead of always pointing right")
	game.right.face_right = true
	game._update_intent()
	check("right" in game._hud._intent_icons.symbols, "Turning invalidates the intent cache even without changing the action state")
	game.pick_tool(1)
	var preview: Dictionary = game._placement_preview(game.left.position)
	check(preview["affected"].has(game.left) and not preview["affected"].has(game.right), "Spring preview identifies the nearby hero before committing")
	check(preview["available"] and preview["radius"] == float(game._items["後撤彈簧"]["range"]), "Spring preview uses the actual trigger radius")
	check(game._placement_preview(Vector2(200, 500)).is_empty(), "The pit cannot display a valid deployment preview")
	game.pick_tool(2)
	game.right.position.x = game.left.position.x + 60
	preview = game._placement_preview(game.left.position)
	check(preview["affected"].size() == 2, "Time-stop preview reveals friendly fire when both actors are inside")
	game._cool[2] = 1
	check(not game._placement_preview(game.left.position)["available"], "Cooldown previews are visually marked unavailable")
	game.free()

	for fps in [30, 60, 120]:
		game = arena()
		shots = 0
		game.spring_counter_fired.connect(func(shooter: Duelist, _target: Duelist, hit: bool) -> void:
			if shooter == game.left and hit:
				shots += 1
		)
		game.pick_tool(1)
		game._place(game.left.position)
		simulate(game, 4, fps)
		check(shots == 1 and game.right.hp < game.right.hp_max, "Arena hero uses the real retreat shot at %d FPS" % fps)
		check(game.left.position.x >= game._bridge_bounds().x and not game.left.out, "Opening spring has safe retreat room at %d FPS" % fps)
		game.free()

	game = arena()
	game.right.hp = 2
	game._land_hit(game.left, game.right, game._moves["彈簧開火"])
	game._finish_round()
	check(game.right.hp == 0 and game.right.out and game._round_state == game.RoundState.RESULT, "The last visible HP point can end the battle")
	check(game._hud.overlay.visible and game._hud.modal_title.text == "勝利" and "cup" in game._hud._result_icon.symbols, "Victory has a persistent trophy panel")
	check(game._hud.modal_reason.text.contains("開火") and game._hud.modal_reason.text.contains("擊倒"), "Health victory gives a concise finishing cause")
	check(Progress.is_cleared(3, TEST_SAVE), "Victory persists a versioned completion record")
	game._hud.primary.pressed.emit()
	check(game.left.hp == 8 and game.right.hp == 30 and not game._hud.overlay.visible, "Result retry restores HP and dismisses the modal")
	check(Progress.is_cleared(3, TEST_SAVE), "Retry never erases a prior completion")
	game.free()

	var levels = load("res://scenes/test_lab.tscn").instantiate()
	levels.progress_path = TEST_SAVE
	root.add_child(levels)
	check(levels.find_child("Level3", true, false).get_node_or_null("ClearedBadge") != null, "A new level-select scene reads the saved completion badge")
	check(levels.testing and levels._levels.size() == 2, "Old duel and spike challenge live in the separate test lab")
	levels.free()

	game = arena(true, LOSS_SAVE)
	game.left.hp = 1
	game._boss_state = "charge"
	game._land_hit(game.right, game.left, game._boss_move)
	game._finish_round()
	check(game._hud.modal_title.text == "失敗" and game._hud.modal_reason.text.contains("衝撞"), "HP defeat tells the player which attack caused it")
	check(not Progress.is_cleared(3, LOSS_SAVE), "A loss cannot unlock completion")
	game.free()

	game = arena()
	game.right.position = Vector2(300, 580)
	game._banana_fall = false
	game._check_spikes()
	check(game._ended and game.right.out and game._hud.modal_reason.text.contains("尖刺"), "Terrain victory uses the physical fall rather than a secret banana flag")
	game.free()

	check(Progress.mark_cleared(3, TEST_SAVE) == OK and FileAccess.file_exists(TEST_SAVE + ".bak"), "Atomic save keeps the previous valid backup")
	var broken := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	broken.store_string("interrupted write")
	broken.close()
	check(Progress.is_cleared(3, TEST_SAVE), "Malformed saves recover completion from backup")
	check(Progress.mark_cleared(3, TEST_SAVE) == OK, "Recovered progress can be written again")
	clean(TEST_SAVE)
	clean(LOSS_SAVE)
	await process_frame
	var menu = load("res://scenes/start.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu._tutorial.pressed.emit()
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/spikes.tscn", "Tutorial button navigates to the playable arena")
	check(current_scene._hud.modal_title.text == "玩法" and current_scene._hud._rules.visible, "Tutorial entry shows tool-to-effect pictograms")
	print("Player feedback tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
