extends RefCounted
## All combat effects use this clock; focus alone uses real time.
const EPS := 0.00001
const CAST_TIME := 0.12
const CATALOG := {
	"fire": {"name":"灵性之火", "cost":1, "cooldown":4.0, "target":"enemy", "damage":6, "description":"造成6点伤害。"},
	"shield": {"name":"书页护幕", "cost":1, "cooldown":6.0, "target":"self", "shield":5, "description":"获得5护盾，持续8战斗秒。"},
	"charge": {"name":"蓄势", "cost":1, "cooldown":10.0, "target":"self", "description":"6战斗秒后获得2灵能；同名待结算项至多1个。"},
	"ember": {"name":"烬印", "cost":1, "cooldown":8.0, "target":"enemy", "burn":2, "description":"施加2层灼烧；蓄力完成前每层造成2伤害并清除。"},
	"ignite": {"name":"焚页", "cost":1, "cooldown":10.0, "target":"enemy", "damage":3, "description":"造成3伤害，立即引燃全部灼烧，每层3伤害。"},
	"ember_shield": {"name":"灼纹护幕", "cost":1, "cooldown":8.0, "target":"self", "shield":4, "burn":2, "description":"获得4护盾8秒；首次抵挡攻击时对攻击者施加2层灼烧。"},
	"heavy_shield": {"name":"书页重护", "cost":2, "cooldown":12.0, "target":"self", "shield":10, "description":"获得10护盾，持续6战斗秒。"},
	"echo": {"name":"余时回响", "cost":2, "cooldown":16.0, "target":"self", "description":"记录最近的火或护幕及原目标，4秒后复演一次。"},
	"delay": {"name":"迟刻", "cost":1, "cooldown":12.0, "target":"enemy", "damage":8, "description":"6秒后对原目标造成8伤害；同目标至多1个。"},
}
var status := "idle"
var time := 0.0
var hp := 50
var max_hp := 50
var energy := 3
var max_energy := 5
var focus := 6.0
var max_focus := 6.0
var selected_card_id := ""
var paused := false
var phase := 0
var cards: Array = []
var enemies: Array = []
var pending: Array = []
var shield_batches: Array = []
var recovery: Dictionary = {}
var last_message := ""
var _events: Array = []
var _upgrades: Dictionary = {}
var _energy_due := 3.0
var _slow_remaining := 2.0
var _cast_slow_until := -1.0
var _cycle_complete := true
var _slow_limit := 2.0
var _id_counter := 0
var _last_base: Dictionary = {}
var _reanchor_due := -1.0
var _config: Dictionary = {}
var _encounter := ""
var spatial_mode := false
var _spatial_actions: Array = []
var _spatial_live: Dictionary = {}

func get_card_catalog() -> Dictionary:
	return CATALOG.duplicate(true)

func start_battle(encounter: String, config: Dictionary = {}) -> bool:
	if encounter not in ["tutorial", "stairs", "patrol", "lamp", "elite", "corridor", "boss"]:
		return false
	var loadout: Array = config.get("loadout", _default_loadout())
	var accepted: Array = []
	var ids: Dictionary = {}
	for item in loadout:
		if not item is Dictionary:
			continue
		var id := str(item.get("id", ""))
		var type := str(item.get("type", ""))
		if id == "" or not CATALOG.has(type):
			continue
		if ids.has(id):
			return false
		ids[id] = true
		var card: Dictionary = CATALOG[type].duplicate(true)
		card["id"] = id
		card["type"] = type
		card["ready_at"] = 0.0
		accepted.append(card)
	if accepted.is_empty():
		return false
	spatial_mode = bool(config.get("spatial_mode", false))
	_spatial_actions.clear()
	_spatial_live.clear()
	_config = config.duplicate(true)
	_encounter = encounter
	status = "active"
	time = 0.0
	max_hp = 50
	hp = clampi(int(config.get("hp", 50)), 1, max_hp)
	energy = 3
	max_focus = 12.0 if config.get("relaxed_focus", false) else 6.0
	focus = max_focus
	_slow_limit = 4.0 if config.get("relaxed_focus", false) else 2.0
	_slow_remaining = _slow_limit
	_cast_slow_until = -1.0
	_cycle_complete = true
	selected_card_id = ""
	paused = false
	phase = 1 if encounter == "boss" else 0
	_id_counter = 0
	cards = accepted
	enemies = []
	pending = []
	shield_batches = []
	recovery = {}
	_events = []
	_last_base = {}
	_energy_due = 3.0
	_reanchor_due = -1.0
	_upgrades = config.get("upgrades", {}).duplicate(true)
	for card in cards:
		_apply_upgrade(card)
	match encounter:
		"tutorial": _add_enemy("tutorial", "巡刻卫兵·教学", 12)
		"stairs":
			_add_enemy("guard", "巡刻卫兵", 20)
			_add_enemy("instrument", "黄铜星仪", 16)
		"patrol":
			_add_enemy("guard", "巡刻卫兵甲", 20)
			_add_enemy("guard", "巡刻卫兵乙", 20)
		"lamp":
			_add_enemy("guard", "巡刻卫兵", 20)
			_add_enemy("observer", "回声观测员", 12)
		"elite":
			_add_enemy("elite", "整点卫兵", 34)
			_add_enemy("instrument", "黄铜星仪", 16)
		"corridor":
			_add_enemy("guard", "巡刻卫兵", 20)
			_add_enemy("instrument", "黄铜星仪", 16)
			_add_enemy("observer", "回声观测员", 12)
		"boss": _add_enemy("boss", "克洛诺斯·试炼相", 120)
	_emit("start", "意图公开。选择已装备卡牌后确认目标，敌人持续行动。")
	return true

func _default_loadout() -> Array:
	var result: Array = []
	for type in ["fire", "shield", "charge"]:
		for i in (2 if type == "charge" else 4):
			result.append({"id":"initial_" + type + "_" + str(i + 1), "type":type})
	return result

func retry_battle() -> bool:
	return start_battle(_encounter, _config)

func _new_id(prefix: String) -> String:
	_id_counter += 1
	return prefix + "_" + str(_id_counter)

func _apply_upgrade(card: Dictionary) -> void:
	# Upgrades are bound to a permanently owned physical card.
	var upgrade = _upgrades.get(card.id, 0)
	if not upgrade:
		return
	var mode := ""
	if upgrade is String:
		mode = upgrade
	elif upgrade is Dictionary:
		mode = str(upgrade.get("stat", ""))
	if mode == "":
		mode = "damage" if card.has("damage") else ("shield" if card.has("shield") else ("burn" if card.has("burn") else "cooldown"))
	if mode not in ["damage", "shield", "burn", "cooldown"] or (mode != "cooldown" and not card.has(mode)):
		return
	if mode == "cooldown":
		card.cooldown = maxf(0.0, float(card.cooldown) - 2.0)
	elif card.has(mode):
		card[mode] += 1 if mode == "burn" else 2
	card["upgraded"] = true
	card.description += " 升级：" + mode + ("−2秒" if mode == "cooldown" else ("+1层" if mode == "burn" else "+2"))

func _add_enemy(kind: String, name: String, health: int) -> Dictionary:
	var enemy := {"id":_new_id(kind), "kind":kind, "name":name, "hp":health, "max_hp":health, "shield":0, "burn":0, "charge":0.0, "duration":4.0, "intent":"", "is_anchor":false, "action_index":0, "echo_mark":false}
	enemies.append(enemy)
	_set_intent(enemy)
	return enemy

func _set_intent(enemy: Dictionary) -> void:
	match enemy.kind:
		"tutorial", "guard":
			enemy.intent = "刺击 · " + str(2 if enemy.kind == "tutorial" else 3) + "伤害"
			enemy.duration = 4.0
		"elite":
			var heavy: bool = int(enemy.action_index) % 3 == 2
			enemy.intent = "重刺 · 8伤害" if heavy else "刺击 · 3伤害"
			enemy.duration = 7.0 if heavy else 4.0
		"instrument":
			enemy.intent = "护持 · 友方4护盾" if _owned_anchor(enemy.id) != "" else "定格 · 小锚4生命 / 10秒回收"
			enemy.duration = 6.0
		"observer":
			enemy.intent = "复述 · 标记友方下一次攻击"
			enemy.duration = 6.0
		"boss":
			var bell: bool = int(enemy.action_index) % 3 == 2
			enemy.intent = "整点钟鸣 · 9伤害" if bell else "指针斩 · 3伤害" + (" / 3秒后残响2" if phase == 3 else "")
			enemy.duration = 8.0 if bell else 5.0

func _find_card(id: String) -> Dictionary:
	for card in cards:
		if card.id == id:
			return card
	return {}

func select_card(card_id: String) -> bool:
	if paused or status != "active":
		return false
	var card := _find_card(card_id)
	if card.is_empty():
		return false
	var state := _card_state(card)
	if state != "ready":
		_emit("invalid", _state_reason(card, state))
		return false
	if selected_card_id == "" and _cycle_complete:
		_slow_remaining = _slow_limit
		_cycle_complete = false
	selected_card_id = card_id
	_emit("select", "已选：" + card.name + "；确认前不扣费。")
	return true

func cancel_selection() -> void:
	selected_card_id = ""
	# Cancellation never refreshes focus or the current selection window.
	_emit("cancel", "取消选择；专注与本次减速额度保留当前余量。")

func _card_state(card: Dictionary) -> String:
	if float(card.ready_at) > time + EPS:
		return "cooldown"
	if energy < int(card.cost):
		return "energy"
	if card.type == "charge" and _has_pending("charge"):
		return "condition"
	if card.type == "echo" and _last_base.is_empty():
		return "condition"
	if card.type == "delay":
		var available := false
		for enemy in enemies:
			if not _has_pending("delay", enemy.id):
				available = true
		if not available:
			return "condition"
	return "ready"

func _state_reason(card: Dictionary, state: String) -> String:
	match state:
		"cooldown": return "冷却中，剩余 %.1f 战斗秒。" % maxf(0.0, float(card.ready_at) - time)
		"energy": return "灵能不足，需要%d点。" % int(card.cost)
		"condition":
			if card.type == "charge": return "已有蓄势等待结算。"
			if card.type == "echo": return "本战尚未施放灵性之火或书页护幕。"
			return "全部目标已有迟刻等待结算。"
	return "可施放；确认后支付费用并开始独立冷却。"

func play_selected(target_id: String = "") -> bool:
	if paused or status != "active" or selected_card_id == "":
		return false
	var card := _find_card(selected_card_id)
	if card.is_empty() or _card_state(card) != "ready":
		_emit("invalid", "费用不足、冷却中或效果尚待结算；卡牌保留。")
		return false
	if card.target == "enemy" and _find_enemy(target_id).is_empty():
		_emit("invalid", "目标已失效，请重新选择；卡牌保留。")
		return false
	if card.type == "delay" and _has_pending("delay", target_id):
		_emit("invalid", "该目标已有迟刻；卡牌保留。")
		return false
	_commit_card(card, target_id)
	return true

func _commit_card(card: Dictionary, target_id: String) -> void:
	energy -= int(card.cost)
	card.ready_at = time + float(card.cooldown)
	selected_card_id = ""
	_cast_slow_until = time + CAST_TIME
	var effect := {"kind":"cast", "type":card.type, "due":time + CAST_TIME, "label":card.name + " · 施放", "target":target_id, "card":card.duplicate(true)}
	if card.type == "fire" or card.type == "shield":
		_last_base = {"type":card.type, "target":target_id, "amount":int(card.get("damage", card.get("shield", 0)))}
	if card.type == "charge":
		effect.kind = "charge"
		effect.due = time + 6.0
		effect.label = "蓄势 · +2灵能"
	elif card.type == "delay":
		effect.kind = "delay"
		effect.due = time + 6.0
		effect.label = "迟刻 · " + str(card.damage) + "伤害"
	elif card.type == "echo":
		effect.kind = "echo"
		effect.due = time + 4.0
		effect.label = "余时回响 · " + CATALOG[_last_base.type].name
		effect["record"] = _last_base.duplicate(true)
	pending.append(effect)
	_emit("cast", card.name + "已登记，实体卡独立冷却。", target_id)
	_events[-1]["card_id"] = card.id

func set_paused(value: bool) -> void:
	paused = value

func _time_scale() -> float:
	if status != "active" or paused:
		return 0.0
	if (selected_card_id != "" or _cast_slow_until > time + EPS) and focus > EPS and _slow_remaining > EPS:
		return 0.2
	return 1.0

func tick(real_delta: float) -> void:
	if paused or status != "active" or real_delta <= 0:
		return
	var remaining := real_delta
	while remaining > EPS and status == "active":
		var scale := _time_scale()
		var step := remaining
		if scale < 1.0:
			step = minf(step, minf(focus, _slow_remaining))
		if _cast_slow_until > time + EPS:
			step = minf(step, (_cast_slow_until - time) / scale)
		step = minf(step, maxf(EPS, (_next_due() - time) / scale))
		if scale < 1.0:
			focus = maxf(0.0, focus - step)
			_slow_remaining = maxf(0.0, _slow_remaining - step)
			if focus <= EPS:
				_slow_remaining = 0.0
		else:
			focus = minf(max_focus, focus + step / 3.0)
		_advance(step * scale)
		remaining -= step
		if _cast_slow_until >= 0 and _cast_slow_until <= time + EPS:
			_cast_slow_until = -1.0
			_cycle_complete = true

func _next_due() -> float:
	var due := _energy_due
	for enemy in enemies:
		if not enemy.is_anchor:
			due = minf(due, time + maxf(0.0, float(enemy.duration) - float(enemy.charge)))
	for effect in pending:
		due = minf(due, float(effect.due))
	for batch in shield_batches:
		due = minf(due, float(batch.due))
	if not recovery.is_empty():
		due = minf(due, float(recovery.due))
	if _reanchor_due >= 0:
		due = minf(due, _reanchor_due)
	return maxf(time + EPS, due)

func _advance(delta: float) -> void:
	time += delta
	for enemy in enemies:
		if not enemy.is_anchor:
			enemy.charge += delta
	# Defensive effects due at this instant precede every hit at this instant.
	for effect in pending.duplicate():
		if float(effect.due) <= time + EPS and _is_defensive(effect):
			pending.erase(effect)
			_resolve(effect)
	shield_batches = shield_batches.filter(func(batch): return float(batch.due) > time + EPS and int(batch.amount) > 0)
	for effect in pending.duplicate():
		if status != "active":
			break
		if float(effect.due) <= time + EPS:
			pending.erase(effect)
			_resolve(effect)
	for enemy in enemies.duplicate():
		if status != "active":
			break
		if not enemy.is_anchor and not _find_enemy(enemy.id).is_empty() and float(enemy.charge) + EPS >= float(enemy.duration):
			_enemy_action(enemy)
	if status != "active":
		return
	if not recovery.is_empty() and float(recovery.due) <= time + EPS:
		_resolve_recovery()
	if _reanchor_due >= 0 and _reanchor_due <= time + EPS:
		_reanchor_due = -1.0
		_spawn_boss_anchors()
	while _energy_due <= time + EPS:
		energy = mini(max_energy, energy + 1)
		_energy_due += 3.0

func _is_defensive(effect: Dictionary) -> bool:
	return (effect.kind == "cast" and effect.type in ["shield", "ember_shield", "heavy_shield"]) or (effect.kind == "echo" and effect.record.type == "shield")

func _resolve(effect: Dictionary) -> void:
	match effect.kind:
		"charge":
			energy = mini(max_energy, energy + 2)
			_emit("energy", "蓄势结算：+2灵能。")
		"delay": _hurt_enemy(effect.target, int(effect.card.damage), "迟刻")
		"echo":
			if effect.record.type == "shield":
				_add_shield(int(effect.record.amount), 8.0)
			else:
				if spatial_mode:
					_queue_spatial({"kind":"fire", "target":effect.record.target, "amount":int(effect.record.amount), "label":"余时回响"})
				else:
					_hurt_enemy(effect.record.target, int(effect.record.amount), "余时回响")
		"enemy_echo":
			if spatial_mode:
				_queue_spatial({"kind":"enemy", "attacker":effect.target, "amount":int(effect.amount), "label":"残响复演", "geometry":effect.get("geometry", {}), "echo":true})
			else:
				_hit_player(int(effect.amount), effect.target, "残响复演")
		"small_recovery":
			var ally := _find_enemy(effect.target)
			if not ally.is_empty() and not _find_enemy(effect.anchor).is_empty():
				ally.hp = maxi(int(ally.hp), int(effect.recorded_hp))
				_emit("recovery", "小锚回收：友方恢复至设锚生命。", ally.id)
			_remove_anchor(effect.anchor)
		"cast": _resolve_card(effect)

func _resolve_card(effect: Dictionary) -> void:
	var card: Dictionary = effect.card
	match effect.type:
		"fire":
			if spatial_mode:
				_queue_spatial({"kind":"fire", "target":effect.target, "amount":int(card.damage), "label":card.name})
			else:
				_hurt_enemy(effect.target, int(card.damage), card.name)
		"shield": _add_shield(int(card.shield), 8.0)
		"ember_shield": _add_shield(int(card.shield), 8.0, int(card.burn))
		"heavy_shield": _add_shield(int(card.shield), 6.0)
		"ember":
			var target := _find_enemy(effect.target)
			if not target.is_empty():
				target.burn += int(card.burn)
				_emit("burn", "烬印：施加" + str(card.burn) + "层灼烧。", effect.target)
		"ignite":
			var target := _find_enemy(effect.target)
			if not target.is_empty():
				var damage := int(card.damage) + int(target.burn) * 3
				target.burn = 0
				_hurt_enemy(effect.target, damage, card.name)

func _add_shield(amount: int, duration: float, burn: int = 0) -> void:
	shield_batches.append({"amount":amount, "due":time + duration, "burn":burn, "triggered":false})
	shield_batches.sort_custom(func(a, b): return a.due < b.due)
	_emit("shield", "获得" + str(amount) + "护盾，独立持续" + str(int(duration)) + "秒。", "player", amount)

func _hit_player(amount: int, attacker: String, label: String) -> void:
	var remaining := amount
	for batch in shield_batches:
		if remaining <= 0:
			break
		if int(batch.amount) <= 0:
			continue
		var blocked := mini(int(batch.amount), remaining)
		batch.amount -= blocked
		remaining -= blocked
		if blocked > 0 and int(batch.burn) > 0 and not batch.triggered:
			batch.triggered = true
			var enemy := _find_enemy(attacker)
			if not enemy.is_empty():
				enemy.burn += int(batch.burn)
				_emit("burn", "灼纹护幕首次抵挡：攻击者获得灼烧。", attacker)
	hp = maxi(0, hp - remaining)
	_emit("hit", label + "：" + str(amount) + "伤害，护盾抵挡" + str(amount - remaining) + "。", "player", remaining)
	if hp <= 0:
		status = "lost"
		selected_card_id = ""
		_emit("loss", "魔法书强制撤离。可重新挑战。")

func _hurt_enemy(id: String, amount: int, label: String) -> void:
	var enemy := _find_enemy(id)
	if enemy.is_empty():
		_emit("fizzle", label + "原目标已失效，效果消散。", id)
		return
	var blocked := mini(int(enemy.shield), amount)
	enemy.shield -= blocked
	enemy.hp = maxi(0, int(enemy.hp) - amount + blocked)
	_emit("hit", label + "命中" + enemy.name + "：" + str(amount - blocked) + "伤害。", id, amount - blocked)
	if int(enemy.hp) <= 0:
		if enemy.is_anchor:
			_destroy_anchor(enemy)
		else:
			enemies.erase(enemy)
			_cancel_small_anchors(id)
			_emit("death", enemy.name + "消散。", id)
			if enemy.kind == "boss":
				_finish_win()
			elif not _has_living_actor():
				_finish_win()
	elif enemy.kind == "boss":
		if phase == 1 and int(enemy.hp) <= 80:
			_transition_phase(2)
		if phase == 2 and int(enemy.hp) <= 40:
			_transition_phase(3)

func _finish_win() -> void:
	status = "won"
	selected_card_id = ""
	pending.clear()
	enemies.clear()
	recovery = {}
	_reanchor_due = -1.0
	_emit("win", "试炼完成。你已经看清了，那么就由你亲手推动它。")

func _enemy_action(enemy: Dictionary) -> void:
	if int(enemy.burn) > 0:
		var burn_damage := int(enemy.burn) * 2
		enemy.burn = 0
		_hurt_enemy(enemy.id, burn_damage, "灼烧 · 行动前")
		if _find_enemy(enemy.id).is_empty() or status != "active":
			return
	match enemy.kind:
		"tutorial", "guard", "elite", "boss":
			var damage := 3
			if enemy.kind == "tutorial": damage = 2
			elif enemy.kind == "elite" and int(enemy.action_index) % 3 == 2: damage = 8
			elif enemy.kind == "boss" and int(enemy.action_index) % 3 == 2: damage = 9
			if spatial_mode:
				var echo_amount := 2 if enemy.kind == "boss" and phase == 3 and int(enemy.action_index) % 3 != 2 else 0
				if enemy.echo_mark:
					echo_amount += ceili(damage / 2.0)
					enemy.echo_mark = false
				_queue_spatial({"kind":"enemy", "attacker":enemy.id, "amount":damage, "label":enemy.intent, "bell":enemy.kind == "boss" and int(enemy.action_index) % 3 == 2, "echo_amount":echo_amount})
			else:
				_hit_player(damage, enemy.id, enemy.intent)
				if status == "active":
					if enemy.kind == "boss" and phase == 3 and int(enemy.action_index) % 3 != 2:
						pending.append({"kind":"enemy_echo", "due":time + 3.0, "label":"指针斩残响 · 2伤害", "amount":2, "target":enemy.id})
					if enemy.echo_mark:
						enemy.echo_mark = false
						pending.append({"kind":"enemy_echo", "due":time + 3.0, "label":"回声复述 · " + str(ceili(damage / 2.0)) + "伤害", "amount":ceili(damage / 2.0), "target":enemy.id})
		"instrument":
			var ally := _lowest_ally()
			if not ally.is_empty():
				if _owned_anchor(enemy.id) != "":
					ally.shield += 4
					_emit("shield", "黄铜星仪护持：友方+4护盾。", ally.id)
				else:
					var anchor := _make_anchor(4, enemy.id)
					pending.append({"kind":"small_recovery", "due":time + 10.0, "label":"小锚回收 · " + ally.name, "target":ally.id, "anchor":anchor.id, "recorded_hp":int(ally.hp), "owner":enemy.id})
		"observer":
			var ally := _attack_ally()
			if not ally.is_empty():
				ally.echo_mark = true
				_emit("mark", "回声观测员标记：下一次命中后3秒复述。", ally.id)
	enemy.charge = 0.0
	enemy.action_index += 1
	_set_intent(enemy)

func _make_anchor(health: int, owner: String) -> Dictionary:
	var anchor := {"id":_new_id("anchor"), "kind":"anchor", "name":"时间锚" if health == 6 else "小锚", "hp":health, "max_hp":health, "shield":0, "burn":0, "charge":0.0, "duration":0.0, "intent":"无行动条 · 可被单体攻击击破", "is_anchor":true, "owner":owner}
	enemies.append(anchor)
	_emit("anchor", anchor.name + "生成。", anchor.id)
	return anchor

func _transition_phase(next_phase: int) -> void:
	phase = next_phase
	recovery = {}
	for enemy in enemies.duplicate():
		if enemy.is_anchor: enemies.erase(enemy)
	_reanchor_due = -1.0
	var boss := _boss()
	_set_intent(boss)
	if phase == 2:
		_spawn_boss_anchors()
		_emit("phase", "二 · 锚定：留住这一刻很容易；18秒后回收。")
	else:
		_reanchor_due = time + 6.0
		_emit("phase", "三 · 残响：指针斩3秒后复演；6秒后新一轮锚。")

func _spawn_boss_anchors() -> void:
	var boss := _boss()
	if boss.is_empty() or phase < 2:
		return
	var count := 2 if phase == 2 else 1
	var ids: Array = []
	for i in count:
		ids.append(_make_anchor(6, boss.id).id)
	recovery = {"due":time + 18.0, "recorded_hp":int(boss.hp), "total_anchors":count, "living_anchors":count, "ids":ids}
	_emit("anchor", "记录Boss生命" + str(boss.hp) + "；18秒后回收。")

func _destroy_anchor(anchor: Dictionary) -> void:
	enemies.erase(anchor)
	pending = pending.filter(func(effect): return effect.get("anchor", "") != anchor.id)
	_emit("anchor", anchor.name + "击破。", anchor.id)
	if not recovery.is_empty() and recovery.ids.has(anchor.id):
		recovery.living_anchors -= 1
		if int(recovery.living_anchors) <= 0:
			recovery = {}
			var boss := _boss()
			if not boss.is_empty(): boss.charge = 0.0
			_reanchor_due = time + 6.0
			_emit("recovery_cut", "全部锚击破：回收截断，Boss当前蓄力清零；6秒后重锚。")
	for enemy in enemies:
		if enemy.kind == "instrument": _set_intent(enemy)

func _remove_anchor(id: String) -> void:
	var anchor := _find_enemy(id)
	if not anchor.is_empty(): enemies.erase(anchor)
	for enemy in enemies:
		if enemy.kind == "instrument": _set_intent(enemy)

func _resolve_recovery() -> void:
	var boss := _boss()
	if boss.is_empty():
		recovery = {}
		return
	var missing := maxi(0, int(recovery.recorded_hp) - int(boss.hp))
	var destroyed := int(recovery.total_anchors) - int(recovery.living_anchors)
	var amount := int(ceil(float(missing) / pow(2.0, destroyed)))
	boss.hp = mini(int(boss.max_hp), int(boss.hp) + amount)
	for id in recovery.ids: _remove_anchor(id)
	recovery = {}
	_reanchor_due = time + 6.0
	_emit("recovery", "锚回收：恢复" + str(amount) + "生命；6秒后重新设锚。", boss.id, amount)

func _cancel_small_anchors(id: String) -> void:
	for effect in pending.duplicate():
		if effect.kind == "small_recovery" and effect.target == id:
			_remove_anchor(effect.anchor)
			pending.erase(effect)

func _owned_anchor(owner: String) -> String:
	for enemy in enemies:
		if enemy.is_anchor and enemy.get("owner", "") == owner:
			return enemy.id
	return ""

func _lowest_ally() -> Dictionary:
	var lowest: Dictionary = {}
	for enemy in enemies:
		if not enemy.is_anchor and (lowest.is_empty() or int(enemy.hp) < int(lowest.hp)):
			lowest = enemy
	return lowest

func _attack_ally() -> Dictionary:
	for enemy in enemies:
		if enemy.kind in ["tutorial", "guard", "elite", "boss"]:
			return enemy
	return {}

func _boss() -> Dictionary:
	for enemy in enemies:
		if enemy.kind == "boss": return enemy
	return {}

func _find_enemy(id: String) -> Dictionary:
	for enemy in enemies:
		if enemy.id == id: return enemy
	return {}

func _has_living_actor() -> bool:
	for enemy in enemies:
		if not enemy.is_anchor: return true
	return false

func _has_pending(kind: String, target: String = "") -> bool:
	for effect in pending:
		if effect.kind == kind and (target == "" or effect.get("target", "") == target): return true
	return false

func _card_view(card: Dictionary) -> Dictionary:
	var view: Dictionary = card.duplicate(true)
	var state := _card_state(card)
	view["remaining"] = maxf(0.0, float(card.ready_at) - time)
	view["state"] = state
	view["reason"] = _state_reason(card, state)
	view["playable"] = state == "ready" and status == "active" and not paused
	view["selected"] = card.id == selected_card_id
	return view

func get_snapshot() -> Dictionary:
	var visible_cards: Array = []
	for card in cards:
		visible_cards.append(_card_view(card))
	var visible_pending: Array = []
	for effect in pending:
		visible_pending.append({"label":effect.label, "remaining":maxf(0.0, float(effect.due) - time), "kind":effect.kind, "target":effect.get("target", "")})
	if _reanchor_due >= 0:
		visible_pending.append({"label":"重新设锚", "remaining":maxf(0.0, _reanchor_due - time), "kind":"reanchor", "target":""})
	var rec := recovery.duplicate(true)
	if not rec.is_empty(): rec["remaining"] = maxf(0.0, float(rec.due) - time)
	var shield := 0
	var batches: Array = []
	for batch in shield_batches:
		shield += int(batch.amount)
		var view: Dictionary = batch.duplicate(true)
		view["remaining"] = maxf(0.0, float(batch.due) - time)
		batches.append(view)
	return {"spatial_mode":spatial_mode, "status":status, "time":time, "time_scale":_time_scale(), "hp":hp, "max_hp":max_hp, "shield":shield, "energy":energy, "max_energy":max_energy, "focus":focus, "max_focus":max_focus, "selected_card_id":selected_card_id, "cards":visible_cards, "enemies":enemies.duplicate(true), "phase":phase, "recovery":rec, "pending":visible_pending, "last_message":last_message, "paused":paused, "shield_batches":batches, "slow_remaining":_slow_remaining}

func _emit(type: String, message: String, target: String = "", amount: int = 0) -> void:
	last_message = message
	_events.append({"type":type, "message":message, "target":target, "amount":amount, "time":time})

func take_events() -> Array:
	var result := _events.duplicate(true)
	_events.clear()
	return result

# Runtime submits collision facts; only this model mutates health/resources.
func _queue_spatial(action: Dictionary) -> void:
	action["action_id"] = _new_id("action")
	_spatial_live[action.action_id] = action.duplicate(true)
	_spatial_actions.append(action)

func drain_spatial_actions() -> Array:
	var result := _spatial_actions.duplicate(true)
	_spatial_actions.clear()
	return result

func resolve_spatial_hit(action_id: String, geometry: Dictionary = {}) -> bool:
	if not spatial_mode or paused or status != "active" or not _spatial_live.has(action_id):
		return false
	var action: Dictionary = _spatial_live[action_id]
	_spatial_live.erase(action_id)
	if action.kind == "fire":
		if _find_enemy(action.target).is_empty():
			_emit("fizzle", "原目标失效，流光消散。", action.target)
			return false
		_hurt_enemy(action.target, int(action.amount), action.label)
	else:
		_hit_player(int(action.amount), action.attacker, action.label)
		if status == "active" and int(action.get("echo_amount", 0)) > 0:
			pending.append({"kind":"enemy_echo", "due":time+3.0, "label":"命中路径残响", "amount":int(action.echo_amount), "target":action.attacker, "geometry":geometry.duplicate(true)})
	return true

func expire_spatial_action(action_id: String) -> void:
	_spatial_live.erase(action_id)

func get_enemy(id: String) -> Dictionary:
	return _find_enemy(id).duplicate(true)
