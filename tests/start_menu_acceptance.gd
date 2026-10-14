extends SceneTree
var failures: Array = []
func _initialize():
	call_deferred("run")
func check(value: bool, message: String):
	if not value: failures.append(message)
func run():
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://start_menu_acceptance_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	check(game.screen == "start_menu", "Default scene starts at the new menu")
	var menu = game.start_menu
	check(menu.theme_mode == "A", "Menu retains the silver-white A theme")
	check(menu.background.name == "ArchitecturalBackground", "Menu uses the architectural environment")
	var environment_state: Dictionary = menu.background.presentation_state()
	check(environment_state.environment == "night_terrace", "Menu backdrop is the night terrace")
	check(environment_state.anomalies.is_empty() and environment_state.constellation_lines.is_empty(), "Menu has no star-map anomalies or constellation lines")
	var portrait_position: Vector2 = menu.portrait_texture.position
	menu.background.advance(10.0)
	await process_frame
	check(menu.portrait_texture.position == portrait_position, "Portrait stays fixed instead of floating vertically")
	check(menu.background.presentation_state().floor_motion == Vector2.ZERO, "Floor contact plane remains fixed")
	check(menu.buttons.keys() == ["new", "continue", "authority", "journal", "quit"], "Five ordered menu actions")
	check(menu.buttons["continue"].disabled, "No persisted expedition is advertised as continuable")
	check(game.page.get_child_count() == 1, "Menu bypasses legacy header and chapter backdrop")
	var before: Array = game.collection
	menu.buttons["journal"].pressed.emit()
	check(is_instance_valid(game.overlay), "Journal opens from menu")
	game.close_overlay()
	check(game.screen == "start_menu" and game.collection == before, "Journal closes to untouched menu and collection")
	menu.buttons["authority"].pressed.emit()
	check(game.screen == "collection", "Authority opens existing permanent collection")
	check(game.loadout_confirm.text == "返回主菜单", "Collection has menu return route")
	game.loadout_confirm.pressed.emit()
	check(game.screen == "start_menu" and game.collection == before, "Collection returns without collection mutation")
	game.start_menu.buttons["new"].pressed.emit()
	var session = game.exploration_session
	session.set_physics_process(false)
	check(game.screen == "exploration" and session.mode == "opening", "First new exploration starts the opening")
	session.opening.set_process(false)
	session.opening.advance(30)
	session.opening.advance(0.5)
	session.opening.buttons.yes.pressed.emit()
	check(session.mode == "explore" and game.store.data.visits == 1, "Accepting opens the continuous world once")
	check(game.collection == before, "New exploration preserves permanent collection")
	var world = session.world
	var player = world.player
	var position_before = player.position
	var original_screen: String = game.screen
	game.show_start_menu()
	check(not game.start_menu.buttons["continue"].disabled, "In-session suspended route enables continue")
	game.start_menu.buttons["journal"].pressed.emit()
	game.close_overlay()
	game.start_menu.buttons["authority"].pressed.emit()
	game.loadout_confirm.pressed.emit()
	game.start_menu.buttons["continue"].pressed.emit()
	check(game.screen == original_screen and session.world == world and session.world.player == player, "Continue restores same world and player after journal and collection")
	check(game.collection == before and player.position == position_before, "Continue retains position and collection")
	game.show_intro()
	check(game.screen == "intro", "Optional old narrative intro remains callable")
	game.begin_expedition(true)
	game.start_encounter("boss")
	game.confirm_loadout()
	check(game.screen == "battle", "Existing battle route still opens")
	var combat_state: Dictionary = game.combat.get_snapshot()
	var battle_page = game.page.get_children()
	game.show_pause()
	game.show_start_menu()
	game._process(2.0)
	check(is_equal_approx(float(game.combat.get_snapshot().time), float(combat_state.time)), "Battle clock stays frozen at menu")
	check(not game.start_menu.buttons["continue"].disabled, "Suspended live battle can continue")
	game.continue_session_exploration()
	check(game.screen == "battle" and game.page.get_children() == battle_page, "Battle UI instances restore intact")
	check(is_equal_approx(float(game.combat.get_snapshot().time), float(combat_state.time)), "Resume retains exact combat time")
	check(game.collection == before, "Menu suspension never changes permanent collection")
	var test_path: String = game.save_path
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	if failures.is_empty(): print("START_MENU_ACCEPTANCE_PASS")
	else: push_error(str(failures))
	quit(0 if failures.is_empty() else 1)
