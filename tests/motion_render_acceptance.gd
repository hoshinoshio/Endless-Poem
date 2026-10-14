extends SceneTree
## GPU acceptance driven through the production scene and real input dispatch.
## Fixed capture delta is supplied to the same production _process clock; no
## combat state, input rules, or presentation hook is overridden.
const Scene = preload("res://scenes/main.tscn")
const CardFace = preload("res://scripts/ui/battle_card.gd")
const SAVE = "user://_motion_render_acceptance.json"
const OUTPUT = "res://docs/verification/"
const FRAMES = OUTPUT + "motion_frames/"
const FPS = 16
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
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
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
	return {"actors": actors, "battle_elapsed": stage.battle_elapsed, "authority": stage.authority_fx.presentation_state().duplicate(true)}

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
	await process_frame
	await click_at(app.loadout_confirm.get_global_rect().get_center())
	check(app.screen == "battle" and is_instance_valid(app.battle_world), "production mouse confirmation opens " + encounter)
	check(app.battle_visual_missing_assets.is_empty(), "all production poses and scenery available: " + encounter)
	await click_at(app.authority_button.get_global_rect().get_center())
	await process_frame
	for face in app.card_buttons.values():
		check(face is CardFace and face.illustration != null, "real card illustration loaded: " + str(face.card_data.type))
		check(face.title_label.visible and not face.title_label.text.is_empty() and face.state_label.visible and face.card_data.has("cost"), "card exposes title, fee and availability: " + str(face.card_data.type))
	return app.battle_world.stage

func segment(encounter: String):
	var stage = await begin(encounter)
	if not is_instance_valid(stage): return
	var cast_id = ""
	for card in app.snapshot.cards:
		if card.type == "fire": cast_id = card.id; break
	var target = str(app.snapshot.enemies[0].id)
	var idle_seen: Dictionary = {}
	var fx_seen = false
	var moving_heads: Dictionary = {}
	var pause_state: Dictionary = {}
	var elapsed_before_pause = 0.0
	var spell_screenshot_taken = false
	for local_frame in 48:
		if local_frame == 20:
			await click_at(app.card_buttons[cast_id].get_global_rect().get_center())
			await click_at(app.get_battle_target_rect(target).get_center())
			check(app.card_buttons[cast_id].card_data.remaining > 0, "mouse card / sprite target dispatches actual spell: " + encounter)
		if local_frame == 37:
			# Esc first cancels selection if it remains, then collapses, then opens pause.
			await escape()
			await escape()
			if not is_instance_valid(app.overlay): await escape()
			check(app.combat.paused, "real Esc sequence opens pause: " + encounter)
			pause_state = world_state(stage)
			elapsed_before_pause = app.combat.time
		if local_frame == 45:
			check(world_state(stage) == pause_state and app.combat.time == elapsed_before_pause, "pause freezes actor frames, environment clock and moving spell state: " + encounter)
			await escape()
			check(not app.combat.paused, "Esc resumes production clock: " + encounter)
			await click_at(app.authority_button.get_global_rect().get_center())
		app._process(1.0/FPS)
		if local_frame < 20:
			for id in stage.actors:
				var actor = stage.actors[id]
				if not idle_seen.has(id): idle_seen[id] = {}
				if actor.animation_state == "idle": idle_seen[id][actor.animated_sprite.frame] = true
		var fx: Dictionary = stage.authority_fx.presentation_state()
		if fx.beam_count > 0:
			fx_seen = true
			for stream in fx.streams: moving_heads[str(stream.head)] = true
		var shot = "motion_" + encounter + "_cards" if local_frame == 0 else ""
		if not spell_screenshot_taken:
			for stream in fx.streams:
				if stream.progress >= 0.4 and stream.progress <= 0.7 and stream.history_count > 0:
					shot = "motion_" + encounter + "_spell"
					spell_screenshot_taken = true
					break
		await capture(encounter, "idle" if local_frame < 20 else ("paused" if local_frame >= 37 and local_frame < 45 else "cast_and_dissipation"), stage, shot)
	for id in idle_seen:
		var key = encounter + "/" + str(id)
		check(idle_seen[id].size() >= 4, "GPU sequence observes four production idle indices: " + key)
		var distinct: Dictionary = {}
		for value in rendered_idle_hashes.get(key, {}).values(): distinct[value] = true
		check(distinct.size() >= 4, "actual rendered actor-region hashes differ across four idle frames: " + key)
	check(fx_seen and moving_heads.size() > 4, "GPU spell stream heads advance along path: " + encounter)
	check(spell_screenshot_taken, "main spell screenshot catches a travelling head with live history at forty to seventy percent: " + encounter)
	check(stage.authority_fx.presentation_state().beam_count == 0, "travelling streams and short trails dissipate: " + encounter)
	check(stage.environment_motion != null and stage.battle_elapsed > 0, "production environment moves with battle clock: " + encounter)

func run():
	if DisplayServer.get_name() == "headless":
		print("MOTION_RENDER_ACCEPTANCE requires -Render; no synthetic or headless images accepted")
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
		check(app.store.claim_reward("motion_fixture:" + type,type), "isolated legitimate reward source: " + type)
		for card in app.collection:
			if card.type == type and not equipped.has(card.id): equipped.append(card.id); break
	for card in app.collection:
		if card.type == "fire" and not equipped.has(card.id): equipped.append(card.id); break
	app.store.set_equipped(equipped)
	check(equipped.size() == 10, "ten real equipped entities include all nine illustrated types")
	verify_idle_resources()
	await segment("patrol")
	await segment("boss")
	check(frame_number == 96, "six-second contiguous zero-based sequence at sixteen frames per second")
	evidence["frame_count"] = frame_number
	evidence["rendered_idle_region_hashes"] = rendered_idle_hashes
	evidence["checks_count"] = checks
	evidence["failures"] = failures
	evidence["clicks"] = clicks
	evidence["isolated_save"] = SAVE
	var output = FileAccess.open(OUTPUT + "motion_render_evidence.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(evidence,"\t"))
	output.close()
	print("MOTION_RENDER_ACCEPTANCE checks=%d failures=%d frames=%d clicks=%d" % [checks,failures,frame_number,clicks])
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
