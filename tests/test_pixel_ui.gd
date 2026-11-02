extends SceneTree
## Functional UI checks: readable bundled glyphs, safe bounds, focus and real HP.

const MenuUi := preload("res://scripts/menu_ui.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func settle() -> void:
	for i in 4:
		await process_frame


func fits(control: Control) -> bool:
	var bounds := Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1)
	return bounds.encloses(control.get_global_rect())


func mount(path: String) -> Node:
	var node: Node = load(path).instantiate()
	root.add_child(node)
	return node


func _run() -> void:
	var font := MenuUi.font()
	var glyphs := "小小反擊木棧前哨風車峽谷鐘樓工坊冰封貨港熔爐車站王座機關塔香蕉彈簧時停暫停勝利失敗借力反擊選關繼續開始重試安全繩0123456789BOSS×"
	var missing := ""
	for character in glyphs:
		if not font.has_char(character.unicode_at(0)):
			missing += character
	check(missing.is_empty(), "Bundled pixel font must contain the real Traditional Chinese UI: " + missing)
	for dimensions in [Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(1920, 1080)]:
		root.size = dimensions
		var start = mount("res://scenes/start.tscn")
		await settle()
		check(root.gui_get_focus_owner() == start._play, "Main menu has an initial keyboard target at " + str(dimensions))
		for button in [start._play, start._tutorial, start._lab]:
			check(fits(button), "Main menu controls stay within " + str(dimensions))
		start.free()
		var map = mount("res://scenes/levels.tscn")
		await settle()
		for stop in map._levels:
			check(fits(stop), "Every route landmark remains reachable at " + str(dimensions))
		map._show_blueprint(preload("res://scripts/campaign_catalog.gd").chapter(6))
		await settle()
		var modal_focus := root.gui_get_focus_owner()
		check(is_instance_valid(modal_focus) and map._overlay.is_ancestor_of(modal_focus), "Final boss blueprint owns keyboard input")
		map.free()
		var game = mount("res://scenes/spikes.tscn")
		await settle()
		check(fits(game._hud._modal_panel), "Briefing panel fits at " + str(dimensions))
		game._start_round()
		game.set_process(false)
		for actor in [game.left, game.right]:
			actor.set_process(false)
		await settle()
		for button in game._hud.tool_buttons:
			if button.visible:
				check(fits(button), "Available tools stay on screen at " + str(dimensions))
		check(not game._hud.hero_bar.get_global_rect().intersects(game._hud.boss_bar.get_global_rect()), "The two health gauges remain separate")
		game._hud.set_health(9, 12, 4, 12)
		check(game._hud.hero_bar.value == 9 and game._hud.boss_bar.value == 4, "Visual damage trails do not delay actual HP")
		game._pause_round()
		await settle()
		check(game._hud.overlay.is_ancestor_of(root.gui_get_focus_owner()), "Pause owns focus after replacing the gauge and buttons")
		game.free()
	print("Pixel UI checks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
