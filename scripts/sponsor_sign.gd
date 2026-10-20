class_name SponsorSign
extends Node2D

var shown_hits := 0

var _font: SystemFont
var _swings: Dictionary = {}
var _kick := 0.0
var _kick_dir := 1.0
var _bits: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("sponsor")
	z_index = 4
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft JhengHei UI", "Microsoft JhengHei", "Microsoft YaHei"])


func _process(delta: float) -> void:
	if _kick > 0.0:
		_kick = maxf(_kick - delta * 3.2, 0.0)
	var kept: Array[Dictionary] = []
	for bit in _bits:
		bit["p"] = (bit["p"] as Vector2) + (bit["v"] as Vector2) * delta
		bit["v"] = (bit["v"] as Vector2) + Vector2(0, 980.0) * delta
		bit["life"] = float(bit["life"]) - delta
		if float(bit["life"]) > 0.0:
			kept.append(bit)
	_bits = kept
	queue_redraw()


func _physics_process(_delta: float) -> void:
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as Fighter
		if fighter == null or fighter.attack_active <= 0.0:
			continue
		if int(_swings.get(fighter.get_instance_id(), -1)) == fighter.swing_id:
			continue
		var gap := global_position - fighter.global_position
		if absf(gap.y) > 82.0 or absf(gap.x) > 88.0:
			continue
		if gap.x != 0.0 and signf(gap.x) != signf(fighter.facing):
			continue
		_swings[fighter.get_instance_id()] = fighter.swing_id
		_hit(fighter)


func celebrate_confetti() -> void:
	for _i in 14:
		_bits.append({
			"p": Vector2(randf_range(-8, 8), -8),
			"v": Vector2(randf_range(-240, 240), randf_range(-420, -90)),
			"c": Color(randf(), randf() * 0.55, 0.12),
			"life": 0.75,
		})


func _hit(fighter: Fighter) -> void:
	shown_hits += 1
	_kick = 1.0
	_kick_dir = fighter.facing if fighter.facing != 0.0 else 1.0
	var director := get_tree().get_first_node_in_group("match")
	if director == null or not director.has_method("note_sponsor"):
		return
	var effect := str(director.note_sponsor(fighter))
	if effect == "confetti":
		celebrate_confetti()


func _draw() -> void:
	var shake := Vector2(_kick_dir * 12.0 * _kick, 0)
	draw_rect(Rect2(Vector2(-50, -40) + shake, Vector2(100, 92)), Color(0.08, 0.08, 0.08))
	draw_rect(Rect2(Vector2(-44, -34) + shake, Vector2(88, 40)), Color(0.98, 0.84, 0.12))
	draw_rect(Rect2(Vector2(-44, 8) + shake, Vector2(88, 38)), Color.WHITE)
	if _font != null:
		draw_string(_font, Vector2(-26, -6) + shake, "贊助", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.08, 0.08, 0.08))
		draw_string(_font, Vector2(-22, 36) + shake, "%d/3" % shown_hits, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.08, 0.08, 0.08))
	for bit in _bits:
		var tint: Color = bit["c"]
		tint.a = clampf(float(bit["life"]) / 0.75, 0.0, 1.0)
		draw_rect(Rect2(bit["p"] as Vector2, Vector2(7, 7)), tint)
