extends Control

const MenuUi := preload("res://scripts/menu_ui.gd")
const Icons := preload("res://scripts/arena_icons.gd")
const Thumbnail := preload("res://scripts/chapter_thumbnail.gd")
const Catalog := preload("res://scripts/campaign_catalog.gd")
const Progress := preload("res://scripts/player_progress.gd")
const PixelSkin := preload("res://scripts/pixel_skin.gd")
const Route := preload("res://scripts/campaign_route.gd")
const MapStop := preload("res://scripts/map_stop.gd")
const LEVEL_ONE := "res://scenes/spikes.tscn"
const LEVEL_TWO := "res://scenes/level_two.tscn"
const LEVEL_THREE := "res://scenes/spikes_challenge.tscn"
@export var testing := false
var progress_path := ""
var _stage: Control
var _levels: Array[Button] = []
var _overlay: Control
var _grid: Control
var _back: Button
var _lab: Button
var _return_focus: Control


func _label(text: String, size: int, color := MenuUi.INK) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", MenuUi.body_font())
	label.add_theme_font_size_override("font_size", MenuUi.pixel_size(size))
	label.add_theme_color_override("font_color", color)
	return label


func _skin(_fill: Color, _border := PixelSkin.BRASS) -> StyleBoxTexture:
	return PixelSkin.box("panel")


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(64, 48)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", MenuUi.body_font())
	button.add_theme_font_size_override("font_size", 24)
	PixelSkin.button(button)
	button.pressed.connect(action)
	return button


func _ready() -> void:
	if progress_path.is_empty():
		progress_path = Progress.LAB_SAVE_PATH if testing else Progress.SAVE_PATH
	_stage = MenuUi.mount(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 28)
	_stage.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	margin.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var title := _label("實驗關卡" if testing else "冒險地圖", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	if not testing:
		_lab = _button("", func() -> void: get_tree().change_scene_to_file("res://scenes/test_lab.tscn"))
		_lab.name = "TestLab"
		_lab.text = ""
		_lab.tooltip_text = "試驗場"
		_add_icon(_lab, "flask")
		header.add_child(_lab)
	_back = _button("返回", _on_back)
	_back.name = "Back"
	_back.tooltip_text = "返回"
	header.add_child(_back)
	var center: Control = CenterContainer.new() if testing else Control.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(center)
	if testing:
		_grid = GridContainer.new()
		(_grid as GridContainer).columns = 3
		_grid.add_theme_constant_override("h_separation", 24)
		_grid.add_theme_constant_override("v_separation", 24)
	else:
		_grid = Route.new()
		_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(_grid)
	var chapters: Array = Catalog.CHAPTERS
	if testing:
		chapters = [
			{"id": 2, "name": "對打試驗", "theme": "clock", "tools": [0, 1, 2], "playable": true, "scene": LEVEL_TWO},
			{"id": 3, "name": "尖刺試驗", "theme": "forge", "tools": [0, 1, 2], "playable": true, "scene": LEVEL_THREE},
			{"id":101,"name":"動作Ⅰ · 斷柱前哨","theme":"forest","tools":[0,1],"playable":true,"scene":"res://scenes/action_trial_1.tscn"},
			{"id":102,"name":"動作Ⅱ · 懸橋機關","theme":"valley","tools":[0,1],"playable":true,"scene":"res://scenes/action_trial_2.tscn"},
			{"id":103,"name":"動作Ⅲ · 熔爐核心","theme":"forge","tools":[0,1],"playable":true,"scene":"res://scenes/action_trial_3.tscn"},
			{"id":200,"name":"舊版場地 · 3–6","theme":"tower","tools":[1],"playable":true,"scene":"res://scenes/legacy_chapters.tscn"},
		]
	for chapter in chapters:
		_add_chapter(chapter)
	var footer := _label("原型對打　即時動作　舊版場地" if testing else "借力反擊", 24, PixelSkin.PAPER)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(footer)
	_stage.resized.connect(_layout)
	_grid.resized.connect(_layout)
	_layout()
	MenuUi.focus_when_visible.call_deferred(_levels[0].get_instance_id())


func _add_icon(button: Button, kind: String) -> void:
	var icon := Icons.new()
	icon.set_symbols([kind])
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.offset_left = -14
	icon.offset_right = 14
	icon.offset_top = -14
	icon.offset_bottom = 14
	button.add_child(icon)


func _add_chapter(chapter: Dictionary) -> void:
	var number := int(chapter["id"])
	if not testing:
		var landmark := MapStop.new()
		landmark.chapter = chapter
		landmark.name = "Level%d" % number
		landmark.cleared = Progress.is_cleared(number, progress_path)
		landmark.set_meta("playable", bool(chapter["playable"]))
		landmark.tooltip_text = chapter["name"] + ("" if chapter["playable"] else " · 關卡藍圖")
		landmark.pressed.connect(func() -> void: _select(chapter))
		_grid.add_child(landmark)
		_levels.append(landmark)
		return
	var button := _button("", func() -> void: _select(chapter))
	button.name = "Level%d" % number
	button.set_meta("playable", bool(chapter["playable"]))
	button.tooltip_text = chapter["name"] if chapter["playable"] else chapter["name"] + " · 關卡藍圖"
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 12
	column.offset_top = 12
	column.offset_right = -12
	column.offset_bottom = -12
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	var art := Thumbnail.new()
	art.environment = chapter["theme"]
	art.custom_minimum_size.y = 92
	column.add_child(art)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var label := _label(("" if testing else "%02d  " % number) + str(chapter["name"]), 22)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	var status := Icons.new()
	status.glyph_size = 23
	status.set_symbols(["play" if chapter["playable"] else "lock"])
	heading.add_child(status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var loadout := Icons.new()
	loadout.glyph_size = 22
	var symbols: Array = []
	for tool in chapter["tools"]:
		symbols.append(Catalog.TOOL_ICONS[tool])
	loadout.set_symbols(symbols)
	row.add_child(loadout)
	var badge_number := number - 100 if number in [101, 102, 103] else number
	var badge_path := "user://action_trial_progress.json" if number in [101, 102, 103] else progress_path
	if chapter["playable"] and Progress.is_cleared(badge_number, badge_path):
		var cleared := _label("✓", 20, Color("9bc991"))
		cleared.name = "ClearedBadge"
		button.add_child(cleared)
		cleared.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		cleared.offset_left = -34
		cleared.offset_top = 14
	_grid.add_child(button)
	_levels.append(button)


func _layout() -> void:
	var width := _stage.size.x
	if testing:
		for button in _levels:
			button.custom_minimum_size = Vector2(clampf((width - 180) / 3 - 24, 230, 340), 190)
	else:
		for i in _levels.size():
			var button := _levels[i]
			button.size = Vector2(216, 174)
			button.position = (Route.STOPS[i] * _grid.size - Vector2(108, 44)).round()
			button.focus_neighbor_left = _levels[maxi(i - 1, 0)].get_path()
			button.focus_neighbor_right = _levels[mini(i + 1, _levels.size() - 1)].get_path()
			button.focus_next = _levels[(i + 1) % _levels.size()].get_path()
			button.focus_previous = _levels[posmod(i - 1, _levels.size())].get_path()


func _select(chapter: Dictionary) -> void:
	if chapter["playable"]:
		get_tree().change_scene_to_file(chapter["scene"])
	else:
		_show_blueprint(chapter)


func _show_blueprint(chapter: Dictionary) -> void:
	_return_focus = get_viewport().gui_get_focus_owner()
	for button in _levels + [_back, _lab]:
		if is_instance_valid(button):
			button.focus_mode = Control.FOCUS_NONE
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = PanelContainer.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_theme_stylebox_override("panel", _skin(Color(0.05, 0.1, 0.13, 0.97), Color("79967c")))
	_stage.add_child(_overlay)
	var center := CenterContainer.new()
	_overlay.add_child(center)
	var stack := VBoxContainer.new()
	stack.custom_minimum_size.x = minf(680, _stage.size.x - 64)
	stack.add_theme_constant_override("separation", 12)
	center.add_child(stack)
	var art := Thumbnail.new()
	art.environment = chapter["theme"]
	art.custom_minimum_size.y = 210
	stack.add_child(art)
	stack.add_child(_label(chapter["name"] + " · " + chapter["boss"], 28))
	stack.add_child(_label(chapter["focus"], 20, Color("a3d0a5")))
	var detail := _label(chapter["terrain"] + "\n" + chapter["counter"], 19)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(detail)
	stack.add_child(_label("規劃中", 17, Color("b7a983")))
	var back := _button("返回", _close_blueprint)
	stack.add_child(back)
	for direction in ["left", "right", "top", "bottom"]:
		back.set("focus_neighbor_" + direction, back.get_path())
	back.focus_next = back.get_path()
	back.focus_previous = back.get_path()
	MenuUi.focus_when_visible.call_deferred(back.get_instance_id())


func _close_blueprint() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
	for button in _levels + [_back, _lab]:
		if is_instance_valid(button):
			button.focus_mode = Control.FOCUS_ALL
	if is_instance_valid(_return_focus):
		MenuUi.focus_when_visible.call_deferred(_return_focus.get_instance_id())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(_overlay):
			_close_blueprint()
		else:
			_on_back()
		get_viewport().set_input_as_handled()


func _on_level_one() -> void:
	get_tree().change_scene_to_file(LEVEL_ONE)


func _on_level_two() -> void:
	get_tree().change_scene_to_file(LEVEL_TWO)


func _on_level_three() -> void:
	get_tree().change_scene_to_file(LEVEL_THREE)


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/levels.tscn" if testing else "res://scenes/start.tscn")
