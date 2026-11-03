extends "res://scripts/action_trial.gd"
const StudyStage := preload("res://scripts/terrain_study_stage.gd")
@export_range(4,6) var layout_id := 4
var study_ready := false
func _ready() -> void:
	trial_id=3
	super._ready()
	remove_child(_stage)
	_stage.queue_free()
	_stage=StudyStage.new()
	_stage.layout_id=layout_id
	add_child(_stage)
	study_ready=true
	_reset()
	_briefing()
func _reset() -> void:
	super._reset()
	if not study_ready: return
	right.hide()
	right.position=Vector2(710,520 if layout_id==6 else 570 if layout_id==5 else 500)
	left.position=Vector2(710,520) if layout_id==6 else Vector2(410,500)
	left.ground_y=left.position.y
	left._plant()
	_hud.hero_bar.hide()
	_hud.boss_bar.hide()
	_hud.hero_health.text="自由走跳"
	_hud.boss_health.text="地形研究 · 不計勝敗"
	_hud.set_loadout([1])
	_hud._key_labels[0].text="E"
	_hud.tool_buttons[0].tooltip_text="E · 腳下彈簧高跳"
	_hud.set_rescue(false)
	_hud.objective.text=["冰港 · 雙側跳台與滑行區","車站 · 移動平台與低層回收路","高塔 · 三層路線與可破壞側台"][layout_id-4]
	_action_hint.text="A/D 移動　Space 跳躍\nE 彈簧　F 測試機關"
	_difficulty_button.hide()
func _briefing() -> void:
	if not study_ready: return
	_round_state=State.BRIEFING
	_hud.show_briefing(false,["冰港地形研究","車站地形研究","高塔地形研究"][layout_id-4])
	_hud.modal_reason.text="場地原型，尚未接入主線 Boss"
	_hud.modal_detail.text="A/D 移動　Space 跳躍　E 彈簧\nF 切換滑行／平台移動／側台崩落"
	_hud.modal_detail.show()
	_action_hint.hide()
func _start_round() -> void:
	super._start_round()
	_difficulty_button.hide()
func _step_world(dt: float) -> void:
	_stage.tick(dt,left,float(_held_right)-float(_held_left))
	super._step_world(dt)
func _tick_boss(_dt: float) -> void: pass
func _tick_environment(_dt: float) -> void:
	_hud.set_intent("場地測試",["levels"])
	_hud.set_timing(0,0,_pace)
func _act() -> void:
	if _round_state==State.PLAYING:
		_stage.interact()
		_audio.cue("phase")
func _banana() -> void: pass
func _hurt(_amount: int,_reason: String) -> void:
	left.position=Vector2(710,520) if layout_id==6 else Vector2(410,500)
	left.ground_y=left.position.y
	left._plant()
	left.hp=left.hp_max
	_hud.tell("回到安全台",1,["shield"])
func _finish() -> void: pass
func _leave() -> void:
	get_tree().change_scene_to_file("res://scenes/terrain_studies.tscn")
