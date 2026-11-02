extends SceneTree
const Catalog := preload("res://scripts/campaign_catalog.gd")
var checks:=0
var failures:=0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(why)
func scene(path: String):
	var g=load(path).instantiate()
	g.process_mode=Node.PROCESS_MODE_DISABLED
	g.progress_path="res://.test-data/action-trial-tests.json"
	g.set_meta("automated_capture",true)
	root.add_child(g)
	g._start_round()
	return g
func key(g, code: Key, down: bool=true) -> void:
	var e:=InputEventKey.new()
	e.keycode=code
	e.physical_keycode=code
	e.pressed=down
	g._input(e)
func simulate(g, seconds: float, fps: int=60) -> void:
	for i in int(seconds*fps): g._process(1.0/fps)
func policy(g) -> void:
	var n: int=g.trial_id
	var target: float=345 if n==1 else (920 if g.catch_used else 620) if n==2 else 555
	g._held_left=g.left.position.x>target+3
	g._held_right=g.left.position.x<target-3
	if n==1:
		if g.boss_state=="windup" and g.boss_time<.22: g._buffer=.15
		if g.boss_state=="exposed": g._act()
	else:
		if absf(g.left.position.x-target)<8 and not g.left.airborne and g.left.position.y>400: g._spring()
		if n==2:
			if g.catch_used and g.left.position.x>677 and g.left.position.x<715 and not g.left.airborne: g._buffer=.15
			if g.left.position.y<390 and g.right.position.x>620 and g.right.position.x<810: g._act()
		if n==3:
			if g.boss_state=="windup" and g.boss_time<.25: g._buffer=.15
			if g.boss_state=="exposed": g._act()
func _run() -> void:
	for n in range(1,7):
		check(Catalog.chapter(n)["scene"]==("res://scenes/spikes.tscn" if n==1 else "res://scenes/chapter_%d.tscn" % n),"Original chapter %d scene remains unchanged" % n)
	for fps in [30,60,120]:
		for hard in [false,true]:
			for n in [1,2,3]:
				var g=scene("res://scenes/action_trial_%d.tscn" % n)
				if hard: g._toggle_hard()
				for i in 90*fps:
					if g._ended: break
					policy(g)
					g._process(1.0/fps)
				print("ACTION n=%d hard=%s fps=%d hero=%d boss=%d hits=%d t=%.2f" % [n,hard,fps,g.left.hp,g.right.hp,g.hits,g._time])
				check(g.right.hp==0 and g.left.hp>0,"Physical action strategy wins trial %d hard=%s at %d FPS" % [n,hard,fps])
				check(g.hits==3 if n!=2 else g.catch_used,"Win requires three true counter hits or both bridge falls")
				check(g._hud.overlay.visible and g._hud.next_button.visible==(n<3),"Actual outcome offers the correct continuation")
				g.free()
	for n in [1,2,3]:
		var g=scene("res://scenes/action_trial_%d.tscn" % n)
		for i in 120*60:
			if g._ended: break
			if i%6==0:
				g._act();g._banana();g._spring()
			g._process(1.0/60)
		check(g.right.hp>0,"Stationary attack and tool spam cannot clear trial %d" % n)
		g.free()
	var g=scene("res://scenes/action_trial_1.tscn")
	var x: float=g.left.position.x
	key(g,KEY_D);simulate(g,.2);key(g,KEY_D,false)
	check(g.left.position.x>x+40,"A real input event moves the hero directly")
	x=g.left.position.x
	simulate(g,.1)
	check(absf(g.left.position.x-x)<1,"Releasing movement stops on normal terrain")
	key(g,KEY_SPACE);simulate(g,.25)
	check(g.left.airborne and g.left.position.y<430,"Space produces a real controllable jump")
	var before: float=g._cool[1]
	g._spring()
	check(g._cool[1]==before,"Midair spring spam cannot create unlimited flight")
	g._pause()
	var snapshot: Vector2=g.left.position
	simulate(g,.5)
	check(g.left.position==snapshot,"Pause freezes the actual jump")
	g._start_round();simulate(g,.5)
	check(not g.left.airborne,"Resume continues the same jump to landing")
	g._restart()
	g._act();simulate(g,.3)
	check(g.right.hp==12,"Attacking without a real opening cannot break armor")
	g.free()
	for n in [4,5,6]:
		g=scene("res://scenes/terrain_study_%d.tscn" % n)
		check(not g.right.visible and g._hud.boss_health.text.contains("不計勝敗"),"Research layout %d clearly has no completed boss encounter" % n)
		check(g._stage.strips.size()>=3,"Research layout %d has physical height differences" % n)
		if n==4:
			g.left.position=Vector2(650,500);g._held_right=true;simulate(g,.4);g._held_right=false
			var at: float=g.left.position.x
			simulate(g,.2)
			check(g.left.position.x>at+10,"Ice retains genuine horizontal momentum after release")
		elif n==5:
			g.left.position=Vector2(g._stage.moving_x+60,400);g.left.ground_y=400;g.left._plant()
			var at: float=g.left.position.x
			simulate(g,.2)
			check(absf(g.left.position.x-at)>5 and absf(g.left.position.y-400)<4,"A standing hero rides the moving platform")
		else:
			g._act()
			check(g._stage.support_at(990,420)>500,"Breaking a side platform removes its actual collision surface")
			simulate(g,4.1)
			check(g._stage.support_at(990,420)==420,"The side platform physically regenerates for repeatable testing")
		g.left.position.y=800
		g._hurt(99,"test")
		check(not g._ended and g.left.hp==g.left.hp_max,"Research falls reset safely without a fake win or lost save")
		g.free()
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path("res://.test-data/action-trial-tests.json"+suffix))
	print("Action trials: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
