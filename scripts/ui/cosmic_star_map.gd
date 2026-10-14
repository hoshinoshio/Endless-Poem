extends Control
## Standalone menu backdrop. All animation time comes from advance(delta).
const MAX_ACTIVE = 3
const HISTORY_LIMIT = 24
const STAR_COUNT = 260
var recent_anomaly_events: Array:
	get: return _history.duplicate(true)
var _rng = RandomNumberGenerator.new()
var _stars: Array = []
var _active: Array = []
var _history: Array = []
var _elapsed = 0.0
var _next_event = 0.0
var _test_seeded = false
var _mist_material: ShaderMaterial

func configure_test_seed(value: int) -> void:
	_test_seeded = true
	_rng.seed = value
	_rebuild()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mist = ColorRect.new()
	mist.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mist.show_behind_parent = true
	_mist_material = ShaderMaterial.new()
	_mist_material.shader = preload("res://shaders/cosmic_star_map.gdshader")
	mist.material = _mist_material
	add_child(mist)
	if not _test_seeded:
		_rng.randomize()
		_rebuild()

func _rebuild() -> void:
	_stars.clear()
	_active.clear()
	_history.clear()
	_elapsed = 0.0
	_next_event = _rng.randf_range(2.5, 4.5)
	for i in range(STAR_COUNT):
		_stars.append({"id": i, "uv": Vector2(_rng.randf(), _rng.randf()), "depth": _rng.randf_range(0.2, 1.0), "radius": _rng.randf_range(0.45, 1.6), "phase": _rng.randf() * TAU, "light": _rng.randf_range(0.25, 0.78)})
	queue_redraw()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if delta <= 0.0: return
	_elapsed += delta
	if _mist_material: _mist_material.set_shader_parameter("elapsed", _elapsed)
	for i in range(_active.size() - 1, -1, -1):
		if _elapsed >= _active[i].start + _active[i].duration:
			_active.remove_at(i)
	if _elapsed >= _next_event:
		if _active.size() < MAX_ACTIVE and not _stars.is_empty():
			var available = _stars.filter(func(star): return not _active.any(func(event): return event.star_id == star.id))
			var selected = available[_rng.randi_range(0, available.size() - 1)]
			var event = {"star_id": selected.id, "type": ["dark_red", "irregular_glow", "asymmetric_rays"][_rng.randi_range(0, 2)], "start": _elapsed, "duration": _rng.randf_range(9.0, 18.0), "phase": _rng.randf() * TAU}
			_active.append(event)
			_history.append(event.duplicate(true))
			if _history.size() > HISTORY_LIMIT: _history.pop_front()
		_next_event = _elapsed + _rng.randf_range(4.0, 8.0)
	queue_redraw()

func _envelope(event: Dictionary) -> float:
	var progress = clampf((_elapsed - event.start) / event.duration, 0.0, 1.0)
	return smoothstep(0.0, 0.23, progress) * (1.0 - smoothstep(0.72, 1.0, progress))

func presentation_state() -> Dictionary:
	var anomalies = _active.duplicate(true)
	for event in anomalies:
		event["intensity"] = _envelope(event)
		event["remaining"] = maxf(0.0, event.start + event.duration - _elapsed)
		event["screen_position"] = _point(_stars[event.star_id], size if size.x > 0.0 else Vector2(1440, 900))
	var visible_stars = _stars.duplicate(true)
	for star in visible_stars:
		star["screen_position"] = _point(star, size if size.x > 0.0 else Vector2(1440, 900))
		star["brightness"] = star.light * (0.94 + 0.06 * sin(_elapsed * 0.25 + star.phase))
		star["anomaly_type"] = ""
		star["remaining"] = 0.0
		for event in anomalies:
			if event.star_id == star.id:
				star["anomaly_type"] = event.type
				star["remaining"] = event.remaining
				if event.type == "dark_red": star.brightness = lerpf(star.brightness, 0.95, event.intensity)
				elif event.type == "irregular_glow": star.brightness = lerpf(star.brightness, 0.48 + 0.30 * sin(_elapsed * 0.9 + event.phase) * sin(_elapsed * 0.43 + 0.7), event.intensity)
				else: star.brightness = lerpf(star.brightness, 0.9, event.intensity)
	return {"elapsed": _elapsed, "stars": visible_stars, "active_anomalies": anomalies, "recent_events": recent_anomaly_events, "max_active": MAX_ACTIVE, "history_limit": HISTORY_LIMIT}

func _point(star: Dictionary, canvas: Vector2) -> Vector2:
	var drift = Vector2(_elapsed * 0.00065, sin(_elapsed * 0.009 + star.phase) * 0.003) * star.depth
	return Vector2(fposmod(star.uv.x + drift.x, 1.0), fposmod(star.uv.y + drift.y, 1.0)) * canvas

func _draw() -> void:
	var canvas = size if size.x > 0.0 else Vector2(1440, 900)
	if not _mist_material: draw_rect(Rect2(Vector2.ZERO, canvas), Color("050b19"))
	# Fine, distant dust uses stable procedural coordinates without consuming the
	# anomaly RNG stream. Main-star distribution and scheduling stay unchanged.
	for mote in range(1500):
		var x = fposmod(sin(mote * 127.1 + 17.0) * 43758.5453 + _elapsed * 0.00013, 1.0)
		var y = fposmod(sin(mote * 311.7 + 31.0) * 22578.1459, 1.0)
		var opacity = 0.07 + fposmod(mote * 0.61803, 1.0) * 0.17
		draw_circle(Vector2(x, y) * canvas, 0.38 + fposmod(mote * 0.41421, 1.0) * 0.24, Color(0.54, 0.66, 0.82, opacity))
	# Broad, faint dust layers keep title and face areas quiet.
	for cloud in range(7):
		var center = Vector2(0.35 + cloud * 0.045, 0.18 + sin(cloud * 1.7 + _elapsed * 0.004) * 0.12) * canvas
		for ring in range(18, 0, -1):
			draw_circle(center, ring * canvas.y * 0.014, Color(0.14, 0.22, 0.37, 0.0035))
	# Sparse local links; avoid long lines jumping across wrapped boundaries.
	for i in range(0, _stars.size() - 2, 9):
		var a = _point(_stars[i], canvas)
		var b = _point(_stars[i + 1], canvas)
		if a.distance_to(b) < canvas.x * 0.17:
			draw_line(a, b, Color(0.40, 0.58, 0.75, 0.22), 0.65, true)
	for arc in range(3):
		draw_arc(Vector2(canvas.x * 0.51, canvas.y * 0.51), canvas.y * (0.36 + arc * 0.19), -2.1 + _elapsed * 0.0008, -0.7 + _elapsed * 0.0008, 90, Color(0.32, 0.51, 0.69, 0.14), 0.65, true)
	for star in _stars:
		var point = _point(star, canvas)
		var intensity = 0.0
		var kind = ""
		var event_phase = 0.0
		for event in _active:
			if event.star_id == star.id:
				intensity = _envelope(event)
				kind = event.type
				event_phase = event.phase
		var brightness = star.light * (0.94 + 0.06 * sin(_elapsed * 0.25 + star.phase))
		var tint = Color(0.63, 0.77, 0.94, brightness)
		var radius = star.radius * (0.6 + star.depth * 0.65)
		if kind == "dark_red":
			tint = tint.lerp(Color(0.96, 0.17, 0.23, 0.95), intensity)
			radius += intensity * 1.6
		elif kind == "irregular_glow":
			tint.a = lerpf(brightness, 0.48 + 0.30 * sin(_elapsed * 0.9 + event_phase) * sin(_elapsed * 0.43 + 0.7), intensity)
			radius += intensity * 1.8
		elif kind == "asymmetric_rays":
			tint = tint.lerp(Color(0.78, 0.60, 0.94, 0.9), intensity)
			radius += intensity
		for glow in range(4, 0, -1):
			draw_circle(point, radius * (1.0 + glow * (1.6 + intensity)), Color(tint.r, tint.g, tint.b, tint.a * (0.016 + intensity * 0.026)))
		draw_circle(point, radius, tint)
		if kind == "asymmetric_rays" and intensity > 0.0:
			var contour = PackedVector2Array()
			for vertex in range(9):
				var angle = vertex * TAU / 8.0 + _elapsed * 0.025
				var extent = (9.0 if vertex % 2 == 0 else 3.2) * (1.0 + 0.22 * sin(vertex * 1.7 + event_phase))
				contour.append(point + Vector2(1.8, -1.2) * intensity + Vector2.from_angle(angle) * extent * intensity)
			draw_polyline(contour, Color(tint.r, tint.g, tint.b, 0.55 * intensity), 0.8, true)
			draw_line(point + Vector2(-12, 3) * intensity, point + Vector2(16, -4) * intensity, Color(0.84, 0.68, 0.96, 0.48 * intensity), 0.7, true)
		if star.depth > 0.83 or intensity > 0.0:
			var ray = radius * (3.0 + intensity * 2.0)
			var asymmetry = intensity * (0.25 + 0.12 * sin(_elapsed * 0.4 + event_phase)) if kind == "asymmetric_rays" else 0.0
			draw_line(point - Vector2(ray, 0), point + Vector2(ray * (1.0 + asymmetry), ray * asymmetry), Color(tint.r, tint.g, tint.b, tint.a * 0.32), 0.65, true)
			draw_line(point - Vector2(0, ray * 0.7), point + Vector2(ray * asymmetry, ray), Color(tint.r, tint.g, tint.b, tint.a * 0.26), 0.65, true)
