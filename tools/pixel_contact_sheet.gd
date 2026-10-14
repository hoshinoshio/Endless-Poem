extends SceneTree
func _initialize(): call_deferred("render_sheet")
func render_sheet():
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/pixel_v1/manifest.json"))
	var actor = load("res://scripts/visuals/pixel_actor.gd").new()
	if not actor.configure(data.actors.player): quit(2); return
	var background := ColorRect.new()
	background.color = Color("18202b")
	background.size = Vector2(1440,900)
	root.add_child(background)
	var names := ["WALK 1","WALK 2","WALK 3","WALK 4","WALK 5","WALK 6","WALK 7","WALK 8","RUN 1","RUN 2","RUN 3","RUN 4","RUN 5","RUN 6","RUN 7","RUN 8","IDLE 1","IDLE 2","IDLE 3","IDLE 4","START 1","START 2","STOP 1","STOP 2","RISE 1","RISE 2","FALL 1","FALL 2","LAND 1","LAND 2","TURN 1","TURN 2"]
	for i in actor.textures.size():
		var origin := Vector2(18+(i%8)*178,8+(i/8)*222)
		var spr := Sprite2D.new()
		spr.texture = actor.textures[i]
		spr.centered = false
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.scale = Vector2(3,3)
		spr.position = origin
		root.add_child(spr)
		var floor_line := ColorRect.new()
		floor_line.position = origin+Vector2(0,193)
		floor_line.size = Vector2(144,1)
		floor_line.color = Color("526779")
		root.add_child(floor_line)
		var label := Label.new()
		label.text = names[i]
		label.position = origin+Vector2(2,196)
		label.add_theme_font_size_override("font_size",13)
		root.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/verification/pixel_motion_contact_sheet.png")
	print("PIXEL_CONTACT_SHEET frames=",actor.textures.size()," native48x64 display3")
	actor.free()
	quit()
