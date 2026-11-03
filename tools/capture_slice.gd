extends SceneTree
var game: Node
func _initialize() -> void:
	_run.call_deferred()
func snap(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/" + filename + ".png")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa"))
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/start.tscn").instantiate()
	root.add_child(game)
	await snap("00-start")
	game.free()
	game = load("res://scenes/levels.tscn").instantiate()
	root.add_child(game)
	await snap("01-map")
	game.free()
	for number in range(1, 7):
		var path: String = preload("res://scripts/campaign_catalog.gd").chapter(number)["scene"]
		game = load(path).instantiate()
		root.add_child(game)
		await snap("chapter-%d-briefing" % number)
		game._start_round()
		if number == 6:
			game._mechanic_damage(12, "護肩拆解")
			game._start_round()
			game._mechanic_damage(12, "發條拆解")
			game._start_round()
		if number == 3 or number == 6:
			game._begin_slam()
		if number == 4:
			game.pick_tool(3)
			game._place(Vector2(780, 500))
		if number == 5:
			game.pick_tool(4)
			game._place(Vector2(610, 500))
		await snap("chapter-%d-battle" % number)
		if number == 2:
			game.pick_tool(1)
			game._place(game.right.position)
			for frame in 20:
				await process_frame
			await snap("chapter-2-wind-lift")
			for frame in 180:
				if game._wind_impacts > 0:
					break
				await process_frame
			await snap("chapter-2-wind-impact")
		game._pause_round()
		# Reproduce the state sequence that used to re-show the play icon.
		game._hud.show_result(false, "", 0, false)
		game._hud.show_pause()
		await snap("chapter-%d-pause" % number)
		game.free()
	await process_frame
	await process_frame
	quit()
