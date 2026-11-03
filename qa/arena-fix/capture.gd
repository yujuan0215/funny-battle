extends SceneTree
func _initialize() -> void: _run.call_deferred()
func snap(g, name: String) -> void:
	g._stage.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/arena-fix/"+name+".png")
func _run() -> void:
	root.size=Vector2i(1280,720)
	for number in [2,3,4,5,6]:
		var g=load("res://scenes/chapter_%d.tscn" % number).instantiate()
		g.process_mode=Node.PROCESS_MODE_DISABLED
		g.set_meta("automated_capture",true)
		g.progress_path="res://.test-data/arena_art_capture.json"
		root.add_child(g)
		g._start_round()
		if number==3:
			g._begin_slam()
			g.slam_left=g.slam_duration*.6
			await snap(g,"chapter-3-hammer")
			g.slam_left=0
			g._resolve_slam()
			await snap(g,"chapter-3-impact")
		else:
			await snap(g,"chapter-%d-barriers" % number)
		g.free()
		await process_frame
	quit()
