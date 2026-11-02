extends "res://upstream/level_two/duel.gd"
## Keep the remote level-two rules and menus; adapt only local campaign flow.

const Progress := preload("res://scripts/player_progress.gd")
const PixelSkin := preload("res://scripts/pixel_skin.gd")
const PixelHealth := preload("res://scripts/pixel_health.gd")
var progress_path := Progress.LAB_SAVE_PATH
var _result_checked := false
var _pixel_health: Array[ProgressBar] = []
var _health_snapshot := Vector4i(-1, -1, -1, -1)


func _ready() -> void:
	qte = false
	brawl = false
	campaign_level = 2
	super._ready()
	_pace = 0.5
	_apply_pace()
	for layer in get_children():
		if not layer is CanvasLayer:
			continue
		for control in layer.get_children():
			if control is Control:
				control.theme = MenuUi.theme()
				control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				for button: Button in control.find_children("*", "Button", true, false):
					button.add_theme_font_override("font", MenuUi.font())
					button.add_theme_font_size_override("font_size", 24)
					PixelSkin.button(button)
					for state in ["normal", "hover", "pressed", "disabled", "focus"]:
						button.add_theme_stylebox_override(state, PixelSkin.compact(state))
				for item in control.get_children():
					if item is HpStrip:
						item.hide()
						_build_pixel_health(control)
	_sync_pixel_health()


func _process(delta: float) -> void:
	super._process(delta)
	_sync_pixel_health()
	if not _result_checked and (left.out or right.out):
		_result_checked = true
		if right.out and not left.out:
			Progress.mark_cleared(2, progress_path)
			offer_success()


func _restart() -> void:
	_result_checked = false
	super._restart()


func _next_level() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/spikes_challenge.tscn")


func _back_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/test_lab.tscn")


func offer_success() -> void:
	super.offer_success()
	_next_button.show()
	_next_button.text = "尖刺試驗"
	_place_flow_buttons(_success_panel, [_next_button, _success_panel.get_node("SuccessMenu")])


func _build_pixel_health(root: Control) -> void:
	for side in 2:
		var column := VBoxContainer.new()
		column.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT if side == 0 else Control.PRESET_TOP_RIGHT)
		column.offset_left = 24 if side == 0 else -424
		column.offset_right = 424 if side == 0 else -24
		column.offset_top = 0
		column.add_theme_constant_override("separation", 0)
		root.add_child(column)
		var title := Label.new()
		title.text = "主角" if side == 0 else "BOSS"
		title.add_theme_font_size_override("font_size", 24)
		column.add_child(title)
		var bar := PixelHealth.new()
		bar.boss = side == 1
		bar.custom_minimum_size = Vector2(400, 36)
		column.add_child(bar)
		_pixel_health.append(bar)


func _sync_pixel_health() -> void:
	if _pixel_health.size() != 2:
		return
	var health := Vector4i(left.hp, left.hp_max, right.hp, right.hp_max)
	if health == _health_snapshot:
		return
	_health_snapshot = health
	for i in 2:
		_pixel_health[i].max_value = left.hp_max if i == 0 else right.hp_max
		_pixel_health[i].value = left.hp if i == 0 else right.hp


func _flow_button(text: String, _font_size: int) -> Button:
	var translated := {"Return to battle": "繼續", "Back to menu": "選關", "Next level": "尖刺試驗"}.get(text, text) as String
	var button: Button = super._flow_button(translated, 24)
	PixelSkin.button(button)
	button.focus_mode = Control.FOCUS_ALL
	return button


func _flow_panel(parent: Control, node_name: String, heading: String) -> Control:
	var translated := "暫停" if heading == "Paused" else "勝利" if heading == "Success" else heading
	var panel: Control = super._flow_panel(parent, node_name, translated)
	for child in panel.get_children():
		if child is ColorRect and child.size == Vector2(480, 360):
			child.hide()
	var frame := Panel.new()
	frame.position = Vector2(400, 180)
	frame.size = Vector2(480, 360)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", PixelSkin.box("panel"))
	panel.add_child(frame)
	panel.move_child(frame, 1)
	return panel
