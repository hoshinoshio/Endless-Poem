extends SceneTree
## Real default-scene GPU acceptance. Uses only an isolated temporary save.
const OUTPUT = "res://docs/verification/"
var save_path = "user://menu_a_acceptance_%d.json" % Time.get_ticks_usec()
var game
var failures := 0
var checks := 0
var clicks := 0

func _initialize(): call_deferred("run")

func check(value: bool, message: String):
	checks += 1
	if not value: failures += 1
	print(("PASS " if value else "FAIL ") + message)

func frame_image() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func capture(name: String):
	var image: Image = await frame_image()
	check(image != null and not image.is_empty(), "GPU image " + name)
	if image != null and not image.is_empty():
		check(image.save_png(OUTPUT + name + ".png") == OK, "saved " + name)

func move_pointer(point: Vector2):
	var event = InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	await process_frame

func click(node: Control):
	await move_pointer(node.get_global_rect().get_center())
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = node.get_global_rect().get_center()
	event.global_position = event.position
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame
	clicks += 1

func escape():
	var event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func layout_check(menu):
	var bounds = Rect2(Vector2.ZERO, Vector2(root.get_visible_rect().size))
	var previous = Rect2()
	for key in ["new", "continue", "authority", "journal", "quit"]:
		var button: Control = menu.buttons[key]
		var rect = button.get_global_rect()
		check(button.is_visible_in_tree() and bounds.encloses(rect), key + " fully inside visible viewport")
		check(previous.size == Vector2.ZERO or not previous.intersects(rect), key + " hit target does not overlap previous action")
		previous = rect
		# GUI picking is verified again by actual clicks below; title/portrait must ignore mouse.
	check(menu.portrait_texture.mouse_filter == Control.MOUSE_FILTER_IGNORE and menu.title_texture.mouse_filter == Control.MOUSE_FILTER_IGNORE, "art cannot intercept action mouse input")

func run():
	if DisplayServer.get_name() == "headless":
		print("FAIL requires real GPU window")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT + "menu_a_motion_frames"))
	var scene_path: String = ProjectSettings.get_setting("application/run/main_scene")
	check(scene_path == "res://scenes/main.tscn", "actual configured default scene")
	game = load(scene_path).instantiate()
	game.save_path = save_path
	root.add_child(game)
	await create_timer(0.7).timeout
	var menu = game.start_menu
	check(game.screen == "start_menu" and menu.buttons.size() == 5, "default scene shows all five menu A actions")
	check(menu.theme_mode == "A", "approved menu A selected")
	check(menu.title_texture.texture.resource_path.ends_with("menu_a_reference_title.png"), "approved reference title loaded")
	check(menu.portrait_texture.texture.resource_path.ends_with("menu_a_reference_portrait.png"), "approved full reference portrait loaded")
	check(menu.background.presentation_state().background_path.ends_with("menu_a_reference_background.png"), "approved reference background loaded")
	check(menu.buttons["continue"].disabled, "fresh isolated save disables continue")
	var collection: Array = game.collection.duplicate(true)
	await click(menu.buttons["continue"])
	check(game.screen == "start_menu" and not is_instance_valid(game.exploration_session), "disabled continue cannot launch a run")
	await move_pointer(Vector2(420, 850))
	menu.buttons["new"].release_focus()
	await create_timer(0.3).timeout
	layout_check(menu)
	await capture("menu_a_default")
	var fixed_rect: Rect2 = menu.portrait_texture.get_global_rect()
	var idle_highlight: float = menu.buttons["new"].highlight
	await move_pointer(menu.buttons["new"].get_global_rect().get_center())
	await create_timer(0.25).timeout
	check(menu.buttons["new"].highlight > idle_highlight + 0.3, "physical mouse motion animates new-action highlight")
	await capture("menu_a_hover")
	await move_pointer(Vector2(420, 850))
	menu.buttons["journal"].grab_focus()
	await create_timer(0.25).timeout
	check(menu.buttons["journal"].highlight > 0.5, "keyboard focus has visible animated feedback")
	await capture("menu_a_focus")
	menu.buttons["journal"].release_focus()
	await create_timer(0.3).timeout
	var first: Image = await frame_image()
	var saved := true
	for i in range(60):
		await create_timer(0.05).timeout
		var frame: Image = await frame_image()
		saved = saved and frame != null and not frame.is_empty()
		if frame != null: saved = saved and frame.save_png(OUTPUT + "menu_a_motion_frames/frame_%03d.png" % i) == OK
	var last: Image = await frame_image()
	# Upper sky, beyond title; entry fade has already finished before this comparison.
	var sky = Rect2i(600, 20, 700, 300)
	check(first.get_region(sky).get_data() != last.get_region(sky).get_data(), "GPU upper-sky pixels change after settled entry fade")
	check(menu.portrait_texture.get_global_rect().is_equal_approx(fixed_rect), "portrait position and proportions remain fixed during motion")
	check(saved, "60 full GPU motion frames saved for video review")
	await click(menu.buttons["journal"])
	check(is_instance_valid(game.overlay), "mouse opens exploration journal")
	await escape()
	check(not is_instance_valid(game.overlay) and game.screen == "start_menu", "Esc returns from journal to menu A")
	await click(game.start_menu.buttons["authority"])
	check(game.screen == "collection", "mouse opens authority collection")
	await click(game.loadout_confirm)
	check(game.screen == "start_menu", "collection return reaches menu A")
	check(game.collection == collection, "journal and collection actions preserve collection")
	await click(game.start_menu.buttons["new"])
	check(game.screen == "exploration" and game.exploration_session.mode == "opening", "new exploration opens narrative")
	var session = game.exploration_session
	session.set_physics_process(false)
	session.opening.set_process(false)
	session.opening.advance(30)
	session.opening.advance(0.5)
	await click(session.opening.buttons.yes)
	check(session.mode == "explore", "mouse narrative acceptance enters continuous map")
	game.show_start_menu()
	await process_frame
	check(not game.start_menu.buttons["continue"].disabled, "suspended run enables continue")
	await click(game.start_menu.buttons["continue"])
	check(game.screen == "exploration" and game.exploration_session == session and session.mode == "explore", "mouse continue resumes same live session")
	game.show_start_menu()
	await process_frame
	check(game.collection == collection, "new and continue preserve collection")
	root.size = Vector2i(1152, 720)
	await create_timer(0.3).timeout
	layout_check(game.start_menu)
	await capture("menu_a_small_window")
	root.size = Vector2i(1440, 900)
	game.queue_free()
	await process_frame
	game = load(scene_path).instantiate()
	game.save_path = save_path
	root.add_child(game)
	await create_timer(0.3).timeout
	check(not game.start_menu.buttons["continue"].disabled, "fresh default scene detects persisted run")
	await click(game.start_menu.buttons["continue"])
	check(game.screen == "exploration" and game.exploration_session.mode == "explore", "mouse continue restores persisted map in fresh main instance")
	check(game.collection == collection, "persisted continue preserves collection")
	print("MENU_A_REFERENCE_RENDER checks=%d failures=%d mouse_clicks=%d default_scene=%s" % [checks, failures, clicks, scene_path])
	game.queue_free()
	await process_frame
	for suffix in ["", ".tmp", ".bak"]:
		var path = ProjectSettings.globalize_path(save_path + suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	quit(0 if failures == 0 else 1)
