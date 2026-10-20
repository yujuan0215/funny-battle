class_name Platform
extends StaticBody2D

const REGROW_TIME := 4.0
const FRAGMENT_SCENE := preload("res://scenes/fragment.tscn")

@export var polygon_points: PackedVector2Array = PackedVector2Array()

var original_polygon := PackedVector2Array()
var current_polygon := PackedVector2Array()
var regrow_left := 0.0

@onready var fill: Polygon2D = $Fill
@onready var outline: Line2D = $Outline
@onready var collision_poly: CollisionPolygon2D = $CollisionPolygon2D


func _ready() -> void:
	add_to_group("platforms")
	collision_layer = 1
	collision_mask = 0
	if polygon_points.size() >= 3:
		collision_poly.polygon = polygon_points
	original_polygon = collision_poly.polygon
	current_polygon = original_polygon
	_apply_polygon(current_polygon)


func _physics_process(delta: float) -> void:
	if regrow_left <= 0.0:
		return
	regrow_left -= delta
	if regrow_left <= 0.0:
		current_polygon = original_polygon
		_apply_polygon(current_polygon)


func try_cut(world_a: Vector2, world_b: Vector2) -> bool:
	var parts: Array = PolygonCut.split_by_segment(current_polygon, to_local(world_a), to_local(world_b))
	if parts.is_empty():
		return false
	var first: PackedVector2Array = parts[0]
	var second: PackedVector2Array = parts[1]
	var first_area := PolygonCut.area(first)
	var second_area := PolygonCut.area(second)
	# Slivers are hard to read. A real gag needs a chunk you can stand on.
	if minf(first_area, second_area) < 900.0:
		return false
	var small := first if first_area < second_area else second
	var large := second if first_area < second_area else first
	if absf(first_area - second_area) / maxf(first_area, second_area) < 0.08:
		var origin := _centroid(current_polygon)
		if _centroid(first).distance_to(origin) > _centroid(second).distance_to(origin):
			small = first
			large = second
		else:
			small = second
			large = first
	current_polygon = large
	_apply_polygon(large)
	regrow_left = REGROW_TIME
	_spawn_fragment(small)
	_take_items(small)
	if _blame_fighters(small) == 0:
		var director := get_tree().get_first_node_in_group("match")
		if director != null and director.has_method("host_record"):
			director.host_record("cut", null, "whiff", "切到空平台")
	return true


func top_world(local_x: float) -> Vector2:
	return to_global(Vector2(local_x, _top_y(local_x)))


func snap_placement(world_point: Vector2) -> Variant:
	var local := to_local(world_point)
	var bounds := _bounds(current_polygon)
	if local.x < bounds.position.x + 10.0 or local.x > bounds.end.x - 10.0:
		return null
	var top := _top_y(local.x)
	if local.y < top - 64.0 or local.y > top + 90.0:
		return null
	return to_global(Vector2(local.x, top))


func _spawn_fragment(poly: PackedVector2Array) -> void:
	var root := get_tree().get_first_node_in_group("fragments_root")
	if root == null:
		return
	var fragment := FRAGMENT_SCENE.instantiate() as StageFragment
	root.add_child(fragment)
	fragment.setup(poly, global_transform)


func _blame_fighters(removed: PackedVector2Array) -> int:
	var count := 0
	var director := get_tree().get_first_node_in_group("match")
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as Fighter
		if fighter == null or not fighter.alive:
			continue
		var feet := to_local(fighter.global_position + Vector2(0, 36.0))
		if not Geometry2D.is_point_in_polygon(feet, removed) and not Geometry2D.is_point_in_polygon(feet + Vector2(0, 16.0), removed):
			continue
		count += 1
		var falling := fighter.hitstun > 0.0 or fighter.slip_time > 0.0 or fighter.launch_time > 0.0 or not fighter.is_on_floor()
		if falling:
			fighter.last_cause = "cut"
			fighter.velocity.y = maxf(fighter.velocity.y, 80.0)
			fighter.mark_host_fault(4.2, "cut")
			if director != null and director.has_method("host_record"):
				director.host_record("cut", fighter, "hit", "腳下的地沒了")
		else:
			fighter.hop_onto(_rescue_feet(feet.x))
			if director != null and director.has_method("host_record"):
				director.host_record("cut", fighter, "silly", "好好地站著")
	return count


func _rescue_feet(local_x: float) -> Vector2:
	var bounds := _bounds(current_polygon)
	var x := clampf(local_x, bounds.position.x + 14.0, bounds.end.x - 14.0)
	return to_global(Vector2(x, _top_y(x)))


func _take_items(removed: PackedVector2Array) -> void:
	var root := get_tree().get_first_node_in_group("fragments_root")
	if root == null or root.get_child_count() == 0:
		return
	var fragment := root.get_child(root.get_child_count() - 1)
	for node in get_tree().get_nodes_in_group("items"):
		if not (node is StageItem) or node.consumed:
			continue
		var item := node as StageItem
		var probe := to_local(item.global_position + Vector2(0, item.hover_height))
		if Geometry2D.is_point_in_polygon(probe, removed):
			item.attach_to(fragment)


func _apply_polygon(poly: PackedVector2Array) -> void:
	current_polygon = poly
	collision_poly.polygon = poly
	fill.polygon = poly
	var points := poly.duplicate()
	if points.size() > 0:
		points.append(points[0])
	outline.points = points


func _top_y(x: float) -> float:
	var best := 100000.0
	var found := false
	var count := current_polygon.size()
	for i in count:
		var p: Vector2 = current_polygon[i]
		var q: Vector2 = current_polygon[(i + 1) % count]
		if absf(q.x - p.x) < 0.001:
			continue
		var min_x := minf(p.x, q.x)
		var max_x := maxf(p.x, q.x)
		if x < min_x - 0.01 or x > max_x + 0.01:
			continue
		var t := clampf((x - p.x) / (q.x - p.x), 0.0, 1.0)
		var y := p.y + (q.y - p.y) * t
		if not found or y < best:
			best = y
			found = true
	return best if found else 0.0


func _bounds(poly: PackedVector2Array) -> Rect2:
	var rect := Rect2(poly[0], Vector2.ZERO)
	for point in poly:
		rect = rect.expand(point)
	return rect


func _centroid(poly: PackedVector2Array) -> Vector2:
	var total := Vector2.ZERO
	for point in poly:
		total += point
	return total / float(poly.size())
