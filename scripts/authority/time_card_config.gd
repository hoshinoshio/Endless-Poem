extends RefCounted
## Stage B greybox values. Tune here; these are not final combat balance.
const CATEGORIES = {"hero": "主角", "monster": "怪物", "npc": "NPC", "item": "道具", "scene": "场景"}
const PRIORITY = {"hero": 1, "monster": 2, "npc": 3, "item": 4, "scene": 5}
const CARDS = {
	"stop": {"title": "停止时间", "duration": 2.0, "cooldown": 6.0, "multiplier": 0.0, "preview": "局部时间停止 · 2 秒", "nature": {"hero": "debuff", "monster": "debuff", "npc": "debuff", "item": "neutral", "scene": "neutral"}},
	"fast_forward": {"title": "快进时间", "duration": 4.0, "cooldown": 8.0, "multiplier": 2.0, "preview": "局部时间 2 倍速 · 4 秒", "nature": {"hero": "buff", "monster": "buff", "npc": "buff", "item": "neutral", "scene": "neutral"}},
	"reverse": {"title": "倒退时间", "duration": 0.0, "cooldown": 10.0, "rewind": 3.0, "preview": "瞬时回到 3 秒前", "nature": {"hero": "neutral", "monster": "neutral", "npc": "neutral", "item": "neutral", "scene": "neutral"}},
}
const HISTORY_INTERVAL = 1.0 / 30.0
const HISTORY_LIMIT = 128 # More than 3 seconds at 30 samples per world second.
const DRAG_TIME_SCALE = 0.05
