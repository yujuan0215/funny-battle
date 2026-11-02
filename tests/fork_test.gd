extends SceneTree

const DUEL := preload("res://scripts/duel.gd")
var checks := 0
var failures := 0
var seen_moves: Dictionary = {}
const TEST_PROGRESS := "user://fork_test_progress.json"


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func scene(path: String):
	var node = load(path).instantiate()
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if path in ["res://scenes/spikes_challenge.tscn", "res://scenes/levels.tscn"]:
		node.progress_path = TEST_PROGRESS
	root.add_child(node)
	if path == "res://scenes/spikes_challenge.tscn":
		node._start_round()
	return node


func simulate(arena, seconds: float, fps: int = 60) -> void:
	for frame in int(seconds * fps):
		if arena._ended:
			break
		arena._process(1.0 / fps)
		if not arena._ended:
			arena.left._process(1.0 / fps)
			arena.right._process(1.0 / fps)
		for body in [arena.left, arena.right]:
			if body.use_module and not body.sheet_move.is_empty():
				var role := "hero" if body == arena.left else "boss"
				seen_moves[role + ":" + str(body.sheet_move["id"])] = true
		for prop in get_nodes_in_group("duel_prop"):
			if not prop.is_queued_for_deletion():
				prop._process(1.0 / fps)
			if prop.is_queued_for_deletion():
				prop.free()


func run_tests() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/start.tscn", "Start page is the main scene")
	var start_page = scene("res://scenes/start.tscn")
	var play = start_page.get_node("Stage/Play")
	var tutorial = start_page.get_node("Stage/Tutorial")
	check(play is Button and not play.get_signal_connection_list("pressed").is_empty(), "Play opens level selection")
	check(tutorial is Button and tutorial.shape == "help", "Tutorial uses a book pictogram")
	check(start_page.get_node("Background").get_script() == load("res://scripts/pixel_backdrop.gd"), "Start page uses the shared pixel environment")
	check(start_page.has_method("_on_tutorial") and not tutorial.get_signal_connection_list("pressed").is_empty(), "Tutorial opens playable arena instructions")
	start_page.free()
	var levels = scene("res://scenes/levels.tscn")
	check(levels.LEVEL_ONE == "res://scenes/spikes.tscn", "Level 1 leads to the spike arena")
	var level_one = levels._levels[0]
	check(bool(level_one.get_meta("playable")) and not level_one.get_signal_connection_list("pressed").is_empty(), "Level 1 is open")
	for index in range(2, 7):
		var locked = levels._levels[index - 1]
		check(not bool(locked.get_meta("playable")), "Chapter %d is a blueprint, not a fake playable level" % index)
	check(levels._back is Button, "Level select can return to the start page")
	levels.free()
	var menu = scene("res://scenes/main.tscn")
	var buttons: Dictionary = {}
	for child in menu._start_layer.get_children():
		if child is Button:
			buttons[child.text] = child
	for name in ["開打", "干擾決鬥", "閃光格檔", "大亂鬥", "尖刺場地"]:
		check(buttons.has(name), "Menu retains " + name)
		if buttons.has(name):
			check(not buttons[name].get_signal_connection_list("pressed").is_empty(), "Menu action connected: " + name)
	for entry in [["開打", 180], ["干擾決鬥", 430], ["閃光格檔", 680], ["大亂鬥", 930]]:
		check(buttons[entry[0]].position == Vector2(entry[1], 530), "Original button layout retained: " + entry[0])
	menu.begin_match()
	check(menu.started and not menu.red.locked and not menu.blue.locked, "Original first mode starts")
	menu.free()
	for mode in ["duel", "qte", "brawl"]:
		DUEL.qte = mode == "qte"
		DUEL.brawl = mode == "brawl"
		DUEL.brawl_count = 4
		var original = scene("res://scenes/duel.tscn")
		check(original._bodies().size() == (4 if mode == "brawl" else 2), "Original fighter count: " + mode)
		if mode == "qte":
			check(original._rack == null, "Original QTE keeps its own controls")
		else:
			check(original._rack != null and original._items.has("香蕉") and original._items.has("彈簧") and original._items.has("時停"), "Original three selectable props retained: " + mode)
		if mode == "brawl":
			check(original._goal == original.right and original.right.goal, "Original brawl goal retained")
		original.free()
	var arena = scene("res://scenes/spikes_challenge.tscn")
	check(not DUEL.qte and not DUEL.brawl, "Spike arena does not inherit the last mode's flags")
	check(arena._rack.get_script() == load("res://scripts/tool_rack.gd"), "Spike arena uses original prop bar")
	check(arena._items.has("後撤彈簧") and arena._cool.size() == 3, "Three selectable props include the retreat spring variant")
	check(arena._cast_buttons.is_empty(), "Spike arena has no costume row")
	check(arena._watch_button == null and arena._pace_button == null and arena._hp_button == null and arena._practice_button == null, "Spike arena has no preview or pace row")
	check(arena._ground_button == null, "Spike arena has no terrain button")
	check(arena._hint != null and not arena._hint.visible and arena._hint.text == "", "Spike arena hides the prop description")
	check(not arena._rack.get_parent().visible and arena._hud.objective.text != "", "Player HUD replaces sandbox labels with a clear objective")
	check(arena.left.hp < arena.right.hp and arena.left.scale.x < arena.right.scale.x, "Small weak hero faces large boss")
	check(arena.left.hp == 8 and arena.left.hp_max == 8, "Hero starts with eight health")
	check(arena.ground_height(460, 500) == 500 and arena.ground_height(300, 500) > 578, "Bridge ends above the spike pit")
	seen_moves.clear()
	simulate(arena, 1)
	check(arena.left.position.x > 480, "Hero moves toward the enemy without taking damage first")
	simulate(arena, 59)
	check(arena._ended and arena.left.out and not arena.right.out, "No intervention loses")
	print("No intervention: ", arena._title.text)
	print("Default battle moves: ", seen_moves.keys())
	check(seen_moves.has("boss:普通1") and seen_moves.has("boss:普通2") and seen_moves.has("boss:普通3"), "Boss performs the original punch, kick, and slash combo")
	check(seen_moves.has("boss:遠距離普攻"), "Boss mixes ranged attacks into the default fight")
	check(seen_moves.has("boss:蓄力"), "Boss mixes the original charged attack into the default fight")
	arena.free()
	for fps in [30, 60, 120]:
		arena = scene("res://scenes/spikes_challenge.tscn")
		for i in 25 * fps:
			simulate(arena, 1.0 / fps, fps)
			if arena._boss_state == "charge" and arena.right.position.x < 470:
				break
		arena.pick_tool(0)
		arena._place(Vector2(arena._rush_target, 500))
		check(get_nodes_in_group("duel_prop").size() == 1, "Existing banana is placed")
		var peel_at_edge = get_nodes_in_group("duel_prop").back()
		check(peel_at_edge.radius == arena.BANANA_RADIUS, "Banana requires close foot contact")
		simulate(arena, 15, fps)
		check(arena._ended and arena.right.out and not arena.left.out, "Predicted edge placement wins at %d FPS" % fps)
		print("Banana at %d FPS: %s" % [fps, arena._title.text])
		arena._restart()
		check(not arena._ended and arena.left.hp == 8 and arena.right.hp == 30, "Retry resets the increased health")
		check(arena.left.position == Vector2(600, 500) and arena.right.position == Vector2(840, 500), "Retry resets positions with safe retreat room")
		check(arena._cool == [0.0, 0.0, 0.0], "Retry resets original cooldowns")
		check(not arena._banana_fall and arena._boss_state == "", "Retry resets the rush and fall permission")
		arena.free()
	for fps in [30, 60, 120]:
		arena = scene("res://scenes/spikes_challenge.tscn")
		for i in 10 * fps:
			simulate(arena, 1.0 / fps, fps)
			if arena._boss_state == "charge" and arena.right.position.x < 690:
				break
		arena.pick_tool(0)
		arena._place(arena.right.position)
		simulate(arena, 1.0 / fps, fps)
		var start: float = arena.right._from
		var destination: float = arena.right._to
		check(arena.right.slipping and absf(destination - start) <= 64.01, "Middle banana only slides a short distance")
		check(not arena._banana_fall and destination > arena._bridge_bounds().x, "Middle banana cannot enable a pit fall")
		simulate(arena, 4, fps)
		check(not arena.right.out and arena.right.position.y < 578, "Middle banana stays on bridge at %d FPS (hero_out=%s, boss=%s)" % [fps, arena.left.out, arena.right.position])
		arena.free()
	arena = scene("res://scenes/spikes_challenge.tscn")
	for edge in [380.0, 1030.0]:
		arena._restart()
		arena.right.position = Vector2(edge, 500)
		arena.right._from = edge
		arena.right._to = edge
		var damage: Dictionary = arena._moves["普通3"].duplicate()
		damage["kb"] = 1000.0
		for hit in 40:
			arena._land_hit(arena.left, arena.right, damage)
		check(arena.right.position.x == edge and arena.right._to == edge, "Normal attacks never push a boss off either edge")
		check(arena.right.hp == 0 and arena.right.out, "Visible damage can defeat the boss, including its last health point")
		check(not arena._banana_fall, "Normal attacks do not authorize falling")
	arena.free()
	arena = scene("res://scenes/spikes_challenge.tscn")
	for i in 600:
		simulate(arena, 1.0 / 60)
		if arena._boss_state == "windup":
			break
	var windup_origin: float = arena.right.position.x
	simulate(arena, 0.3)
	check(arena.right.position.x == windup_origin and arena.right.glow == 1, "Boss signals the rush while standing still")
	for i in 600:
		simulate(arena, 1.0 / 60)
		if arena._boss_state == "charge":
			break
	var charge_target: float = arena.right._to
	arena._land_hit(arena.left, arena.right, arena._moves["普通1"])
	check(arena.right.use_module and arena.right._to == charge_target and not arena.right.reacting, "Hero attack does not cancel the predicted rush")
	simulate(arena, 3.7)
	check(arena.right.position.x >= 360 and not arena.right.out and not arena._banana_fall, "Rush brakes before the edge without a banana")
	arena.free()
	arena = scene("res://scenes/spikes_challenge.tscn")
	arena.left.position = Vector2(940, 500)
	for i in 1800:
		simulate(arena, 1.0 / 60)
		if arena._boss_state == "charge" and arena.right.position.x > 950:
			break
	check(arena._rush_direction > 0 and arena._rush_target < 1050, "Boss can also rush toward the right edge")
	arena.pick_tool(0)
	arena._place(Vector2(arena._rush_target, 500))
	simulate(arena, 15)
	check(arena._ended and arena.right.out and not arena.left.out, "Right-edge prediction also wins")
	arena.free()
	for edge in [360.0, 1050.0]:
		arena = scene("res://scenes/spikes_challenge.tscn")
		if edge > 700:
			arena.left.position = Vector2(940, 500)
		for i in 1800:
			simulate(arena, 1.0 / 60)
			if arena._boss_state == "charge" and absf(arena.right.position.x - edge) < 110:
				break
		arena.pick_tool(0)
		arena._place(Vector2(edge, 500))
		simulate(arena, 15)
		check(arena._ended and arena.right.out and not arena.left.out, "A peel on the actual bridge lip is reachable")
		arena.free()
	arena = scene("res://scenes/spikes_challenge.tscn")
	arena.right.position = Vector2(380, 500)
	arena.right.face_right = false
	arena.right.vx = -200
	var edge_spring := DuelProp.new()
	edge_spring.kind = "spring"
	arena.add_child(edge_spring)
	arena._try_spring(arena.right, edge_spring)
	edge_spring.free()
	simulate(arena, 12)
	check(arena.right.out and arena._ended, "An outward spring obeys the left edge instead of warping the boss back")
	arena.free()
	arena = scene("res://scenes/spikes_challenge.tscn")
	arena.right.position = Vector2(960, 500)
	arena.right.face_right = false
	arena.left.position = Vector2(600, 500)
	var right_spring := DuelProp.new()
	right_spring.kind = "spring"
	right_spring.retreat = true
	arena.add_child(right_spring)
	check(arena._try_spring(arena.right, right_spring) and arena.right.airborne and arena.right.air_vx > 0.0, "Retreat spring bounces the boss toward the right edge")
	right_spring.free()
	simulate(arena, 3)
	check(arena._ended and arena.right.out and arena.right.position.x > arena._bridge_bounds().y, "Spring can bounce the boss off the right edge")
	arena.free()
	arena = scene("res://scenes/spikes_challenge.tscn")
	for tool in 3:
		arena.pick_tool(tool)
		arena._place(Vector2(1000, 500))
		var prop = get_nodes_in_group("duel_prop").back()
		check(prop.kind == ["peel", "spring", "stop"][tool], "Tool key maps to existing item %d" % (tool + 1))
		check(arena._cool[tool] == DUEL.TOOL_COOL[tool], "Original cooldown retained")
		prop.free()
	var peel := DuelProp.new()
	peel.kind = "peel"
	arena.add_child(peel)
	check(arena._try_peel(arena.left, peel) and arena.left.slipping, "Hero also slips")
	check(arena.left.sheet_move.is_empty(), "Banana does not turn into an attack in the spike arena")
	peel.free()
	var hp: int = arena.left.hp
	arena._land_hit(arena.right, arena.left, arena._boss_move)
	check(arena.left.hp < hp, "Slipping hero has no immunity")
	arena._restart()
	var spring := DuelProp.new()
	spring.kind = "spring"
	arena.add_child(spring)
	check(arena._try_spring(arena.left, spring) and arena.left.airborne, "Original spring still launches")
	spring.free()
	arena._restart()
	var stop := DuelProp.new()
	stop.kind = "stop"
	stop.position = arena._prop_at("stop", arena.right.position.x, 500)
	arena.add_child(stop)
	arena._resolve_stop(stop)
	check(arena.right.frozen > 0 and arena.left.frozen == 0, "Original time stop still freezes its target")
	stop.free()
	arena._restart()
	arena.left.position = Vector2(300, 580)
	arena._check_spikes()
	check(arena._ended and arena.left.out and arena._title.text == "失敗", "Hero dies to spikes as well")
	arena._restart()
	arena._tool = 0
	arena._place(Vector2(200, 500))
	check(get_nodes_in_group("duel_prop").is_empty() and arena._cool[0] == 0, "Invalid pit placement does not use cooldown")
	arena.free()
	arena = scene("res://scenes/spikes_challenge.tscn")
	arena.left.hp_max = 200
	arena.left.hp = 200
	arena.right.hp_max = 500
	arena.right.hp = 500
	seen_moves.clear()
	simulate(arena, 100)
	check(seen_moves.has("hero:普通1") and seen_moves.has("hero:普通2") and seen_moves.has("hero:普通3"), "Hero follows up with the original combo when the openings permit")
	check(seen_moves.has("boss:遠距離追擊"), "Boss includes the original chase attack")
	arena._restart()
	arena.left.position = Vector2(600, 500)
	arena.right.position = Vector2(800, 500)
	arena.right.frozen = 1.5
	arena._think_open(arena.left, arena.right)
	check(str(arena.left.sheet_move.get("id", "")) == "遠距離普攻", "Hero uses the original ranged counter against a frozen boss")
	arena._restart()
	arena.left.position = Vector2(460, 500)
	arena.right.position = Vector2(800, 500)
	arena.right.frozen = 1.5
	arena._think_open(arena.left, arena.right)
	check(str(arena.left.sheet_move.get("id", "")) == "蓄力", "Hero uses the original charged counter at long range")
	arena._restart()
	arena.left.position = Vector2(700, 500)
	arena.right.position = Vector2(780, 500)
	arena._boss_state = "windup"
	arena._think_open(arena.left, arena.right)
	check(arena.left._to < 700, "Hero backs away from a warned rush")
	arena._restart()
	arena.left.position = Vector2(434, 500)
	arena.right.position = Vector2(700, 500)
	arena._boss_state = "windup"
	arena._think_open(arena.left, arena.right)
	check(arena.left._to >= 432, "Voluntary retreat stops before the spike edge")
	check(arena._boss_turn == 0 and arena._boss_action == "", "Retry resets the mixed move pattern")
	arena.free()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
