class_name SpringItem
extends StageItem

func _ready() -> void:
	hover_height = 12.0
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(54, 22)
	shape_node.shape = rect
	add_child(shape_node)
	super()
	z_index = 3


func _process(_delta: float) -> void:
	queue_redraw()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if consumed or not is_inside_tree():
		return
	for body in get_overlapping_bodies():
		if body is Fighter:
			_consider(body as Fighter)
			if consumed:
				return


func _consider(fighter: Fighter) -> void:
	if not fighter.alive:
		return
	var rising := not fighter.is_on_floor() and fighter.velocity.y < 60.0 and fighter.hitstun <= 0.0 and fighter.slip_time <= 0.0
	if rising:
		return
	var detail := fighter.state_label()
	var silly := fighter.is_on_floor() and fighter.hitstun <= 0.0 and fighter.slip_time <= 0.0 and fighter.launch_time <= 0.0
	consumed = true
	monitoring = false
	if silly:
		fighter.launch(Vector2(fighter.facing * 90.0, -640.0), "spring")
	else:
		var speed := maxf(fighter.velocity.y, absf(fighter.velocity.x))
		var power := clampf(speed / 900.0, 0.25, 1.0)
		var dir := signf(fighter.velocity.x)
		if dir == 0.0:
			dir = fighter.facing
		fighter.launch(Vector2(dir * lerpf(420.0, 1100.0, power), -lerpf(620.0, 1240.0, power)), "spring")
	var director := get_tree().get_first_node_in_group("match")
	if director != null and director.has_method("host_record"):
		director.host_record("spring", fighter, "silly" if silly else "hit", detail)
	queue_free()


func _draw() -> void:
	var ink := Color(0.08, 0.08, 0.08)
	draw_line(Vector2(-22, 8), Vector2(-11, -8), ink, 4.0)
	draw_line(Vector2(-11, -8), Vector2(0, 8), ink, 4.0)
	draw_line(Vector2(0, 8), Vector2(11, -8), ink, 4.0)
	draw_line(Vector2(11, -8), Vector2(22, 8), ink, 4.0)
