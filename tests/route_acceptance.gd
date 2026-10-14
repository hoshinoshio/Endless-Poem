extends SceneTree
## Integration acceptance uses only route buttons, owned loadouts and ordinary casts.
const Scene = preload("res://scenes/main.tscn")
const Policy = preload("res://tests/battle_policy.gd")
const SAVE = "user://_route_acceptance_v2.json"
const BRANCH_SAVE = "user://_route_branch_acceptance_v2.json"
var app
var checks := 0
var casts := 0
var failures: Array[String] = []
var visited: Array[int] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	print(("PASS " if condition else "FAIL ") + message)
	if not condition: failures.append(message)

func clean(path: String) -> void:
	# These are this test's named isolated save and transaction files only.
	for suffix in ["", ".tmp", ".bak"]:
		var absolute := ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)

func create_app(path: String) -> void:
	app = Scene.instantiate()
	app.save_path = path
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app._process(0.0)

func release_app() -> void:
	app.queue_free()
	await process_frame

func buttons(node: Node) -> Array:
	var found: Array = []
	for child in node.get_children():
		if child is Button: found.append(child)
		found.append_array(buttons(child))
	return found

func press(text: String, occurrence: int = 0, parent: Node = null) -> bool:
	var search_root: Node = parent if parent != null else app.page
	for b in buttons(search_root):
		if text in b.text:
			if occurrence > 0:
				occurrence -= 1
				continue
			check(not b.disabled, "route button enabled: " + text)
			if b.disabled: return false
			b.pressed.emit()
			return true
	check(false, "route button found: " + text)
	return false

func node_at(index: int) -> void:
	check(app.route_index == index, "actual route node " + str(index + 1) + "/8")
	if not visited.has(index): visited.append(index)

func enter_battle(label: String, equip_all: bool = true) -> bool:
	check(app.screen == "equip", label + " opens real equipment screen")
	if app.screen != "equip": return false
	if equip_all: press("全部装备")
	press("确认装备 · 开战")
	check(app.screen == "battle" and app.snapshot.status == "active", label + " starts owned equipped battle")
	check(app.snapshot.cards.map(func(card): return card.id) == app.equipped_ids, label + " exact persisted equipment used")
	return app.screen == "battle"

func fight(label: String) -> bool:
	var steps := 0
	var phases: Array = []
	while app.screen == "battle" and app.snapshot.status == "active" and steps < 20000:
		var snapshot: Dictionary = app.snapshot
		if not phases.has(snapshot.phase): phases.append(snapshot.phase)
		var choice: Dictionary = Policy.choose(snapshot)
		if not choice.is_empty():
			if not app.deck_open: app.toggle_deck()
			if not app.choose_card(choice.card_id):
				check(false, label + " normal card accepted " + str(choice.card_id))
				return false
			app.confirm_selected(choice.target_id)
			casts += 1
		app._process(0.05)
		steps += 1
		if steps % 200 == 0: await process_frame
	var won: bool = app.snapshot.get("status", "") == "won"
	check(won, label + " normal route victory")
	print("ROUTE_BATTLE %s status=%s hp=%s time=%.2f phases=%s cards=%s" % [label, app.snapshot.get("status"), app.snapshot.get("hp"), app.snapshot.get("time", 0.0), phases, app.snapshot.get("cards", []).size()])
	if label == "main_boss": check(phases == [1, 2, 3], "full-route boss really visits three phases")
	return won

func reward(index: int, label: String) -> void:
	var count: int = app.collection.size()
	var equipped: Array = app.equipped_ids.duplicate()
	var source: String = app.reward_source
	press("永久收藏 · 领取", index)
	check(app.collection.size() == count + 1 and app.claimed_rewards.has(source), label + " adds one entity plus saved receipt")
	check(app.equipped_ids == equipped, label + " reward does not automatically equip")

func investigate() -> void:
	node_at(2)
	var before_hp: int = app.run_hp
	var before_coins: int = app.coins
	check(app.investigation_seen == ["落日前"], "accident begins at before-sunset slice")
	press("钟鸣后 · 断桥与碎灯")
	check(app.investigation_seen.has("落日前") and app.investigation_seen.has("钟鸣后"), "both accident slices actually visited")
	press("落日前 · 完好的桥")
	check(app.run_hp == before_hp and app.coins == before_coins, "slice switching has no resource cost")
	press("取得断桥刻痕" if not app.evidence.has("断桥刻痕") else "已调查 · 跳过并继续")
	check(app.evidence.has("断桥刻痕"), "fixed accident grants bridge evidence")

func opening(label: String) -> bool:
	app.begin_expedition(false)
	node_at(0)
	press("进入教学战")
	if not enter_battle(label + "_tutorial"): return false
	if not await fight(label + "_tutorial"): return false
	check(app.coins == 10 and app.collection.size() >= 10, label + " tutorial gives ten crystals and no reward card")
	press("继续前往星台阶梯")
	node_at(1)
	press("穿过巡刻卫兵")
	if not enter_battle(label + "_stairs"): return false
	if not await fight(label + "_stairs"): return false
	check(app.coins == 30, label + " fixed stair reward adds twenty crystals")
	return true

func run() -> void:
	clean(SAVE)
	clean(BRANCH_SAVE)
	await create_app(SAVE)
	check(app.collection.size() == 10 and app.equipped_ids.size() == 10, "main route starts with real ten starter entities")
	if not await opening("main"):
		await finish()
		return
	reward(1, "stairs heavy shield")
	investigate()
	node_at(3)
	var coins_before_lamp: int = app.coins
	press("未点亮的灯 · 永久卡奖励")
	enter_battle("main_lamp")
	if not await fight("main_lamp"):
		await finish()
		return
	check(app.coins == coins_before_lamp, "unlit-lamp battle grants no crystals")
	reward(1, "unlit-lamp delay")
	node_at(4)
	check(app.evidence.has("值守名单") and app.record_choice == "", "observatory grants roster while records remain undecided")
	press("保留两份待核对记录")
	node_at(5)
	press("休整 · 回复或升级")
	var before_rest: int = app.run_hp
	var before_rest_coins: int = app.coins
	press("回复15生命")
	check(app.run_hp == mini(50, before_rest + 15) and app.coins == before_rest_coins, "real free rest restores fifteen health")
	node_at(6)
	press("进入回廊战")
	enter_battle("main_corridor")
	if not await fight("main_corridor"):
		await finish()
		return
	reward(0, "corridor fire")
	node_at(7)
	check(app.evidence.size() == 3 and app.evidence.has("断桥刻痕") and app.evidence.has("值守名单") and app.evidence.has("锚的钥匙"), "all three fixed evidences present before boss")
	check(visited == [0, 1, 2, 3, 4, 5, 6, 7], "all eight actual route nodes visited in order")
	press("接受克洛诺斯的考核")
	enter_battle("main_boss")
	if not await fight("main_boss"):
		await finish()
		return
	press("走向指针")
	check(app.screen == "ending" and not app.chapter_completed, "boss victory proceeds to nonfailing dial")
	press("拨针 · 让第一个夜晚到来")
	check(app.record_choice == "", "dial leads to actual undecided record choice")
	press("保留《暮笙手记》原件")
	check(app.chapter_completed and app.record_choice == "暮笙手记", "record choice completes chapter through normal action")
	press("返回魔法书据点")
	check(app.screen == "hub", "completed chapter returns to hub")
	var saved_collection: Array = app.collection.duplicate(true)
	var saved_equipped: Array = app.equipped_ids.duplicate()
	await release_app()
	await create_app(SAVE)
	check(app.chapter_completed and app.record_choice == "暮笙手记" and app.evidence.size() == 3, "completed chapter record and evidence survive real restart")
	check(app.collection == saved_collection and app.equipped_ids == saved_equipped, "complete real route collection and equipment survive restart")
	app.show_record_choice()
	check(app.record_choice == "暮笙手记" and not buttons(app.page).any(func(b): return "保留《观测环刻录》原件" in b.text), "revisit cannot replace recorded original")
	# Replay the actual early encounters to check one-time rewards in route UI.
	if await opening("revisit"):
		check(app.screen == "reward" and app.claimed_rewards.has("chapter1:battle:stairs"), "repeat stairs displays previously claimed source")
		check(not buttons(app.page).any(func(b): return "永久收藏 · 领取" in b.text), "repeat source has no grant button")
		press("继续远征")
		check(app.collection == saved_collection, "winning same source again grants no extra physical entity")
	await release_app()
	await test_branch()
	await finish()

func test_branch() -> void:
	await create_app(BRANCH_SAVE)
	if not await opening("branch"): return
	reward(2, "branch stairs charge")
	investigate()
	node_at(3)
	press("补给 · 结晶商店")
	check(app.screen == "supply" and app.coins == 30, "branch shop uses genuinely earned thirty crystals")
	var count: int = app.collection.size()
	var equipped: Array = app.equipped_ids.duplicate()
	press("灵性之火 · 购买30")
	check(app.coins == 0 and app.collection.size() == count + 1 and app.claimed_rewards.has("chapter1:shop:3:fire"), "shop purchase pays thirty and persists one real entity")
	check(app.equipped_ids == equipped, "shop reward also does not automatically equip")
	var bought_button: Button = null
	for b in buttons(app.page):
		if "灵性之火 · 已领取" in b.text: bought_button = b
	check(bought_button != null and bought_button.disabled, "purchased shop source disabled against repeated grants")
	press("离开工坊 · 继续")
	node_at(4)
	press("保留两份待核对记录")
	node_at(5)
	press("挑战精英")
	enter_battle("branch_elite")
	var elite_coins: int = app.coins
	if not await fight("branch_elite"): return
	check(app.coins == elite_coins, "elite battle gives no extra crystals")
	reward(1, "elite delay")
	check(is_instance_valid(app.overlay), "elite real card reward opens free entity upgrade")
	var upgrade_id := ""
	for card in app.collection:
		if card.type == "fire" and app.equipped_ids.has(card.id): upgrade_id = card.id; break
	press(upgrade_id, 0, app.overlay)
	check(app.upgrades.has(upgrade_id) and app.coins == 0, "elite upgrade applies to one existing entity for free")
	node_at(6)
	press("进入回廊战")
	enter_battle("branch_failure")
	var upgraded_seen := false
	for card in app.snapshot.cards:
		if card.id == upgrade_id: upgraded_seen = card.damage == 8
	check(upgraded_seen, "next real battle receives selected entity damage upgrade")
	var owned_before_loss: Array = app.collection.duplicate(true)
	var equipment_before_loss: Array = app.equipped_ids.duplicate()
	# Deliberately take normal incoming damage; never assign player HP or status.
	var iterations := 0
	while app.screen == "battle" and iterations < 1000:
		app._process(0.5)
		iterations += 1
		if iterations % 100 == 0: await process_frame
	check(app.snapshot.status == "lost" and app.run_hp == 0, "normal route incoming attacks cause actual failure")
	check(app.collection == owned_before_loss and app.equipped_ids == equipment_before_loss, "failure preserves all permanently earned cards and equipment")
	press("重新挑战本次路线")
	check(app.route_index == 0 and app.run_hp == 50 and app.coins == 0 and app.upgrades.is_empty(), "retry resets route health crystals and expedition upgrades normally")
	check(app.collection == owned_before_loss and app.equipped_ids == equipment_before_loss and app.evidence.has("断桥刻痕") and app.evidence.has("值守名单"), "retry retains earned collection saved equipment and evidence")
	await release_app()
	await create_app(BRANCH_SAVE)
	check(app.collection == owned_before_loss and app.equipped_ids == equipment_before_loss and app.claimed_rewards.has("chapter1:shop:3:fire") and app.claimed_rewards.has("chapter1:battle:elite"), "post-failure restart preserves shop and elite receipts with collection")
	await release_app()

func finish() -> void:
	print("ROUTE_ACCEPTANCE checks=%d failures=%d casts=%d visited=%s" % [checks, failures.size(), casts, visited])
	for message in failures: print("FAILED: " + message)
	if is_instance_valid(app): await release_app()
	quit(0 if failures.is_empty() else 1)
