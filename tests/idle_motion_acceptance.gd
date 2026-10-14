extends SceneTree
const Idle = preload("res://scripts/visuals/idle_motion_assets.gd")
const Atlas = preload("res://scripts/visuals/sprite_atlas.gd")
const Actor = preload("res://scripts/world/combat_actor.gd")
const Chapter = preload("res://scripts/visuals/chapter1_assets.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var atlas := Image.create(80,120,false,Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for i in 4:
		var origin := Vector2i((i%2)*40+10,(i/2)*60+10)
		atlas.fill_rect(Rect2i(origin,Vector2i(20,40)),Color(float(i)/4.0,1,1,1))
	var temporary := "user://idle_motion_acceptance.png"
	atlas.save_png(temporary)
	var old := SpriteFrames.new()
	old.remove_animation(&"default")
	var canvas := Image.create(100,100,false,Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	canvas.fill_rect(Rect2i(30,20,40,80),Color.WHITE)
	var texture := ImageTexture.create_from_image(canvas)
	for state in ["idle","cast","attack","hurt","defeat"]:
		old.add_animation(state)
		old.add_frame(state,texture)
	var result := Idle.apply(old,temporary)
	var regional := Idle.apply(old,temporary,[[0,0,40,60],[40,0,40,60],[0,60,40,60],[40,60,40,60]])
	assert(regional.get_frame_count(&"idle") == 4)
	assert(result.get_frame_count(&"idle") == 4)
	assert(result.get_animation_speed(&"idle") == 4)
	assert(result.get_animation_loop(&"idle"))
	assert(old.get_frame_count(&"idle") == 1)
	for state in ["cast","attack","hurt","defeat"]:
		assert(result.get_frame_count(state) == old.get_frame_count(state))
		assert(result.get_frame_texture(state,0) == old.get_frame_texture(state,0))
	for i in 4:
		var image := result.get_frame_texture(&"idle",i).get_image()
		assert(image.get_size() == Vector2i(100,100))
		assert(image.get_used_rect() == Rect2i(30,20,40,80))
		assert(image.get_pixel(50,50).r != result.get_frame_texture(&"idle",(i+1)%4).get_image().get_pixel(50,50).r)
		assert(image.get_data() == regional.get_frame_texture(&"idle",i).get_image().get_data())
	var actor = Actor.new()
	root.add_child(actor)
	actor.configure("hero",{"sprite_frames":result},217,300)
	assert(is_equal_approx(actor.get_visual_height(),217))
	var picking: Rect2 = actor.get_target_rect()
	actor.advance(.3)
	assert(actor.animated_sprite.frame == 1)
	actor.play_animation("cast")
	assert(actor.get_target_rect() == picking)
	actor.advance(.2)
	assert(actor.get_target_rect() == picking)
	var checked := 0
	for id in ["moonli_authority","patrol_guard","hour_guard","brass_instrument","echo_observer","chronos_trial","time_anchor"]:
		var path: String = "res://assets/chapter1/idle/"+id+"_atlas.png"
		if FileAccess.file_exists(path):
			var source := Atlas.build("res://assets/chapter1/"+id+"_atlas.png")
			var regions: Array = [[0,0,627,643],[627,0,627,643],[0,643,627,611],[627,643,627,611]] if id == "moonli_authority" else []
			var applied := Idle.apply(source,path,regions)
			assert(applied.get_frame_count(&"idle") == 4)
			var expected_height := source.get_frame_texture(&"idle",0).get_image().get_used_rect().size.y
			var idle_texture := applied.get_frame_texture(&"idle",0)
			assert(idle_texture.get_image().get_used_rect().size.y == expected_height)
			for state in applied.get_animation_names():
				if state == &"default":
					continue
				for index in applied.get_frame_count(state):
					assert(applied.get_frame_texture(state,index).get_size() == idle_texture.get_size())
			for state in ["cast","attack","hurt","defeat"]:
				for index in source.get_frame_count(state):
					var old_image := source.get_frame_texture(state,index).get_image()
					var new_image := applied.get_frame_texture(state,index).get_image()
					var padding := (new_image.get_width()-old_image.get_width())/2
					assert(new_image.get_region(Rect2i(padding,0,old_image.get_width(),old_image.get_height())).get_data() == old_image.get_data())
			checked += 1
	assert(checked == 7)
	var manifest := Chapter.build()
	actor.configure("integrated_hero",manifest.player,217,300)
	assert(is_equal_approx(actor.get_visual_height(),217))
	assert(actor.animated_sprite.sprite_frames.get_frame_count(&"idle") == 4)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	print("IDLE_MOTION_ACCEPTANCE_PASS original_actions=true shared_canvas=true uniform_scale=true footpoint=true hero_height=217 stable_collision=true actual_assets_checked=",checked)
	quit()
