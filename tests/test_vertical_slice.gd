extends SceneTree
const Catalog := preload("res://scripts/campaign_catalog.gd")
const Progress := preload("res://scripts/player_progress.gd")
const SAVE := "res://.test-data/vertical_slice.json"
var checks := 0
var failures := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.test-data"))
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func scene(number: int):
	var game = load(Catalog.chapter(number)["scene"]).instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.progress_path = SAVE
	root.add_child(game)
	return game

func step(game, fps: int = 60) -> void:
	game._process(1.0 / fps)
	if game._round_state == game.RoundState.PLAYING:
		game.left._process(1.0 / fps)
		game.right._process(1.0 / fps)
	for prop in get_nodes_in_group("duel_prop"):
		if not prop.is_queued_for_deletion() and prop.is_processing():
			prop._process(1.0 / fps)
		if prop.is_queued_for_deletion():
			prop.free()

func strategy(game) -> void:
	if game._round_state != game.RoundState.PLAYING:
		return
	var number: int = game.chapter_number
	if number == 2:
		if game._cool[1] <= 0 and not game.right.airborne and (game.wind > 0 and game.right.position.x >= 650 or game.wind < 0 and game.right.position.x <= 760):
			game.pick_tool(1)
			game._place(game.right.position)
		return
	if number == 4 and game._boss_state in ["windup", "charge"] and game._cool[3] <= 0:
		game.pick_tool(3)
		game._place(Vector2(game.right.position.x + game._rush_direction * 60, 500))
	elif number == 5 and game._cool[4] <= 0:
		game.pick_tool(4)
		game._place(Vector2(400 if game.crate_x > game.right.position.x else 1010, 500))
	elif number in [3, 6] and game.slam_left > 0.9 and game._cool[1] <= 0 and not game.left.airborne:
		game.pick_tool(1)
		game._place(game.left.position + Vector2(0, 0))
	elif game._cool[1] <= 0 and not game.left.airborne and not game.left.slipping and game.left.frozen <= 0 and absf(game.left.position.x - game.right.position.x) < 180:
		game.pick_tool(1)
		game._place(game.left.position + Vector2(12 if game.left.face_right else -12, 0))

func _run() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	for number in range(2, 7):
		var game = scene(number)
		check(game.chapter_number == number and game._level_number() == number, "Chapter identity %d" % number)
		check(game._hud.overlay.visible and not game.left.is_processing(), "Chapter %d has a safe briefing" % number)
		check(game._hud.tool_ids == Catalog.chapter(number)["tools"], "Chapter %d shows its actual loadout" % number)
		check(game._hud.modal_detail.visible and game._hud.modal_detail.text == Catalog.opening(number) and game._hud.modal_detail.text.split("\n").size() == 2, "Chapter %d opens with two brief attack/terrain lines" % number)
		check(not game._hud.modal_detail.text.contains("反制") and not game._hud.modal_detail.text.contains("彈起") and not game._hud.modal_detail.text.contains("沙袋") and not game._hud.modal_detail.text.contains("磁鐵"), "Chapter %d opening leaves the solution for the player to discover" % number)
		check(not game._stage.hazard_edges and game._stage.support_at(340, 500) == 500 and game._stage.support_at(1070, 500) == 500, "Chapter %d has a continuous floor without a pit" % number)
		check("spikes" not in game._hud.win_conditions.symbols and game._rescues_left == 0, "Chapter %d exposes no spike win or safety rope" % number)
		var boss_hp: int = game.right.hp
		var boss_phase: int = game.phase
		game.right.position.y = 600
		game._check_spikes()
		check(not game._ended and game.right.hp == boss_hp and game.phase == boss_phase, "Former pit threshold cannot damage, kill or phase-skip chapter %d" % number)
		game.right.position.y = 500
		game._start_round()
		check(game._pace == 1.0 and game.left.hp_max == 6 and game.left.hp_max < game.right.hp_max, "Chapter %d starts at 1x with a clearly weaker hero" % number)
		for slot in game._allowed_tools().size():
			var key := InputEventKey.new()
			key.pressed = true
			key.keycode = KEY_1 + slot
			game._unhandled_input(key)
			check(game._tool == game._allowed_tools()[slot], "Chapter %d slot %d keyboard mapping" % [number, slot])
		game._pause_round()
		var snapshot: float = game.world_time
		step(game)
		check(game.world_time == snapshot, "Chapter %d pauses the environment" % number)
		game.free()
	var ui_game = scene(2)
	for cycle in 6:
		ui_game._hud.show_pause()
		check(ui_game._hud.primary.text == "繼續" and ui_game._hud.primary.get_child_count() == 0, "Resume stays text-only after repeated result/pause changes %d" % cycle)
		ui_game._hud.show_result(cycle % 2 == 0, "", 0, true)
	ui_game.free()
	for fps in [30, 60, 120]:
		for number in range(2, 7):
			var edge_game = scene(number)
			for body in [edge_game.left, edge_game.right]:
				for side in [-1.0, 1.0]:
					body.position = Vector2(385 if side < 0 else 1025, 500)
					body.relax()
					var health: int = body.hp
					body.begin_slip(side, 300, 0.5)
					for frame in fps:
						body._process(1.0 / fps)
					check(body.position.x >= 380 and body.position.x <= 1030 and body.position.y == 500 and body.hp == health, "Chapter %d slip stops at wall, side %.0f, %d FPS" % [number, side, fps])
					body.launch_arc(side * 1200, 600, 2000, false, 0.06)
					for frame in 2 * fps:
						body._process(1.0 / fps)
					check(body.position.x >= 380 and body.position.x <= 1030 and body.position.y == 500 and not body.airborne and body.hp == health, "Chapter %d outward spring lands inside with no pit damage, side %.0f, %d FPS" % [number, side, fps])
			edge_game.free()
		for number in range(2, 7):
			var game = scene(number)
			game._start_round()
			for frame in 180 * fps:
				if game._ended:
					break
				strategy(game)
				step(game, fps)
			print("PLAY chapter=%d fps=%d time=%.1f hero=%d boss=%d phase=%d props=%d counters=%d" % [number, fps, game._elapsed, game.left.hp, game.right.hp, game.phase, game._props_used, game._counter_hits])
			check(game._ended and game.right.out and not game.left.out, "Real strategy clears chapter %d at %d FPS" % [number, fps])
			check(Progress.is_cleared(number, SAVE), "Chapter %d saves its own clear" % number)
			check(game._hud.next_button.visible == (number < 6), "Chapter %d offers correct continuation" % number)
			if number == 2:
				check(game._wind_impacts == 4, "Twelve HP requires four distinct three-damage windmill collisions")
			if number == 6:
				check(game.phase == 2, "Final boss passes all three phases")
			game.free()
	var game = scene(6)
	game._start_round()
	var hero_position: Vector2 = game.left.position
	game._mechanic_damage(100, "test")
	check(game.left.position == hero_position, "Phase transition preserves the hero position")
	check(game.phase == 1 and game.right.hp == 24 and not game._ended, "Overkill cannot skip a boss phase")
	check(game._round_state == game.RoundState.PLAYING and game.left.is_processing() and game.right.is_processing() and not game._hud.overlay.visible, "Phase transition continues combat without a modal or confirm")
	game._restart()
	check(game.phase == 1 and game.right.hp == 24 and game.left.hp == game.left.hp_max, "Retry restores the actual checkpoint")
	game._mechanic_damage(100, "test")
	check(game.phase == 2 and game.right.hp == 12, "Second checkpoint is independent")
	game._restart()
	check(game.phase == 2 and game.right.hp == 12, "Final phase retry preserves progress")
	game.free()
	game = scene(2)
	game._start_round()
	var armor_hp: int = game.right.hp
	for id in ["普通1", "普通2", "普通3", "彈簧開火", "蓄力"]:
		game._land_hit(game.left, game.right, game._move_for(game.left, id))
	check(game.right.hp == armor_hp and not game._ended, "Chapter two cannot be won by fists or repeated gunfire")
	game._preferred_pace = 0.5
	game._restart()
	check(game._pace == 1.0, "Retry restores the requested 1x start")
	game.free()
	for pace in [1.0, 0.5, 0.15]:
		for fps in [30, 60, 120]:
			game = scene(2)
			game._start_round()
			game._preferred_pace = pace
			game._pace = pace
			game._apply_pace()
			var before_lift: int = game.right.hp
			game.pick_tool(1)
			game._place(game.right.position)
			for frame in 5:
				step(game, fps)
			check(game.right.hp == before_lift, "Spring lift does not directly damage the armored boss at %.2fx/%d FPS" % [pace, fps])
			game._pause_round()
			var air_position: Vector2 = game.right.position
			var wind_time: float = game.world_time
			step(game, fps)
			check(game.right.position == air_position and game.world_time == wind_time, "Pause freezes both airborne motion and wind")
			game._start_round()
			for frame in int(3.0 / pace * fps):
				if game._ended:
					break
				step(game, fps)
			check(game._wind_crash and game._wind_impacts == 1 and game.right.hp == before_lift - 3 and not game._ended and not game.right.out, "One real windmill collision deals exactly three damage without ending combat at %.2fx/%d FPS" % [pace, fps])
			check(game.right.position.y == 500 and not game.right.airborne, "Surviving boss lands and can continue fighting after the collision")
			game.free()
	game = scene(2)
	game._start_round()
	var ground_x: float = game.right.position.x
	game._tick_wind(1)
	check(game.right.position.x == ground_x and not game.right.out, "Wind cannot blow away a grounded boss")
	game.right.launch_arc(0, 700, 1400, false, 0.2)
	game._wind_lifted = true
	game._tick_wind(0.2)
	check(game.right.air_vx > 0, "Right wind accelerates a lifted boss rightward")
	game.wind = -1
	game._tick_wind(1)
	check(game.right.air_vx < 0, "Reversing wind changes real airborne drift, not only an arrow")
	game.free()
	game = scene(3)
	game._start_round()
	game._begin_slam()
	game.right.frozen = 2
	var before: float = game.slam_left
	step(game)
	check(game.slam_left == before, "Time stop delays the real slam countdown")
	game.free()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	print("Vertical slice: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
