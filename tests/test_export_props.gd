extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	print("RAW_CSV=",FileAccess.file_exists("res://docs/攻擊模組 - 攻擊模組.csv"))
	for number in [1,2,3]:
		var g=load("res://scenes/spikes.tscn" if number==1 else "res://scenes/chapter_%d.tscn" % number).instantiate()
		g.process_mode=Node.PROCESS_MODE_DISABLED
		g.progress_path=OS.get_cache_dir().path_join("funny-export-prop-test.json")
		g.set_meta("automated_capture",true)
		root.add_child(g)
		g._start_round()
		print("CHAPTER ",number," ITEMS=",g._items.keys())
		check(g._items.has("香蕉") and g._items.has("彈簧") and g._items.has("時停"),"Export contains every prop row")
		for tool in ([0,1] if number<=2 else [1,2]):
			g.pick_tool(tool)
			g._cool[tool]=0
			g._place(g.left.position)
			var props=get_nodes_in_group("duel_prop")
			check(props.size()==1,"Chapter %d tool %d can actually be placed" % [number,tool])
			if tool==2 and props.size()==1:
				g._resolve_stop(props[0])
				check(g.left.frozen>=2.99,"Time stop begins at 3 seconds")
				var before:Vector2=g.left.position
				for i in 120: g.left._process(1.0/60)
				check(g.left.frozen>.95 and g.left.position.is_equal_approx(before),"Time stop still holds after 2 seconds")
				for i in 61: g.left._process(1.0/60)
				check(g.left.frozen<=.001,"Time stop ends after 3 seconds")
			for prop in props: prop.free()
		g.free()
		await process_frame
	for number in [3,6]:
		var g=load("res://scenes/chapter_%d.tscn" % number).instantiate()
		g.process_mode=Node.PROCESS_MODE_DISABLED
		g.progress_path=OS.get_cache_dir().path_join("funny-export-prop-test.json")
		root.add_child(g)
		g._start_round()
		g._begin_slam()
		var health:int=g.left.hp
		g._resolve_slam()
		check(g.left.hp==health-1,"Chapter %d hammer hit deducts actual hero HP" % number)
		g._begin_slam()
		health=g.right.hp
		g.left.airborne=true
		g._resolve_slam()
		check(g.right.hp==health-4,"Chapter %d dodged hammer damages boss core" % number)
		g.free()
		await process_frame
	print("Export prop test: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
