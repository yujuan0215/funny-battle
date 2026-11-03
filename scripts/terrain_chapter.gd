extends "res://scripts/chapter_arena.gd"
## Original automatic encounters on sculpted, collidable terrain. No new controller.
const WorldTerrain := preload("res://scripts/world_terrain.gd")
var _world_ready := false
var encounter_started := true
var slam_floor := 500.0
var _fixed_accumulator := 0.0
var _camera_focus := Vector2(705,370)
func _ready() -> void:
	super._ready()
	remove_child(_stage)
	_stage.queue_free()
	_stage=WorldTerrain.new()
	_stage.arena=self
	_stage.configure(chapter_number)
	add_child(_stage)
	_stage.z_index=-2
	_world_ready=true
	_reset_fighters()
	var details: Dictionary={3:"場地：下沉工坊與兩側高台",4:"場地：冰面凹谷與貨港高台",5:"場地：隆起鐵軌與兩側貨台",6:"場地：通往王座的階梯高台"}
	_hud.modal_detail.text=Campaign.opening(chapter_number).split("\n")[0]+"\n"+details[chapter_number]
	_hud.modal_detail.show()
	camera.position=_camera_focus
	camera.zoom=Vector2.ONE*1.2
func _reset_fighters() -> void:
	super._reset_fighters()
	if not _world_ready: return
	_stage.configure(chapter_number)
	for body: Duelist in [left,right]:
		body.position.x=600 if body==left else 840
		body.ground_y=_stage.base_height(body.position.x)
		body.relax()
		body.position.y=body.ground_y
		body.motion_bounds=Vector2(380,1030)
	_fixed_accumulator=0
	_camera_focus=(left.position+right.position)*.5+Vector2(0,-105)
	camera.position=_camera_focus
	camera.offset=Vector2.ZERO
func _start_round() -> void:
	super._start_round()
	for body in [left,right]: body.set_process(false)
func _process(delta: float) -> void:
	if not _world_ready or _round_state!=RoundState.PLAYING or _ended: return
	_fixed_accumulator+=minf(delta,.1)
	while _fixed_accumulator>=1.0/120 and _round_state==RoundState.PLAYING:
		var dt:=1.0/120
		_stage.tick(dt*_pace)
		super._process(dt)
		if _round_state==RoundState.PLAYING:
			left._process(dt)
			right._process(dt)
			_update_camera(dt*_pace)
		_fixed_accumulator-=dt
func _update_camera(dt: float,cut: bool=false) -> void:
	# Follow the automatic duel, preserving its original controls and timing.
	var target: Vector2=(left.position+right.position)*.5+Vector2(0,-110)
	target.x=clampf(target.x,650,760)
	target.y=clampf(target.y,160,480)
	var overflow:=target-_camera_focus
	_camera_focus.x+=signf(overflow.x)*maxf(0,absf(overflow.x)-60)
	_camera_focus.y+=signf(overflow.y)*maxf(0,absf(overflow.y)-24)
	var weight:=1.0 if cut else 1-exp(-6.0*dt)
	camera.zoom=camera.zoom.lerp(Vector2.ONE*1.2,weight)
	camera.position=camera.position.lerp(_camera_focus,weight)
func _placement_preview(at: Vector2) -> Dictionary:
	if not encounter_started or not _world_ready: return {}
	if at.x<380 or at.x>1030: return {}
	var y:=ground_height(at.x,at.y)
	if y>640 or absf(at.y-y)>180: return {}
	var affected: Array[Duelist]=[]
	var radius:=36.0 if _tool==3 else 100.0 if _tool==4 else float((_items["後撤彈簧"] if _tool==1 else _items["時停"])["range"])
	for body: Duelist in [left,right]:
		if not body.airborne and absf(body.position.x-at.x)<radius and absf(body.position.y-y)<60: affected.append(body)
	var spot:=_prop_at("spring" if _tool==1 else "stop",at.x,y)
	return {"floor":Vector2(at.x,y),"spot":spot,"radius":radius,"affected":affected,"available":_cool[_tool]<=0}
func _place(at: Vector2) -> void:
	if not encounter_started: return
	var count:=sandbags.size()
	super._place(at)
	if sandbags.size()>count: sandbags[-1]["y"]=ground_height(at.x,at.y)
func _begin_slam() -> void:
	super._begin_slam()
	slam_floor=left.position.y
func _resolve_slam() -> void:
	# Being on a different floor matters; the impact belongs to its locked height.
	if absf(left.position.y-slam_floor)>80:
		var was_airborne:=left.airborne
		left.airborne=true
		super._resolve_slam()
		left.airborne=was_airborne
	else: super._resolve_slam()
func _draw() -> void:
	if not _world_ready or _round_state!=RoundState.PLAYING: return
	for body: Duelist in [left,right]:
		_draw_beam(body)
		_draw_spring_aim(body)
		var at:=body.position+Vector2(0,-(Duelist.FOOT*Duelist.SCALE+128)*body.scale.y-16)
		ArenaHud.Icons.paint(self,"diamond" if body==left else "boss",at,20,Color("9bd2be") if body==left else Color("ed7758"))
	_draw_placement_preview()
	if _boss_state in ["windup","charge"]:
		var points:=PackedVector2Array()
		var lo:=minf(right.position.x,_rush_target)
		var hi:=maxf(right.position.x,_rush_target)
		for i in 25:
			var x:=lerpf(lo,hi,i/24.0)
			points.append(Vector2(x,_stage.base_height(x)-5))
		draw_polyline(points,Color("421f24"),8)
		draw_polyline(points,Color("ec8663"),3)
func _finish_round() -> void:
	super._finish_round()
	if right.out and not left.out: _hud.modal_reason.text=_last_boss_hit+"擊倒"
	elif left.out: _hud.modal_reason.text=_last_hero_hit+"擊倒"
func _tick_sandbags(dt: float) -> void:
	for i in range(sandbags.size()-1,-1,-1):
		var bag: Dictionary=sandbags[i]
		bag["life"]-=dt
		if bag["life"]<=0:
			sandbags.remove_at(i)
			continue
		var floor_y: float=bag.get("y",ground_height(bag["x"],420))
		if absf(left.position.x-float(bag["x"]))<34 and absf(left.position.y-floor_y)<55 and left.slipping:
			var health:=left.hp
			left.relax()
			left.hp=health
		if _boss_state=="charge" and not right.airborne and absf(right.position.x-float(bag["x"]))<52 and absf(right.position.y-floor_y)<65:
			sandbags.remove_at(i)
			_interrupt_boss()
			_mechanic_damage(4,"撞上沙袋 · 破甲")
func _tick_crate(dt: float) -> void:
	if chapter_number<5 or magnet_left<=0: return
	magnet_left=maxf(0,magnet_left-dt)
	var before:=crate_x
	crate_x=move_toward(crate_x,clampf(magnet_x,390,1020),dt*260)
	var in_path:=right.position.x>=minf(before,crate_x)-44 and right.position.x<=maxf(before,crate_x)+44
	var same_level:=absf(right.position.y-_stage.base_height(right.position.x))<65
	if crate_ready and absf(crate_x-before)>.01 and not right.airborne and in_path and same_level:
		crate_ready=false
		_interrupt_boss()
		_mechanic_damage(6,"鐵箱撞擊 · 爐心破甲")
		_audio.cue("counter")
func _draw_placement_preview() -> void:
	if _tool<3:
		super._draw_placement_preview()
		return
	var data:=_placement_preview(get_global_mouse_position())
	if data.is_empty(): return
	var ink:=Color("8ace85") if data["available"] else Color("ed7758")
	ArenaHud.Icons.paint(self,"sandbag" if _tool==3 else "magnet",data["floor"]-Vector2(0,26),36,Color(1,1,1,0.85 if data["available"] else 0.4))
	Placement.footprint(self,data["floor"],data["radius"],ink)
	if _tool==4:
		Placement.arrow(self,Vector2(crate_x,_stage.base_height(crate_x)-26),data["floor"]-Vector2(0,26),ink)
