extends SceneTree
## In-engine review of every deployment cue, including cooldown and wind launch.
var game: Node

func _initialize() -> void:
	_run.call_deferred()

func snap(label: String, at: Vector2) -> void:
	for i in 4:
		await process_frame
	root.warp_mouse(game.get_global_transform_with_canvas() * at)
	await process_frame
	await process_frame
	game.queue_redraw()
	for control in game._hud.root.find_children("*", "Control", true, false):
		control.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	print(label, ": tool=", game._tool, " cursor=", game.get_global_mouse_position(), " intended=", at)
	root.get_texture().get_image().save_png("res://qa/pixel-" + label + ".png")

func mount(chapter: int) -> void:
	game = load(preload("res://scripts/campaign_catalog.gd").chapter(chapter)["scene"]).instantiate()
	game.set_meta("automated_capture", true)
	game.progress_path = "res://.test-data/pixel-placement-capture.json"
	root.add_child(game)
	game._start_round()
	for actor in [game, game.left, game.right]:
		actor.set_process(false)
	await process_frame

func _run() -> void:
	root.size = Vector2i(1280, 720)
	await mount(1)
	for tool in [0, 1]:
		game.pick_tool(tool)
		await snap(["banana-preview", "spring-preview"][tool], Vector2(680, 500))
	game.pick_tool(0)
	game._place(Vector2(680, 500))
	game._cool[0] = 1.2
	game._hud.set_tools(0, game._cool, game._pace)
	await snap("banana-cooldown", Vector2(780, 500))
	game.pick_tool(1)
	game._place(Vector2(820, 500))
	await snap("props-deployed", Vector2(950, 500))
	game.free()
	await mount(2)
	game.pick_tool(1)
	await snap("wind-spring", game.right.position)
	game.free()
	await mount(3)
	game.pick_tool(2)
	await snap("clock-preview", Vector2(720, 520))
	game._place(Vector2(720, 520))
	await snap("clock-deployed", Vector2(650, 520))
	game.free()
	await mount(5)
	for tool in [3, 4]:
		game.pick_tool(tool)
		await snap("terrain-" + ("sandbag" if tool == 3 else "magnet"), Vector2(720, 520))
	game.free()
	await process_frame
	quit()
