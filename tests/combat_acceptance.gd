extends SceneTree

const Model = preload("res://scripts/combat/combat_model.gd")
const Policy = preload("res://tests/battle_policy.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)

func close(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001

func make(encounter: String = "boss", types: Array = []) -> RefCounted:
	var model = Model.new()
	var config := {}
	if not types.is_empty():
		var loadout: Array = []
		for i in types.size():
			loadout.append({"id":"test_" + str(i), "type":types[i]})
		config.loadout = loadout
	check(model.start_battle(encounter, config), "start " + encounter)
	return model

func card_of(model, type: String, index: int = 0) -> Dictionary:
	for card in model.get_snapshot().cards:
		if card.type == type:
			if index == 0:
				return card
			index -= 1
	return {}

func actor(model, kind: String = "boss") -> Dictionary:
	for enemy in model.get_snapshot().enemies:
		if enemy.kind == kind:
			return enemy
	return {}

func cast(model, type: String, target: String = "", index: int = 0) -> bool:
	var card := card_of(model, type, index)
	return not card.is_empty() and model.select_card(card.id) and model.play_selected(target)

func cast_ready(model, type: String, target: String = "") -> bool:
	for card in model.get_snapshot().cards:
		if card.type == type and card.playable:
			return model.select_card(card.id) and model.play_selected(target)
	return false

func run_to(model, battle_time: float) -> void:
	var guard := 0
	while float(model.get_snapshot().time) < battle_time - 0.00001 and model.get_snapshot().status == "active" and guard < 100000:
		model.tick(minf(0.05, (battle_time - float(model.get_snapshot().time)) / float(model.get_snapshot().time_scale)))
		guard += 1

func _run() -> void:
	_test_loadouts()
	_test_costs_and_clock()
	_test_cards()
	_test_support_anchors()
	_test_recovery()
	_test_normal_battles()
	_test_phase_three()
	print("COMBAT_ACCEPTANCE checks=", checks, " failures=", failures.size())
	for failure in failures:
		print("FAILED: ", failure)
	quit(0 if failures.is_empty() else 1)

func _test_loadouts() -> void:
	var m = make()
	var snapshot: Dictionary = m.get_snapshot()
	check(snapshot.cards.size() == 10, "default ten physical cards")
	var counts := {"fire":0, "shield":0, "charge":0}
	for card in snapshot.cards:
		counts[card.type] += 1
	check(counts == {"fire":4, "shield":4, "charge":2}, "default 4/4/2")
	check(m.get_card_catalog().size() == 9, "nine card types")
	for key in ["hand", "deck", "draw", "draw_queue"]:
		check(not snapshot.has(key), "no legacy " + key)
	check(not m.start_battle("boss", {"loadout":[]}), "explicit empty rejected")
	check(not m.start_battle("boss", {"loadout":[{"id":"old", "type":"insight"}]}), "removed type rejected")
	check(not m.start_battle("boss", {"loadout":[{"id":"dup", "type":"fire"}, {"id":"dup", "type":"shield"}]}), "duplicate physical ID rejected")
	var loadout: Array = []
	for i in 30:
		loadout.append({"id":"physical_" + str(i), "type":"fire"})
	check(m.start_battle("boss", {"loadout":loadout}), "unlimited loadout accepted")
	check(m.get_snapshot().cards.size() == 30, "all thirty equipped cards present")
	for i in 30:
		check(m.get_snapshot().cards[i].id == "physical_" + str(i), "stable equipment order " + str(i))
	check(m.start_battle("boss", {"loadout":[{"id":"one", "type":"fire"}, {"id":"two", "type":"fire"}], "upgrades":{"one":"damage", "two":"cost"}}), "physical upgrades start")
	check(card_of(m, "fire").damage == 8 and card_of(m, "fire", 1).damage == 6, "upgrade affects only requested entity")
	check(card_of(m, "fire", 1).cost == 1 and not card_of(m, "fire", 1).has("upgraded"), "unsupported upgrade cannot modify cost or claim upgrade")
	check(not m.get_card_catalog().echo.has("trial") and not m.get_card_catalog().delay.has("trial"), "permanent time cards have no legacy trial flag")

func _test_costs_and_clock() -> void:
	var m = make()
	var fire := card_of(m, "fire")
	check(m.select_card(fire.id), "select without spending")
	check(m.get_snapshot().energy == 3, "selection free")
	check(not m.play_selected("missing"), "invalid target rejected")
	check(m.get_snapshot().energy == 3 and close(card_of(m, "fire").remaining, 0), "invalid target has no cost/cooldown")
	m.tick(1.0)
	check(close(m.get_snapshot().time, 0.2) and close(m.get_snapshot().focus, 5.0), "0.2 scale uses real focus")
	check(close(actor(m).charge, 0.2), "enemy clock scales")
	m.cancel_selection()
	check(m.get_snapshot().energy == 3 and close(card_of(m, "fire").remaining, 0), "cancel has no cost/cooldown")
	m.tick(3.0)
	check(close(m.get_snapshot().time, 3.2) and close(m.get_snapshot().focus, 6.0), "normal 3:1 focus restore")
	m.select_card(fire.id)
	m.tick(1.5)
	check(close(m.get_snapshot().time, 3.9), "cancel/reselect does not refresh two-second window")
	m.cancel_selection()
	check(cast(m, "fire", actor(m).id), "physical fire cast")
	check(card_of(m, "fire").remaining > 0 and close(card_of(m, "fire", 1).remaining, 0), "same-name copies independent cooldown")
	m.tick(0.12)
	m.select_card(card_of(m, "shield").id)
	var cooldown_before: float = card_of(m, "fire").remaining
	var charge_before: float = actor(m).charge
	m.tick(0.5)
	check(close(cooldown_before - card_of(m, "fire").remaining, 0.1) and close(actor(m).charge - charge_before, 0.1), "cooldown and enemy share slowed combat clock")
	m.cancel_selection()
	var ids: Array = []
	for card in m.get_snapshot().cards: ids.append(card.id)
	var before: Dictionary = m.get_snapshot()
	m.set_paused(true)
	m.tick(20)
	var paused: Dictionary = m.get_snapshot()
	check(close(paused.time, before.time) and close(paused.focus, before.focus) and paused.pending == before.pending, "pause freezes all clocks")
	m.set_paused(false)
	run_to(m, before.time + 4.0)
	check(close(card_of(m, "fire").remaining, 0), "cooldown ends directly equipped")
	var after_ids: Array = []
	for card in m.get_snapshot().cards: after_ids.append(card.id)
	check(ids == after_ids, "casting preserves card positions")
	var exhausted = make()
	for i in 3:
		check(cast(exhausted, "shield", "", i), "spend energy " + str(i))
	check(not exhausted.select_card(card_of(exhausted, "fire").id), "insufficient energy selection rejected")
	check(exhausted.get_snapshot().energy == 0 and close(card_of(exhausted, "fire").remaining, 0), "insufficient energy free")
	var focus_model = make()
	for i in 3:
		check(focus_model.select_card(card_of(focus_model, "shield", i).id), "focus selection cycle")
		focus_model.tick(2.0)
		check(focus_model.play_selected(), "focus setup cast")
		focus_model.tick(0.12)
	check(focus_model.get_snapshot().focus < 0.13, "six real seconds focus spent without cast refresh")
	# Zero energy prevents selecting another card; wait for the scheduled +1.
	run_to(focus_model, 3.0)
	check(focus_model.select_card(card_of(focus_model, "fire").id), "low-focus selection still usable")
	focus_model.tick(5.0)
	check(focus_model.get_snapshot().time_scale == 1.0 and focus_model.get_snapshot().slow_remaining == 0, "focus exhaustion returns normal speed without blocking cards")
	check(focus_model.play_selected(actor(focus_model).id), "can play after focus exhausted")

func _test_cards() -> void:
	var m = make("boss", ["charge", "charge", "fire", "ember", "ignite", "ember_shield", "heavy_shield", "echo", "delay", "shield"])
	check(not m.select_card(card_of(m, "echo").id), "echo requires previous base card")
	check(cast(m, "charge"), "charge registered")
	check(not m.select_card(card_of(m, "charge", 1).id), "charge pending singleton")
	m.select_card(card_of(m, "fire").id)
	m.tick(1.0)
	check(close(m.get_snapshot().time, 0.2), "pending charge shares slowed clock")
	check(close(m.get_snapshot().pending[0].remaining, 5.8), "charge due countdown scaled")
	m.cancel_selection()
	run_to(m, 6.0)
	check(m.get_snapshot().energy == 5, "charge and regeneration capped at five")
	check(cast(m, "ember", actor(m).id), "ember cast")
	run_to(m, 6.12)
	check(actor(m).burn == 2, "ember adds two stacks")
	check(cast(m, "ignite", actor(m).id), "ignite cast")
	run_to(m, 6.24)
	check(actor(m).hp == 111 and actor(m).burn == 0, "ignite 3+two*3 damage")
	check(cast(m, "delay", actor(m).id), "delay cast")
	check(not m.select_card(card_of(m, "delay").id), "delay cooldown rejects re-use")
	run_to(m, 12.24)
	check(actor(m).hp == 103, "delay deals eight once")
	check(cast(m, "fire", actor(m).id), "base fire before echo")
	run_to(m, 12.36)
	check(cast(m, "echo"), "echo records base fire")
	run_to(m, 16.36)
	check(actor(m).hp == 91, "echo replays six without new copy or cost")
	check(m.get_snapshot().cards.size() == 10, "echo never adds physical card")
	var defense = make("boss", ["ember_shield", "heavy_shield", "shield"])
	run_to(defense, 4.88)
	check(cast(defense, "ember_shield"), "defense simultaneous cast")
	run_to(defense, 5.0)
	check(defense.get_snapshot().hp == 50 and defense.get_snapshot().shield == 1 and actor(defense).burn == 2, "defense precedes same instant attack and burns attacker")
	run_to(defense, 10.0)
	check(actor(defense).hp == 116 and actor(defense).burn == 0, "natural burn resolves before action")
	check(cast(defense, "heavy_shield"), "heavy shield cast")
	run_to(defense, 10.12)
	check(defense.get_snapshot().shield == 10, "heavy ten shield")
	run_to(defense, 16.12)
	check(defense.get_snapshot().shield == 0, "shield batches expire independently")
	var fizzle = make("patrol", ["delay", "fire", "fire", "echo"])
	var victim: String = actor(fizzle, "guard").id
	check(cast(fizzle, "delay", victim), "fizzle delay setup")
	for i in 2:
		check(cast(fizzle, "fire", victim, i), "fizzle fire setup")
		run_to(fizzle, fizzle.get_snapshot().time + 0.12)
	run_to(fizzle, 6.0)
	check(actor(fizzle, "guard").id != victim, "delay only original target")
	check(actor(fizzle, "guard").hp == 20, "delay never retargets")
	var disappeared = Model.new()
	check(disappeared.start_battle("patrol", {"loadout":[{"id":"d", "type":"delay"}, {"id":"f1", "type":"fire"}, {"id":"f2", "type":"fire"}, {"id":"f3", "type":"fire"}, {"id":"e", "type":"echo"}], "upgrades":{"f1":"damage", "f2":"damage", "f3":"damage"}}), "delayed-target invalidation setup")
	var original: String = actor(disappeared, "guard").id
	check(cast(disappeared, "delay", original), "register delay before target death")
	check(cast(disappeared, "fire", original, 0), "first upgraded fire")
	check(cast(disappeared, "fire", original, 1), "second upgraded fire")
	run_to(disappeared, 3.0)
	check(cast(disappeared, "fire", original, 2), "third upgraded fire kills original")
	run_to(disappeared, 3.12)
	check(actor(disappeared, "guard").id != original, "original target actually removed")
	run_to(disappeared, 6.0)
	var fizzled := false
	for event in disappeared.take_events():
		if event.type == "fizzle" and event.target == original: fizzled = true
	check(fizzled and actor(disappeared, "guard").hp == 20, "registered delay fizzles after original target dies")
	run_to(disappeared, 9.0)
	check(cast(disappeared, "echo"), "echo records invalid original target")
	run_to(disappeared, 13.0)
	fizzled = false
	for event in disappeared.take_events():
		if event.type == "fizzle" and event.target == original: fizzled = true
	check(fizzled and actor(disappeared, "guard").hp == 20, "echo never retargets invalid original target")

func _test_recovery() -> void:
	var m = make()
	while m.get_snapshot().phase < 2:
		var action: Dictionary = Policy.choose(m.get_snapshot())
		if not action.is_empty():
			check(m.select_card(action.card_id) and m.play_selected(action.target_id), "normal cards reach phase two")
		m.tick(0.05)
	var rec: Dictionary = m.get_snapshot().recovery
	check(rec.total_anchors == 2 and rec.living_anchors == 2, "phase two immediate two anchors")
	var recorded: int = rec.recorded_hp
	var anchor_id := ""
	for enemy in m.get_snapshot().enemies:
		if enemy.is_anchor: anchor_id = enemy.id; break
	while m.get_snapshot().energy < 1: m.tick(0.05)
	check(cast_ready(m, "fire", anchor_id), "one fire destroys anchor")
	run_to(m, m.get_snapshot().time + 0.12)
	check(m.get_snapshot().recovery.living_anchors == 1, "one anchor removed")
	while m.get_snapshot().energy < 1: m.tick(0.05)
	var remaining_fire := ""
	for card in m.get_snapshot().cards:
		if card.type == "fire" and card.playable: remaining_fire = card.id; break
	check(m.select_card(remaining_fire) and m.play_selected(actor(m).id), "damage recorded boss normally")
	run_to(m, m.get_snapshot().time + 0.12)
	var before_hp: int = actor(m).hp
	run_to(m, rec.due)
	check(actor(m).hp == before_hp + ceili((recorded - before_hp) / 2.0), "one destroyed anchor halves recovery")
	check(m.get_snapshot().phase == 2, "recovery never regresses phase")
	check(m.get_snapshot().recovery.is_empty(), "recovery clears round")
	run_to(m, rec.due + 6.0)
	check(m.get_snapshot().recovery.total_anchors == 2, "reanchor after six seconds")
	for enemy in m.get_snapshot().enemies:
		if enemy.is_anchor:
			while m.get_snapshot().energy < 1: m.tick(0.05)
			var ready_fire := ""
			for card in m.get_snapshot().cards:
				if card.type == "fire" and card.playable: ready_fire = card.id; break
			check(m.select_card(ready_fire) and m.play_selected(enemy.id), "break all anchors normally")
			run_to(m, m.get_snapshot().time + 0.12)
	check(m.get_snapshot().recovery.is_empty() and close(actor(m).charge, 0), "all anchors cut recovery and reset charge")

func _test_support_anchors() -> void:
	var m = make("stairs")
	run_to(m, 6.0)
	var instrument_id: String = actor(m, "instrument").id
	var small_anchor := ""
	for enemy in m.get_snapshot().enemies:
		if enemy.is_anchor:
			small_anchor = enemy.id
			check(enemy.hp == 4 and enemy.duration == 0, "instrument small anchor four health no action")
	check(small_anchor != "", "instrument creates small anchor at six seconds")
	check(cast(m, "fire", instrument_id), "damage anchored ally normally")
	run_to(m, 6.12)
	check(actor(m, "instrument").hp == 10, "anchored ally takes damage")
	run_to(m, 12.0)
	check(actor(m, "instrument").shield == 4, "instrument with existing anchor gives four shield")
	run_to(m, 16.0)
	check(actor(m, "instrument").hp == 16, "small anchor recovers recorded ally health after ten seconds")
	var broken = make("stairs", ["fire", "ember", "ignite"])
	run_to(broken, 6.0)
	small_anchor = ""
	for enemy in broken.get_snapshot().enemies:
		if enemy.is_anchor: small_anchor = enemy.id
	check(cast(broken, "ember", small_anchor), "anchor accepts burn")
	run_to(broken, 10.0)
	var found: Dictionary = {}
	for enemy in broken.get_snapshot().enemies:
		if enemy.id == small_anchor: found = enemy
	check(not found.is_empty() and found.hp == 4 and found.burn == 2, "nonacting anchor never naturally triggers burn")
	check(cast(broken, "ignite", small_anchor), "ignite destroys burned anchor")
	run_to(broken, 10.12)
	var remaining_small_recovery := false
	for effect in broken.get_snapshot().pending:
		if effect.kind == "small_recovery": remaining_small_recovery = true
	check(not remaining_small_recovery, "breaking small anchor cancels recovery immediately")
	check(cast(broken, "fire", actor(broken, "instrument").id), "damage after breaking small anchor")
	run_to(broken, 16.0)
	check(actor(broken, "instrument").hp == 10, "broken small anchor cannot heal ally")

func _test_normal_battles() -> void:
	for encounter in ["tutorial", "stairs", "patrol", "lamp", "elite", "corridor", "boss"]:
		var m = make(encounter)
		var phases: Array = []
		var cuts := 0
		var echoes := 0
		var steps := 0
		while m.get_snapshot().status == "active" and steps < 20000:
			var snap: Dictionary = m.get_snapshot()
			if not phases.has(snap.phase): phases.append(snap.phase)
			var action: Dictionary = Policy.choose(snap)
			if not action.is_empty():
				check(m.select_card(action.card_id) and m.play_selected(action.target_id), encounter + " normal policy cast")
			m.tick(0.05)
			for event in m.take_events():
				if event.type == "recovery_cut": cuts += 1
				if event.type == "hit" and event.message.begins_with("残响"): echoes += 1
			steps += 1
		check(m.get_snapshot().status == "won", encounter + " normal card victory")
		print("NORMAL_BATTLE ", encounter, " status=", m.get_snapshot().status, " hp=", m.get_snapshot().hp, " time=", snappedf(m.get_snapshot().time, 0.01), " phases=", phases, " recovery_cuts=", cuts, " echoes=", echoes)
		if encounter == "boss":
			check(phases == [1, 2, 3], "boss all three phases visited")
			check(cuts > 0, "boss anchor cuts observed")
	var loss = make("boss")
	loss.tick(200.0)
	check(loss.get_snapshot().status == "lost" and loss.get_snapshot().hp == 0, "normal incoming damage causes failure")
	check(loss.retry_battle(), "retry existing battle")
	check(loss.get_snapshot().hp == 50 and loss.get_snapshot().time == 0 and loss.get_snapshot().cards.size() == 10 and loss.get_snapshot().focus == 6, "retry resets encounter clocks and physical cards")

func _test_phase_three() -> void:
	var m = make("boss")
	var steps := 0
	while m.get_snapshot().phase < 3 and m.get_snapshot().status == "active" and steps < 10000:
		var action: Dictionary = Policy.choose(m.get_snapshot())
		if not action.is_empty():
			check(m.select_card(action.card_id) and m.play_selected(action.target_id), "phase-three setup normal cast")
		m.tick(0.05)
		steps += 1
	check(m.get_snapshot().phase == 3, "reach phase three without mutation")
	m.take_events()
	var saw_echo := false
	var saw_round := false
	var phase_three_start: float = m.get_snapshot().time
	while not saw_echo and m.get_snapshot().status == "active" and m.get_snapshot().time < phase_three_start + 20.0:
		var snapshot: Dictionary = m.get_snapshot()
		if not snapshot.recovery.is_empty():
			saw_round = snapshot.recovery.total_anchors == 1
		var threat := false
		for enemy in snapshot.enemies:
			if enemy.kind == "boss" and float(enemy.duration) - float(enemy.charge) < 0.5: threat = true
		for effect in snapshot.pending:
			if effect.kind == "enemy_echo" and float(effect.remaining) < 0.5: threat = true
		if threat and snapshot.shield < 3:
			cast_ready(m, "shield")
		m.tick(0.05)
		for event in m.take_events():
			if event.type == "hit" and event.message.begins_with("残响复演"):
				saw_echo = true
	check(saw_round, "phase three reanchors with one six-health anchor")
	check(saw_echo and m.get_snapshot().status == "active", "phase three residual damage really resolves and is survivable")
	while m.get_snapshot().status == "active" and steps < 20000:
		var action: Dictionary = Policy.choose(m.get_snapshot())
		if not action.is_empty():
			check(m.select_card(action.card_id) and m.play_selected(action.target_id), "after residual normal cast")
		m.tick(0.05)
		steps += 1
	check(m.get_snapshot().status == "won", "normal victory after deliberately observing residual")
	print("BOSS_RESIDUAL_VERIFIED status=", m.get_snapshot().status, " hp=", m.get_snapshot().hp, " time=", snappedf(m.get_snapshot().time, 0.01))
