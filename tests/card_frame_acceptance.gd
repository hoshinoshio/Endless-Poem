extends SceneTree
const Palette = preload("res://scripts/authority/authority_palette.gd")
const Card = preload("res://scripts/authority/time_card.gd")
const Temporal = preload("res://scripts/authority/temporal_controller.gd")
const Session = preload("res://scripts/exploration/exploration_session.gd")
const Main = preload("res://scripts/ui/main.gd")
const Store = preload("res://scripts/progression/collection_store.gd")
var failures: Array[String] = []
var checks := 0
var clicked_id := ""

func _initialize() -> void:
	call_deferred("run_test")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL ", label)

func text_nodes(node: Node) -> Array:
	var found: Array = []
	if node is Label or node is RichTextLabel: found.append(node)
	for child in node.get_children(): found.append_array(text_nodes(child))
	return found

func run_test() -> void:
	check(Palette.AUTHORITIES.size() == 7, "seven authority definitions")
	for id in ["magic", "time", "space", "ether", "life", "self", "end"]:
		var path := Palette.gem_path(id)
		check(not Palette.display_name(id).is_empty() and ResourceLoader.exists(path), id + " resolves to a named gem")
		var texture := load(path) as Texture2D
		check(texture != null and texture.get_size() == Vector2(104, 104), id + " imports at 2x")
	check(Palette.gem_path("time").ends_with("/gem_time.svg"), "time uses supplied blue gem_time")
	check(Palette.gem_path("space").ends_with("/gem_space.svg"), "space uses supplied amber gem_space")
	check(Card.FRAME.get_size() == Vector2(500, 700), "frame imports at 2x")
	var expected := ["使所选对象的局部时间停止 2 秒。", "使所选对象的局部时间加速推进。", "使所选对象回到 3 秒前的状态。"]
	var catalog := Temporal.card_catalog()
	for index in catalog.size():
		var face := Card.new()
		root.add_child(face)
		face.configure(catalog[index])
		check(text_nodes(face).size() == 2, "card contains exactly two text nodes")
		check(face.title_label.text == catalog[index].title and face.description_label.text == expected[index] and catalog[index].description == expected[index], "name and effect match catalog and approved copy")
		check(Rect2(22, 244, 206, 80).encloses(face.description_label.get_rect()), "effect text stays inside description frame")
		check(catalog[index].authority == "time" and face.gem.texture.resource_path == Palette.gem_path("time"), "catalog authority selects time gem")
		check(face.art_clip.clip_contents and face.art_clip.get_rect() == Rect2(24, 62, 202, 168), "art clip matches frame window")
		check(face.illustration.get_rect() == Rect2(0, 0, 202, 168) and face.illustration.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED and face.illustration.material.shader == Card.ART_MASK, "covered art has rounded mask inside clipping parent")
		check(face.placeholder_clock.visible, "empty art uses clock placeholder")
		check(face.custom_minimum_size.is_equal_approx(Vector2(150, 210)), "default card size is 150x210")
		for factor in [0.9, 2.0, 0.6]:
			face.card_scale = factor
			check(face.custom_minimum_size.is_equal_approx(Vector2(250, 350) * factor) and face.design.scale.is_equal_approx(Vector2.ONE * factor), "scale updates layout and all design elements")
		var texture_before := face.gem.texture
		face.set_selected(true)
		check(face.selected and face.gem.texture == texture_before and face.modulate == Color.WHITE, "selection preserves face colors")
		face.card_clicked.connect(func(id): clicked_id = id)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		face._gui_input(click)
		check(clicked_id == catalog[index].id, "click signal retains catalog id")
		face.configure({"authority": "space", "art": "res://assets/cards/frame_c/gem_space.svg"})
		check(not face.placeholder_clock.visible and face.illustration.texture.resource_path.ends_with("gem_space.svg"), "provided art replaces placeholder")
		face.queue_free()
	# Exercise the actual caller layouts without touching the user's save.
	var path := "user://card_frame_%d.json" % Time.get_ticks_usec()
	var store := Store.new()
	check(store.initialize_time_authority(path), "isolated store initializes")
	var session := Session.new()
	root.add_child(session)
	session.configure(store, true)
	session._accept_opening()
	session._tutorial_event("walked", {})
	session._tutorial_event("jump_landed", {})
	check(session._repair_device(), "fixture unlocks three cards")
	session.toggle_deck()
	session.set_physics_process(false)
	await process_frame
	await process_frame
	var previous := Rect2()
	for face in session.card_buttons.values():
		var rect: Rect2 = face.get_global_rect()
		check(session.deck_scroll.get_global_rect().encloses(rect.grow(3)), "deck includes selected outline")
		check(rect.end.y < session.hp_bar.get_global_rect().position.y and not rect.intersects(session.authority_button.get_global_rect()), "deck clears health and clock HUD")
		check(not rect.intersects(previous), "deck cards do not overlap")
		previous = rect
	var main := Main.new()
	main.save_path = path
	root.add_child(main)
	main.show_time_authority_collection()
	previous = Rect2()
	var count := 0
	for face in main.page.get_children():
		if face.get_script() != Card: continue
		count += 1
		var rect: Rect2 = face.get_global_rect()
		check(Rect2(0, 80, 1440, 820).encloses(rect.grow(3)) and not rect.intersects(main.return_button.get_global_rect()), "collection fits viewport and clears navigation")
		check(not rect.intersects(previous) and is_equal_approx(face.card_scale, 0.9), "collection cards use 0.9 without overlap")
		previous = rect
	check(count == 3, "collection displays three time cards")
	main.queue_free()
	session.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("CARD_FRAME_CHECKS=", checks, " FAILURES=", failures.size())
	print("PASS card_frame_acceptance" if failures.is_empty() else "FAIL card_frame_acceptance")
	quit(0 if failures.is_empty() else 1)
