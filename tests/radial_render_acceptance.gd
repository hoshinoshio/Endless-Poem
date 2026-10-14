extends SceneTree
## GPU acceptance driven through the production scene and real input dispatch.
## Fixed capture delta is supplied to the same production _process clock; no
## combat state, input rules, or presentation hook is overridden.
const Scene = preload("res://scenes/main.tscn")
const CardFace = preload("res://scripts/ui/battle_card.gd")
const SAVE = "user://_radial_render_acceptance.json"
const OUTPUT = "res://docs/verification/"
const FRAMES = OUTPUT + "radial_frames/"
const FPS = 30
const TYPES = ["fire", "shield", "charge", "ember", "ignite", "ember_shield", "heavy_shield", "echo", "delay"]
var app
var checks = 0
var failures = 0
var clicks = 0
var frame_number = 0
var rendered_idle_hashes: Dictionary = {}
var evidence: Dictionary = {"fps": FPS, "canvas": [1440,900], "timeline": [], "idle_art_hashes": {}, "checks": []}

func _initialize(): call_deferred("run")
func check(value: bool, message: String):
	checks += 1
	if not value: failures += 1
	print(("PASS " if value else "FAIL ") + message)
	evidence.checks.append({"pass": value, "message": message})

func digest(image: Image) -> String:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_data())
	return context.finish().hex_encode()

func click_at(point: Vector2):
	await physics_frame
	await process_frame
	var radial = InputEventMouseMotion.new()
	radial.position = point
	radial.global_position = point
	root.push_input(radial, true)
	var down = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = point
	down.global_position = point
	down.pressed = true
	root.push_input(down, true)
	await physics_frame
	await process_frame
	var up = down.duplicate()
	up.pressed = false
	root.push_input(up, true)
	await physics_frame
	await process_frame
	app._process(0.0)
	clicks += 1

func escape():
	var down = InputEventKey.new()
	down.keycode = KEY_ESCAPE
	down.physical_keycode = KEY_ESCAPE
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	var up = down.duplicate()
	up.pressed = false
	root.push_input(up, true)
	await process_frame

func world_state(stage) -> Dictionary:
	var actors: Dictionary = {}
	for id in stage.actors:
		var actor = stage.actors[id]
		actors[id] = {"state": actor.animation_state, "frame": actor.animated_sprite.frame, "clock": actor.animation_elapsed, "position": [actor.position.x,actor.position.y]}
	var authority: Dictionary = stage.authority_fx.presentation_state().duplicate(true)
	for stream in authority.streams:
		for key in stream.keys():
			if stream[key] is Vector2: stream[key] = [stream[key].x, stream[key].y]
	authority.source = [stage.authority_fx.source.x, stage.authority_fx.source.y]
	return {"actors": actors, "battle_elapsed": stage.battle_elapsed, "authority": authority}

func capture(encounter: String, phase: String, stage, main_shot = ""):
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	if image == null or image.is_empty():
		check(false, "GPU viewport produced a complete image")
		return
	if frame_number == 0: check(image.get_size() == Vector2i(1440,900), "actual GPU canvas is 1440 by 900")
	image.save_png(FRAMES + "frame_%04d.png" % frame_number)
	if not main_shot.is_empty(): image.save_png(OUTPUT + main_shot + ".png")
	var state = world_state(stage)
	state["frame"] = frame_number
	state["encounter"] = encounter
	state["phase"] = phase
	state["combat_time"] = app.combat.time
	state["paused"] = app.combat.paused
	state["viewport_hash"] = digest(image)
	if phase == "idle":
		for id in stage.actors:
			var actor = stage.actors[id]
			if actor.animation_state != "idle": continue
			var region = Rect2i(actor.get_target_rect()).intersection(Rect2i(0,0,1440,900))
			if not region.has_area(): continue
			var key = encounter + "/" + str(id)
			if not rendered_idle_hashes.has(key): rendered_idle_hashes[key] = {}
			var index = str(actor.animated_sprite.frame)
			if not rendered_idle_hashes[key].has(index):
				rendered_idle_hashes[key][index] = digest(image.get_region(region))
	evidence.timeline.append(state)
	frame_number += 1

func verify_idle_resources():
	var manifest: Dictionary = app.battle_visual_assets
	var assets = manifest.enemies.duplicate()
	assets["player"] = manifest.player
	for id in assets:
		var frames: SpriteFrames = assets[id].get("sprite_frames")
		var hashes: Array = []
		if frames != null and frames.has_animation("idle"):
			for i in mini(4,frames.get_frame_count("idle")):
				hashes.append(digest(frames.get_frame_texture("idle",i).get_image()))
		var unique: Dictionary = {}
		for value in hashes: unique[value] = true
		check(hashes.size() == 4 and unique.size() == 4, "four independent illustrated idle frame hashes: " + str(id))
		evidence.idle_art_hashes[id] = hashes

func begin(encounter: String):
	app.start_encounter(encounter)
	# Allow the new Control hierarchy and initial window input state to settle.
	await physics_frame
	await process_frame
	await RenderingServer.frame_post_draw
	await click_at(app.loadout_confirm.get_global_rect().get_center())
	if app.screen == "equip":
		print("INITIAL_INPUT_RETRY encounter=%s disabled=%s equipped=%d" % [encounter, app.loadout_confirm.disabled, app.equipped_ids.size()])
		await click_at(app.loadout_confirm.get_global_rect().get_center())
	check(app.screen == "battle" and is_instance_valid(app.battle_world), "production mouse confirmation opens " + encounter)
	if app.screen != "battle": return null
	check(app.battle_visual_missing_assets.is_empty(), "all production poses and scenery available: " + encounter)
	await click_at(app.authority_button.get_global_rect().get_center())
	await process_frame
	for face in app.card_buttons.values():
		check(face is CardFace and face.illustration != null, "real card illustration loaded: " + str(face.card_data.type))
		check(face.title_label.visible and not face.title_label.text.is_empty() and face.state_label.visible and face.card_data.has("cost"), "card exposes title, fee and availability: " + str(face.card_data.type))
	check(app.hp_bar.visible and not app.hp_bar.show_percentage, "player health is a bar without numbers: " + encounter)
	check(not app.resources_label.visible and not app.energy_bar.visible and not app.focus_bar.visible and not app.time_label.visible and not app.message_label.visible and not app.pause_button.visible, "live GPU scene omits resource text, timing, damage messages and pause button: " + encounter)
	for enemy in app.snapshot.enemies:
		check(app.target_hp_bars[enemy.id].visible and not app.target_hp_bars[enemy.id].show_percentage and not app.target_labels[enemy.id].visible and not app.target_bars[enemy.id].visible and not app.target_debuffs[enemy.id].visible, "only enemy health bar remains: " + str(enemy.id))
	return app.battle_world.stage

func segment(encounter: String):
	var stage = await begin(encounter)
	if not is_instance_valid(stage): return
	var cast_id = ""
	for card in app.snapshot.cards:
		if card.type == "fire": cast_id = card.id; break
	var target = str(app.snapshot.enemies[0].id)
	var origins: Dictionary = {}
	var quadrants: Dictionary = {}
	var outward: Dictionary = {}
	var reached: Dictionary = {}
	var moving: Dictionary = {}
	var emitted = false
	var spark_seen = false
	var shots: Dictionary = {}
	for local_frame in 90:
		if local_frame == 20:
			await click_at(app.card_buttons[cast_id].get_global_rect().get_center())
			await click_at(app.get_battle_target_rect(target).get_center())
			check(app.card_buttons[cast_id].card_data.remaining > 0, "real mouse card and target input starts " + encounter)
		var fx: Dictionary = stage.authority_fx.presentation_state()
		var shot = "radial_" + encounter + "_cards" if local_frame == 0 else ""
		var maximum_progress := 0.0
		for stream in fx.streams: maximum_progress = maxf(maximum_progress, float(stream.progress))
		var moment := ""
		if fx.beam_count > 0 and not shots.has("origins"): moment = "origins"
		elif fx.beam_count > 0 and maximum_progress >= 0.18 and maximum_progress <= 0.32 and not shots.has("outward"): moment = "outward"
		elif fx.beam_count > 0 and maximum_progress >= 0.60 and maximum_progress <= 0.85 and not shots.has("flight"): moment = "flight"
		elif fx.impacts.any(func(burst): return burst.age >= 0.0) and not shots.has("impact"): moment = "impact"
		elif emitted and fx.beam_count == 0 and fx.spark_count == 0 and fx.impacts.is_empty() and not shots.has("dissipated"): moment = "dissipated"
		if not moment.is_empty():
			shots[moment] = true
			shot = "radial_" + encounter + "_" + moment
		if fx.beam_count == 8: emitted = true
		if fx.spark_count > 0: spark_seen = true
		for beam in stage.authority_fx.beams:
			var lane = str(beam.lane)
			var origin: Vector2 = beam.get("origin", beam.get("source", Vector2.ZERO))
			var radial = (origin - stage.authority_fx.source).normalized()
			origins[str(origin)] = true
			if absf(radial.x) > 0.01 and absf(radial.y) > 0.01:
				quadrants["%d/%d" % [int(sign(radial.x)),int(sign(radial.y))]] = true
			var early: Vector2 = stage.authority_fx.path_point(beam, 0.18)
			if (early-origin).dot(radial) >= 20.0: outward[lane] = true
			if stage.authority_fx.path_point(beam, 1.0).distance_to(beam.end) < 2: reached[lane] = true
		for stream in fx.streams: moving[str(stream.head)] = true
		await capture(encounter, "idle" if local_frame < 20 else "cast_and_dissipation", stage, shot)
		app._process(1.0/FPS)
	check(emitted and origins.size() == 8, "eight spatially distinct circumference origins: " + encounter)
	check(quadrants.has("1/1") and quadrants.has("-1/1") and quadrants.has("1/-1") and quadrants.has("-1/-1"), "origins occupy all four quadrants: " + encounter)
	check(outward.size() == 8, "each of eight paths initially moves outward: " + encounter)
	check(reached.size() == 8, "each of eight paths converges exactly on selected target: " + encounter)
	check(moving.size() > 24 and spark_seen, "GPU sequence observes travelling heads and actual combat impact sparks: " + encounter)
	check(stage.authority_fx.presentation_state().beam_count == 0, "all moving heads and trails fully dissipate: " + encounter)
	check(shots.size() == 5, "GPU captures actual origin, outward, flight, impact and fully cleared moments: " + encounter)
	var clock: Dictionary = stage.authority_fx.presentation_state().clock_projection
	check(clock.hour_marks == 12 and clock.minute_marks == 60 and clock.hands == 3 and clock.opacity < 1.0, "production authority is a translucent mapped clock: " + encounter)

func run():
	if DisplayServer.get_name() == "headless":
		print("RADIAL_RENDER_ACCEPTANCE requires -Render; no synthetic or headless images accepted")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAMES))
	for suffix in ["", ".tmp", ".bak"]:
		var path = ProjectSettings.globalize_path(SAVE + suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	app = Scene.instantiate()
	app.save_path = SAVE
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.quick_mode = true
	var equipped: Array = []
	for type in TYPES:
		check(app.store.claim_reward("radial_fixture:" + type,type), "isolated legitimate reward source: " + type)
		for card in app.collection:
			if card.type == type and not equipped.has(card.id): equipped.append(card.id); break
	for card in app.collection:
		if card.type == "fire" and not equipped.has(card.id): equipped.append(card.id); break
	app.store.set_equipped(equipped)
	check(equipped.size() == 10, "ten real equipped entities include all nine illustrated types")
	verify_idle_resources()
	await segment("patrol")
	await segment("boss")
	check(frame_number == 180, "six-second contiguous zero-based sequence at thirty frames per second")
	evidence["frame_count"] = frame_number
	evidence["rendered_idle_region_hashes"] = rendered_idle_hashes
	evidence["checks_count"] = checks
	evidence["failures"] = failures
	evidence["clicks"] = clicks
	evidence["isolated_save"] = SAVE
	var output = FileAccess.open(OUTPUT + "radial_render_evidence.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(evidence,"\t"))
	output.close()
	print("RADIAL_RENDER_ACCEPTANCE checks=%d failures=%d frames=%d clicks=%d" % [checks,failures,frame_number,clicks])
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

