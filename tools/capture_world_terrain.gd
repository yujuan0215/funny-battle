extends SceneTree
var g: Node
func _initialize() -> void: _run.call_deferred()
func snap(name: String) -> void:
	if g is Node2D: g._stage.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/world-"+name+".png")
func _run() -> void:
	root.size=Vector2i(1280,720)
	for n in range(3,7):
		g=load("res://scenes/chapter_%d.tscn" % n).instantiate()
		g.process_mode=Node.PROCESS_MODE_DISABLED
		g.set_meta("automated_capture",true)
		root.add_child(g)
		await snap("%d-briefing" % n)
		g._start_round()
		for frame in 40: g._process(1.0/60)
		await snap("%d-arena" % n)
		g.free()
	g=load("res://scenes/legacy_chapters.tscn").instantiate()
	root.add_child(g)
	await snap("legacy-hub")
	g.free()
	g=load("res://scenes/test_lab.tscn").instantiate()
	root.add_child(g)
	await snap("lab")
	g.free()
	await process_frame
	quit()
