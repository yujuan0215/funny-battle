extends Button

const MenuUi := preload("res://scripts/menu_ui.gd")
const ArenaIcons := preload("res://scripts/arena_icons.gd")
var shape := "play"
var caption := ""
var font_size := 36


func _ready() -> void:
	MenuUi.PixelSkin.button(self)
	add_theme_font_override("font", MenuUi.font())
	add_theme_font_size_override("font_size", font_size)
	text = caption
	focus_mode = Control.FOCUS_ALL
	for event in [mouse_entered, mouse_exited, button_down, button_up, focus_entered, focus_exited]:
		event.connect(queue_redraw)
	resized.connect(queue_redraw)
	if shape == "lock":
		disabled = true


func _draw() -> void:
	if not caption.is_empty():
		return
	var symbol := {"help": "book", "lab": "flask", "tutorial": "book", "level": "levels"}.get(shape, shape) as String
	var center := size * 0.5 + Vector2(0, 2 if button_pressed else -2)
	ArenaIcons.paint(self, symbol, center, minf(size.x, size.y) * 0.52, MenuUi.INK if not disabled else MenuUi.LOCKED)
