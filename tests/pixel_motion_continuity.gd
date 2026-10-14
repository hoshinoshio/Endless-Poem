extends SceneTree
const Pixel = preload("res://scripts/visuals/pixel_actor.gd")
var failures := 0
func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ")+label)
	if not value: failures += 1
func _initialize() -> void:
	var path := "user://pixel_motion_source.png"
	var source := Image.create(96,64,false,Image.FORMAT_RGBA8)
	source.fill(Color.WHITE)
	source.save_png(path)
	var clips := {}
	for name in ["idle","walk","run","jump","fall","start","stop","turn","land","hurt"]:
		clips[name] = {"frames":[0,1],"fps":10,"loop":name in ["idle","walk","run"]}
	var rig := Pixel.new()
	root.add_child(rig)
	check(rig.configure({"sheet":path,"source_frames":[[0,0,48,64],[48,0,48,64]],"scale":2,"animations":clips}),"configure synthetic authored strips")
	rig.set_motion_state("walk",Vector2(390,0),1)
	check(rig.transition=="start","idle to walk selects authored start")
	rig.advance(.1,25)
	check(is_equal_approx(rig.phase,.25),"actual distance controls stride")
	var phase_before: float = rig.phase
	rig.set_motion_state("run",Vector2(624,0),1)
	check(rig.phase==phase_before and rig.transition=="start","Shift preserves gait phase and current transition")
	rig.advance(.1,40)
	check(is_equal_approx(rig.phase,.5) and rig.transition.is_empty(),"run uses own stride length with shared phase")
	rig.advance(.1,0)
	check(is_equal_approx(rig.phase,.5),"blocked movement does not advance feet")
	rig.set_motion_state("walk",Vector2(-390,0),-1)
	check(rig.transition=="turn" and rig.facing==-1,"direction change responds immediately with authored turn")
	rig.set_motion_state("jump",Vector2(0,-900),-1)
	check(rig.transition.is_empty(),"jump interrupts transition immediately")
	rig.advance(.2,0)
	check(is_equal_approx(rig.phase,.5),"airborne movement preserves gait")
	rig.set_motion_state("idle",Vector2.ZERO,-1)
	check(rig.transition=="land","landing selects authored compression")
	rig.advance(.05,0)
	var snapshot := {}
	for key in ["clock","phase","state","speed","facing","state_time","movement_blend","vertical_speed","authority_pulse","transition","transition_time"]:
		snapshot[key] = rig.get(key)
	var sampled: Dictionary = rig.presentation_state()
	rig.advance(0,90)
	check(sampled==rig.presentation_state(),"pause freezes raster pose")
	rig.advance(.4,0)
	for key in snapshot: rig.set(key,snapshot[key])
	rig._sample()
	check(sampled==rig.presentation_state(),"restore redraws recorded transition deterministically")
	rig.set_motion_state("walk",Vector2(390,0),-1)
	rig.advance(.3,20)
	rig.set_motion_state("idle",Vector2.ZERO,-1)
	check(rig.transition=="stop","release selects authored stop")
	rig.advance(.3,0)
	check(rig.sampled_animation=="idle","stop completes into authored idle")
	check(rig.configure({"sheet":path,"source_frames":[[0,0,48,64],[48,0,48,64]],"frame_anchor":[32,64],"scale":3,"animations":clips}),"asymmetric canvas anchor configures")
	rig.set_motion_state("idle",Vector2.ZERO,1)
	rig._sample()
	check(rig.sprite.position==Vector2(-32,-64),"right facing retains configured foot anchor")
	rig.set_motion_state("idle",Vector2.ZERO,-1)
	rig._sample()
	check(rig.sprite.position==Vector2(32,-64) and rig.sprite.scale.x==-1,"mirroring retains the same world foot anchor")
	rig.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PIXEL MOTION CONTINUITY failures=",failures)
	quit(failures)
