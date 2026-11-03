extends CanvasLayer
## Player-facing arena UI. The battle sends updates; the HUD never reads actor state.

signal start_requested
signal retry_requested
signal leave_requested
signal pause_requested
signal tool_selected(index: int)
signal pace_requested
signal next_requested
signal mute_requested

const MenuUi := preload("res://scripts/menu_ui.gd")
const Icons := preload("res://scripts/arena_icons.gd")
const PixelSkin := preload("res://scripts/pixel_skin.gd")
const Health := preload("res://scripts/pixel_health.gd")
const CYAN := PixelSkin.HERO
const CORAL := PixelSkin.DANGER
const PAPER := PixelSkin.PAPER
const MUTED := PixelSkin.MUTED
const TOOLS := ["香蕉", "彈簧", "時停", "沙袋", "磁鐵"]
const TOOL_SYMBOLS := ["banana", "spring", "clock", "sandbag", "magnet"]
const USES := ["滑倒・橋邊陷阱", "拉開距離・落地開火", "暫停對手・爭取蓄力", "止滑・擋住一次衝撞", "吸引鐵箱・撞停車頭"]

var root: Control
var objective: Label
var win_conditions: Control
var intent: Label
var feedback: Label
var hero_bar: ProgressBar
var boss_bar: ProgressBar
var hero_health: Label
var boss_health: Label
var tool_buttons: Array[Button] = []
var overlay: Control
var modal_title: Label
var modal_reason: Label
var modal_detail: Label
var primary: Button
var retry: Button
var selected := 0
var tool_ids: Array = [0, 1, 2]
var next_button: Button
var _name_labels: Array[Label] = []
var _rule_labels: Array[Label] = []
var _rule_icons: Array[Control] = []
var _key_labels: Array[Label] = []
var pace_button: Button
var intent_timer: Label
var intent_bar: ProgressBar
var _notice_left := 0.0
var _tool_snapshot := ""
var _modal_panel: PanelContainer
var _intent_icons: Control
var _feedback_icons: Control
var _result_icon: Control
var _rules: HBoxContainer
var _tool_icons: Array[Control] = []
var _cool_labels: Array[Label] = []
var _controls: HBoxContainer
var _modal_buttons: HBoxContainer
var _game_buttons: Array[Button] = []
var _last_cooldown: Array[float] = [0.0, 0.0, 0.0]
var rescue_icon: Control
var _timing_opening := -1
var _selected_skin_index := -1


func _ready() -> void:
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = MenuUi.theme()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(root)
	_build_header()
	_build_tools()
	_build_modal()
	_game_buttons.assign(tool_buttons)
	# Focus remains in the open modal; hidden battle controls cannot consume Enter.
	for button in root.find_children("*", "Button", true, false):
		if not overlay.is_ancestor_of(button) and button not in _game_buttons:
			_game_buttons.append(button)
	get_viewport().size_changed.connect(_fit_modal)
	_fit_modal()


func _style(_fill: Color, _border: Color = PixelSkin.BRASS) -> StyleBoxTexture:
	return PixelSkin.box("panel")


func _label(text: String, size: int, color: Color = PAPER) -> Label:
	var node := Label.new()
	node.text = text
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", MenuUi.pixel_size(size))
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.05, 0.9))
	node.add_theme_constant_override("shadow_offset_y", 2)
	return node


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.text = text
	button.custom_minimum_size = Vector2(0, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelSkin.button(button)
	button.pressed.connect(action)
	return button


func _icons(items: Array, glyph: float = 32.0) -> Control:
	var icon := Icons.new()
	icon.glyph_size = maxf(24, roundf(glyph / 12) * 12)
	icon.ink = PAPER
	icon.set_symbols(items)
	return icon


func _icon_button(symbol: String, tooltip: String, action: Callable) -> Button:
	var button := _button("", action)
	button.custom_minimum_size = Vector2(64, 56)
	button.tooltip_text = tooltip
	var icon := _icons([symbol], 26)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.offset_left = -16
	icon.offset_top = -16
	icon.offset_right = 16
	icon.offset_bottom = 16
	button.add_child(icon)
	return button


func _build_header() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 28)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(stack)
	var health := HBoxContainer.new()
	health.add_theme_constant_override("separation", 0)
	stack.add_child(health)
	for role in 2:
		if role == 1:
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			health.add_child(spacer)
		var box := VBoxContainer.new()
		box.custom_minimum_size.x = 240 if role == 0 else 420
		box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if role == 0 else Control.SIZE_SHRINK_END
		health.add_child(box)
		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation", 10)
		box.add_child(heading)
		var mark := _icons(["heart" if role == 0 else "boss"], 24)
		mark.ink = CYAN if role == 0 else CORAL
		heading.add_child(mark)
		var title := _label("", 20, PAPER)
		heading.add_child(title)
		if role == 0:
			rescue_icon = _icons(["shield"], 23)
			rescue_icon.tooltip_text = "安全繩 · 第一次落橋會拉回，不恢復血量"
			rescue_icon.mouse_filter = Control.MOUSE_FILTER_PASS
			heading.add_child(rescue_icon)
			rescue_icon.hide()
		var bar := Health.new()
		bar.boss = role == 1
		bar.show_percentage = false
		bar.custom_minimum_size.y = 44
		box.add_child(bar)
		if role == 0:
			hero_health = title
			hero_bar = bar
		else:
			boss_health = title
			boss_bar = bar
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 18)
	stack.add_child(line)
	var goal := HBoxContainer.new()
	goal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(goal)
	objective = _label("擊敗 BOSS", 17, MUTED)
	goal.add_child(objective)
	var conditions := _icons(["emptyheart", "or", "spikes"], 25)
	win_conditions = conditions
	conditions.tooltip_text = "勝利：BOSS 血量歸零，或落入尖刺。主角必須存活。"
	conditions.mouse_filter = Control.MOUSE_FILTER_PASS
	goal.add_child(conditions)
	conditions.hide()
	pace_button = _button("×1.0", func() -> void: pace_requested.emit())
	pace_button.custom_minimum_size = Vector2(78, 46)
	pace_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	pace_button.tooltip_text = "切換 0.5×／1× · 按住 Space 進一步慢速"
	line.add_child(pace_button)
	var mute := _icon_button("sound", "音效開關 · M", func() -> void: mute_requested.emit())
	mute.size_flags_horizontal = Control.SIZE_SHRINK_END
	line.add_child(mute)
	var pause := _icon_button("pause", "暫停 · Esc", func() -> void: pause_requested.emit())
	pause.size_flags_horizontal = Control.SIZE_SHRINK_END
	line.add_child(pause)
	var intent_center := CenterContainer.new()
	intent_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	intent_center.offset_left = -230
	intent_center.offset_right = 230
	intent_center.offset_top = 56
	intent_center.offset_bottom = 96
	intent_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(intent_center)
	var intent_row := HBoxContainer.new()
	intent_row.add_theme_constant_override("separation", 10)
	intent_center.add_child(intent_row)
	_intent_icons = _icons(["boss"], 27)
	_intent_icons.ink = CORAL
	intent_row.add_child(_intent_icons)
	intent = _label("", 19, CORAL)
	intent_row.add_child(intent)
	intent_timer = _label("", 18, PAPER)
	intent_row.add_child(intent_timer)
	var timing_center := CenterContainer.new()
	timing_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	timing_center.offset_left = -110
	timing_center.offset_right = 110
	timing_center.offset_top = 102
	timing_center.offset_bottom = 110
	timing_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(timing_center)
	intent_bar = ProgressBar.new()
	intent_bar.show_percentage = false
	intent_bar.max_value = 1
	intent_bar.custom_minimum_size = Vector2(180, 5)
	var track := StyleBoxFlat.new()
	track.bg_color = PixelSkin.OUTLINE
	intent_bar.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = CORAL
	intent_bar.add_theme_stylebox_override("fill", fill)
	timing_center.add_child(intent_bar)
	intent_bar.hide()
	var feedback_center := CenterContainer.new()
	feedback_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	feedback_center.offset_left = -260
	feedback_center.offset_right = 260
	feedback_center.offset_top = 180
	feedback_center.offset_bottom = 216
	feedback_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(feedback_center)
	var feedback_row := HBoxContainer.new()
	feedback_row.add_theme_constant_override("separation", 10)
	feedback_center.add_child(feedback_row)
	_feedback_icons = _icons([], 27)
	feedback_row.add_child(_feedback_icons)
	feedback = _label("", 19, CYAN)
	feedback_row.add_child(feedback)


func _build_tools() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 14)
	root.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)
	var center := CenterContainer.new()
	stack.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)
	for i in 3:
		var button := _button("", func() -> void: tool_selected.emit(int(tool_ids[i])))
		button.name = "Tool%d" % (i + 1)
		button.custom_minimum_size = Vector2(128, 112)
		button.tooltip_text = "%d · %s\n%s" % [i + 1, TOOLS[i], USES[i]]
		var icon := _icons([["banana"], ["spring"], ["clock"]][i], 38)
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon.offset_left = -24
		icon.offset_right = 24
		icon.offset_top = -32
		icon.offset_bottom = 16
		button.add_child(icon)
		_tool_icons.append(icon)
		var key := _label(str(i + 1), 15, MUTED)
		key.position = Vector2(10, 6)
		button.add_child(key)
		_key_labels.append(key)
		var name_label := _label(TOOLS[i], 17)
		name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		name_label.offset_top = -40
		name_label.offset_bottom = -8
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_child(name_label)
		_name_labels.append(name_label)
		var cool_label := _label("", 15, CORAL)
		cool_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		cool_label.offset_left = -56
		cool_label.offset_top = 6
		cool_label.offset_right = -6
		cool_label.offset_bottom = 36
		cool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.add_child(cool_label)
		_cool_labels.append(cool_label)
		row.add_child(button)
		tool_buttons.append(button)


func _control_legend() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_icons(["mouse"], 21))
	row.add_child(_label("部署", 16, MUTED))
	row.add_child(_label("   Space 慢速", 16, PAPER))
	row.add_child(_icons(["clock"], 21))
	return row


func _build_modal() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.04, 0.07, 0.76)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	_modal_panel = PanelContainer.new()
	_modal_panel.add_theme_stylebox_override("panel", _style(Color(0.07, 0.1, 0.15), Color(0.25, 0.45, 0.49)))
	center.add_child(_modal_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	_modal_panel.add_child(stack)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 16)
	stack.add_child(title_row)
	_result_icon = _icons(["play"], 44)
	title_row.add_child(_result_icon)
	modal_title = _label("", 32)
	title_row.add_child(modal_title)
	modal_reason = _label("", 23, CYAN)
	modal_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(modal_reason)
	modal_detail = _label("", 18, MUTED)
	modal_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(modal_detail)
	_controls = _control_legend()
	stack.add_child(_controls)
	_rules = HBoxContainer.new()
	_rules.add_theme_constant_override("separation", 20)
	stack.add_child(_rules)
	var sequences := [["banana", "right", "slip"], ["spring", "back", "shot"], ["clock", "right", "charge"]]
	for i in 3:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rules.add_child(column)
		var sequence := _icons(sequences[i], 29)
		sequence.tooltip_text = USES[i]
		sequence.mouse_filter = Control.MOUSE_FILTER_PASS
		column.add_child(sequence)
		_rule_icons.append(sequence)
		var name_label := _label(TOOLS[i], 17, MUTED)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(name_label)
		_rule_labels.append(name_label)
	var row := HBoxContainer.new()
	_modal_buttons = row
	row.add_theme_constant_override("separation", 12)
	stack.add_child(row)
	primary = _button("開始", func() -> void: start_requested.emit())
	row.add_child(primary)
	retry = _button("重試", func() -> void: retry_requested.emit())
	row.add_child(retry)
	row.add_child(_button("返回", func() -> void: leave_requested.emit()))
	next_button = _button("下一章", func() -> void: next_requested.emit())
	row.add_child(next_button)
	next_button.hide()
	overlay.hide()


func _fit_modal() -> void:
	_modal_panel.custom_minimum_size.x = minf(620, get_viewport().get_visible_rect().size.x - 48)


func set_health(hero: int, hero_max: int, boss: int, boss_max: int) -> void:
	hero_health.text = "%d / %d" % [hero, hero_max]
	boss_health.text = "BOSS    %d / %d" % [boss, boss_max]
	hero_bar.max_value = hero_max
	hero_bar.value = hero
	boss_bar.max_value = boss_max
	boss_bar.value = boss


func set_rescue(available: bool) -> void:
	rescue_icon.visible = available


func set_loadout(allowed: Array) -> void:
	tool_ids = allowed.duplicate()
	for i in 3:
		var enabled := i < tool_ids.size()
		tool_buttons[i].visible = enabled
		_rules.get_child(i).visible = enabled
		if not enabled:
			continue
		var id := int(tool_ids[i])
		tool_buttons[i].tooltip_text = "%d · %s\n%s" % [i + 1, TOOLS[id], USES[id]]
		_name_labels[i].text = TOOLS[id]
		_tool_icons[i].set_symbols([TOOL_SYMBOLS[id]])
		_rule_labels[i].text = TOOLS[id]
		_rule_icons[i].set_symbols([TOOL_SYMBOLS[id], "right", "shot" if id in [1, 4] else "clock" if id == 2 else "slip"])
	_tool_snapshot = ""
	_selected_skin_index = -1


func set_tools(tool: int, cooldown: Array[float], pace: float = 1.0) -> void:
	var snapshot := str(tool) + str(snappedf(pace, 0.01))
	for id in tool_ids:
		snapshot += ":%d" % ceili(cooldown[id] / pace * 10)
	if snapshot == _tool_snapshot:
		return
	_tool_snapshot = snapshot
	selected = tool
	for i in tool_ids.size():
		var id := int(tool_ids[i])
		var button := tool_buttons[i]
		_cool_labels[i].text = "" if cooldown[id] <= 0 else "%.1f" % (ceilf(cooldown[id] / pace * 10) / 10)
		_tool_icons[i].ink = PAPER if cooldown[id] <= 0 else MUTED.darkened(0.4)
		_last_cooldown[i] = maxf(_last_cooldown[i], cooldown[id]) if cooldown[id] > 0 else 0.0
		_tool_icons[i].cooldown = clampf(cooldown[id] / maxf(_last_cooldown[i], 0.001), 0, 1)
		_tool_icons[i].queue_redraw()
		if _selected_skin_index != tool:
			button.add_theme_stylebox_override("normal", PixelSkin.box("selected" if id == tool else "normal"))
	_selected_skin_index = tool


func tell(message: String, seconds: float = 2.4, symbols: Array = [], bad: bool = false) -> void:
	feedback.text = message
	feedback.add_theme_color_override("font_color", CORAL if bad else CYAN)
	_feedback_icons.ink = CORAL if bad else CYAN
	_feedback_icons.set_symbols(symbols)
	_notice_left = seconds


func set_intent(message: String, symbols: Array) -> void:
	intent.text = message
	_intent_icons.set_symbols(symbols)


func set_pace(value: float) -> void:
	pace_button.text = "×%.2f" % value if value < 0.5 else "×%.1f" % value


func set_timing(remaining: float, duration: float, pace: float, opening: bool = false) -> void:
	intent_bar.visible = remaining > 0 and duration > 0
	intent_timer.text = "%.1fs" % (ceilf(remaining / maxf(pace, 0.01) * 10) / 10) if intent_bar.visible else ""
	var ink := CYAN if opening else CORAL
	if _timing_opening != int(opening):
		_timing_opening = int(opening)
		intent.add_theme_color_override("font_color", ink)
		_intent_icons.ink = ink
		_intent_icons.queue_redraw()
		(intent_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = ink
	if intent_bar.visible:
		intent_bar.value = clampf(remaining / duration, 0, 1)


func _process(delta: float) -> void:
	if _notice_left > 0 and not overlay.visible:
		_notice_left = maxf(0, _notice_left - delta)
		if _notice_left <= 0:
			feedback.text = ""
			_feedback_icons.set_symbols([])


func show_briefing(tutorial: bool = false, arena_name: String = "尖刺斷橋") -> void:
	_show_modal("玩法" if tutorial else arena_name, "擊敗 BOSS", "", "開始", false)
	_rules.visible = tutorial
	_controls.visible = tutorial
	_result_icon.set_symbols(["book"] if tutorial else ["play"])


func show_pause() -> void:
	_show_modal("暫停", "", "", "繼續", true)
	_rules.hide()
	_controls.hide()
	_result_icon.set_symbols(["pause"])


func show_result(won: bool, reason: String, uses: int, saved: bool) -> void:
	var detail := "道具 × %d" % uses
	if won and saved:
		detail += "　·　已通關"
	if won and not saved:
		detail += "　·　紀錄未儲存"
	_show_modal("勝利" if won else "失敗", reason, detail, "重玩" if won else "重試", false)
	_rules.hide()
	_controls.hide()
	_result_icon.set_symbols(["cup"] if won else ["miss"])
	_result_icon.ink = CYAN if won else CORAL
	modal_title.add_theme_color_override("font_color", CYAN if won else CORAL)


func _show_modal(title: String, reason: String, detail: String, action: String, with_retry: bool) -> void:
	modal_title.text = title
	modal_title.add_theme_color_override("font_color", PAPER)
	_result_icon.ink = CYAN
	modal_reason.text = reason
	modal_detail.text = detail
	modal_detail.visible = not detail.is_empty()
	modal_reason.visible = not reason.is_empty()
	next_button.hide()
	primary.tooltip_text = action + " · Enter"
	primary.text = action
	retry.visible = with_retry
	for button in _game_buttons:
		button.focus_mode = Control.FOCUS_NONE
	var active: Array[Button] = []
	for button: Button in _modal_buttons.get_children():
		if button.visible:
			active.append(button)
	for i in active.size():
		active[i].focus_neighbor_left = active[posmod(i - 1, active.size())].get_path()
		active[i].focus_neighbor_right = active[(i + 1) % active.size()].get_path()
		active[i].focus_neighbor_top = active[i].get_path()
		active[i].focus_neighbor_bottom = active[i].get_path()
		active[i].focus_next = active[(i + 1) % active.size()].get_path()
		active[i].focus_previous = active[posmod(i - 1, active.size())].get_path()
	overlay.show()
	MenuUi.focus_when_visible.call_deferred(primary.get_instance_id())


func close_modal() -> void:
	overlay.hide()
	for button in _game_buttons:
		button.focus_mode = Control.FOCUS_ALL
	get_viewport().gui_release_focus()


func offer_next(available: bool, caption: String) -> void:
	next_button.visible = available
	if not available:
		return
	next_button.text = "下一章"
	next_button.tooltip_text = caption
	var active: Array[Button] = [primary, _modal_buttons.get_child(2), next_button]
	for i in active.size():
		active[i].focus_neighbor_left = active[posmod(i - 1, active.size())].get_path()
		active[i].focus_neighbor_right = active[(i + 1) % active.size()].get_path()
		active[i].focus_next = active[(i + 1) % active.size()].get_path()
		active[i].focus_previous = active[posmod(i - 1, active.size())].get_path()
