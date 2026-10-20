class_name Broadcast
extends Node

const CARD_TITLE: Array[String] = [
	"落後者必須逆轉",
	"必須打中招牌三次",
	"木頭人：鏡頭裡不能有人",
	"兩人都必須出一次糗",
	"摸魚君必須出風頭",
]
const CARD_BODY: Array[String] = [
	"落後的那個必須在你出手後 8 秒內變成領先，或用自己的拳拿下一次擊殺。他們自己打出來的不算。",
	"中間有一塊招牌。參賽者的拳要打中它三次，炸彈不算。第三次會噴出彩帶或一張香蕉皮。",
	"場中央有一個鏡頭。每八秒喊一次 3、2、1、木頭人。喊下的那一瞬，鏡頭裡不能有人，有人這張單就失敗。連續三次都是空的才算過。",
	"認真君和摸魚君各自都要被工具碰到一次。滑倒、炸到、踩彈簧、腳下被切開、被燈定住，或聽進麥克風才算。打空的、沒理你的不算。",
	"摸魚君要拿下最後一擊、自己贏得這場，或在最後 15 秒打出比較多的傷害。認真君自己贏了，這張單失敗。",
]
const SHOT := Rect2(490, 330, 300, 190)
const WOOD_NEED := 3
const WOOD_CYCLE := 8.0

var card := 0
var scores: Array[int] = [0, 0, 0]
var replay: Array[Dictionary] = []
var sponsor_hits := 0
var card_ok := false
var card_fail := false
var last_note := ""
var wood_clears := 0
var embarrassed_count := 0
var shot_alarm := 0

var _uses: Dictionary = {}
var _actions: Array[Dictionary] = []
var _embarrassed: Dictionary = {}
var _trailer_id := 0
var _ready_lead := false
var _self_flip_scored := false
var _wood_origin := 0.0
var _wood_cycle := 0
var _wood_flags := 0
var _shot_hot_until := -1.0


func setup() -> void:
	card = randi() % CARD_TITLE.size()


func arm(battle: Battle) -> void:
	_ready_lead = true
	_trailer_id = _current_trailer(battle)
	_wood_origin = battle.now()
	_wood_cycle = 0
	_wood_flags = 0


func record(battle: Battle, kind: String, focus: Variant, style: String, detail: String, joke: String = "") -> void:
	var fighter: Fighter = focus as Fighter
	var key := joke if joke != "" else kind
	var repeats := int(_uses.get(key, 0)) if style != "whiff" else 0
	var host_on := battle.host_body != null and battle.host_body.on_stage
	var judged := _judge(kind, style, repeats, host_on)
	var chen := int(judged["chen"])
	var xiao := int(judged["xiao"])
	var who := fighter.display_name if fighter != null else ""
	_line(battle, _title(kind), _who(who, detail), chen, xiao, 0, str(judged["why"]))
	if style == "whiff":
		return
	_uses[key] = repeats + 1
	var trailer: Variant = battle.trailer()
	_actions.append({
		"time": battle.now(),
		"trailer": trailer.get_instance_id() if trailer is Fighter else 0,
	})
	if repeats >= 1:
		battle.shout("看過了")
	if fighter != null and style in ["hit", "eat", "silly"] and kind != "host" and kind != "sponsor":
		_embarrass(battle, fighter)


func roll_box(battle: Battle) -> void:
	var red := battle.red
	var blue := battle.blue
	var before := "%s%s，%s%s" % [red.display_name, red.state_label(), blue.display_name, blue.state_label()]
	match randi() % 4:
		0:
			for fighter in [red, blue]:
				if fighter.is_on_floor():
					fighter.flutter()
				else:
					fighter.flip_gravity(1.1)
			record(battle, "box_gravity", null, "hit", before)
			battle.shout("短重力")
			battle.add_shake(8.0)
			for fighter in [red, blue]:
				if fighter.gravity_flip > 0.0:
					_embarrass(battle, fighter)
		1:
			var pos := red.global_position
			var vel := red.velocity
			red.global_position = blue.global_position
			red.velocity = blue.velocity
			blue.global_position = pos
			blue.velocity = vel
			red.launch_time = 0.22
			blue.launch_time = 0.22
			red.last_cause = "box"
			blue.last_cause = "box"
			red.mark_host_fault(2.0, "box")
			blue.mark_host_fault(2.0, "box")
			record(battle, "box_swap", null, "hit", before)
			battle.shout("換位")
			battle.add_shake(14.0)
			_embarrass(battle, red)
			_embarrass(battle, blue)
		2:
			red.force_attack()
			blue.force_attack()
			record(battle, "box_both", null, "hit", before)
			battle.shout("同時出招")
			battle.add_shake(10.0)
			_embarrass(battle, red)
			_embarrass(battle, blue)
		_:
			record(battle, "box_empty", null, "empty", "什麼都沒有")
			battle.shout("謝謝收看")


func sponsor_punched(battle: Battle, fighter: Fighter) -> String:
	sponsor_hits += 1
	var detail := fighter.state_label()
	var effect := ""
	if sponsor_hits == 3:
		effect = "banana" if randf() < 0.5 else "confetti"
		detail += "，第三次噴出%s" % ("香蕉皮" if effect == "banana" else "彩帶")
	record(battle, "sponsor", fighter, "hit", detail)
	if card == 1 and sponsor_hits >= 3:
		_succeed(battle, "招牌打滿三次")
	return effect


func poll(battle: Battle) -> void:
	if not _ready_lead or battle.match_over:
		return
	_poll_wood(battle)
	var now_id := _current_trailer(battle)
	if now_id != 0 and _trailer_id != 0 and now_id != _trailer_id:
		_on_flip(battle, _trailer_id)
	if now_id != 0:
		_trailer_id = now_id


func _poll_wood(battle: Battle) -> void:
	if card != 2 or card_fail or card_ok:
		shot_alarm = 0
		return
	var elapsed := battle.now() - _wood_origin
	var cycle := int(elapsed / WOOD_CYCLE)
	var phase := fmod(elapsed, WOOD_CYCLE)
	if cycle > _wood_cycle:
		_wood_cycle = cycle
		_wood_flags = 0
		_freeze(battle)
		if card_fail or card_ok:
			shot_alarm = 2 if battle.now() < _shot_hot_until else 0
			return
	if phase >= 5.0 and (_wood_flags & 1) == 0:
		_wood_flags |= 1
		battle.shout("3")
	if phase >= 6.0 and (_wood_flags & 2) == 0:
		_wood_flags |= 2
		battle.shout("2")
	if phase >= 7.0 and (_wood_flags & 4) == 0:
		_wood_flags |= 4
		battle.shout("1")
	if battle.now() < _shot_hot_until:
		shot_alarm = 2
	elif phase >= 5.0:
		shot_alarm = 1
	else:
		shot_alarm = 0


func _freeze(battle: Battle) -> void:
	_shot_hot_until = battle.now() + 0.5
	shot_alarm = 2
	var caught: PackedStringArray = PackedStringArray()
	for fighter in [battle.red, battle.blue]:
		if _in_shot(fighter):
			caught.append(fighter.display_name)
	if caught.size() > 0:
		_line(battle, "鏡頭", "%s在鏡頭裡" % "、".join(caught), 0, 0, 0, "木頭人，有人沒離開")
		battle.shout("木頭人")
		_fail(battle, "%s在鏡頭裡" % "、".join(caught))
		return
	wood_clears += 1
	_line(battle, "鏡頭", "沒有人", 0, 0, 0, "木頭人，鏡頭是空的")
	if wood_clears >= WOOD_NEED:
		_succeed(battle, "連續三次鏡頭是空的")
	else:
		battle.shout("空的")


func _in_shot(fighter: Fighter) -> bool:
	return fighter != null and fighter.alive and SHOT.has_point(fighter.global_position)


func _embarrass(battle: Battle, fighter: Fighter) -> void:
	if fighter == null:
		return
	var id := fighter.get_instance_id()
	if _embarrassed.has(id):
		return
	_embarrassed[id] = true
	embarrassed_count = _embarrassed.size()
	if card != 3:
		return
	if _embarrassed.has(battle.red.get_instance_id()) and _embarrassed.has(battle.blue.get_instance_id()):
		_succeed(battle, "兩個人都出糗了")


func on_ko(battle: Battle, victim: Fighter) -> void:
	var attacker := victim.last_attacker
	var cause := victim.last_cause
	if cause == "punch" and attacker != null and _was_trailer(attacker, battle.now()):
		_line(battle, "收尾", "%s用自己的拳擊殺%s" % [attacker.display_name, victim.display_name], 3, 0, 0, "落後者自己的拳，陳裁判給高分")
		if card == 0:
			_succeed(battle, "%s用自己的拳擊殺" % attacker.display_name)
	elif cause == "punch" and attacker != null:
		_line(battle, "收尾", "%s用自己的拳擊殺%s" % [attacker.display_name, victim.display_name], 1, 0, 0, "是拳，但是領先的那個打的")
	elif cause != "":
		_line(battle, "收尾", "這一擊來自%s" % _title(cause), -2, 0, 0, "道具收尾，陳裁判扣分")


func resolve(battle: Battle, loser: Fighter) -> void:
	if card != 4 or card_fail:
		return
	var lazy := battle.blue
	var serious := battle.red
	var last_hit := loser.last_attacker == lazy and loser.last_cause == "punch" and battle.now() - loser.last_attack_time <= 3.0
	var lazy_won := loser == serious
	var lazy_damage := battle.recent_damage(lazy) > battle.recent_damage(serious)
	if last_hit:
		_succeed(battle, "摸魚拿下最後一擊")
	elif lazy_won:
		_succeed(battle, "摸魚贏得這場")
	elif lazy_damage:
		_succeed(battle, "摸魚最後打出比較多")
	else:
		_fail(battle, "摸魚沒有出風頭")


func state_word(finished: bool = false) -> String:
	if card_fail:
		return "失敗"
	if card_ok:
		return "達成"
	if finished:
		return "沒達成"
	return "還沒完成"


func task(battle: Battle) -> String:
	if last_note != "":
		return last_note
	match card:
		0:
			var who: Variant = battle.trailer()
			if who is Fighter:
				return "落後：%s，還差一次逆轉" % (who as Fighter).display_name
			return "兩邊差不多，還沒有落後者"
		1:
			return "招牌 %d/3" % sponsor_hits
		2:
			var left := _seconds_until_freeze(battle)
			if shot_alarm == 1:
				return "木頭人 %d/3    %d 秒後，人要離開鏡頭" % [wood_clears, left]
			return "木頭人 %d/3    %d 秒後看鏡頭" % [wood_clears, left]
		3:
			return "%s    %s" % [_shame_mark(battle.red), _shame_mark(battle.blue)]
		_:
			var lazy_n := int(round(battle.recent_damage(battle.blue)))
			var serious_n := int(round(battle.recent_damage(battle.red)))
			return "近 15 秒  摸魚 %d    認真 %d    收尾才算" % [lazy_n, serious_n]


func _shame_mark(fighter: Fighter) -> String:
	var mark := "已出糗" if _embarrassed.has(fighter.get_instance_id()) else "還沒"
	return "%s %s" % [fighter.display_name, mark]


func _seconds_until_freeze(battle: Battle) -> int:
	var elapsed := battle.now() - _wood_origin
	if elapsed < 0.0:
		elapsed = 0.0
	var phase := fmod(elapsed, WOOD_CYCLE)
	return maxi(int(ceil(WOOD_CYCLE - phase)), 1)


func scores_text() -> String:
	return "陳 %d    笑 %d    表 %d" % [scores[0], scores[1], scores[2]]


func comment(index: int) -> String:
	var value := scores[index]
	if index == 0:
		if value >= 3:
			return "拳還是他們自己打的"
		if value <= -2:
			return "道具收尾太多"
		return "他在看誰出拳"
	if index == 1:
		if value >= 4:
			return "出糗了"
		if value <= 1:
			return "太像寫好的笑話"
		return "有一點出糗"
	if value >= 3:
		return "數字有動"
	return "數字沒動"


func result_word() -> String:
	if card_fail:
		return "失敗"
	if card_ok:
		return "達成"
	return "沒達成"


func secrets() -> String:
	return "陳裁判真正在意的是誰打出最後一拳。道具把人送出去他扣分，落後者自己的拳他給高分。\n笑姐不給標準笑點。太準的香蕉和彈簧幾乎是 0 分，同一種第二次也是 0 分。出糗、空箱、挨打她才加分。\n阿表只看領先有沒有換人。你出手後 8 秒內換人給 3 分，他們自己換人只給 1 分。"


func replay_lines() -> Array[String]:
	var lines: Array[String] = []
	for item in replay:
		lines.append("%.1fs   %s   %s   陳%d 笑%d 表%d   %s" % [
			float(item["t"]), str(item["title"]), str(item["detail"]),
			int(item["chen"]), int(item["xiao"]), int(item["biao"]), str(item["why"]),
		])
	if lines.is_empty():
		lines.append("這場沒有留下可以重播的干擾")
	return lines


func _on_flip(battle: Battle, previous: int) -> void:
	var hosted := false
	var now := battle.now()
	for action in _actions:
		if now - float(action["time"]) > 8.0:
			continue
		if int(action["trailer"]) == previous:
			hosted = true
			break
	if hosted:
		_line(battle, "易主", "落後的那個變成領先", 0, 0, 3, "出手後 8 秒內領先易主，阿表給滿分")
		if card == 0:
			_succeed(battle, "落後的那個變成領先")
	elif not _self_flip_scored:
		_self_flip_scored = true
		_line(battle, "易主", "他們自己把領先換了", 0, 0, 1, "沒有你的出手，阿表只給一分")


func _was_trailer(attacker: Fighter, now: float) -> bool:
	var id := attacker.get_instance_id()
	for action in _actions:
		if now - float(action["time"]) > 8.0:
			continue
		if int(action["trailer"]) == id:
			return true
	return false


func _current_trailer(battle: Battle) -> int:
	var who: Variant = battle.trailer()
	if who is Fighter:
		return (who as Fighter).get_instance_id()
	return 0


func _line(battle: Battle, title: String, detail: String, chen: int, xiao: int, biao: int, why: String) -> void:
	scores[0] += chen
	scores[1] += xiao
	scores[2] += biao
	replay.append({
		"t": battle.now(),
		"title": title,
		"detail": detail,
		"chen": chen,
		"xiao": xiao,
		"biao": biao,
		"why": why,
	})


func _fail(battle: Battle, note: String = "") -> void:
	if card_fail:
		return
	card_fail = true
	card_ok = false
	if note != "":
		last_note = note
	battle.shout("失敗")


func _succeed(battle: Battle, note: String = "") -> void:
	if card_fail or card_ok:
		return
	card_ok = true
	if note != "":
		last_note = note
	battle.shout("達成")


func _who(who: String, detail: String) -> String:
	if who == "":
		return detail
	return "%s，%s" % [who, detail]


func _judge(kind: String, style: String, repeats: int, host_on: bool) -> Dictionary:
	var chen := 0
	var xiao := 0
	var why := ""
	match kind:
		"slip":
			if style == "whiff":
				why = "速度不夠，他跨過去了"
			else:
				chen = -1
				why = "太標準的滑倒，笑姐幾乎不給分"
		"bomb":
			if style == "eat":
				chen = -1
				xiao = 2
				why = "出拳把爆炸吃進去"
			elif style == "hit":
				chen = -1
				xiao = 1
				why = "炸彈直接改了場面"
			else:
				why = "旁邊沒人"
		"cut":
			if style == "silly":
				xiao = 2
				why = "站得好好的，只跳了一下"
			elif style == "hit":
				chen = -1
				xiao = 1
				why = "人在不穩的時候被拆地面"
			else:
				why = "切到空平台"
		"mic":
			if style == "ignore":
				chen = -1
				xiao = 2
				why = "他沒理你"
			else:
				chen = -2
				xiao = 2
				why = "麥克風是第四面牆"
		"spring":
			chen = -1
			if style == "silly":
				xiao = 2
				why = "走上去只是跳一下"
			else:
				why = "彈得太準，笑姐覺得像寫好的"
		"light":
			if style == "whiff":
				why = "光穿過去了"
			else:
				chen = -2
				xiao = 2
				why = "定格燈是擺拍"
		"photo":
			chen = -2
			xiao = 3
			why = "擺拍的時候被打中"
		"box_gravity", "box_swap", "box_both":
			chen = -1
			xiao = 2
			why = "開之前不知道結果"
		"box_empty":
			xiao = 3
			why = "空箱"
		"host":
			chen = -2
			xiao = 3
			why = "主持人挨打"
		"sponsor":
			chen = -1
			xiao = 1
			why = "拳打在招牌上"
		_:
			why = kind
	if repeats >= 1 and style != "whiff":
		xiao = 0
		why = _join(why, "笑姐看過了")
	if host_on and style != "whiff" and kind != "host" and kind != "box_empty":
		chen -= 1
		why = _join(why, "人在場上")
	return {"chen": chen, "xiao": xiao, "why": why}


func _join(a: String, b: String) -> String:
	if a == "":
		return b
	return "%s，%s" % [a, b]


func _title(kind: String) -> String:
	match kind:
		"slip":
			return "香蕉皮"
		"bomb":
			return "炸彈"
		"cut":
			return "橫切"
		"mic":
			return "麥克風"
		"spring":
			return "彈簧"
		"light":
			return "定格燈"
		"photo":
			return "拍照擊中"
		"box_gravity":
			return "短重力"
		"box_swap":
			return "換位"
		"box_both":
			return "同時出招"
		"box_empty":
			return "空箱"
		"box":
			return "密封箱"
		"host":
			return "挨打"
		"sponsor":
			return "招牌"
		"spring_hop":
			return "彈簧"
		_:
			return kind
