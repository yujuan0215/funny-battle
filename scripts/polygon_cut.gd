class_name PolygonCut
extends RefCounted

## Split a convex polygon with a finite segment. Returns two polygons, or empty if the segment does not pass fully through.


static func split_by_segment(poly: PackedVector2Array, a: Vector2, b: Vector2) -> Array:
	if poly.size() < 3:
		return []
	if a.distance_to(b) < 1.0:
		return []
	if _intersection_count(poly, a, b) != 2:
		return []
	var positive := PackedVector2Array()
	var negative := PackedVector2Array()
	var direction := b - a
	var count := poly.size()
	for i in count:
		var current: Vector2 = poly[i]
		var nxt: Vector2 = poly[(i + 1) % count]
		var side_current := direction.cross(current - a)
		var side_next := direction.cross(nxt - a)
		if side_current >= -0.05:
			positive.append(current)
		if side_current <= 0.05:
			negative.append(current)
		if side_current * side_next < 0.0:
			var t := side_current / (side_current - side_next)
			var point := current.lerp(nxt, t)
			positive.append(point)
			negative.append(point)
	positive = _clean(positive)
	negative = _clean(negative)
	if positive.size() < 3 or negative.size() < 3:
		return []
	if area(positive) < 30.0 or area(negative) < 30.0:
		return []
	return [positive, negative]


static func area(poly: PackedVector2Array) -> float:
	var total := 0.0
	var count := poly.size()
	for i in count:
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % count]
		total += p.x * q.y - q.x * p.y
	return absf(total) * 0.5


static func _intersection_count(poly: PackedVector2Array, a: Vector2, b: Vector2) -> int:
	var hits: Array[Vector2] = []
	var count := poly.size()
	for i in count:
		var point: Variant = _segment_hit(poly[i], poly[(i + 1) % count], a, b)
		if point == null:
			continue
		var hit: Vector2 = point
		var unique := true
		for existing in hits:
			if existing.distance_to(hit) < 1.5:
				unique = false
				break
		if unique:
			hits.append(hit)
	return hits.size()


static func _segment_hit(p1: Vector2, p2: Vector2, a: Vector2, b: Vector2) -> Variant:
	var edge := p2 - p1
	var cut := b - a
	var denom := edge.cross(cut)
	if absf(denom) < 0.00001:
		return null
	var t := (a - p1).cross(cut) / denom
	var u := (a - p1).cross(edge) / denom
	if t >= -0.0001 and t <= 1.0001 and u >= -0.0001 and u <= 1.0001:
		return p1 + edge * clampf(t, 0.0, 1.0)
	return null


static func _clean(poly: PackedVector2Array) -> PackedVector2Array:
	var cleaned := PackedVector2Array()
	for point in poly:
		if cleaned.is_empty() or cleaned[cleaned.size() - 1].distance_to(point) > 0.75:
			cleaned.append(point)
	if cleaned.size() >= 2 and cleaned[0].distance_to(cleaned[cleaned.size() - 1]) <= 0.75:
		cleaned.remove_at(cleaned.size() - 1)
	return cleaned
