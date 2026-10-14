extends SceneTree
const Stage = preload("res://scripts/world/combat_stage.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)

func run() -> void:
	var image := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var frames := SpriteFrames.new()
	for animation in ["idle", "cast", "hurt", "defeat"]:
		frames.add_animation(animation)
		frames.set_animation_speed(animation, 8.0)
		frames.set_animation_loop(animation, animation == "idle")
		for i in 4:
			frames.add_frame(animation, texture)
	var stage = Stage.new()
	root.add_child(stage)
	stage.configure("test", {"time_authority":true, "player":{"sprite_frames":frames}, "enemies":{"test":{"texture":texture}}})
	stage.sync_snapshot({"hp":50, "enemies":[{"id":"e1", "kind":"test", "hp":10, "max_hp":10}]})
	check(is_equal_approx(stage.actors.player.get_visual_height(), 217.0), "player height 217")
	check(stage.authority_fx.z_index < stage.actors.player.z_index, "authority behind player")
	var source: Vector2 = stage.authority_fx.source
	check(source.x < stage.actors.player.position.x, "authority behind actor source")
	stage.consume_events([{"type":"cast", "target":"e1", "message":"registered", "amount":0, "time":0.0}])
	var state: Dictionary = stage.authority_fx.presentation_state()
	check(state.beam_count == stage.authority_fx.STREAM_COUNT and state.targets == ["e1"], "eight target streams")
	check(stage.actors.player.animated_sprite.visible and stage.actors.player.animation_state == "cast", "SpriteFrames cast preserved")
	for beam in stage.authority_fx.beams:
		check(beam.source == source, "stream originates at authority")
	stage.advance(1.0, 0.0)
	check(stage.authority_fx.presentation_state() == state, "pause freezes all effects")
	check(stage.actors.player.animated_sprite.frame == 0, "pause freezes SpriteFrames")
	stage.advance(1.0, 0.15)
	check(is_equal_approx(stage.authority_fx.battle_elapsed, 0.15), "slow selection combat clock")
	check(stage.actors.player.animated_sprite.frame == 1, "SpriteFrames advances on battle clock")
	var last_position: Vector2 = stage._target_positions.e1
	stage.sync_snapshot({"hp":50, "enemies":[]})
	stage.consume_events([{"type":"hit", "target":"e1", "amount":10}, {"type":"death", "target":"e1"}])
	check(stage.authority_fx.sparks[0].origin == last_position.round(), "removed enemy impact position retained")
	stage.advance(1.0, 1.0)
	stage.consume_events([{"type":"cast", "target":""}])
	check(stage.authority_fx.beams.is_empty() and stage.authority_fx.glow > 0, "self cast glow without enemy stream")
	stage.configure("test", {})
	check(stage.authority_fx == null, "manifest opt in")
	stage.queue_free()
	await process_frame
	if failures.is_empty():
		print("AUTHORITY_FX_ACCEPTANCE_PASS")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

