extends RefCounted
## Six playable demo encounters; the original mechanic labs stay separate.

const CHAPTERS: Array[Dictionary] = [
	{"id": 1, "name": "尖刺世界", "theme": "spikes", "boss": "守橋鐵衛", "tools": [0, 1], "focus": "引誘衝撞 · 借力反擊", "terrain": "尖刺深坑上的斷橋", "counter": "香蕉截住衝撞，或彈簧脫身開火。", "unlock": "香蕉 · 彈簧", "playable": true, "scene": "res://scenes/spikes.tscn"},
	{"id": 2, "name": "風車峽谷", "theme": "valley", "boss": "風翼巡守", "tools": [0, 1], "focus": "彈起重甲 · 借風撞機關", "terrain": "每六秒換向的峽谷風場", "counter": "在 BOSS 腳下放彈簧，借風吹進亮起的風車；拳腳與子彈無法破甲。", "unlock": "沿用兩件道具，學一種新場地", "playable": true, "scene": "res://scenes/chapter_2.tscn"},
	{"id": 3, "name": "鐘樓工坊", "theme": "clock", "boss": "發條拳王", "tools": [1, 2], "focus": "打斷蓄力 · 掌握節拍", "terrain": "鎖定落點的三拍重錘", "counter": "時停延後重錘；彈簧跳出紅框，重錘落空反傷。", "unlock": "時停", "playable": true, "scene": "res://scenes/chapter_3.tscn"},
	{"id": 4, "name": "冰封貨港", "theme": "ice", "boss": "滑行裝甲蟹", "tools": [1, 2, 3], "focus": "改變摩擦 · 控制停點", "terrain": "光滑冰面與可停靠貨台", "counter": "衝撞路線上放沙袋，撞停破甲；彈簧拉開距離。", "unlock": "沙袋", "playable": true, "scene": "res://scenes/chapter_4.tscn"},
	{"id": 5, "name": "熔爐車站", "theme": "forge", "boss": "熔爐機車長", "tools": [1, 3, 4], "focus": "改變路線 · 借場地破甲", "terrain": "貨運軌道、金屬箱與熔爐閘門", "counter": "把磁鐵放在鐵箱另一側，拉箱撞停車頭；沙袋也能阻擋。", "unlock": "磁鐵", "playable": true, "scene": "res://scenes/chapter_5.tscn"},
	{"id": 6, "name": "王座機關塔", "theme": "tower", "boss": "百變機關王", "tools": [1, 2, 4], "focus": "三階段綜合反擊", "terrain": "可切換的風道、齒輪與金屬軌道", "counter": "衝撞、重錘、連鎖終幕；躲開鎖定紅框讓核心反傷。", "unlock": "彈簧 · 時停 · 磁鐵；階段檢查點", "playable": true, "scene": "res://scenes/chapter_6.tscn"},
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


# Neutral encounter context only; the player discovers the counterplay.
const OPENINGS: Array[String] = [
	"招式：單拳、直線衝撞\n場地：尖刺世界，斷橋兩側是尖刺深坑",
	"招式：重甲單拳、衝撞\n場地：側風定時換向，兩側設有風車",
	"招式：單拳、鎖定落點的重錘\n場地：狹長工坊，重錘落點會出現紅框",
	"招式：長距離滑行衝撞\n場地：結冰貨台，兩端設有護欄",
	"招式：沿軌道衝撞\n場地：鐵軌中央有可移動的金屬箱",
	"招式：衝撞、重錘、連續重錘\n場地：封閉高塔，設有軌道與金屬箱",
]

static func opening(number: int) -> String:
	return OPENINGS[clampi(number - 1, 0, OPENINGS.size() - 1)]
