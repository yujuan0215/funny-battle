extends Node2D
## Authored, collidable landforms. Every visible walkable edge is sampled here.
const Backdrop := preload("res://scripts/pixel_backdrop.gd")
const MechanismArt := preload("res://scripts/arena_mechanism_art.gd")
const Icons := preload("res://scripts/arena_icons.gd")
var arena: Node2D
var chapter := 3
var chapter_theme := "clock"
var editing := false
var hazard_edges := false
var strips: Array[Dictionary] = []
var surfaces: Array[Dictionary] = []
var world_bounds := Rect2(-2700,-100,4100,1900)
var hazard_y := 1450.0
var time := 0.0
var checkpoints: Array[Vector2] = []
var _materials: Dictionary = {}
const PALETTES := {
	3:[Color("48382e"),Color("856144"),Color("dfb778"),Color("282c35")],
	4:[Color("264554"),Color("467386"),Color("bdedf1"),Color("16323f")],
	5:[Color("402d31"),Color("80533b"),Color("e9a365"),Color("282630")],
	6:[Color("322e4b"),Color("665276"),Color("d2ae6b"),Color("1c2339")],
}
func configure(number: int) -> void:
	chapter=number
	chapter_theme={3:"clock",4:"ice",5:"forge",6:"tower"}[chapter]
	surfaces.clear()
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	_build_materials()
	var battle_profiles: Dictionary={
		3:[Vector2(360,500),Vector2(470,500),Vector2(600,570),Vector2(740,570),Vector2(870,460),Vector2(1050,460)],
		4:[Vector2(360,500),Vector2(500,500),Vector2(660,580),Vector2(800,580),Vector2(950,500),Vector2(1050,500)],
		5:[Vector2(360,500),Vector2(520,500),Vector2(700,420),Vector2(820,420),Vector2(950,500),Vector2(1050,500)],
		6:[Vector2(360,500),Vector2(480,500),Vector2(620,430),Vector2(800,430),Vector2(920,360),Vector2(1050,360)],
	}
	_land(battle_profiles[chapter],"ice" if chapter==4 else "rail" if chapter==5 else "tower" if chapter==6 else "clock",130 if chapter==4 else 180 if chapter==5 else 400)
	_ledge(385,510,410,"wood" if chapter==3 else "ice" if chapter==4 else "rail" if chapter==5 else "tower")
	_ledge(900,1040,285 if chapter==6 else 390,"wood" if chapter==3 else "ice" if chapter==4 else "rail" if chapter==5 else "tower")
	strips=[{"x0":360.0,"x1":1050.0,"y0":500.0,"y1":500.0}]
	world_bounds=Rect2(-40,-100,1460,1200)
	checkpoints.clear()
	hazard_y=660 if chapter==4 else 640 if chapter==5 else 1100
	time=0
	queue_redraw()
func _land(points: Array, material: String, depth: float) -> void:
	surfaces.append({"points":PackedVector2Array(points),"material":material,"depth":depth,"ledge":false})
func _ledge(x0: float,x1: float,y: float,material: String) -> void:
	surfaces.append({"points":PackedVector2Array([Vector2(x0,y),Vector2(x1,y)]),"material":material,"depth":36.0,"ledge":true})
func height_on(surface: Dictionary,x: float) -> float:
	var points: PackedVector2Array=surface["points"]
	for i in range(points.size()-1):
		var a:=points[i]
		var b:=points[i+1]
		if x>=a.x and x<=b.x: return lerpf(a.y,b.y,inverse_lerp(a.x,b.x,x))
	return INF
func support_at(x: float,feet_y: float) -> float:
	var best:=INF
	for s in surfaces:
		var y:=height_on(s,x)
		if not s["ledge"] or y>=feet_y-28: best=minf(best,y)
	return best if is_finite(best) else hazard_y+400
func base_height(x: float) -> float:
	for s in surfaces:
		if not s["ledge"]:
			var y:=height_on(s,x)
			if is_finite(y): return y
	return hazard_y+400
func surface_kind(x: float,y: float) -> String:
	for s in surfaces:
		if absf(height_on(s,x)-y)<28: return s["material"]
	return ""
func tick(dt: float) -> void:
	time+=dt
	queue_redraw()
func _draw() -> void:
	if surfaces.is_empty(): return
	var view: Rect2=(get_canvas_transform().affine_inverse()*get_viewport_rect()).grow(90)
	Backdrop.paint(self,view,chapter_theme,true)
	draw_rect(view,Color(0.025,0.045,0.07,.22))
	var p: Array=PALETTES[chapter]
	# Parallax silhouettes anchored to world space; the foreground scrolls faster.
	var eye: Vector2=view.get_center()
	for i in range(-5,8):
		var x:=i*440.0+eye.x*.55
		var y:=740.0+eye.y*.38
		_architecture(Vector2(x,y),180,520,Color(p[3],.38),false)
	_draw_hazard(view)
	_draw_landmarks(p)
	for s in surfaces: _draw_land(s,p)
	for point in checkpoints:
		var active: bool=is_instance_valid(arena) and arena.route_checkpoint.x>=point.x
		_lantern(point+Vector2(38,-66),p[2] if active else Color(p[2],.45))
		Icons.paint(self,"right",point+Vector2(80,-48),24,Color(p[2],.8))
	for side in [-1, 1]:
		var edge := 380.0 if side < 0 else 1030.0
		MechanismArt.barrier(self, edge, base_height(edge), side, p[0], p[2])
	_draw_mechanisms(p)
func _draw_land(s: Dictionary,p: Array) -> void:
	var edge: PackedVector2Array=s["points"]
	var a:=edge[0]
	var b:=edge[-1]
	var depth: float=s["depth"]
	var material: String=s["material"]
	var fill: Color=p[0]
	var rim: Color=p[2]
	var polygon:=edge.duplicate()
	# Broken cliff strata / tapered hulls replace rectangular platform slabs.
	polygon.append(b+Vector2(-18,depth*.4))
	polygon.append(Vector2(b.x-(b.x-a.x)*.17,b.y+depth*.72))
	polygon.append(Vector2(a.x+(b.x-a.x)*.54,maxf(a.y,b.y)+depth))
	polygon.append(Vector2(a.x+(b.x-a.x)*.25,a.y+depth*.76))
	polygon.append(a+Vector2(12,depth*.32))
	if material=="ship": fill=Color("3c3b42")
	var uv:=PackedVector2Array()
	for point in polygon: uv.append(point/96.0)
	draw_polygon(polygon,PackedColorArray([Color.WHITE]),uv,_materials["ice" if material=="ice" else "ship" if material=="ship" else "wall"])
	draw_polyline(polygon,fill.darkened(.4),5)
	for i in range(edge.size()-1):
		var left:=edge[i]
		var right:=edge[i+1]
		var step:=16 if material in ["clock","tower"] else 24
		for x in range(int(left.x),int(right.x),step):
			var y:=lerpf(left.y,right.y,inverse_lerp(left.x,right.x,x))
			var next_y:=lerpf(left.y,right.y,inverse_lerp(left.x,right.x,minf(x+step,right.x)))
			if material in ["clock","tower"]:
				draw_rect(Rect2(x,y-2,minf(step,right.x-x),10),p[1])
				draw_line(Vector2(x,y),Vector2(minf(x+step,right.x),y),rim,3)
				draw_line(Vector2(minf(x+step,right.x),y),Vector2(minf(x+step,right.x),next_y),rim.darkened(.3),2)
			else:
				draw_line(Vector2(x,y),Vector2(minf(x+step,right.x),next_y),rim,5)
			if material=="ice":
				var tooth:=12+posmod(x,29)
				draw_colored_polygon(PackedVector2Array([Vector2(x,y+12),Vector2(x+9,y+12),Vector2(x+4,y+tooth)]),Color("6da9b9"))
			elif material=="rail":
				draw_line(Vector2(x,y+4),Vector2(x,y+20),Color("b29478"),6)
				draw_line(Vector2(x,y-7),Vector2(minf(x+step,right.x),next_y-7),Color("a1a7a3"),3)
			if depth>80 and posmod(x,3)==0:
				draw_line(Vector2(x+7,y+36),Vector2(x+19,y+58),p[1].darkened(.25),4)
			if material in ["clock","tower"] and depth>100 and posmod(x,64)==0:
				_window(Vector2(x+18,y+60),p[2].darkened(.45))
	if material in ["clock","tower","rail"] and not s["ledge"]:
		for x in range(int(a.x)+80,int(b.x)-40,170):
			var top:=height_on(s,x)
			_architecture(Vector2(x,top+depth*.78),60,minf(depth*.65,260),p[3],true)
	if material=="ship":
		draw_line(a+Vector2(30,80),b+Vector2(-50,80),p[1],5)
		for x in range(int(a.x)+45,int(b.x)-40,62):
			var y:=height_on(s,x)+60
			draw_circle(Vector2(x,y),10,Color("111d27"))
			draw_arc(Vector2(x,y),12,0,TAU,12,p[1],3)
func _architecture(base: Vector2,width: float,height: float,ink: Color,arch: bool) -> void:
	if arch:
		draw_rect(Rect2(base.x-width/2,base.y-height,width,height),ink)
	else:
		_textured_box(Rect2(base.x-width/2,base.y-height,width,height),"wall",ink)
	if arch:
		var hole:=PackedVector2Array([base+Vector2(-width*.3,0),base+Vector2(-width*.3,-height*.55),base+Vector2(0,-height*.78),base+Vector2(width*.3,-height*.55),base+Vector2(width*.3,0)])
		draw_colored_polygon(hole,ink.darkened(.45))
	else:
		draw_colored_polygon(PackedVector2Array([base+Vector2(-width*.65,-height),base+Vector2(0,-height-60),base+Vector2(width*.65,-height)]),ink)
		for j in 3: _window(base+Vector2(0,-height+50+j*100),ink.lightened(.14))
func _window(at: Vector2,color: Color) -> void:
	draw_rect(Rect2(at-Vector2(7,20),Vector2(14,32)),Color("182334"))
	draw_rect(Rect2(at-Vector2(4,17),Vector2(8,22)),color)
	draw_line(at+Vector2(-6,-5),at+Vector2(6,-5),Color("332b36"),3)
func _lantern(at: Vector2,color: Color) -> void:
	draw_line(at+Vector2(0,66),at+Vector2(0,-10),Color("302a35"),5)
	draw_rect(Rect2(at-Vector2(11,15),Vector2(22,30)),Color("2a2731"))
	draw_rect(Rect2(at-Vector2(6,10),Vector2(12,20)),color)
func _draw_landmarks(p: Array) -> void:
	if chapter==3:
		var at:=Vector2(160,205)
		draw_line(at+Vector2(0,130),at+Vector2(0,490),p[3],16)
		Backdrop._gear(self,at,130,p[1])
		draw_circle(at,99,Color("252c34"))
		draw_arc(at,91,0,TAU,48,p[2],4)
		for i in 12:
			var end:=at+Vector2(cos(i*TAU/12),sin(i*TAU/12))*82
			draw_rect(Rect2(end.round()-Vector2(3,3),Vector2(6,6)),p[2])
		draw_line(at,at+Vector2(sin(time*.2),-cos(time*.2))*72,p[2],5)
		draw_line(at,at+Vector2(-47,-18),p[2],8)
		for at2 in [Vector2(-680,510),Vector2(950,280)]:
			Backdrop._gear(self,at2,65,p[1])
			draw_circle(at2,44,p[3])
			draw_arc(at2,37,0,TAU,24,p[2].darkened(.4),5)
			for spoke in 6:
				var angle:=spoke*TAU/6+time*.15
				draw_line(at2,at2+Vector2(cos(angle),sin(angle))*40,p[1],8)
			draw_circle(at2,10,p[2])
	elif chapter==4:
		var mast:=Vector2(200,540)
		draw_line(mast,mast+Vector2(0,-380),p[1],12)
		draw_line(mast+Vector2(-120,-250),mast+Vector2(180,-250),p[1],9)
		draw_colored_polygon(PackedVector2Array([mast+Vector2(12,-360),mast+Vector2(124,-280),mast+Vector2(108,-260),mast+Vector2(136,-244),mast+Vector2(12,-140)]),Color("66838b"))
		for row in 5:
			var y:= -325+row*32
			draw_line(mast+Vector2(18,y),mast+Vector2(42+row*12,y),Color("78979f"),3)
		for x in [185,1080]:
			var base:=Vector2(x,support_at(x,0))
			draw_colored_polygon(PackedVector2Array([base+Vector2(-55,0),base+Vector2(-20,-100),base+Vector2(8,-45),base+Vector2(34,-140),base+Vector2(63,0)]),Color("6597a8"))
	elif chapter==5:
		for x in [-2050,-970,250]:
			var y:=support_at(x,0)
			_textured_box(Rect2(x-28,y-280,56,280),"wall",p[3])
			draw_rect(Rect2(x-38,y-285,76,18),p[1])
			draw_rect(Rect2(x-15,y-210,30,110),Color("c96339"))
			for i in 3: draw_rect(Rect2(x-12+i*12,y-210,4,110),Color("442c31"))
	else:
		for x in [-2040,-1430,-760,170,1000]:
			var y:=support_at(x,0)
			_architecture(Vector2(x,y+240),95,570,p[0].darkened(.25),false)
			draw_colored_polygon(PackedVector2Array([Vector2(x+35,y-290),Vector2(x+85,y-280),Vector2(x+75,y-130),Vector2(x+35,y-150)]),Color("703f64"))
		# A visible crown at the summit, rather than another floating rectangle.
		var crown:=PackedVector2Array([Vector2(590,330),Vector2(565,245),Vector2(640,285),Vector2(700,210),Vector2(760,285),Vector2(835,245),Vector2(810,330)])
		draw_colored_polygon(crown,p[2].darkened(.22))
func _draw_hazard(view: Rect2) -> void:
	var color:=Color("3c91a8") if chapter==4 else Color("ed7739") if chapter==5 else Color("353147")
	draw_rect(Rect2(view.position.x,hazard_y,view.size.x,maxf(4,view.end.y-hazard_y)),color.darkened(.5))
	for x in range(floori(view.position.x/32)*32,ceili(view.end.x/32)*32,32):
		var y:=hazard_y+sin(x*.03+time*1.4)*5
		draw_rect(Rect2(x,y,26,5),color)
		if chapter==4:
			draw_colored_polygon(PackedVector2Array([Vector2(x,y+10),Vector2(x+8,y-15),Vector2(x+21,y+10)]),color.lightened(.2))
		elif chapter==5:
			draw_rect(Rect2(x+5,hazard_y-24-fposmod(time*40+x,130),3,5),Color(color,.6))
func _draw_mechanisms(p: Array) -> void:
	if not is_instance_valid(arena): return
	if chapter>=5:
		var x: float=arena.crate_x
		var y:=base_height(x)
		draw_rect(Rect2(x-24,y-48,48,46),Color("45545b"))
		draw_rect(Rect2(x-24,y-48,48,46),p[2],false,3)
		draw_line(Vector2(x-20,y-44),Vector2(x+20,y-4),p[2].darkened(.2),4)
		if arena.magnet_left>0:
			Icons.paint(self,"magnet",Vector2(arena.magnet_x,support_at(arena.magnet_x,420)-28),30,p[2])
	for bag in arena.sandbags:
		Icons.paint(self,"sandbag",Vector2(bag["x"],bag.get("y",base_height(bag["x"]))-24),38,p[2])
	MechanismArt.slam(self, arena.slam_x, arena.slam_floor, arena.slam_left, arena.slam_duration, arena.slam_impact_left)

func _build_materials() -> void:
	# Original pixel tiles, made once per scene, reused by every landform mesh.
	_materials.clear()
	var palette: Array=PALETTES[chapter]
	for kind in ["wall","ice","ship"]:
		var img:=Image.create(32,32,false,Image.FORMAT_RGBA8)
		var base: Color=palette[0] if kind=="wall" else Color("355f70") if kind=="ice" else Color("44454c")
		for y in 32:
			for x in 32:
				var mortar:=y%8==0 or posmod(x+(16 if y/8%2 else 0),32)==0
				var seed_value:=posmod((x/8)*17+(y/8)*31,11)
				var c:=base.lightened(seed_value*.008)
				if mortar: c=base.darkened(.28)
				elif y%8==1: c=base.lightened(.14)
				elif y%8==7: c=base.darkened(.16)
				if kind=="ice":
					var crack:=posmod(x*3+y,29)<2 or posmod(x-y*2,37)<1
					c=base.lightened(.18+float(posmod(x+y*7,9))*.012) if crack else base.lightened(float(posmod(x/8+y/7,4))*.035)
				if kind=="ship":
					c=base.darkened(.25) if y%6==0 else base.lightened(.09 if y%6==1 else 0)
					if x%16==0 and y%6==3: c=Color("988870")
				img.set_pixel(x,y,c)
		_materials[kind]=ImageTexture.create_from_image(img)
func _textured_box(rect: Rect2,kind: String,tint: Color) -> void:
	if not _materials.has(kind):
		draw_rect(rect,tint)
		return
	var pts:=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	var uv:=PackedVector2Array()
	for point in pts: uv.append(point/96.0)
	draw_polygon(pts,PackedColorArray([tint.lightened(.4)]),uv,_materials[kind])
