extends ProgressBar
## HP changes instantly; the pale damage trail catches up without delaying the result.

const PixelSkin := preload("res://scripts/pixel_skin.gd")
var boss := false
var _trail := -1.0
var _delay := 0.0


func _ready() -> void:
	show_percentage = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for part in ["background", "fill"]:
		add_theme_stylebox_override(part, StyleBoxEmpty.new())
	value_changed.connect(_changed)
	resized.connect(queue_redraw)
	_trail = value
	set_process(false)


func _changed(current: float) -> void:
	if _trail < current or _trail < 0 or _trail > max_value:
		_trail = current
	_delay = 0.25
	set_process(_trail > current)
	queue_redraw()


func _process(delta: float) -> void:
	_delay -= delta
	if _delay <= 0:
		_trail = move_toward(_trail, value, delta * max_value * 1.8)
		queue_redraw()
		if is_equal_approx(_trail, value):
			set_process(false)


func _draw() -> void:
	draw_style_box(PixelSkin.box("panel"), Rect2(Vector2.ZERO, size))
	var inside := Rect2(12, 12, maxf(0, size.x - 24), maxf(0, size.y - 28))
	draw_rect(inside, PixelSkin.OUTLINE)
	var color := PixelSkin.DANGER if boss else PixelSkin.HERO
	var trail_width := floorf(inside.size.x * clampf(_trail / maxf(max_value, 1), 0, 1))
	draw_rect(Rect2(inside.position, Vector2(trail_width, inside.size.y)), PixelSkin.PAPER)
	var width := floorf(inside.size.x * value / maxf(max_value, 1))
	draw_rect(Rect2(inside.position, Vector2(width, inside.size.y)), color)
	draw_rect(Rect2(inside.position, Vector2(width, 2)), color.lightened(0.3))
	var units := mini(int(max_value), 30)
	for i in range(1, units):
		var x := inside.position.x + floorf(inside.size.x * i / units)
		draw_rect(Rect2(x, inside.position.y, 2, inside.size.y), PixelSkin.OUTLINE)
