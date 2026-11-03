extends "res://scripts/action_trial_stage.gd"
## Research layouts inspired by platform fighters, using original project art.
var layout_id := 4
var time := 0.0
var slide_velocity := 0.0
var slippery := true
var moving := true
var fragile_left := 0.0
var moving_x := 660.0
func configure(_number: int) -> void:
	trial=layout_id
	time=0
	fragile_left=0
	slide_velocity=0
	if layout_id==4:
		theme_name="ice"
		strips=[surface(340,1080,500),surface(435,575,400),surface(845,985,360)]
	elif layout_id==5:
		theme_name="forge"
		strips=[surface(340,1080,570),surface(340,520,500),surface(940,1080,500),surface(660,790,400)]
	else:
		theme_name="tower"
		strips=[surface(550,870,520),surface(360,500,420),surface(920,1060,420),surface(640,780,300)]
	queue_redraw()
func tick(dt: float, body: Duelist, axis: float) -> void:
	time+=dt
	if layout_id==4:
		var on_ice: bool=slippery and not body.airborne and body.position.y>475 and body.position.x>590 and body.position.x<850
		var target:=axis*260
		slide_velocity=move_toward(slide_velocity,target,(200 if on_ice else 1600)*dt)
		if on_ice: body.position.x=clampf(body.position.x+(slide_velocity-target)*dt,340,1080)
	elif layout_id==5:
		var before:=moving_x
		if moving: moving_x=660+sin(time*.8)*160
		var standing: bool=not body.airborne and absf(body.position.y-400)<8 and body.position.x>=before and body.position.x<=before+130
		strips[3]["x0"]=moving_x
		strips[3]["x1"]=moving_x+130
		if standing: body.position.x+=moving_x-before
	elif fragile_left>0:
		fragile_left=maxf(0,fragile_left-dt)
		if fragile_left==0: strips.append(surface(920,1060,420))
	queue_redraw()
func interact() -> void:
	if layout_id==4: slippery=not slippery
	elif layout_id==5: moving=not moving
	elif fragile_left==0:
		for i in range(strips.size()-1,-1,-1):
			if strips[i]["x0"]==920.0: strips.remove_at(i)
		fragile_left=4
	queue_redraw()
func _draw() -> void:
	# Reuse platform materials and backgrounds, with research-specific geometry.
	var saved:=trial
	trial=0
	super._draw()
	trial=saved
	if layout_id==4:
		draw_rect(Rect2(590,496,260,8),Color("b0e0de") if slippery else Color("ab7950"))
		for x in range(610,840,36): draw_line(Vector2(x,509),Vector2(x+25,502),Color("9ac4c5"),3)
	elif layout_id==5:
		draw_dashed_line(Vector2(490,420),Vector2(960,420),Color("dfb269"),2,12)
	else:
		for x in [365,485,925,1045]: draw_line(Vector2(x,420),Vector2(x,470),Color("dfb269"),4)
	for point in [Vector2(505,400),Vector2(915,360)] if layout_id==4 else [Vector2(moving_x+65,400),Vector2(1000,500)] if layout_id==5 else [Vector2(430,420),Vector2(710,300),Vector2(990,420)]:
		Icons.paint(self,"diamond",point-Vector2(0,24),24,Color("8ace85"))
