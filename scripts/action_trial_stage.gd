extends "res://scripts/stage_edit.gd"
## Authored collision geometry for the new, separate action trials.
const Backdrop := preload("res://scripts/pixel_backdrop.gd")
const Icons := preload("res://scripts/arena_icons.gd")
var trial := 1
var arena: Node2D
var bridge_open := false
var theme_name := "forest_arena"
func surface(a: float, b: float, y: float) -> Dictionary:
	return {"x0":a,"x1":b,"y0":y,"y1":y,"tilt":false}
func configure(number: int) -> void:
	trial = number
	bridge_open = false
	theme_name = ["forest_arena", "valley", "forge"][trial - 1]
	strips = [surface(340,1080,500)]
	if trial == 1: strips.append(surface(650,770,432))
	elif trial == 2:
		strips = [surface(340,600,500),surface(820,1080,500),surface(520,700,350),surface(450,525,425),surface(600,820,500),surface(860,1020,350)]
	else:
		strips.append(surface(450,620,350))
		strips.append(surface(850,1020,350))
		strips.append(surface(660,765,430))
	queue_redraw()
func set_bridge(open: bool) -> void:
	if trial != 2 or open == bridge_open: return
	bridge_open = open
	if open:
		for i in range(strips.size()-1,-1,-1):
			if strips[i]["x0"]==600.0 and strips[i]["x1"]==820.0 and strips[i]["y0"]==500.0: strips.remove_at(i)
	else: strips.append(surface(600,820,500))
	queue_redraw()
func _draw() -> void:
	var view := (get_canvas_transform().affine_inverse() * get_viewport_rect()).grow(80)
	Backdrop.paint(self,view,theme_name,true)
	var dark := Color("241c27")
	var wood := Color("69483f")
	var gold := Color("dfb269")
	draw_rect(Rect2(view.position.x,670,view.size.x,maxf(30,view.end.y-670)),dark)
	for x in range(320,1100,32):
		draw_colored_polygon(PackedVector2Array([Vector2(x,694),Vector2(x+16,670),Vector2(x+32,694)]),Color("607e86"))
	for strip in strips:
		var a := Vector2(strip["x0"],strip["y0"])
		var w: float = strip["x1"]-strip["x0"]
		draw_rect(Rect2(a,Vector2(w,30)),wood if trial != 3 else Color("4a3428"))
		draw_rect(Rect2(a+Vector2(0,26),Vector2(w,6)),dark)
		draw_line(a,a+Vector2(w,0),gold,4)
		for x in range(int(a.x)+20,int(a.x+w),36):
			draw_line(Vector2(x,a.y+5),Vector2(x,a.y+25),dark,3)
		if a.y < 480:
			for x in [a.x+10,a.x+w-10]:
				draw_line(Vector2(x,a.y+30),Vector2(x,540),dark,8)
	if trial == 1:
		for x in [355,1065]:
			draw_rect(Rect2(x-12,408,24,92),wood)
			for y in [420,475]: draw_rect(Rect2(x-17,y,34,10),gold)
			Icons.paint(self,"charge",Vector2(x,390),24,Color("ed7758"))
	if trial == 2 and not bridge_open:
		for x in range(612,818,34):
			draw_polyline(PackedVector2Array([Vector2(x,503),Vector2(x-6,514),Vector2(x+5,523)]),dark,4)
			draw_rect(Rect2(x-8,531,16,4),Color("ed7758"))
	if trial in [2,3]:
		var active_x: float=(920 if arena.catch_used else 620) if trial==2 else 555
		for x in [620.0,920.0] if trial==2 else [555.0]:
			var lever:=Vector2(x,350)
			var active:=absf(x-active_x)<1
			var metal:=gold if active else Color("607e86")
			draw_rect(Rect2(x-14,336,28,14),dark)
			draw_line(lever+Vector2(0,-14),lever+Vector2(16 if bridge_open else -16,-44),metal,6)
			Icons.paint(self,"check" if active else "lock",lever+Vector2(0,-68),24,Color("8ace85") if active else metal)
			if active and arena.lever_cool>0: Icons.paint(self,"clock",lever+Vector2(0,-96),24,metal)
		if trial == 3:
			draw_line(Vector2(710,160),Vector2(710,240),gold.darkened(.3),5)
			draw_rect(Rect2(688,220,44,44),Color("607e86"))
			draw_line(Vector2(692,224),Vector2(728,260),gold,4)
