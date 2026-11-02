extends "res://scripts/chapter_arena.gd"
## Archive navigation is independent of campaign progress and the redesigned route.
func _leave_arena() -> void:
	get_tree().change_scene_to_file("res://scenes/legacy_chapters.tscn")
func _next_chapter() -> void:
	if chapter_number<6: get_tree().change_scene_to_file("res://scenes/legacy_chapter_%d.tscn" % (chapter_number+1))
	else: _leave_arena()
