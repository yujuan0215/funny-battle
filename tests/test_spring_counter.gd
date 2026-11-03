extends SceneTree
## 執行：Godot --headless --path <專案> --fixed-fps 120 --script res://tests/test_spring_counter.gd

const DUEL := preload("res://scenes/duel.tscn")
var failures := 0
var shots: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func make_game() -> Node2D:
	var script := preload("res://scripts/duel.gd")
	script.qte = false
	script.brawl = false
	var game := DUEL.instantiate()
	root.add_child(game)
	game._start_spring_practice()
	shots.clear()
	game.spring_counter_fired.connect(func(shooter: Duelist, target: Duelist, hit: bool) -> void:
		shots.append({"shooter": shooter, "target": target, "hit": hit})
	)
	return game


func frames(count: int) -> void:
	for i in count:
		await process_frame


func dispose(game: Node) -> void:
	root.remove_child(game)
	game.free()
	await process_frame


func _run() -> void:
	var game := make_game()
	var hero: Duelist = game.left
	var enemy: Duelist = game.right
	await frames(30)
	check(shots.is_empty() and is_equal_approx(hero.position.x, 600.0), "練習等待玩家實際放置道具")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.get_global_transform_with_canvas() * hero.position
	game._unhandled_input(click)
	var placed := get_nodes_in_group("duel_prop")
	check(placed.size() == 1 and is_equal_approx(placed[0].position.x, hero.position.x), "放置採用點擊事件座標，不受稍後游標移動影響")
	await frames(20)
	check(hero.airborne and hero.position.x < 600.0 and hero.face_right, "後撤向左，身體仍面向右方敵人")
	check(enemy.hp == enemy.hp_max, "彈射過程不會提前造成射擊傷害")
	await frames(160)
	check(shots.size() == 1 and bool(shots[0]["hit"]), "實際落地與動畫影格觸發一次命中")
	check(enemy.hp == enemy.hp_max - 2, "命中僅扣 CSV 中的兩點傷害")
	check(enemy.frozen <= 0.0 and hero.frozen <= 0.0, "不需要先時停任何角色")
	check(hero.position.x < 536.0, "後撤產生了實際位移")
	await frames(180)
	check(shots.size() == 1, "同一次後撤不能無限開火")
	game._restart()
	check(hero.spring_shot == Duelist.SpringShot.NONE and not game._practice_started and enemy.hp == enemy.hp_max, "R 重來清除機會並恢復練習")
	game._toggle_spring_practice()
	check(not game._spring_practice and is_equal_approx(game._pace, 0.3) and hero.display_name == "穿甲", "離開練習恢復原本速度和名稱")
	game.set_process(false)
	game._park(180.0)
	check(game._pick(hero, enemy) != "彈簧開火", "普通對峙不會無條件獲得後撤射擊")
	enemy.frozen = 1.0
	check(game._pick(hero, enemy) == "遠距離普攻", "原本的時停開火規則仍可使用")
	await dispose(game)

	game = make_game()
	game._toggle_spring_practice()
	game._pace = 1.0
	game._park(90.0)
	hero = game.left
	enemy = game.right
	game._tool = 1
	game._place(hero.position)
	await frames(180)
	check(shots.size() == 1 and bool(shots[0]["hit"]) and shots[0]["shooter"] == hero, "正常對打中也能後撤命中，不依賴練習模式")
	await dispose(game)

	game = make_game()
	hero = game.left
	enemy = game.right
	hero.position.x = 700.0
	enemy.position.x = 610.0
	hero.face_right = false
	enemy.face_right = true
	game._stand(hero)
	game._stand(enemy)
	game._place(hero.position)
	await frames(20)
	check(hero.airborne and hero.position.x > 700.0 and not hero.face_right, "鏡像位置向右後撤，仍面向左方敵人")
	await frames(160)
	check(shots.size() == 1 and bool(shots[0]["hit"]) and enemy.hp == enemy.hp_max - 2, "鏡像方向也能落地命中")
	await dispose(game)

	game = make_game()
	hero = game.left
	game._place(hero.position)
	await frames(20)
	hero.react("hit", hero.position.x, 0.0, 0.0, true, 0.2)
	await frames(180)
	check(shots.is_empty() and hero.spring_shot == Duelist.SpringShot.NONE, "受擊打斷後撤機會，不補發射擊")
	await dispose(game)

	game = make_game()
	hero = game.left
	enemy = game.right
	hero.position.x = 80.0
	enemy.position.x = 170.0
	game._stand(hero)
	game._stand(enemy)
	game._place(hero.position)
	await frames(200)
	check(shots.is_empty() and hero.spring_shot == Duelist.SpringShot.NONE, "牆邊無法實際後撤時，不憑空獲得開火")
	await dispose(game)

	game = make_game()
	hero = game.left
	game._place(hero.position)
	var props := get_nodes_in_group("duel_prop")
	props[0].position.y -= 120.0
	await frames(60)
	check(not game._practice_started and hero.spring_shot == Duelist.SpringShot.NONE, "不同高度的彈簧不會隔空觸發")
	await dispose(game)

	game = make_game()
	hero = game.left
	enemy = game.right
	game._place(hero.position)
	var aiming := false
	for i in 200:
		await process_frame
		if hero.use_module and str(hero.sheet_move.get("id", "")) == "彈簧開火":
			aiming = true
			break
	check(aiming and enemy.hp == enemy.hp_max, "瞄準前搖尚未扣血")
	enemy.position.x = hero.position.x + 500.0
	game._stand(enemy)
	enemy.set_process(false)
	await frames(80)
	check(shots.size() == 1 and not bool(shots[0]["hit"]) and enemy.hp == enemy.hp_max, "開火前離開射程會打空，不保證命中")
	await dispose(game)

	game = make_game()
	game._toggle_spring_practice()
	game.set_process(false)
	hero = game.left
	game._park(220.0)
	var spring := DuelProp.new()
	spring.kind = "spring"
	spring.retreat = false
	game.add_child(spring)
	hero.vx = 200.0
	game._try_spring(hero, spring)
	check(hero.airborne and hero.big_launch and hero.spring_shot == Duelist.SpringShot.NONE, "拋高模式保留原本大拋／下落攻擊")
	await dispose(game)

	game = make_game()
	game._toggle_spring_practice()
	game._preview_play("彈簧開火")
	await frames(480)
	check(shots.size() == 1 and bool(shots[0]["hit"]), "慢速拆解示範使用相同的實際觸發和射擊規則")
	await dispose(game)
	print("Spring counter tests: ", failures, " failure(s)")
	quit(0 if failures == 0 else 1)
