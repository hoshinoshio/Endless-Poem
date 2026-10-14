extends SceneTree
## Separate real-main process: exit code 0 plus BOTH markers proves actual quit.
var game
var save_path = "user://menu_a_quit_%d.json" % Time.get_ticks_usec()

func _initialize(): call_deferred("run")

func cleanup():
	print("MENU_A_QUIT_TREE_EXIT")
	for suffix in ["", ".tmp", ".bak"]:
		var path = ProjectSettings.globalize_path(save_path + suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func run():
	if DisplayServer.get_name() == "headless": quit(2); return
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	game.save_path = save_path
	root.add_child(game)
	game.tree_exiting.connect(cleanup)
	await create_timer(0.7).timeout
	var button: Control = game.start_menu.buttons["quit"]
	var point = button.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.global_position = point
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release = press.duplicate()
	release.pressed = false
	print("MENU_A_QUIT_BEFORE_REAL_MOUSE_RELEASE")
	root.push_input(release, true)
	await create_timer(2.0).timeout
	print("FAIL MENU_A_QUIT timeout: actual main did not quit")
	quit(1)
