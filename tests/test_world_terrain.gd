extends SceneTree
const Catalog := preload("res://scripts/campaign_catalog.gd")
const SAVE := "res://.test-data/terrain_campaign.json"
var checks:=0
var failures:=0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func scene(number: int):
	var g=load(Catalog.chapter(number)["scene"]).instantiate()
	g.process_mode=Node.PROCESS_MODE_DISABLED
	g.set_meta("automated_capture",true)
	g.progress_path=SAVE
	root.add_child(g)
	return g
func battle_policy(g) -> void:
	if g.chapter_number==4 and g._boss_state in ["windup","charge"] and g._cool[3]<=0:
		g.pick_tool(3)
		g._place(Vector2(g.right.position.x+g._rush_direction*50,g.right.position.y))
	elif g.chapter_number>=5 and g._cool[4]<=0:
		g.pick_tool(4)
		g._place(Vector2(400 if g.crate_x>g.right.position.x else 1010,g._stage.base_height(400 if g.crate_x>g.right.position.x else 1010)))
	elif g.chapter_number in [3,6] and g.slam_left>.8 and not g.left.airborne and g._cool[1]<=0:
		g.pick_tool(1)
		g._place(g.left.position)
	elif g._cool[1]<=0 and not g.left.airborne and g.left.frozen<=0 and not g.left.slipping and absf(g.left.position.x-g.right.position.x)<180:
		g.pick_tool(1)
		g._place(g.left.position)
func _run() -> void:
	for fps in [30,60,120]:
		for number in range(3,7):
			var g=scene(number)
			check(g._hud.overlay.visible and g.left.position.x==600 and g.right.position.x==840,"Chapter %d begins directly in the original duel, without an approach segment" % number)
			check(g._hud.tool_ids==Catalog.chapter(number)["tools"],"Chapter %d retains its original loadout" % number)
			check(g.left.hp_max==6 and g.right.hp_max==(36 if number==6 else 16),"Chapter %d preserves original HP" % number)
			var heights: Array[float]=[]
			for point in g._stage.surfaces[0]["points"]: heights.append(point.y)
			check(heights.max()-heights.min()>=70,"Chapter %d actual battle floor has elevation changes" % number)
			check(g._stage.support_at(1000,800)<640,"Solid slopes prevent falling through higher terrain")
			g._start_round()
			check(g._pace==1 and not g._hud.tool_buttons[0].disabled,"Battle begins immediately with tools available")
			for frame in 120*fps:
				if g._ended: break
				battle_policy(g)
				g._process(1.0/fps)
				for prop in get_nodes_in_group("duel_prop"):
					if not prop.is_queued_for_deletion(): prop._process(1.0/fps)
					if prop.is_queued_for_deletion(): prop.free()
			print("BOSS chapter=%d fps=%d hero=%d boss=%d phase=%d props=%d" % [number,fps,g.left.hp,g.right.hp,g.phase,g._props_used])
			check(g._ended and g.right.out and not g.left.out,"Chapter %d original prop strategy wins at %d FPS" % [number,fps])
			g._restart()
			check(g.left.position.x==600 and g._round_state==g.RoundState.PLAYING,"Retry starts directly in battle")
			g._pause_round()
			var snapshot: Vector2=g.camera.position
			g._process(1)
			check(g.camera.position==snapshot,"Pause freezes the duel camera")
			g.free()
	for n in range(3,7):
		var legacy=load("res://scenes/legacy_chapter_%d.tscn" % n).instantiate()
		legacy.process_mode=Node.PROCESS_MODE_DISABLED
		root.add_child(legacy)
		check(legacy._stage.support_at(340,500)==500 and legacy._stage.support_at(1070,500)==500,"Legacy %d keeps original flat terrain" % n)
		check(legacy.progress_path=="user://legacy_campaign_progress.json","Legacy saves stay independent")
		legacy.free()
	var g=scene(4)
	g._start_round()
	var position_before: Vector2=g.left.position
	for code in [KEY_W,KEY_A,KEY_S,KEY_D]:
		var key:=InputEventKey.new()
		key.keycode=code
		key.pressed=true
		g._input(key)
		g._unhandled_input(key)
	check(g.left.position==position_before,"WASD does not introduce a campaign controller")
	g.sandbags.clear()
	g.sandbags.append({"x":400.0,"y":410.0,"life":5.0})
	g.right.position=Vector2(400,500)
	g.right.airborne=false
	g._boss_state="charge"
	var health_before: int=g.right.hp
	g._tick_sandbags(.01)
	check(g.right.hp==health_before and g.sandbags.size()==1,"A sandbag on an upper floor cannot hit a boss below it")
	g.right.position.y=410
	g._tick_sandbags(.01)
	check(g.right.hp==health_before-4 and g.sandbags.is_empty(),"Same-floor contact retains the original four-damage counter")
	g.camera.position=Vector2(705,300)
	g._camera_focus=g.camera.position
	g.left.position.y=570
	g.right.position.y=580
	for frame in 120: g._update_camera(1.0/60)
	check(g.camera.position.y>400,"Camera reframes downward to follow the actual floor")
	g.left.position.y=250
	g.right.position.y=300
	for frame in 120: g._update_camera(1.0/60)
	check(g.camera.position.y<210,"Camera follows higher exchanges")
	g.free()
	print("RESULT: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
