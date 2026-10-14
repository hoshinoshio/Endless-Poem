extends SceneTree
func _initialize():
	var img=Image.new()
	var error=img.load_svg_from_string(FileAccess.get_file_as_string("res://art_review/2026-10-08-locomotion/walk_pose_guide.svg"))
	if error!=OK: quit(1);return
	img.save_png("res://art_review/2026-10-08-locomotion/walk_pose_guide.png")
	quit()
