class_name BananaItem
extends StageItem

const SLIP_SPEED := 230.0

var _whiffed: Dictionary = {}


func _ready() -> void:
	hover_height = 10.0
	super()


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
	if not fighter.alive or not fighter.is_on_floor():
		return
	var fast := absf(fighter.velocity.x) >= SLIP_SPEED or fighter.hitstun > 0.0
	if not fast:
		var id := fighter.get_instance_id()
		if not _whiffed.has(id):
			_whiffed[id] = true
			_tell(fighter, "whiff", fighter.state_label())
		return
	var direction := signf(fighter.velocity.x)
	if direction == 0.0:
		direction = fighter.facing
	var detail := fighter.state_label()
	fighter.slip(direction)
	consumed = true
	_tell(fighter, "hit", detail)
	queue_free()


func _tell(fighter: Fighter, style: String, detail: String) -> void:
	var director := get_tree().get_first_node_in_group("match")
	if director != null and director.has_method("host_record"):
		director.host_record("slip", fighter, style, detail)


func _draw() -> void:
	var peel := PackedVector2Array([
		Vector2(-22, 2), Vector2(20, -6), Vector2(16, 8), Vector2(-18, 12)
	])
	draw_colored_polygon(peel, Color(0.98, 0.84, 0.12))
	draw_polyline(PackedVector2Array([peel[0], peel[1], peel[2], peel[3], peel[0]]), Color(0.08, 0.08, 0.08), 3.0, true)
	draw_line(Vector2(18, -4), Vector2(26, -12), Color(0.35, 0.22, 0.08), 3.0)
