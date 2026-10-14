extends SceneTree
const Atlas = preload("res://scripts/visuals/sprite_atlas.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Synthetic resource fixture, never overwrites production assets.
	var fixture := Image.create(80, 30, false, Image.FORMAT_RGBA8)
	fixture.fill(Color.TRANSPARENT)
	for i in 4:
		var height := 5 if i == 3 else 20
		fixture.fill_rect(Rect2i(i * 20 + 4, 28 - height, 8, height), Color.WHITE)
	# A neighboring weapon crosses the idle region; explicit ownership mask excludes it.
	fixture.fill_rect(Rect2i(17, 3, 6, 2), Color.RED)
	fixture.set_pixel(0, 0, Color(1, 0, 1, 3.0 / 255.0))
	var path := "user://sprite_atlas_acceptance_strip.png"
	fixture.save_png(path)
	var animations := Atlas.build(path, [], Vector2i(40, 40), [[Rect2i(0, 0, 16, 30)]])
	var imported := Atlas.build("res://assets/chapter1/moonli_authority_strip.png", [], Vector2i(256, 256))
	var failed := false
	if imported.get_frame_count(&"idle") != 1 or imported.get_frame_texture(&"idle", 0).get_size() != Vector2(256, 256):
		failed = true
	for name in ["idle", "cast", "attack", "hurt", "defeat"]:
		if not animations.has_animation(name):
			failed = true
		for i in animations.get_frame_count(name):
			if animations.get_frame_texture(name, i).get_size() != Vector2(40, 40):
				failed = true
	var idle := animations.get_frame_texture(&"idle", 0).get_image()
	var defeat := animations.get_frame_texture(&"defeat", 0).get_image()
	print("ATLAS_BOUNDS idle=", idle.get_used_rect(), " defeat=", defeat.get_used_rect(), " cast=", animations.get_frame_count(&"cast"))
	if idle.get_used_rect().end.y != 40 or defeat.get_used_rect().end.y != 40 or defeat.get_used_rect().size.y >= idle.get_used_rect().size.y:
		failed = true
	for y in idle.get_height():
		for x in idle.get_width():
			var color := idle.get_pixel(x, y)
			if color.a > 0.0 and color.g < 0.1:
				failed = true
	if animations.get_frame_count(&"cast") != 3 or animations.get_frame_count(&"hurt") != 2 or animations.get_animation_loop(&"defeat"):
		failed = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failed:
		push_error("SPRITE_ATLAS_ACCEPTANCE_FAILED")
	else:
		print("SPRITE_ATLAS_ACCEPTANCE_PASS")
	quit(1 if failed else 0)
