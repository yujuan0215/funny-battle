class_name BombItem
extends StageItem

var fuse := 0.9
var boom_left := -1.0

const RADIUS := 165.0


func _ready() -> void:
	hover_height = 16.0
	super()
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if consumed:
		return
	fuse -= delta
	if fuse <= 0.0:
		explode()


func _process(delta: float) -> void:
	queue_redraw()
	if boom_left < 0.0:
		return
	boom_left -= delta
	if boom_left <= 0.0:
		queue_free()


func _draw() -> void:
	if boom_left >= 0.0:
		var t := 1.0 - boom_left / 0.18
		draw_arc(Vector2.ZERO, lerpf(18.0, 96.0, t), 0.0, TAU, 36, Color(0.9, 0.16, 0.1, 1.0 - t), 7.0)
		return
	var pulse := 1.0 + 0.14 * sin(fuse * 36.0)
	draw_circle(Vector2.ZERO, 18.0 * pulse, Color(0.08, 0.08, 0.08))
	var hot := Color(0.92, 0.18, 0.12).lerp(Color(1, 0.85, 0.2), clampf(1.0 - fuse / 0.9, 0.0, 1.0))
	draw_circle(Vector2.ZERO, 13.0 * pulse, hot)
	draw_line(Vector2(0, -14), Vector2(7, -26), Color(0.08, 0.08, 0.08), 3.0)


func _on_body(body: Node2D) -> void:
	if body is Fighter:
		explode()


func explode() -> void:
	if consumed:
		return
	consumed = true
	monitoring = false
	riding = false
	var focus: Fighter = null
	var style := "whiff"
	var detail := "旁邊沒人"
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as Fighter
		if fighter == null or not fighter.alive:
			continue
		var gap := fighter.global_position - global_position
		if gap.length() > RADIUS:
			continue
		var state := fighter.state_label()
		var away := signf(gap.x)
		if away == 0.0:
			away = -1.0 if fighter.display_name == "認真" else 1.0
		if fighter.attack_active > 0.0:
			style = "eat"
			focus = fighter
			detail = state
			fighter.receive_hit(22.0, 40.0, 1180.0, 11.0, -fighter.facing, true, "bomb")
		else:
			if style != "eat":
				style = "hit"
				focus = fighter
				detail = state
			var angle := lerpf(76.0, 46.0, clampf(absf(gap.x) / RADIUS, 0.0, 1.0))
			fighter.receive_hit(20.0, angle, 1040.0, 10.0, away, true, "bomb")
	var director := get_tree().get_first_node_in_group("match")
	if director != null and director.has_method("host_record"):
		director.host_record("bomb", focus, style, detail)
	if director != null and director.has_method("add_shake"):
		director.add_shake(18.0)
	boom_left = 0.18
	set_physics_process(false)
