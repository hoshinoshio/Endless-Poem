extends SceneTree
## GPU evidence fixture: production CombatActors and World, no alternate renderer.
const Actor = preload("res://scripts/world/combat_actor.gd")
const Assets = preload("res://scripts/visuals/chapter1_assets.gd")
const Pixel = preload("res://scripts/visuals/pixel_actor.gd")
const World = preload("res://scripts/exploration/exploration_world.gd")
const FONT = preload("res://assets/msyh.ttc")
const OUTPUT := "res://docs/verification/"
const KEYS := ["player","guard","elite","instrument","observer","boss","anchor","musheng"]
const NAMES := ["月璃","巡刻卫兵","整点卫兵","黄铜星仪","回声观测员","克洛诺斯 · 试炼相","时间锚","暮笙"]
class Gallery extends Node2D:
	var stage := "待机"
	func _draw():
		draw_rect(Rect2(0,0,1440,900),Color("1d2938"))
		for row in 2:
			var ground := 360.0+row*380
			draw_rect(Rect2(0,ground,1440,105),Color("26303a"))
			draw_line(Vector2(30,ground),Vector2(1410,ground),Color("667079"),1)
		draw_string(FONT,Vector2(44,45),"全阵容像素动作 · 实际运行渲染",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("d6dce3"))
		draw_string(FONT,Vector2(1140,45),stage,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("b8c8d8"))
		for index in 8:
			var center := Vector2(180+(index%4)*360,360+(index/4)*380)
			draw_line(center-Vector2(8,0),center+Vector2(8,0),Color("a9b9ca"),2)
			draw_string(FONT,center+Vector2(-130,47),NAMES[index],HORIZONTAL_ALIGNMENT_CENTER,260,21,Color("dbe0e7"))
var failures := 0
var checks := 0
var gallery
var actors: Array = []
var feet: Array = []
var observed: Array = []
func _initialize(): call_deferred("run")
func check(value,label):
	checks += 1
	print(("PASS " if value else "FAIL ")+label)
	if not value: failures += 1
func capture(path: String, jpg := false):
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if jpg: image.save_jpg(path,.92)
	else: image.save_png(path)
func set_stage(state: String):
	gallery.stage={"idle":"待机","walk":"行走","windup":"蓄力 / 施法","attack":"动作","recover":"恢复","hurt":"受击","defeat":"退场"}.get(state,state)
	gallery.queue_redraw()
	for index in actors.size():
		var actor = actors[index]
		var actual := state
		if index==0 and state=="windup": actual="cast"
		if index==0 and state=="recover": actual="idle"
		actor.play_animation(actual)
		actor.set_motion_state(actual,Vector2(100,0) if actual=="walk" else Vector2.ZERO,1)
func run():
	if DisplayServer.get_name()=="headless": printerr("GPU renderer required"); quit(2); return
	root.content_scale_size=Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT+"pixel_roster_frames"))
	gallery=Gallery.new()
	root.add_child(gallery)
	var assets: Dictionary = Assets.build()
	for index in KEYS.size():
		var key: String=KEYS[index]
		var actor=Actor.new()
		gallery.add_child(actor)
		var asset: Dictionary=assets.player if key=="player" else assets.enemies[key]
		actor.configure(key,asset,240,280)
		actor.position=Vector2(180+(index%4)*360,360+(index/4)*380)
		check(actor.continuous_motion is Pixel,key+" production actor uses authored pixels")
		actors.append(actor)
		feet.append(actor.position)
		observed.append({})
	if failures>0: quit(1); return
	set_stage("idle")
	# Clock-zero pause proof does not manipulate rig transforms or swap textures.
	var before: Array=[]
	for actor in actors: before.append(actor.continuous_motion.presentation_state())
	for index in actors.size():
		actors[index].advance(0)
		check(actors[index].continuous_motion.presentation_state()==before[index],KEYS[index]+" zero paused clock holds exact pose")
	var last_stage := ""
	for frame in 240:
		var t := frame/30.0
		var stage := "idle"
		if t>=1 and t<3: stage="walk"
		elif t>=3 and t<3.4: stage="windup"
		elif t>=3.4 and t<3.7: stage="attack"
		elif t>=3.7 and t<4.2: stage="recover"
		elif t>=4.2 and t<4.5: stage="hurt"
		elif t>=4.5 and t<5.3: stage="defeat"
		if stage!=last_stage: set_stage(stage); last_stage=stage
		for index in actors.size():
			actors[index].advance(1.0/30)
			var rig = actors[index].continuous_motion
			observed[index][str(rig.sampled_animation)+":"+str(rig.frame_index)]=true
			if actors[index].position!=feet[index]: check(false,KEYS[index]+" root foot drift")
		await capture(OUTPUT+"pixel_roster_frames/frame_%04d.jpg" % frame,true)
		if frame==20: await capture(OUTPUT+"pixel_roster_2026-10-10.png")
		if frame==65: await capture(OUTPUT+"pixel_roster_2026-10-10_moving.png")
	for index in actors.size():
		check(observed[index].size()>8,KEYS[index]+" raster frames advance across actual state sequence")
		check(actors[index].position==feet[index],KEYS[index]+" root feet remain fixed throughout gallery")
	gallery.free()
	root.canvas_transform=Transform2D.IDENTITY
	var world=World.new()
	root.add_child(world)
	world.configure({"ruleset":"time_authority_v2","position":[2500,1900],"authority_unlocked":false,"authority_tutorial_step":0})
	world.set_physics_process(false)
	check(world.player.continuous_motion is Pixel,"normal world hero uses pixel renderer")
	check(world.observer_npc is Pixel,"normal world Musheng uses independent pixel renderer")
	for frame in 20: world.advance_simulation(1.0/60)
	world.camera.force_update_scroll()
	await capture(OUTPUT+"pixel_world_start_2026-10-10.png")
	world.set_player_position(Vector2(13200,1900))
	for frame in 30: world.advance_simulation(1.0/60)
	world.camera.force_update_scroll()
	await capture(OUTPUT+"pixel_world_musheng_2026-10-10.png")
	world.set_paused(true)
	world.free()
	print("PIXEL_ROSTER_RENDER ",checks," checks failures=",failures," frames=240 display=",DisplayServer.get_name())
	quit(failures)
