extends SceneTree
## Real GPU capture with ordinary randomized startup and unaccelerated playback.
const Scene = preload("res://scenes/previews/cosmic_star_map.tscn")
const OUTPUT = "res://docs/verification/"
const FRAMES = OUTPUT + "cosmic_star_map_frames/"
const FPS = 15
var evidence = {"fps": FPS, "canvas": [1440, 900], "seed_override": false, "timeline": [], "checks": []}
var failures = 0

func _initialize(): call_deferred("run")

func check(value: bool, message: String):
	evidence.checks.append({"pass": value, "message": message})
	if not value: failures += 1
	print(("PASS " if value else "FAIL ") + message)

func json_safe(value):
	if value is Vector2: return [value.x, value.y]
	if value is Dictionary:
		var result = {}
		for key in value: result[key] = json_safe(value[key])
		return result
	if value is Array:
		var result = []
		for item in value: result.append(json_safe(item))
		return result
	return value

func run():
	if DisplayServer.get_name() == "headless":
		print("GPU capture requires -Render")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAMES))
	var background = Scene.instantiate()
	root.add_child(background)
	background.set_process(false)
	await process_frame
	var initial = background.presentation_state()
	var observed_types = {}
	var observed_expiry = false
	var previous_ids = {}
	var hashes = {}
	var frame_count = 0
	for index in range(900):
		if index > 0: background.advance(1.0 / FPS)
		await process_frame
		await RenderingServer.frame_post_draw
		var frame = root.get_texture().get_image()
		if frame == null or frame.is_empty():
			check(false, "GPU produced a nonempty viewport")
			break
		if index == 0:
			check(frame.get_size() == Vector2i(1440, 900), "real 1440 by 900 GPU canvas")
			frame.save_png(OUTPUT + "cosmic_star_map_idle.png")
		frame.save_png(FRAMES + "frame_%04d.png" % index)
		var state = background.presentation_state()
		var ids = {}
		for event in state.active_anomalies:
			ids[str(event.start)] = true
			if event.intensity > 0.9 and not observed_types.has(event.type):
				observed_types[event.type] = true
				frame.save_png(OUTPUT + "cosmic_star_map_" + event.type + ".png")
		for id in previous_ids:
			if not ids.has(id): observed_expiry = true
		previous_ids = ids
		if index % FPS == 0:
			var digest = HashingContext.new()
			digest.start(HashingContext.HASH_SHA256)
			digest.update(frame.get_data())
			hashes[digest.finish().hex_encode()] = true
		evidence.timeline.append({"frame": index, "elapsed": state.elapsed, "active_anomalies": json_safe(state.active_anomalies)})
		frame_count += 1
		if frame_count >= 360 and observed_types.size() == 3 and observed_expiry: break
	var last = background.presentation_state()
	check(initial.stars.size() == 260, "layered star field initialized")
	check(last.stars[0].screen_position.distance_to(initial.stars[0].screen_position) > 0.2, "stars drift throughout capture")
	check(hashes.size() > 10, "actual rendered frames visibly change over time")
	check(not last.recent_events.is_empty(), "ordinary random startup emits anomaly events")
	check(observed_expiry, "anomalies naturally finish during capture")
	check(observed_types.size() >= 2, "multiple random anomaly appearances observed")
	evidence["observed_types"] = observed_types.keys()
	evidence["recent_events"] = last.recent_events
	evidence["frame_count"] = frame_count
	evidence["checks_count"] = evidence.checks.size()
	evidence["failures"] = failures
	var file = FileAccess.open(OUTPUT + "cosmic_star_map_render_evidence.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t"))
	file.close()
	print("COSMIC_STAR_MAP_RENDER checks=%d failures=%d frames=%d types=%s" % [evidence.checks.size(), failures, frame_count, str(observed_types.keys())])
	background.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
