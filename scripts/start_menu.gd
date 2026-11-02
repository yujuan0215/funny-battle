extends Control

const MenuUi := preload("res://scripts/menu_ui.gd")
const IconButton := preload("res://scripts/icon_button.gd")

var _stage: Control
var _play
var _tutorial
var _lab


func _ready() -> void:
	_stage = MenuUi.mount(self)
	var plaque := Panel.new()
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	plaque.offset_left = -360
	plaque.offset_right = 360
	plaque.offset_top = 104
	plaque.offset_bottom = 328
	plaque.add_theme_stylebox_override("panel", MenuUi.PixelSkin.box("panel"))
	_stage.add_child(plaque)
	var title := Label.new()
	title.name = "Title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = "FUNNY BATTLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -340
	title.offset_right = 340
	title.offset_top = 120
	title.offset_bottom = 236
	title.add_theme_font_override("font", MenuUi.font())
	title.add_theme_font_size_override("font_size", MenuUi.TITLE_SIZE)
	title.add_theme_color_override("font_color", MenuUi.TITLE)
	_stage.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "小小反擊"
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	subtitle.offset_left = -200
	subtitle.offset_right = 200
	subtitle.offset_top = 270
	subtitle.offset_bottom = 320
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", MenuUi.body_font())
	subtitle.add_theme_font_size_override("font_size", 36)
	subtitle.add_theme_color_override("font_color", MenuUi.INK)
	_stage.add_child(subtitle)

	_play = IconButton.new()
	_play.name = "Play"
	_play.shape = "play"
	_play.tooltip_text = "冒險地圖"
	_play.pressed.connect(_on_play)
	_stage.add_child(_play)

	_tutorial = IconButton.new()
	_tutorial.name = "Tutorial"
	_tutorial.shape = "help"
	_tutorial.tooltip_text = "玩法教學"
	_tutorial.font_size = MenuUi.BUTTON_TEXT_SIZE
	_tutorial.pressed.connect(_on_tutorial)
	_stage.add_child(_tutorial)
	_lab = IconButton.new()
	_lab.name = "TestLab"
	_lab.shape = "lab"
	_lab.tooltip_text = "試驗場"
	_lab.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/test_lab.tscn"))
	_stage.add_child(_lab)
	_stage.resized.connect(_layout)
	_layout()
	var buttons: Array[Button] = [_play, _tutorial, _lab]
	for i in buttons.size():
		buttons[i].focus_neighbor_left = buttons[posmod(i - 1, buttons.size())].get_path()
		buttons[i].focus_neighbor_right = buttons[(i + 1) % buttons.size()].get_path()
		buttons[i].focus_next = buttons[(i + 1) % buttons.size()].get_path()
		buttons[i].focus_previous = buttons[posmod(i - 1, buttons.size())].get_path()
	MenuUi.focus_when_visible.call_deferred(_play.get_instance_id())


func _layout() -> void:
	var view := _stage.size
	if view.x < 2.0 or view.y < 2.0:
		return
	var play_size := 140.0
	var tutorial_size := Vector2(94, 94)
	var gap := 40.0
	var row_width := play_size + gap + tutorial_size.x
	var left := (view.x - row_width) * 0.5
	var mid_y := view.y * 0.58
	_play.position = Vector2(left, mid_y - play_size * 0.5)
	_play.size = Vector2(play_size, play_size)
	_tutorial.position = Vector2(left + play_size + gap, mid_y - tutorial_size.y * 0.5)
	_tutorial.size = tutorial_size
	_lab.position = Vector2(view.x - 104, view.y - 104)
	_lab.size = Vector2(64, 64)


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/levels.tscn")


func _on_tutorial() -> void:
	get_tree().set_meta("arena_tutorial", true)
	get_tree().change_scene_to_file("res://scenes/spikes.tscn")
