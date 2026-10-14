extends SceneTree
const Scene = preload("res://scenes/main.tscn")
const CardFace = preload("res://scripts/ui/battle_card.gd")
const SAVE = "user://_card_visual_acceptance.json"
var failures = 0
var checks = 0
func _initialize(): call_deferred("run")
func check(value: bool, message: String):
	checks += 1
	if not value: failures += 1
	print(("PASS " if value else "FAIL ") + message)
func run():
	for suffix in ["", ".tmp", ".bak"]:
		var path = ProjectSettings.globalize_path(SAVE + suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	var app = Scene.instantiate()
	app.save_path = SAVE
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.battle_visual_assets = {}
	app.start_encounter("tutorial")
	await process_frame
	for button in app.loadout_buttons.values():
		check(button is CardFace and button.collection_face, "collection uses illustrated entity face")
		check(button.equipped, "equipped collection has visible check state")
	check(app.confirm_loadout(), "isolated equipped entities enter combat")
	app.toggle_deck()
	await process_frame
	check(app.deck_scroll.position == Vector2(299,572), "deck origin remains exact")
	check(app.deck_scroll.size == Vector2(1097,270), "deck viewport remains exact")
	var first = app.snapshot.cards[0]
	var face = app.card_buttons[first.id]
	check(face is CardFace, "battle uses shared illustrated entity face")
	check(face.size == Vector2(168,128), "battle cards keep fixed 168 by 128 geometry")
	check(face.title_label.text == first.name, "short title remains visible")
	check(face.card_data.cost == first.cost, "always visible fee badge has model cost")
	check(face.tooltip_text.contains(first.description), "hover detail provides rules")
	check(face.state_label.text == "可用", "ready status remains compact")
	check(face.tooltip_text.contains(first.reason), "full model availability explanation remains in tooltip")
	var preview_data: Dictionary = first.duplicate(true)
	preview_data["state"] = "energy"
	face.configure(preview_data)
	check(face.state_label.text == "费用不足", "insufficient energy uses compact status")
	preview_data["state"] = "condition"
	face.configure(preview_data)
	check(face.state_label.text == "条件不满足", "unmet effect requirement uses compact status")
	face.configure(first)
	var time_before = app.combat.time
	face.mouse_entered.emit()
	app.combat.tick(0.1)
	check(is_equal_approx(app.combat.time-time_before,0.1), "hover alone neither pauses nor slows combat")
	app.snapshot = app.combat.get_snapshot()
	app.update_battle()
	check(app.choose_card(first.id), "illustrated card keeps entity selection path")
	check(face.state_label.text == "已选中 · 确认施放", "selected card preserves confirmation status")
	app.confirm_selected(str(app.snapshot.enemies[0].id))
	check(face.card_data.remaining > 0 and face.state_label.text.contains("冷却"), "cast shows numeric cooldown and ring state")
	check(face.disabled, "cooling entity is visibly unavailable in stable slot")
	check(app.card_buttons[first.id] == face, "cooldown retains original card node")
	app.current_encounter = "stairs"
	app.show_rewards()
	var reward_count = 0
	for node in app.page.get_children():
		if node is CardFace: reward_count += 1
	check(reward_count == 3, "reward choice reuses illustrated faces without altering quantity")
	app.queue_free()
	await process_frame
	print("CARD_VISUAL_ACCEPTANCE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
