extends RefCounted
## All timers use world seconds. Export is JSON-safe exploration_run data.
const CHANGES = {"harm": -40, "debuff": -25, "neutral": -5, "buff": 15}
const EXTRA = "【待补】暮笙的额外证词"
const GIFT = "【待补】暮笙的赠礼"
var npcs: Dictionary = {}
static func tier(value: int) -> String:
	if value <= -60: return "敌对"
	if value <= -20: return "警惕"
	if value < 20: return "中立"
	if value < 60: return "友善"
	return "信赖"
func entry(id: String) -> Dictionary:
	if not npcs.has(id): npcs[id] = {"value": 0, "buff_remaining": 0.0, "intel_received": false, "gifts_received": [], "hostile": false}
	return npcs[id]
func load_run(run: Dictionary) -> void:
	npcs = run.get("npc_attitudes", {}).duplicate(true)
func save_into(run: Dictionary) -> void:
	run.npc_attitudes = npcs.duplicate(true)
func advance(delta: float) -> void:
	for id in npcs: npcs[id].buff_remaining = maxf(0.0, float(npcs[id].buff_remaining) - delta)
func apply(id: String, nature: String) -> Dictionary:
	var npc := entry(id)
	var before := tier(int(npc.value))
	if not CHANGES.has(nature): return {"changed": false, "tier": before}
	if nature == "buff":
		if float(npc.buff_remaining) > 0.000001: return {"changed": false, "tier": before}
		npc.buff_remaining = 60.0
	npc.value = clampi(int(npc.value) + int(CHANGES[nature]), -100, 100)
	var after := tier(int(npc.value))
	if after == "敌对": npc.hostile = true
	return {"changed": before != after, "tier": after}
func can_interact(id: String) -> bool:
	return not bool(entry(id).hostile)
func claim_gift(id: String) -> Array:
	var npc := entry(id)
	if not can_interact(id) or int(npc.value) < 60 or GIFT in npc.gifts_received: return []
	npc.gifts_received.append(GIFT)
	return [GIFT]
func interaction_rewards(id: String) -> Dictionary:
	var npc := entry(id)
	var rewards := {"evidence": [], "gifts": []}
	if not can_interact(id): return rewards
	if int(npc.value) >= 20 and not npc.intel_received:
		npc.intel_received = true
		rewards.evidence.append(EXTRA)
	rewards.gifts = claim_gift(id)
	return rewards
