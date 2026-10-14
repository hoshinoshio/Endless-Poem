extends SceneTree
var failures: Array = []
var checks := 0
func check(value: bool, label: String):
	checks += 1
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func _initialize(): call_deferred("run_test")
func run_test():
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/pixel_v1/manifest.json"))
	var rig = load("res://scripts/visuals/pixel_actor.gd").new()
	check(rig.configure(data.actors.player),"actual authored assets load")
	check(rig.textures.size()==48,"48 supplied source frames present")
	var valid := true
	var hashes := {}
	for texture in rig.textures:
		var image: Image = texture.get_image()
		valid = valid and image.get_size()==Vector2i(48,64) and image.detect_alpha()!=Image.ALPHA_NONE
		hashes[image.get_data().hex_encode().sha256_text()] = true
	check(valid,"every output frame is native48x64 with alpha")
	check(hashes.size()==48,"all 48 authored raster frames are distinct")
	var config: Dictionary = data.actors.player
	var inside := true
	for entry in config.source_frames:
		var left: float = float(config.frame_anchor[0])-float(entry.anchor[0])*float(config.source_scale)
		var right: float = left+float(entry.rect[2])*float(config.source_scale)
		inside = inside and left>=0 and right<=48.001
	check(inside,"full authored silhouettes fit horizontal canvas without cropping")
	check(rig.animations.walk.frames.size()==8 and rig.animations.run.frames.size()==8,"walk and run each have eight poses")
	check(rig.animations.idle.frames.size()>=4,"idle uses the authored close-leg sequence")
	rig.free()
	var preview = load("res://scenes/previews/pixel_motion_preview.tscn").instantiate()
	root.add_child(preview)
	preview.set_physics_process(false)
	await physics_frame
	var world = preview.world
	for i in 20: world.advance_simulation(1.0/60)
	rig = world.player.continuous_motion
	world.set_movement_input(0,true)
	world.advance_simulation(1.0/60)
	check(rig.state=="jump","actual jump starts rise animation")
	for i in 100:
		world.advance_simulation(1.0/120)
		if world.player.velocity.y>=0: break
	check(rig.state=="fall" and rig.state_time<0.03,"apex starts fall strip with its own fresh timing")
	for i in 140: world.advance_simulation(1.0/120)
	world.set_movement_input(1,false)
	world.advance_simulation(1.0/120)
	var snap: Dictionary = world._capture_player()
	var before: Dictionary = rig.presentation_state()
	check(snap.rig.has("transition") and snap.rig.has("transition_time"),"world snapshots include authored transition")
	for i in 30: world.advance_simulation(1.0/120)
	world._restore_player(snap)
	check(rig.presentation_state()==before,"restoring actual world history restores exact raster pose")
	print("PIXEL_AUTHORED_ASSETS checks=",checks," failures=",failures)
	preview.free()
	quit(0 if failures.is_empty() else 1)
