extends RefCounted
## Object-local exploration controller. Multipliers/history bounds are demo parameters,
## not combat rules. Capture returns a detached value; restore receives a deep copy.

var fast_forward_multiplier: float = 2.0
var history_limit: int = 240
var is_unlocked: bool = false
var paused: bool = false
var selected_card: String = ""
var selected_target: String = ""
var _targets: Dictionary = {}

func _init(config: Dictionary = {}) -> void:
	fast_forward_multiplier = maxf(1.0, float(config.get("fast_forward_multiplier", 2.0)))
	history_limit = maxi(1, int(config.get("history_limit", 240)))

static func card_catalog() -> Array:
	return [
		{"id": "stop", "title": "停止时间", "icon": "pause", "description": "暂停所选对象的局部时间。"},
		{"id": "fast_forward", "title": "快进时间", "icon": "forward", "description": "加速所选对象的局部时间。"},
		{"id": "reverse", "title": "倒退时间", "icon": "reverse", "description": "沿所选对象已有记录倒退。"},
	]

func register_target(id: String, label: String, screen_rect: Callable, capture: Callable, restore: Callable, advance_local: Callable) -> bool:
	if id.is_empty() or _targets.has(id) or not screen_rect.is_valid() or not capture.is_valid() or not restore.is_valid() or not advance_local.is_valid():
		return false
	_targets[id] = {"label": label, "rect": screen_rect, "capture": capture, "restore": restore, "advance": advance_local, "mode": "normal", "clock": 0.0, "history": []}
	return true

func unregister_target(id: String) -> void:
	_targets.erase(id)
	if selected_target == id:
		selected_target = ""

func set_unlocked(value: bool) -> void:
	is_unlocked = value
	if not value:
		cancel_selection()
		for id in _targets:
			reset_target(id)

func set_paused(value: bool) -> void:
	paused = value

func select_card(mode: String) -> bool:
	if not is_unlocked or not _valid_card(mode):
		return false
	selected_card = mode
	return true

func select_target(id: String) -> bool:
	if not apply_card(selected_card, id):
		return false
	selected_target = id
	return true

func apply_card(mode: String, id: String) -> bool:
	if not is_unlocked or not _valid_card(mode) or not _targets.has(id):
		return false
	_targets[id]["mode"] = mode
	return true

func cancel_selection() -> void:
	selected_card = ""
	selected_target = ""

func reset_target(id: String) -> bool:
	if not _targets.has(id):
		return false
	_targets[id]["mode"] = "normal"
	return true

func get_target_mode(id: String) -> String:
	return str(_targets[id]["mode"]) if _targets.has(id) else ""

func reset_target_history(id: String) -> void:
	if not _targets.has(id): return
	_targets[id]["mode"] = "normal"
	_targets[id]["clock"] = 0.0
	_targets[id]["history"] = []

func _valid_card(mode: String) -> bool:
	return mode in ["stop", "fast_forward", "reverse"]

func _copy_state(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value

func _record(target: Dictionary) -> void:
	var history: Array = target["history"]
	history.append({"clock": target["clock"], "state": _copy_state(target["capture"].call())})
	while history.size() > history_limit:
		history.pop_front()

func advance(real_delta: float) -> void:
	if paused or real_delta <= 0.0 or not is_finite(real_delta):
		return
	for id in _targets:
		if paused: break
		var target: Dictionary = _targets[id]
		var mode: String = target["mode"]
		var history: Array = target["history"]
		if mode == "stop":
			continue
		if mode == "reverse":
			if history.is_empty():
				continue
			var wanted: float = maxf(float(history[0]["clock"]), float(target["clock"]) - real_delta)
			while history.size() > 1 and float(history.back()["clock"]) > wanted:
				history.pop_back()
			# Rewind only to captured states; discard the abandoned future branch.
			var frame: Dictionary = history.back()
			target["clock"] = frame["clock"]
			target["restore"].call(_copy_state(frame["state"]))
			continue
		if history.is_empty():
			_record(target)
		var delta: float = real_delta * (fast_forward_multiplier if mode == "fast_forward" else 1.0)
		target["advance"].call(delta)
		target["clock"] = float(target["clock"]) + delta
		_record(target)

func target_at_point(point: Vector2) -> String:
	var ids: Array = _targets.keys()
	ids.reverse()
	# A creature's body takes precedence over broad scenery rectangles behind it.
	for id in ids:
		if str(id).begins_with("enemy_") and _targets[id]["rect"].call().has_point(point):
			return str(id)
	for id in ids:
		var rect: Rect2 = _targets[id]["rect"].call()
		if rect.has_point(point):
			return str(id)
	return ""

func get_presentation() -> Dictionary:
	var targets: Dictionary = {}
	for id in _targets:
		var target: Dictionary = _targets[id]
		targets[id] = {"label": target["label"], "mode": target["mode"], "local_clock": target["clock"], "history_count": target["history"].size(), "screen_rect": target["rect"].call(), "selected": selected_target == id}
	return {"unlocked": is_unlocked, "paused": paused, "selected_card": selected_card, "selected_target": selected_target, "targets": targets, "demo_config": {"fast_forward_multiplier": fast_forward_multiplier, "history_limit": history_limit}}
