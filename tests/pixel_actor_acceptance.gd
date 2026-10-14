extends SceneTree
const Pixel = preload("res://scripts/visuals/pixel_actor.gd")
var failures := 0
func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ")+label)
	if not value: failures += 1
func _initialize() -> void:
	var source := Image.create(96,64,false,Image.FORMAT_RGBA8)
	source.fill(Color.TRANSPARENT)
	source.fill_rect(Rect2i(20,8,8,56),Color.RED)
	source.fill_rect(Rect2i(65,8,14,56),Color.BLUE)
	var path := "user://pixel_acceptance_source.png"
	source.save_png(path)
	var rig := Pixel.new()
	root.add_child(rig)
	var config := {"sheet":path,"source_frames":[[0,0,48,64],[48,0,48,64]],"scale":3,"animations":{"idle":{"frames":[0,1],"fps":6,"loop":true},"walk":{"frames":[0,1],"fps":12,"loop":true},"run":{"frames":[0,1],"fps":16,"loop":true},"jump":{"frames":[1,0],"fps":8,"loop":false},"hover":{"frames":[1,0],"fps":6,"loop":true}}}
	check(rig.configure(config),"valid manifest actor loads")
	for texture in rig.textures: check(texture.get_size()==Vector2(48,64),"normalized canvas is 48 by 64")
	check(rig.scale==Vector2(3,3) and rig.sprite.position==Vector2(-24,-64),"integer display and common bottom center anchor")
	rig.advance(.2)
	check(rig.frame_index==1,"idle samples authored next frame")
	var frozen: Dictionary = rig.presentation_state()
	rig.advance(0)
	check(frozen==rig.presentation_state(),"zero local delta freezes frame and clock")
	rig.set_motion_state("walk",Vector2(390,0),-1)
	rig.phase=.75
	rig._sample()
	check(rig.frame_index==1 and rig.sprite.scale.x==-1,"stride phase and facing sample raster frame")
	rig.clock=0
	rig.phase=0
	rig._sample()
	check(rig.frame_index==0,"restored phase force samples earlier frame")
	rig.set_motion_state("jump",Vector2(0,-950),1)
	rig.advance(.3)
	check(rig.frame_index==1,"nonloop jump reaches final authored frame")
	rig.mechanical=true
	rig.set_motion_state("run",Vector2(300,0),1)
	rig._sample()
	check(rig.sampled_animation=="hover","mechanical movement selects hover rather than humanoid gait")
	check(rig.get_children().size()==1 and rig.get_child(0) is Sprite2D,"pixel renderer has no deforming mesh")
	rig.render_enabled=false
	rig._sample()
	check(not rig.sprite.visible,"restored render state updates visibility")
	var invalid := Pixel.new()
	check(not invalid.configure({}),"invalid actor does not activate pixel renderer")
	invalid.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PIXEL ACCEPTANCE failures=",failures)
	quit(failures)
