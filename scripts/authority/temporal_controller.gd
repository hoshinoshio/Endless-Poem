extends RefCounted
signal card_applied(card_id: String, target_id: String, category: String)
const Config = preload("res://scripts/authority/time_card_config.gd")
var fast_forward_multiplier: float = Config.CARDS.fast_forward.multiplier
var history_limit: int = Config.HISTORY_LIMIT
var is_unlocked := false
var paused := false
var selected_card := ""
var selected_target := ""
var world_clock := 0.0
var cooldowns := {"stop": 0.0, "fast_forward": 0.0, "reverse": 0.0}
var _targets: Dictionary = {}
func _init(config: Dictionary = {}) -> void:
	history_limit = maxi(1, int(config.get("history_limit", Config.HISTORY_LIMIT)))
	fast_forward_multiplier = maxf(1.0, float(config.get("fast_forward_multiplier", fast_forward_multiplier)))

static func card_catalog() -> Array:
	return [
		{"id": "stop", "title": "停止时间", "icon": "pause", "authority": "time", "description": "使所选对象的局部时间停止 2 秒。"},
		{"id": "fast_forward", "title": "快进时间", "icon": "forward", "authority": "time", "description": "使所选对象的局部时间加速推进。"},
		{"id": "reverse", "title": "倒退时间", "icon": "reverse", "authority": "time", "description": "使所选对象回到 3 秒前的状态。"},
	]

func register_target(id: String, label: String, screen_rect: Callable, capture: Callable, restore: Callable, advance_local: Callable, category: String = "scene") -> bool:
	if id.is_empty() or _targets.has(id) or not Config.CATEGORIES.has(category) or not screen_rect.is_valid() or not capture.is_valid() or not restore.is_valid() or not advance_local.is_valid(): return false
	_targets[id] = {"label": label, "category": category, "rect": screen_rect, "capture": capture, "restore": restore, "advance": advance_local, "mode": "normal", "remaining": 0.0, "clock": 0.0, "sample": 0.0, "history": []}
	_record(_targets[id])
	return true
func unregister_target(id: String) -> void:
	_targets.erase(id)
	if selected_target == id: selected_target = ""
func set_category(id: String, category: String) -> void:
	if _targets.has(id) and Config.CATEGORIES.has(category): _targets[id].category = category
func set_unlocked(value: bool) -> void:
	is_unlocked = value
	if not value:
		cancel_selection()
		for id in _targets: reset_target(id)
func set_paused(value: bool) -> void:
	paused = value
func can_cast(card_id: String) -> bool:
	return is_unlocked and not paused and Config.CARDS.has(card_id) and float(cooldowns.get(card_id, 0.0)) <= 0.0
func select_card(card_id: String) -> bool:
	if not can_cast(card_id): return false
	selected_card = card_id
	return true
func select_target(id: String) -> bool:
	if not apply_card(selected_card, id): return false
	selected_target = id
	return true
func apply_card(card_id: String, id: String) -> bool:
	if not can_cast(card_id) or not _targets.has(id): return false
	var target: Dictionary = _targets[id]
	var config: Dictionary = Config.CARDS[card_id]
	target.mode = "normal" if card_id == "reverse" else card_id
	target.remaining = config.duration
	if card_id == "reverse":
		var history: Array = target.history
		var wanted := world_clock - float(config.rewind)
		while history.size() > 1 and float(history.back().time) > wanted: history.pop_back()
		if not history.is_empty():
			var frame: Dictionary = history.back()
			target.clock = frame.clock
			target.restore.call(_copy_state(frame.state))
	cooldowns[card_id] = config.cooldown
	selected_target = id
	card_applied.emit(card_id, id, target.category)
	return true
func cancel_selection() -> void:
	selected_card = ""
	selected_target = ""
func reset_target(id: String) -> bool:
	if not _targets.has(id): return false
	_targets[id].mode = "normal"
	_targets[id].remaining = 0.0
	return true
func get_target_mode(id: String) -> String:
	return str(_targets[id].mode) if _targets.has(id) else ""
func reset_target_history(id: String) -> void:
	if not reset_target(id): return
	_targets[id].clock = 0.0
	_targets[id].history = []
	_targets[id].sample = 0.0
	_record(_targets[id])
func _copy_state(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value
func _record(target: Dictionary) -> void:
	target.history.append({"time": world_clock, "clock": target.clock, "state": _copy_state(target.capture.call())})
	while target.history.size() > history_limit: target.history.pop_front()
func advance(delta: float) -> void:
	if paused or delta <= 0.0 or not is_finite(delta): return
	# Fixed upper sampling interval retains at least three world seconds even during slow-mo.
	var left := delta
	while left > 0.000001 and not paused:
		var step := minf(left, Config.HISTORY_INTERVAL)
		world_clock += step
		for card_id in cooldowns: cooldowns[card_id] = maxf(0.0, float(cooldowns[card_id]) - step)
		for id in _targets:
			if paused: break
			var target: Dictionary = _targets[id]
			var affected := minf(step, float(target.remaining))
			var local_delta := step
			if target.mode == "stop": local_delta -= affected
			elif target.mode == "fast_forward": local_delta += affected * (fast_forward_multiplier - 1.0)
			target.remaining = maxf(0.0, float(target.remaining) - step)
			if target.remaining <= 0.000001: target.mode = "normal"
			if local_delta > 0.000001:
				target.advance.call(local_delta)
				target.clock += local_delta
			target.sample += step
			if target.sample >= Config.HISTORY_INTERVAL - 0.000001:
				target.sample = maxf(0.0, float(target.sample) - Config.HISTORY_INTERVAL)
				_record(target)
		left -= step
func target_at_point(point: Vector2) -> String:
	var best := ""
	var priority := 99
	for id in _targets:
		var target: Dictionary = _targets[id]
		var rank: int = Config.PRIORITY[target.category]
		if rank < priority and target.rect.call().has_point(point):
			best = id
			priority = rank
	return best
func get_presentation() -> Dictionary:
	var targets := {}
	for id in _targets:
		var target: Dictionary = _targets[id]
		targets[id] = {"label": target.label, "category": target.category, "mode": target.mode, "remaining": target.remaining, "local_clock": target.clock, "history_count": target.history.size(), "screen_rect": target.rect.call(), "selected": selected_target == id}
	return {"unlocked": is_unlocked, "paused": paused, "selected_card": selected_card, "selected_target": selected_target, "targets": targets, "cooldowns": cooldowns.duplicate(), "demo_config": {"fast_forward_multiplier": fast_forward_multiplier, "history_limit": history_limit}}
