extends SceneTree
const Map = preload("res://scripts/ui/cosmic_star_map.gd")
var failures: Array = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _initialize() -> void:
	var a = Map.new()
	var b = Map.new()
	a.configure_test_seed(715)
	b.configure_test_seed(716)
	check(a.presentation_state().stars != b.presentation_state().stars, "Different seeds must produce different initial distributions")
	var copy = a.presentation_state().stars
	copy.clear()
	check(a.presentation_state().stars.size() == 260, "State snapshots must not mutate background")
	var first: Dictionary = {}
	for frame in range(3600):
		a.advance(0.1)
		var state = a.presentation_state()
		check(state.active_anomalies.size() <= state.max_active, "Concurrent anomaly cap")
		check(state.recent_events.size() <= state.history_limit, "History cap")
		if first.is_empty() and not state.active_anomalies.is_empty(): first = state.active_anomalies[0].duplicate(true)
		if not first.is_empty() and state.elapsed > first.start + first.duration:
			check(not state.active_anomalies.any(func(event): return event.start == first.start and event.star_id == first.star_id), "Expired event must finish")
	check(not first.is_empty(), "Random scheduler must emit events")
	var history = a.recent_anomaly_events
	var ids = {}
	var kinds = {}
	var durations = {}
	for event in history:
		ids[event.star_id] = true
		kinds[event.type] = true
		durations[event.duration] = true
	check(ids.size() > 3 and kinds.size() == 3 and durations.size() > 3, "Random events must vary targets, kinds and durations")
	var d = Map.new()
	d.configure_test_seed(716)
	for step in range(3600): d.advance(0.1)
	check(history != d.recent_anomaly_events, "Different random streams must produce different event schedules")
	d.free()
	var c = Map.new()
	c.configure_test_seed(715)
	for step in range(60): c.advance(0.1)
	var previous = c.presentation_state().active_anomalies
	var previous_stars = c.presentation_state().stars
	for step in range(30):
		c.advance(0.05)
		var current = c.presentation_state().active_anomalies
		for event in current:
			for old in previous:
				if event.start == old.start and event.star_id == old.star_id:
					check(absf(event.intensity - old.intensity) < 0.08, "Anomaly fade must be continuous")
		previous = current
		var current_stars = c.presentation_state().stars
		for index in range(current_stars.size()):
			check(absf(current_stars[index].brightness - previous_stars[index].brightness) < 0.08, "Visible star brightness must not jump")
		previous_stars = current_stars
	a.free()
	b.free()
	c.free()
	if failures.is_empty(): print("cosmic_star_map_acceptance: PASS")
	else: push_error("cosmic_star_map_acceptance: " + str(failures))
	quit(0 if failures.is_empty() else 1)
