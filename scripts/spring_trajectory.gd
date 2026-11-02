extends RefCounted
## One source for launch physics and the pre-deployment trajectory.
const GRAVITY := 1600.0
static func launch(mode: String, away: float) -> Vector3:
	return Vector3(0, 780, GRAVITY) if mode == "up" else Vector3(away * 260, 520, GRAVITY)
static func trace(origin: Vector2, mode: String, away: float, stage: Node) -> PackedVector2Array:
	var profile := launch(mode, away)
	var at := origin
	var vy := -profile.y
	var points := PackedVector2Array([at])
	for i in 240:
		vy += profile.z / 120.0
		at += Vector2(profile.x, vy) / 120.0
		if i % 5 == 0: points.append(at)
		var floor_y: float = stage.support_at(at.x, at.y)
		if vy > 0 and at.y >= floor_y:
			points.append(Vector2(at.x, floor_y))
			break
	return points
