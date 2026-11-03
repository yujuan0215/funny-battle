extends Control
const Ui := preload("res://scripts/menu_ui.gd")
func _ready() -> void:
	var stage:=Ui.mount(self)
	var center:=CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(center)
	var stack:=VBoxContainer.new()
	stack.custom_minimum_size.x=620
	stack.add_theme_constant_override("separation",20)
	center.add_child(stack)
	var title:=Label.new()
	title.text="舊版場地"
	title.add_theme_font_size_override("font_size",48)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var hint:=Label.new()
	hint.text="保留原地形、Boss 數值與機關"
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(hint)
	var titles: Array[String]=["03　鐘樓工坊", "04　冰封貨港", "05　熔爐車站", "06　王座機關塔"]
	for i in 4:
		var button:=Button.new()
		button.text=titles[i]
		button.custom_minimum_size.y=72
		Ui.PixelSkin.button(button)
		button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/legacy_chapter_%d.tscn" % (i+3)))
		stack.add_child(button)
	var back:=Button.new()
	back.text="返回"
	Ui.PixelSkin.button(back)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/test_lab.tscn"))
	stack.add_child(back)
	Ui.focus_when_visible.call_deferred(stack.get_child(2).get_instance_id())
