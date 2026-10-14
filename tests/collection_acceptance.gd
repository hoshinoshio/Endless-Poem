extends SceneTree

const Store = preload("res://scripts/progression/collection_store.gd")
const Scene = preload("res://scenes/main.tscn")
const SAVE = "user://_collection_acceptance_v2.json"
var checks = 0
var failures: Array = []

func _initialize():
	call_deferred("run")

func check(condition: bool, label: String):
	checks += 1
	print(("PASS " if condition else "FAIL ") + label)
	if not condition: failures.append(label)

func clean(path: String):
	# Remove only this test's isolated, explicitly named transaction files.
	for suffix in ["", ".tmp", ".bak"]:
		var absolute = ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)

func run():
	clean(SAVE)
	var store = Store.new()
	check(store.initialize(SAVE), "initialize isolated collection")
	check(store.collection.size() == 10, "exactly ten starter entities")
	var counts = {"fire": 0, "shield": 0, "charge": 0}
	var ids = []
	for card in store.collection:
		counts[card.type] += 1
		ids.append(card.id)
	check(counts == {"fire": 4, "shield": 4, "charge": 2}, "starter types are fire4 shield4 charge2")
	check(store.equipped_ids == ids, "first initialization equips all ten")
	check(store.claimed_rewards.has("initial:starter_v1"), "starter receipt persisted")
	var reloaded = Store.new()
	check(reloaded.initialize(SAVE), "reload valid save")
	check(reloaded.collection == store.collection, "reload preserves ids without regranting")
	check(store.set_equipped([ids[0], ids[4]]), "save selected equipment")
	check(store.claim_reward("source:A", "fire"), "claim first source")
	check(store.collection.size() == 11 and store.claimed_rewards.has("source:A"), "card and receipt enter the same committed state")
	check(store.equipped_ids == [ids[0], ids[4]], "reward leaves chosen equipment unchanged")
	var before = store.data.duplicate(true)
	check(not store.claim_reward("source:A", "fire"), "same source cannot be claimed twice")
	check(store.data == before, "duplicate claim leaves data unchanged")
	check(store.claim_reward("source:B", "fire"), "another source grants same-name independent entity")
	check(store.collection[-1].id != store.collection[-2].id, "same-name copies have distinct stable ids")
	check(store.claim_reward("source:C", "shield"), "thirteenth card is owned")
	check(store.claim_reward("source:D", "delay"), "fourteenth card is owned")
	var all_ids = store.collection.map(func(card): return card.id)
	check(store.set_equipped(all_ids), "equipment allows more than twelve entities")
	check(not store.set_equipped([all_ids[0], all_ids[0]]), "duplicate physical entity cannot be equipped twice")
	check(not store.set_equipped(["not_owned"]), "unowned entity is rejected")
	check(store.set_equipped(all_ids.slice(0, 13)), "uninstalling a card is free and preserves collection")
	check(store.collection.size() == 14 and store.get_loadout().size() == 13, "unequipped entity remains permanently owned")
	check(store.save_metadata({"evidence": ["断桥刻痕"], "record_choice": "暮笙手记", "chapter_completed": true}), "persist existing progress metadata")
	check(store.save_metadata({"record_choice": "观测环刻录"}), "metadata save respects existing record")
	check(store.data.record_choice == "暮笙手记", "record choice cannot be rewritten")
	check(reloaded.initialize(SAVE), "reload equipment and receipts")
	check(reloaded.collection.size() == 14 and reloaded.equipped_ids.size() == 13 and reloaded.claimed_rewards.has("source:D"), "new entities equipment and receipts survive restart")
	check(reloaded.data.evidence == ["断桥刻痕"] and reloaded.data.chapter_completed, "legacy progress survives collection updates")
	# Write failure must leave both reward and receipt absent, including after retry.
	var invalid = Store.new()
	invalid.data = store.data.duplicate(true)
	invalid.save_path = "user://_collection_missing_dir/test.json"
	before = invalid.data.duplicate(true)
	check(not invalid.claim_reward("source:failed", "fire"), "failed transaction reports failure")
	check(invalid.data == before and not invalid.claimed_rewards.has("source:failed"), "failed write changes neither card nor receipt")
	# Simulate an interrupted replacement by moving the save into its recovery backup.
	var absolute = ProjectSettings.globalize_path(SAVE)
	check(DirAccess.rename_absolute(absolute, absolute + ".bak") == OK, "create interrupted transaction recovery fixture")
	check(reloaded.initialize(SAVE), "recover last complete save from backup")
	check(reloaded.collection.size() == 14 and reloaded.claimed_rewards.has("source:D"), "recovery preserves committed cards and receipts")
	# Old progress files keep their narrative metadata and receive one starter set.
	var legacy_path = "user://_collection_legacy_acceptance_v2.json"
	clean(legacy_path)
	var f = FileAccess.open(legacy_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"evidence": ["值守名单"], "record_choice": "观测环刻录", "chapter_completed": true, "visits": 3}))
	f.close()
	var legacy = Store.new()
	check(legacy.initialize(legacy_path), "migrate old progress file")
	check(legacy.collection.size() == 10 and legacy.equipped_ids.size() == 10, "legacy migration grants one equipped starter set")
	check(legacy.data.evidence == ["值守名单"] and legacy.data.record_choice == "观测环刻录" and legacy.data.chapter_completed and legacy.data.visits == 3, "legacy metadata is retained")
	check(legacy.initialize(legacy_path) and legacy.collection.size() == 10, "migration is idempotent")
	# Integration uses the same collection, not a replacement quick-trial deck.
	var app = Scene.instantiate()
	app.save_path = SAVE
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.begin_expedition(true)
	app.start_encounter("boss")
	check(app.screen == "equip", "every encounter opens equipment screen")
	check(app.confirm_loadout(), "confirm owned equipment starts battle")
	check(app.snapshot.cards.size() == 13, "battle excludes the unequipped fourteenth entity")
	check(app.snapshot.cards.map(func(card): return card.id) == store.equipped_ids and not app.evidence.has("锚的钥匙"), "quick trial preserves equipment and grants no story evidence")
	check(not app.deck_scroll.visible and app.card_buttons.size() == 13, "battle starts collapsed and builds all fixed card cells")
	await process_frame
	check(app.hp_bar.size.y <= 8 and app.hp_bar.get_rect().end.y <= 900 and not app.hp_bar.show_percentage, "hero health bar stays thin and numberless within viewport")
	var boss_id = app.snapshot.enemies[0].id
	var boss_hp: ProgressBar = app.target_hp_bars[boss_id]
	check(boss_hp.size.y <= 8 and is_equal_approx(boss_hp.get_rect().get_center().x, 720.0) and is_equal_approx(boss_hp.position.y, 90.0), "real boss HP bar is centered with ninety-pixel top space")
	print("BAR_RECTS hero_hp=%s hero_energy=%s hero_focus=%s boss_hp=%s boss_action=%s" % [app.hp_bar.get_rect(), app.energy_bar.get_rect(), app.focus_bar.get_rect(), boss_hp.get_rect(), app.target_bars[boss_id].get_rect()])
	app.toggle_deck()
	check(app.deck_scroll.visible and is_equal_approx(float(app.snapshot.time_scale), 1.0), "opening equipment grid applies no slowdown")
	check(app.choose_card(all_ids[0]), "choose a ready owned physical card")
	var energy_before = app.snapshot.energy
	app.toggle_deck()
	check(app.snapshot.selected_card_id == "" and app.snapshot.energy == energy_before, "collapse cancels without payment")
	app.show_hub()
	app.begin_expedition(false)
	check(app.collection.size() == 14 and app.equipped_ids.size() == 13, "new expedition retains permanent collection and configuration")
	app.queue_free()
	await process_frame
	print("COLLECTION_ACCEPTANCE checks=%d failures=%d" % [checks, failures.size()])
	clean(SAVE)
	clean(legacy_path)
	quit(0 if failures.is_empty() else 1)
