extends SceneTree
const OUTPUT = "res://docs/verification/"
var SAVE = "user://start_menu_render_%d.json" % Time.get_ticks_usec()
var game
var failures = 0
var checks = 0
var clicks = 0

func _initialize(): call_deferred("run")

func check(value: bool, message: String):
	checks += 1
	if not value: failures += 1
	print(("PASS " if value else "FAIL ") + message)

func capture(name: String):
	await process_frame
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	check(frame != null and not frame.is_empty(), "GPU capture " + name)
	if frame != null: frame.save_png(OUTPUT + "grounded_" + name + ".png")

func click(node: Control):
	var point = node.get_global_rect().get_center()
	await physics_frame
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.global_position = point
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release = press.duplicate()
	release.pressed = false
	root.push_input(release, true)
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

func run():
	if DisplayServer.get_name() == "headless": quit(2); return
	var default_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	check(default_scene == "res://scenes/main.tscn", "configured default project scene is verified")
	game = load(default_scene).instantiate()
	game.save_path = SAVE
	root.add_child(game)
	await process_frame
	await physics_frame
	check(game.screen == "start_menu", "configured default entry shows new menu")
	var menu = game.start_menu
	check(menu.title_texture.texture != null, "real artistic title texture is loaded")
	check(menu.portrait_texture.texture != null, "real praying portrait texture is loaded")
	check(menu.theme_mode == "A", "user selected silver theme")
	check(menu.background.presentation_state().get("environment") == "night_terrace", "architectural terrace replaces cosmic map")
	check(menu.background.presentation_state().get("background_loaded", false), "independent terrace texture is loaded")
	check(menu.background.presentation_state().get("anomalies", []).is_empty(), "menu no longer presents anomaly stars")
	check(menu.buttons.size() == 5, "all five menu buttons are present")
	check(menu.buttons["continue"].disabled, "fresh process does not pretend a saved expedition exists")
	check(game.page.get_child_count() == 1 and not game.scenery.visible, "old introduction header and scenery are absent")
	check(menu.portrait_texture.get_global_rect().position.x >= 720, "portrait occupies right half")
	check(menu.portrait_texture.size.is_equal_approx(Vector2(540, 675)), "portrait respects agreed proportions")
	var before: Array = game.collection.duplicate(true)
	await capture("start_menu_default")
	var star_time: float = menu.background.presentation_state().elapsed
	await create_timer(0.4).timeout
	check(menu.background.presentation_state().elapsed > star_time, "environment illumination runs during ordinary menu processing")
	await click(menu.buttons["journal"])
	check(is_instance_valid(game.overlay), "mouse opens exploration journal")
	await escape()
	check(not is_instance_valid(game.overlay) and game.screen == "start_menu", "Esc closes journal onto new menu")
	await click(menu.buttons["authority"])
	check(game.screen == "collection", "mouse opens existing authority card collection")
	await click(game.loadout_confirm)
	check(game.screen == "start_menu", "collection returns to new menu")
	check(game.collection == before, "menu actions preserve permanent collection")
	await click(game.start_menu.buttons["new"])
	check(game.screen == "exploration" and game.exploration_session.mode == "opening", "mouse new exploration enters first opening")
	var session = game.exploration_session
	session.set_physics_process(false)
	session.opening.set_process(false)
	session.opening.advance(30)
	session.opening.advance(0.5)
	await click(session.opening.buttons.yes)
	check(session.mode == "explore", "mouse acceptance enters continuous map")
	game.show_start_menu()
	await process_frame
	check(not game.start_menu.buttons["continue"].disabled, "suspended session enables continue")
	await click(game.start_menu.buttons["continue"])
	check(game.screen == "exploration" and game.exploration_session == session and session.mode == "explore", "mouse continue restores same continuous world")
	game.show_start_menu()
	await capture("start_menu_continue")
	# A smaller real window must keep the same layout and readable hit targets.
	root.size = Vector2i(1152, 720)
	await process_frame
	await physics_frame
	check(game.start_menu.portrait_texture.get_global_rect().end.x <= 1440.1, "portrait remains within logical viewport")
	await capture("start_menu_small_window")
	root.size = Vector2i(1440, 900)
	await process_frame
	print("START_MENU_RENDER checks=%d failures=%d mouse_clicks=%d default_scene=%s" % [checks, failures, clicks, default_scene])
	game.queue_free()
	await process_frame
	for suffix in ["", ".tmp", ".bak"]:
		var path = ProjectSettings.globalize_path(SAVE + suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	quit(0 if failures == 0 else 1)
