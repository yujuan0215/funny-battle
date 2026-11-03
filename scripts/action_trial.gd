extends Node2D
## Direct player control. No plans, execution button, or automatic player AI.
const Hud := preload("res://scripts/arena_hud.gd")
const Stage := preload("res://scripts/action_trial_stage.gd")
const Audio := preload("res://scripts/battle_audio.gd")
const Progress := preload("res://scripts/player_progress.gd")
const Trajectory := preload("res://scripts/spring_trajectory.gd")
const TITLES := ["斷柱前哨", "懸橋機關", "熔爐核心"]
const GOALS := ["誘敵撞柱，靠近破綻按 F 反擊", "登上高台，按 F 拉桿讓鐵衛落坑", "避開鎖定重錘，再反擊或落下鐵箱"]
enum State { BRIEFING, PLAYING, PAUSED, RESULT }
@export_range(1,3) var trial_id := 1
@onready var left: Duelist = $Left
@onready var right: Duelist = $Right
@onready var camera: Camera2D = $Camera2D
var _stage: Node2D
var _hud: CanvasLayer
var _audio: Node
var _round_state := State.BRIEFING
var _ended := false
var _pace := 1.0
var hard := false
var progress_path := "user://action_trial_progress.json"
var _held_left := false
var _held_right := false
var _buffer := 0.0
var _coyote := 0.0
var _accumulator := 0.0
var _invulnerable := 0.0
var _hurt_lock := 0.0
var _attack_pending := false
var _attack_age := 0.0
var _attack_cool := 0.0
var _cool: Array[float] = [0.0,0.0,0.0]
var bananas: Array[Dictionary] = []
var boss_state := "approach"
var boss_time := 0.0
var boss_duration := 1.0
var locked_x := 0.0
var locked_y := 500.0
var rush_from := 0.0
var rush_to := 0.0
var _charge_hit := false
var _boss_hurt := 0.0
var bridge_left := 0.0
var lever_cool := 0.0
var crate_y := -1.0
var crate_vy := 0.0
var crate_spent := false
var spring_flash := 0.0
var spring_at := Vector2.ZERO
var catch_used := false
var rescues := 1
var _hit_stop := 0.0
var _shake := 0.0
var hits := 0
var jumps := 0
var _time := 0.0
var _difficulty_button: Button
var _action_hint: Label

func _ready() -> void:
	for body in [left,right]: body.set_process(false)
	_stage = Stage.new()
	_stage.arena = self
	add_child(_stage)
	_hud = Hud.new()
	add_child(_hud)
	_audio = Audio.new()
	add_child(_audio)
	_hud.start_requested.connect(_start_round)
	_hud.retry_requested.connect(_restart)
	_hud.leave_requested.connect(_leave)
	_hud.pause_requested.connect(_pause)
	_hud.pace_requested.connect(_toggle_pace)
	_hud.mute_requested.connect(func() -> void: _audio.toggle_mute())
	_hud.tool_selected.connect(func(id: int) -> void:
		if id == 0: _banana()
		else: _spring()
	)
	_hud.next_requested.connect(_next)
	_hud.set_loadout([0,1])
	_hud._key_labels[0].text = "B"
	_hud._key_labels[1].text = "E"
	_hud.tool_buttons[0].tooltip_text = "B · 向面前投香蕉，先選站位與方向"
	_hud.tool_buttons[1].tooltip_text = "E · 腳下彈簧，只有落地才可再用"
	for label: Label in _hud.root.find_children("*","Label",true,false):
		if label.text.contains("Space 慢速"): label.text = "A/D 移動　Space 跳躍　F 反擊"
	_difficulty_button = _hud._button("標準",_toggle_hard)
	_difficulty_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_difficulty_button.offset_left=-210
	_difficulty_button.offset_right=-32
	_difficulty_button.offset_top=-104
	_difficulty_button.offset_bottom=-36
	_hud.root.add_child(_difficulty_button)
	_action_hint = _hud._label("",24,Hud.CYAN)
	_action_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_action_hint.offset_left=32
	_action_hint.offset_right=410
	_action_hint.offset_top=-114
	_action_hint.offset_bottom=-50
	_hud.root.add_child(_action_hint)
	camera.position=Vector2(710,390)
	camera.zoom=Vector2.ONE*1.22
	_reset()
	_briefing()

func ground_height(x: float, feet_y: float=500) -> float:
	return _stage.support_at(x,feet_y)
func _reset() -> void:
	_ended=false
	_time=0
	_hit_stop=0
	_shake=0
	camera.offset=Vector2.ZERO
	_accumulator=0
	_invulnerable=0
	_hurt_lock=0
	_buffer=0
	_coyote=0
	_attack_pending=false
	_attack_cool=0
	_boss_hurt=0
	_held_left=false
	_held_right=false
	_cool.fill(0)
	bananas.clear()
	bridge_left=0
	lever_cool=0
	crate_y=-1
	crate_spent=false
	hits=0
	catch_used=false
	rescues=0 if hard else 1
	jumps=0
	_stage.configure(trial_id)
	for body in [left,right]:
		body.hp_max=(3 if hard else 6) if body==left else 12
		body.relax()
		body.position=Vector2(485 if body==left else 940,500)
		body.ground_y=500
		body.motion_bounds=Vector2(340,1080)
		body.scale=Vector2.ONE*(0.65 if body==left else 1.08)
		body.show_hp=false
		body.use_sheet("bare" if body==left else "armor")
		body.play("idle")
	left.face_toward(right.position.x)
	right.face_toward(left.position.x)
	boss_state="approach"
	boss_time=.6
	_hud.set_rescue(rescues>0)
	_hud.win_conditions.hide()
	_hud.objective.text="試煉 %d / 3　%s" % [trial_id,TITLES[trial_id-1]]
	_hud.set_health(left.hp,left.hp_max,right.hp,right.hp_max)
	_hud.set_pace(_pace)
	_hud.set_tools(1,_cool,_pace)
	_hud.tell("")
	_difficulty_button.text="挑戰" if hard else "標準"
	_action_hint.text="A/D 移動　Space 跳躍\nE 彈簧　B 香蕉　F 反擊"
	queue_redraw()
func _briefing() -> void:
	_round_state=State.BRIEFING
	_hud.show_briefing(false,"動作試煉 · "+TITLES[trial_id-1])
	_hud.modal_reason.text=GOALS[trial_id-1]
	_hud.modal_detail.text="A/D 移動　Space 跳躍\nE 彈簧　B 香蕉　F 反擊／拉桿"
	_hud.modal_detail.show()
	_difficulty_button.hide()
	_action_hint.hide()
func _start_round() -> void:
	if _round_state==State.RESULT: _reset()
	_round_state=State.PLAYING
	_hud.close_modal()
	_difficulty_button.show()
	_action_hint.show()
func _restart() -> void:
	_reset()
	_start_round()
func _leave() -> void:
	get_tree().change_scene_to_file("res://scenes/test_lab.tscn")
func _next() -> void:
	get_tree().change_scene_to_file("res://scenes/action_trial_%d.tscn" % (trial_id+1))
func _toggle_pace() -> void:
	_pace=.65 if _pace==1 else 1.0
	_hud.set_pace(_pace)
func _toggle_hard() -> void:
	hard=not hard
	_restart()
func _pause() -> void:
	if _round_state==State.PAUSED:
		_start_round()
		return
	if _round_state!=State.PLAYING: return
	_round_state=State.PAUSED
	_held_left=false
	_held_right=false
	_hud.show_pause()
	_hud.modal_detail.text="A/D 移動　Space 跳躍\nE 彈簧　B 香蕉　F 反擊／拉桿"
	_hud.modal_detail.show()
	_difficulty_button.hide()
	_action_hint.hide()
func _process(delta: float) -> void:
	if _round_state!=State.PLAYING: return
	if _hit_stop>0:
		_hit_stop=maxf(0,_hit_stop-delta)
		return
	_accumulator+=minf(delta,.1)*_pace
	while _accumulator>=1.0/120 and _round_state==State.PLAYING:
		_step_world(1.0/120)
		_accumulator-=1.0/120
	_hud.set_tools(1,_cool,_pace)
	queue_redraw()
func _step_world(dt: float) -> void:
	_time+=dt
	_shake=move_toward(_shake,0,35*dt)
	camera.offset=Vector2(sin(_time*91),cos(_time*77))*_shake
	right.modulate=Color(1.0,.72,.52) if _boss_hurt>.48 else Color.WHITE
	_invulnerable=maxf(0,_invulnerable-dt)
	_hurt_lock=maxf(0,_hurt_lock-dt)
	_attack_cool=maxf(0,_attack_cool-dt)
	_boss_hurt=maxf(0,_boss_hurt-dt)
	lever_cool=maxf(0,lever_cool-dt)
	spring_flash=maxf(0,spring_flash-dt)
	for i in _cool.size(): _cool[i]=maxf(0,_cool[i]-dt)
	_buffer=maxf(0,_buffer-dt)
	if not left.airborne: _coyote=.1
	else: _coyote=maxf(0,_coyote-dt)
	if _buffer>0 and _coyote>0 and _hurt_lock==0: _jump(false)
	var axis:=float(_held_right)-float(_held_left)
	if _hurt_lock==0:
		if axis!=0 and not _attack_pending: left.face_toward(left.position.x+axis)
		if left.airborne:
			left.air_vx=move_toward(left.air_vx,axis*260,1800*dt)
		else:
			left.position.x=clampf(left.position.x+axis*260*dt*(.55 if _attack_pending else 1.0),340,1080)
			if not _attack_pending:
				var desired: String="run" if axis else "idle"
				if left.anim!=desired: left.play(desired)
	left.modulate.a=.45 if _invulnerable>0 and int(_time*16)%2==0 else 1.0
	_tick_boss(dt)
	left._process(dt)
	right._process(dt)
	_resolve_attack(dt)
	_tick_bananas(dt)
	_tick_environment(dt)
	if left.position.y>670:
		if rescues>0:
			rescues-=1
			left.position=Vector2(485,500)
			left.ground_y=500
			left._plant()
			_invulnerable=0
			_hurt(2,"安全繩")
			_hud.set_rescue(false)
		else: _hurt(99,"落坑")
	if trial_id==2 and not catch_used and right.position.y>610:
		catch_used=true
		right.hp=6
		right.launch_arc(-600,850,1600,false,.1)
		boss_state="recover"
		boss_time=1.1
		_hud.set_health(left.hp,left.hp_max,right.hp,right.hp_max)
		_hud.objective.text="安全扣 1 / 2　右側拉桿"
		_hud.tell("安全扣斷裂",2,["check"])
	elif right.position.y>670:
		right.hp=0
		right.out=true
	if left.hp<=0 or right.hp<=0: _finish()
	_stage.queue_redraw()
func _jump(boost: bool) -> void:
	if left.airborne and _coyote<=0: return
	if _hurt_lock>0: return
	var profile:=Trajectory.launch("up",0) if boost else Vector3(0,550,1600)
	var axis:=float(_held_right)-float(_held_left)
	left.launch_arc(axis*260,profile.y,profile.z,false,.04)
	_coyote=0
	_buffer=0
	jumps+=1
	_audio.cue("spring" if boost else "place")
func _spring() -> void:
	if _round_state!=State.PLAYING or _cool[1]>0 or left.airborne or _hurt_lock>0: return
	spring_at=left.position
	spring_flash=.45
	_cool[1]=3.2
	_jump(true)
func _banana() -> void:
	if _round_state!=State.PLAYING or _cool[0]>0 or bananas.size()>=1: return
	var x:=clampf(left.position.x+(88 if left.face_right else -88),350,1070)
	var floor_y:=ground_height(x,left.position.y)
	if floor_y>600: return
	bananas.append({"x":x,"y":floor_y,"life":5.0})
	_cool[0]=5
	_audio.cue("place")
func _act() -> void:
	if _round_state!=State.PLAYING or _hurt_lock>0: return
	var lever:=Vector2((920 if catch_used else 620) if trial_id==2 else 555,350)
	if trial_id in [2,3] and left.position.distance_to(lever)<68:
		if lever_cool>0: return
		lever_cool=3.4
		if trial_id==2:
			_stage.set_bridge(true)
			bridge_left=1.35
		else:
			crate_y=220
			crate_vy=0
			crate_spent=false
		_audio.cue("phase")
		return
	if _attack_cool>0: return
	_attack_pending=true
	_attack_age=0
	_attack_cool=.42
	left.face_toward(right.position.x)
	left.play("jab")
func _resolve_attack(dt: float) -> void:
	if not _attack_pending: return
	_attack_age+=dt
	if _attack_age<3.0/14: return
	_attack_pending=false
	if absf(left.position.x-right.position.x)<140 and absf(left.position.y-right.position.y)<105:
		if boss_state=="exposed": _damage_boss(4,"反擊命中")
		else: _hud.tell("重甲",.6,["shield"])
func _tick_boss(dt: float) -> void:
	if right.out: return
	if right.airborne: return
	boss_time-=dt
	if boss_state=="approach":
		var gap:=left.position.x-right.position.x
		if absf(gap)>180:
			right.position.x+=signf(gap)*120*dt
			right.face_toward(left.position.x)
			if right.anim!="walk": right.play("walk")
		elif boss_time<=0:
			locked_x=left.position.x
			locked_y=left.position.y
			rush_from=right.position.x
			var dir:=signf(locked_x-rush_from)
			if dir==0: dir=-1
			rush_to=clampf(locked_x+dir*90,355,1065)
			boss_state="windup"
			boss_duration=1.0 if hard else 1.55
			boss_time=boss_duration
			right.face_toward(locked_x)
			right.play("power")
			_audio.cue("warn")
	elif boss_state=="windup":
		if boss_time<=0:
			_charge_hit=false
			boss_state="slam" if trial_id==3 else "charge"
			boss_duration=.25 if trial_id==3 else maxf(.15,absf(rush_to-rush_from)/(640 if hard else 500))
			boss_time=boss_duration
			right.play("heavy" if trial_id==3 else "run")
	elif boss_state=="charge":
		var before:=right.position.x
		right.position.x=move_toward(before,rush_to,(640 if hard else 500)*dt)
		var touched:=left.position.x>=minf(before,right.position.x)-46 and left.position.x<=maxf(before,right.position.x)+46
		if not _charge_hit and touched and absf(left.position.y-right.position.y)<70:
			_charge_hit=true
			_hurt(2 if hard else 1,"衝撞")
		if is_equal_approx(right.position.x,rush_to):
			if trial_id==1 and (rush_to<=360 or rush_to>=1060): _expose("撞柱")
			else: _recover()
	elif boss_state=="slam":
		if boss_time<=0:
			if absf(left.position.x-locked_x)<72 and absf(left.position.y-locked_y)<52:
				_hurt(2 if hard else 1,"重錘")
				_recover()
			else: _expose("重錘落空")
	elif boss_state=="exposed" or boss_state=="recover":
		if boss_time<=0:
			boss_state="approach"
			boss_time=.45
	elif boss_state=="slip":
		if right.position.x<=362 or right.position.x>=1058:
			if trial_id==1: _expose("滑倒撞柱")
		elif boss_time<=0: _recover()
func _expose(reason: String) -> void:
	boss_state="exposed"
	boss_duration=1.5 if hard else 2.4
	boss_time=boss_duration
	right.play("hit")
	_hud.tell(reason,1,["boss","check"])
	_audio.cue("phase")
func _recover() -> void:
	boss_state="recover"
	boss_time=.9
	right.play("idle")
func _damage_boss(amount: int, reason: String) -> void:
	if boss_state!="exposed" or _boss_hurt>0: return
	right.hp=maxi(0,right.hp-amount)
	_boss_hurt=.65
	hits+=1
	_hit_stop=.055
	_shake=4
	boss_time=minf(boss_time,.6)
	_audio.cue("counter")
	_hud.tell(reason,1,["shot","check"])
	_hud.set_health(left.hp,left.hp_max,right.hp,right.hp_max)
func _hurt(amount: int, reason: String) -> void:
	if _invulnerable>0 and amount<99: return
	left.hp=maxi(0,left.hp-amount)
	_invulnerable=1
	_hit_stop=.04
	_shake=3
	_hurt_lock=.22
	_attack_pending=false
	left.launch_arc(-140 if right.position.x>left.position.x else 140,220,1600,false,.05)
	_hud.set_health(left.hp,left.hp_max,right.hp,right.hp_max)
	_hud.tell(reason,1,["miss"],true)
	_audio.cue("hurt")
func _tick_bananas(dt: float) -> void:
	for i in range(bananas.size()-1,-1,-1):
		var p: Dictionary=bananas[i]
		p["life"]-=dt
		if p["life"]<=0:
			bananas.remove_at(i)
			continue
		for body in [left,right]:
			if body.airborne or absf(body.position.x-float(p["x"]))>27 or absf(body.position.y-float(p["y"]))>26: continue
			if body==right and boss_state!="charge": continue
			if body==left and absf(float(_held_right)-float(_held_left))<.1: continue
			var dir:=1.0 if body.face_right else -1.0
			body.begin_slip(dir,90,.45)
			if body==right:
				boss_state="slip"
				boss_time=.5
			else: _hurt_lock=.45
			bananas.remove_at(i)
			_audio.cue("hit")
			break
func _tick_environment(dt: float) -> void:
	if bridge_left>0:
		bridge_left=maxf(0,bridge_left-dt)
		if bridge_left==0: _stage.set_bridge(false)
	if crate_y>=0:
		crate_vy+=1200*dt
		crate_y+=crate_vy*dt
		if not crate_spent and crate_y>=right.position.y-100 and absf(right.position.x-710)<54:
			crate_spent=true
			_damage_boss(4,"鐵箱命中")
		if crate_y>530: crate_y=-1
	var remaining:=boss_time if boss_state in ["windup","exposed"] else 0.0
	_hud.set_intent({"approach":"接近","windup":"重錘鎖定" if trial_id==3 else "衝撞鎖定","charge":"衝撞","exposed":"破綻 · F","recover":"收招","slam":"重錘","slip":"滑倒"}.get(boss_state,""),["boss","clock" if boss_state=="exposed" else "charge"])
	_hud.set_timing(remaining,boss_duration,_pace,boss_state=="exposed")
func _finish() -> void:
	if _ended: return
	_ended=true
	_round_state=State.RESULT
	var won:=right.hp<=0 and left.hp>0
	var saved:=won and Progress.mark_cleared(trial_id,progress_path)==OK
	_hud.show_result(won,"試煉完成" if won else "看預警，再選移動或跳躍",0,saved)
	_hud.modal_detail.text="有效反擊 %d 次　跳躍 %d 次" % [hits,jumps]
	_hud.modal_detail.show()
	_hud.offer_next(won and trial_id<3,"下一個動作試煉")
	if won and trial_id==3: _hud.modal_title.text="三項試煉完成"
	_difficulty_button.hide()
	_action_hint.hide()
	_audio.cue("win" if won else "lose")
func _input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	var code: Key=event.physical_keycode if event.physical_keycode else event.keycode
	if code in [KEY_A,KEY_LEFT]: _held_left=event.pressed and _round_state==State.PLAYING
	if code in [KEY_D,KEY_RIGHT]: _held_right=event.pressed and _round_state==State.PLAYING
	if not event.pressed or event.echo: return
	if code==KEY_ESCAPE:
		if _round_state in [State.BRIEFING,State.RESULT]: _leave()
		else: _pause()
	elif code==KEY_R: _restart()
	elif code==KEY_SPACE and _round_state==State.PLAYING: _buffer=.15
	elif code==KEY_E: _spring()
	elif code==KEY_B: _banana()
	elif code==KEY_F: _act()
	else: return
	get_viewport().set_input_as_handled()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT: _act()
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and not has_meta("automated_capture") and is_instance_valid(_hud):
		_held_left=false
		_held_right=false
		if _round_state==State.PLAYING: _pause()
func _draw() -> void:
	if not is_instance_valid(_hud): return
	if boss_state=="windup":
		if trial_id==3:
			draw_rect(Rect2(locked_x-72,locked_y-8,144,12),Color("ed7758"),false,3)
			draw_dashed_line(Vector2(locked_x,locked_y-210),Vector2(locked_x,locked_y),Color("ed7758"),3,10)
		else:
			draw_dashed_line(Vector2(rush_from,494),Vector2(rush_to,494),Color("ed7758"),5,12)
			Hud.Icons.paint(self,"left" if rush_to<rush_from else "right",Vector2(rush_to,472),28,Color("ed7758"))
	if boss_state=="exposed": Hud.Icons.paint(self,"charge",right.position+Vector2(0,-220),36,Color("8ace85"))
	for p in bananas: Hud.Icons.paint(self,"banana",Vector2(p["x"],p["y"]-20),36,Color.WHITE)
	if spring_flash>0: Hud.Icons.paint(self,"spring",spring_at-Vector2(0,18),36,Color.WHITE)
	if crate_y>=0:
		draw_rect(Rect2(688,crate_y-22,44,44),Color("607e86"))
		draw_line(Vector2(690,crate_y-20),Vector2(730,crate_y+20),Color("dfb269"),4)
