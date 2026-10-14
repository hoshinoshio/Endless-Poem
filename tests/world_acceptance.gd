extends SceneTree
## Generated textures below are isolated fixtures. They are never shipped as game assets.
const StageScene = preload("res://scenes/world/combat_stage.tscn")
const Combat = preload("res://scripts/combat/combat_model.gd")
var checks := 0
var failures: Array[String] = []
var picked: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)

func fixture(color: Color) -> ImageTexture:
	var image := Image.create(40, 80, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func fixture_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for state in ["idle", "cast", "hurt", "defeat"]:
		frames.add_animation(StringName(state))
		frames.set_animation_speed(StringName(state), 10)
		frames.set_animation_loop(StringName(state), state == "idle")
		frames.add_frame(StringName(state), fixture(Color.BLUE))
		frames.add_frame(StringName(state), fixture(Color.GREEN))
	return frames

func _run() -> void:
	root.size = Vector2i(1440, 900)
	root.physics_object_picking = true
	var stage = StageScene.instantiate()
	root.add_child(stage)
	stage.target_selected.connect(func(id: String): picked.append(id))
	await process_frame
	var frames := fixture_frames()
	var manifest := {
		"player":{"texture":fixture(Color.WHITE), "sprite_frames":frames},
		"enemies":{"guard":{"texture":fixture(Color.RED), "sprite_frames":frames}, "anchor":{"texture":fixture(Color.YELLOW)}},
		"encounters":{"stairs":{"layers":[{"texture":fixture(Color.DARK_BLUE), "z_index":-20}, {"texture":fixture(Color.DARK_GREEN), "z_index":20, "size":[1440, 100], "position":[720, 520]}]}}
	}
	stage.configure("stairs", manifest)
	var snap := {"status":"active", "hp":50, "max_hp":50, "time":0.0, "enemies":[{"id":"guard_1", "kind":"guard", "hp":20, "action_index":0}]}
	stage.sync_snapshot(snap)
	await physics_frame
	await process_frame
	check(stage is Node2D and stage.camera is Camera2D, "real Node2D stage and Camera2D")
	check(stage.layers.size() == 2 and stage.layers[0] is Sprite2D and stage.layers[1].z_index > stage.actors.guard_1.z_index, "texture foreground and background layers")
	check(stage.actors.size() == 2 and stage.actors.has("player") and stage.actors.has("guard_1"), "snapshot IDs map to actual actors")
	var actor = stage.actors.guard_1
	check(actor.animation_state == "idle", "initial action index does not invent enemy attack")
	check(actor.sprite is Sprite2D and actor.animated_sprite is AnimatedSprite2D, "static and animated sprite interfaces")
	check(actor.pick_area is Area2D and actor.collision.shape is RectangleShape2D, "physical pick area and sprite collision bounds")
	var rect: Rect2 = stage.get_target_rect("guard_1")
	check(rect.has_area() and rect.position.y >= 80 and rect.end.y <= 568, "target bounds fit actual battle area")
	check(rect.size == actor.collision.shape.size, "target rect derives from fitted sprite size")
	var query := PhysicsPointQueryParameters2D.new()
	query.position = rect.get_center()
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var found: Array = stage.get_world_2d().direct_space_state.intersect_point(query)
	check(found.size() == 1 and found[0].collider == actor.pick_area, "physics point query finds actual target Area2D")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = rect.get_center()
	click.global_position = click.position
	root.push_input(click, true)
	await physics_frame
	await process_frame
	await physics_frame
	check(picked == ["guard_1"], "real viewport mouse input selects enemy ID")
	var initial_frame: int = actor.animated_sprite.frame
	stage.advance(1.0, 0.1)
	check(actor.animated_sprite.frame != initial_frame and absf(stage.battle_elapsed - 0.1) < 0.00001 and stage.real_elapsed == 1.0, "frame animation follows battle clock while real clock tracked separately")
	var frozen_frame: int = actor.animated_sprite.frame
	stage.advance(2.0, 0.0)
	check(actor.animated_sprite.frame == frozen_frame, "zero battle delta freezes animation even when real time advances")
	stage.consume_events([{"type":"cast", "target":"guard_1", "amount":0, "time":0.1}, {"type":"hit", "target":"guard_1", "amount":6, "time":0.12}])
	check(stage.actors.player.animation_state == "cast" and actor.animation_state == "hurt", "existing combat cast/hit events drive actors")
	stage.advance(1.0, 0.1)
	check(actor.animation_state == "hurt" and actor.animated_sprite.frame == 1, "hurt plays distinct SpriteFrames frames")
	stage.advance(1.0, 0.11)
	check(actor.animation_state == "idle" and stage.actors.player.animation_state == "idle", "nonloop animation completes to idle")
	var anchor_snap: Dictionary = snap.duplicate(true)
	anchor_snap.enemies.append({"id":"anchor_2", "kind":"anchor", "is_anchor":true, "hp":4})
	var stable_rect: Rect2 = stage.get_target_rect("guard_1")
	stage.sync_snapshot(anchor_snap)
	check(stage.get_target_rect("guard_1") == stable_rect, "spawning anchor preserves existing actor position and scale")
	check(stage.actors.has("anchor_2") and stage.actors.anchor_2.uses_static_seed, "new snapshot anchor entity appears using explicitly supplied fixture seed")
	check(stage.missing_assets.has("animation:anchor_2:idle,cast,hurt,defeat"), "static seed clearly reports missing frame animations")
	anchor_snap.enemies[0].action_index = 1
	stage.sync_snapshot(anchor_snap)
	check(actor.animation_state == "cast", "increased enemy action index plays cast fallback")
	frames.add_animation(&"attack")
	frames.set_animation_loop(&"attack", false)
	frames.set_animation_speed(&"attack", 10)
	frames.add_frame(&"attack", fixture(Color.YELLOW))
	frames.add_frame(&"attack", fixture(Color.RED))
	anchor_snap.enemies[0].action_index = 2
	stage.sync_snapshot(anchor_snap)
	check(actor.animation_state == "attack", "optional enemy attack frame animation takes priority")
	stage.advance(0.1, 0.1)
	check(actor.animated_sprite.frame == 1, "enemy attack advances actual SpriteFrames frames")
	stage.consume_events([{"type":"death", "target":"guard_1", "time":0.2}])
	var remaining: Dictionary = snap.duplicate(true)
	remaining.enemies = []
	stage.sync_snapshot(remaining)
	check(not stage.actors.has("guard_1") and not stage.get_target_rect("guard_1").has_area(), "removed snapshot actor cannot remain a target")
	check(actor.animation_state == "defeat" and not actor.pick_area.input_pickable, "retiring actor plays defeat without input target")
	stage.advance(1.0, 0.1)
	check(actor.animated_sprite.frame == 1, "defeat actual frame resource advances")
	stage.advance(1.0, 0.6)
	await process_frame
	check(not is_instance_valid(actor), "retired actors leave scene after combat time expiry")
	stage.configure("boss", {})
	stage.sync_snapshot({"hp":50, "status":"active", "enemies":[{"id":"boss_1", "kind":"boss", "hp":120}]})
	check(stage.actors.player.has_art and stage.actors.player.uses_static_seed, "approved Moonli v1 PNG is the only production fallback")
	check(stage.missing_assets.has("scene:boss") and stage.missing_assets.has("actor:boss_1:boss"), "unapproved scenery and enemy art are recorded")
	check(not stage.actors.boss_1.has_art and stage.actors.boss_1.sprite.texture == null and not stage.get_target_rect("boss_1").has_area(), "missing enemy art produces no substitute image or hidden target")
	check(stage.layers.is_empty(), "missing scene creates no procedural placeholder layers")
	stage.configure("boss", {"player":{"texture":fixture(Color.WHITE)}, "enemies":{"boss":{"texture":fixture(Color.RED)}, "anchor":{"texture":fixture(Color.YELLOW)}}})
	var boss_snap := {"hp":50, "status":"active", "enemies":[{"id":"boss_1", "kind":"boss", "hp":120, "action_index":3}]}
	stage.sync_snapshot(boss_snap)
	var boss_rect: Rect2 = stage.get_target_rect("boss_1")
	boss_snap.enemies.append({"id":"anchor_1", "kind":"anchor", "is_anchor":true, "hp":4})
	boss_snap.enemies.append({"id":"anchor_2", "kind":"anchor", "is_anchor":true, "hp":4})
	stage.sync_snapshot(boss_snap)
	check(stage.get_target_rect("boss_1") == boss_rect and stage.actors.boss_1.position.x == 1030, "boss anchor summon keeps boss position and scale fixed")
	var other_anchor_rect: Rect2 = stage.get_target_rect("anchor_2")
	boss_snap.enemies.remove_at(1)
	stage.sync_snapshot(boss_snap)
	check(stage.get_target_rect("anchor_2") == other_anchor_rect and stage.get_target_rect("boss_1") == boss_rect, "anchor destruction cannot reflow boss or surviving anchor")
	# Live model integration verifies the visual adapter never modifies combat state.
	stage.configure("tutorial", {"player":{"texture":fixture(Color.WHITE)}, "enemies":{"tutorial":{"texture":fixture(Color.RED)}}})
	var model = Combat.new()
	check(model.start_battle("tutorial"), "live model starts")
	var before: Dictionary = model.get_snapshot()
	stage.sync_snapshot(before)
	stage.consume_events(model.take_events())
	stage.advance(0.5, 0.5)
	check(model.get_snapshot() == before, "presentation cannot alter combat model values")
	var fire_id := str(before.cards[0].id)
	var target_id := str(before.enemies[0].id)
	check(model.select_card(fire_id) and model.play_selected(target_id), "live model cast accepted")
	stage.consume_events(model.take_events())
	check(stage.actors.player.animation_state == "cast", "live model event targets player cast")
	var old_time: float = model.time
	model.tick(0.6)
	stage.sync_snapshot(model.get_snapshot())
	stage.consume_events(model.take_events())
	stage.advance(0.6, model.time - old_time)
	check(stage.actors[target_id].snapshot.hp == model.get_snapshot().enemies[0].hp, "live model snapshot keeps actor health authoritative")
	stage.queue_free()
	await process_frame
	print("WORLD_ACCEPTANCE checks=", checks, " failures=", failures.size())
	for failure in failures:
		print("FAILED: ", failure)
	quit(0 if failures.is_empty() else 1)
