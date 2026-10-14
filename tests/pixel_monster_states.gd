extends SceneTree
const Actor = preload("res://scripts/world/combat_actor.gd")
const Assets = preload("res://scripts/visuals/chapter1_assets.gd")
const Pixel = preload("res://scripts/visuals/pixel_actor.gd")
var checks := 0
var failures: Array = []
func check(value: bool,label: String) -> void:
	checks += 1
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var assets: Dictionary = Assets.build()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(Pixel.MANIFEST))
	check(parsed is Dictionary and parsed.get("ready",false),"complete authored set enables normal runtime")
	if not parsed is Dictionary or not parsed.get("ready",false): quit(1); return
	for key in ["guard","elite","instrument","observer","boss","anchor","musheng"]:
		var asset: Dictionary = assets.enemies[key]
		check(asset.get("pixel_key")==key,key+" has explicit authored identity")
		var actor := Actor.new()
		root.add_child(actor)
		actor.configure("test_"+key,asset,240,280)
		check(actor.continuous_motion is Pixel,key+" normal actor loads authored raster")
		if not actor.continuous_motion is Pixel: actor.queue_free(); continue
		var rig: Pixel = actor.continuous_motion
		check(rig.mechanical==(key in ["instrument","anchor"]),key+" correct humanoid/mechanical mode")
		check(not actor.sprite.flip_h and not actor.animated_sprite.flip_h,key+" has only one facing mirror")
		var seen: Dictionary = {}
		for state in ["idle","windup","attack","recover","hurt","defeat"]:
			check(actor.has_animation(state),key+" authored "+state+" available")
			actor.set_motion_state(state,Vector2.ZERO,1)
			actor.advance(0.01)
			check(rig.sampled_animation==state,key+" presents "+state)
			var strip: Dictionary = rig.animations.get(state,{})
			var indices: Array = strip.get("frames",[])
			var distinct := not indices.is_empty()
			for index in indices:
				if seen.has(index): distinct = false
				seen[index] = state
			check(distinct,key+" "+state+" uses distinct authored frames")
			if state=="defeat":
				actor.advance(3)
				check(rig.frame_index==indices.size()-1,key+" defeat holds final pose")
		actor.play_animation("idle")
		actor.set_motion_state("walk",Vector2(100,0),-1)
		actor.advance(0.3)
		check(rig.sampled_animation==("hover" if rig.mechanical else "walk"),key+" moving selects matching gait")
		var extent: Vector2 = Vector2(48,64)*float(rig.display_scale)
		var anchor: Vector2 = rig.frame_anchor*float(rig.display_scale)
		check(actor._local_bounds==Rect2(Vector2(anchor.x-extent.x,-anchor.y),extent),key+" mirrored target bounds honor foot anchor")
		var frozen: Dictionary = rig.presentation_state()
		actor.advance(0)
		check(frozen==rig.presentation_state(),key+" zero battle delta freezes authored pose")
		actor.set_motion_state("idle",Vector2.ZERO,1)
		actor.play_animation("attack")
		var duration: float = float(rig.animations.attack.frames.size())/float(rig.animations.attack.fps)
		check(is_equal_approx(actor.feedback_remaining,duration),key+" feedback lasts authored attack duration")
		actor.advance(duration*0.7)
		check(rig.sampled_animation=="attack",key+" action feedback stays attack before completion")
		actor.advance(duration*0.4)
		check(rig.sampled_animation=="idle",key+" action finishes into requested idle")
		actor.queue_free()
	# Ad hoc actors without an asset key still resolve their model kind.
	var fallback := Actor.new()
	root.add_child(fallback)
	fallback.configure("unit_001",{},240,280)
	fallback.sync({"kind":"guardian"})
	check(fallback.continuous_motion is Pixel and fallback.continuous_motion.actor_key=="guard","model kind fallback resolves guardian")
	fallback.queue_free()
	print("PIXEL_MONSTERS checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
