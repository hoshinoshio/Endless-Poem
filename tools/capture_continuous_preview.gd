extends SceneTree
const Player = preload("res://scripts/exploration/exploration_player.gd")
var actor
func _initialize(): call_deferred("capture")
func capture():
	root.size = Vector2i(1440,900)
	var background = ColorRect.new()
	background.color = Color("1a2233")
	background.size = Vector2(1440,900)
	root.add_child(background)
	var floor_body = StaticBody2D.new()
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(3000,100)
	shape.shape = rect
	floor_body.position = Vector2(700,770)
	floor_body.add_child(shape)
	root.add_child(floor_body)
	var floor_view = ColorRect.new()
	floor_view.position = Vector2(0,720)
	floor_view.size = Vector2(1440,180)
	floor_view.color = Color("344058")
	root.add_child(floor_view)
	actor = Player.new()
	root.add_child(actor)
	actor.position = Vector2(720,720)
	actor.scale = Vector2(2.5,2.5)
	actor.set_authority_unlocked(false)
	await physics_frame
	for mode in ["idle","walk","run"]:
		actor.continuous_motion.set_motion_state(mode,Vector2(624 if mode=="run" else 390 if mode=="walk" else 0,0),1)
		for frame in 16:
			actor.continuous_motion.advance(1.0/32.0)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/verification/rig_%s_%02d.png" % [mode,frame])
	print("CONTINUOUS_RENDER frames=48 source=neutral_idle.png")
	quit()
