extends RefCounted
## Production chapters are separate from mechanic test arenas.

const CHAPTERS: Array[Dictionary] = [
	{"id": 1, "name": "木棧前哨", "theme": "forest", "boss": "守橋鐵衛", "tools": [0, 1], "focus": "引誘衝撞 · 借力反擊", "terrain": "木棧橋與橋邊落差", "counter": "香蕉截住衝撞，或彈簧脫身開火。", "unlock": "香蕉 · 彈簧", "playable": true, "scene": "res://scenes/spikes.tscn"},
	{"id": 2, "name": "風車峽谷", "theme": "valley", "boss": "風翼巡守", "tools": [0, 1], "focus": "觀察風向 · 預判落點", "terrain": "間歇側風與高低平台", "counter": "等順風時彈射；讓衝撞撞進逆風區。", "unlock": "沿用兩件道具，學一種新場地", "playable": false, "scene": ""},
	{"id": 3, "name": "鐘樓工坊", "theme": "clock", "boss": "發條拳王", "tools": [1, 2], "focus": "打斷蓄力 · 掌握節拍", "terrain": "週期齒輪與升降工作台", "counter": "時停鎖住起手，讓主角蓄力反擊。", "unlock": "時停", "playable": false, "scene": ""},
	{"id": 4, "name": "冰封貨港", "theme": "ice", "boss": "滑行裝甲蟹", "tools": [1, 2, 3], "focus": "改變摩擦 · 控制停點", "terrain": "光滑冰面與可停靠貨台", "counter": "用沙袋造出止滑點，讓重甲衝過頭。", "unlock": "沙袋", "playable": false, "scene": ""},
	{"id": 5, "name": "熔爐車站", "theme": "forge", "boss": "熔爐機車長", "tools": [1, 3, 4], "focus": "改變路線 · 借場地破甲", "terrain": "貨運軌道、金屬箱與熔爐閘門", "counter": "磁鐵改變鐵箱路線，擋住車頭露出核心。", "unlock": "磁鐵", "playable": false, "scene": ""},
	{"id": 6, "name": "王座機關塔", "theme": "tower", "boss": "百變機關王", "tools": [0, 1, 2, 3, 4], "focus": "三階段綜合反擊", "terrain": "可切換的風道、齒輪與金屬軌道", "counter": "每階段破解一種機關，最後讓王的攻擊擊中自己的核心。", "unlock": "彈簧固定＋任選兩件；階段間可換裝", "playable": false, "scene": ""},
]

const TOOLS := ["香蕉", "彈簧", "時停", "沙袋", "磁鐵"]
const TOOL_ICONS := ["banana", "spring", "clock", "sandbag", "magnet"]
const FINAL_PHASES: Array[Dictionary] = [
	{"name": "衝撞鎧甲", "signal": "亮起肩甲 → 鎖定直線", "answer": "位移與滑倒，把重拳導向兩側鎧甲鎖", "change": "拆掉護肩，縮小攻擊範圍"},
	{"name": "發條心臟", "signal": "核心三拍閃光 → 長蓄力", "answer": "時停爭取蓄力，或用金屬箱擋住炮口", "change": "拆掉發條，場地露出最後一條軌道"},
	{"name": "借力終幕", "signal": "三處落點依序點亮 → 最終砸擊", "answer": "改變站位與箱子路線，讓王砸中自己的核心", "change": "弱點大開，主角完成最後一擊"},
]


static func chapter(number: int) -> Dictionary:
	return CHAPTERS[clampi(number - 1, 0, CHAPTERS.size() - 1)]
