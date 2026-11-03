extends SceneTree
var g: Node
func _initialize() -> void: _run.call_deferred()
func snap(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/experiment-"+name+".png")
func _run() -> void:
	root.size=Vector2i(1280,720)
	g=load("res://scenes/test_lab.tscn").instantiate()
	root.add_child(g)
	await snap("lab")
	g.free()
	for n in [1,2,3]:
		g=load("res://scenes/action_trial_%d.tscn" % n).instantiate()
		g.process_mode=Node.PROCESS_MODE_DISABLED
		g.set_meta("automated_capture",true)
		root.add_child(g)
		await snap("action-%d-briefing" % n)
		g._start_round()
		for i in 170: g._process(1.0/60)
		await snap("action-%d-battle" % n)
		g.free()
	for n in [4,5,6]:
		g=load("res://scenes/terrain_study_%d.tscn" % n).instantiate()
		g.process_mode=Node.PROCESS_MODE_DISABLED
		g.set_meta("automated_capture",true)
		root.add_child(g)
		g._start_round()
		for i in 30: g._process(1.0/60)
		await snap("terrain-%d" % n)
		g.free()
	await process_frame
	await process_frame
	quit()
