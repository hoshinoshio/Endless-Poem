extends Control

const Combat = preload("res://scripts/combat/combat_model.gd")
const Observatory = preload("res://scripts/ui/observatory.gd")
const PORTRAIT = preload("res://assets/moonli_battle_v1.png")
const FONT = preload("res://assets/msyh.ttc")
const PAPER = Color("f0e4cf")
const MUTED = Color("a7bdc7")
const GOLD = Color("c9a16b")
const INK = Color("122132")
const BATTLE_INK = Color("111d31")
const BATTLE_COPPER = Color("b88b55")
const BATTLE_TEAL = Color("80d6dc")
const ROUTE = ["观测环外缘", "星台阶梯", "事故点", "灯廊岔路", "观测环", "钟楼下层", "钟楼回廊", "时间锚"]
const TYPES = ["fire", "shield", "charge", "ember", "ignite", "ember_shield", "heavy_shield", "echo", "delay"]
const TIME_TYPES = ["echo", "delay"]
const CollectionStore = preload("res://scripts/progression/collection_store.gd")
const BattleCard = preload("res://scripts/ui/battle_card.gd")
const ClockIcon = preload("res://scripts/ui/clock_icon.gd")
const BattleWorldPresenter = preload("res://scripts/ui/battle_world_presenter.gd")
const DebuffIcons = preload("res://scripts/ui/debuff_icons.gd")
const StartMenu = preload("res://scripts/ui/start_menu.gd")
const ExplorationSession = preload("res://scripts/exploration/exploration_session.gd")
var exploration_session
var start_menu
var _run_active = false
var _suspended_page
var _suspended_world
var _suspended_screen = ""
var _collection_from_menu = false
var battle_visual_assets: Dictionary = load("res://scripts/visuals/chapter1_assets.gd").build()
var battle_world
var battle_visual_missing_assets: Array = []
var save_path = "user://chapter_one.json"
var combat = Combat.new()
var scenery
var page
var overlay
var screen = "intro"
var route_index = 0
var run_hp = 50
var store = CollectionStore.new()
var collection: Array:
	get: return store.collection
var equipped_ids: Array:
	get: return store.equipped_ids
var claimed_rewards: Array:
	get: return store.claimed_rewards
var card_buttons = {}
var authority_button
var deck_scroll
var deck_open = false
var loadout_buttons = {}
var loadout_message
var loadout_confirm
var collection_only = false
var upgrades = {}
var coins = 0
var evidence = []
var record_choice = ""
var chapter_completed = false
var visits = 0
var reduced_feedback = false
var relaxed_focus = false
var quick_mode = false
var current_encounter = ""
var snapshot = {}
var battle_finished = false
var card_labels = []
var target_buttons = {}
var target_labels = {}
var target_bars = {}
var target_hp_bars = {}
var target_debuffs = {}
var resources_label
var focus_label
var time_label
var message_label
var pending_label
var recovery_label
var confirm_button
var pause_button
var hp_bar
var energy_bar
var focus_bar
var log_lines = []
var log_label
var status_refresh = 0.0
var active_enemy_ids = []
var investigation_seen = []
var overlay_pauses = false
var upgrade_callback: Callable
var upgrade_selection_page = 0
var reward_source = ""

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme_data = Theme.new()
	theme_data.default_font = FONT
	theme_data.default_font_size = 17
	theme = theme_data
	scenery = Observatory.new()
	scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scenery)
	page = Control.new()
	page.z_index = 100
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	load_progress()
	show_start_menu()

func _discard_suspended_run():
	if is_instance_valid(_suspended_page): _suspended_page.queue_free()
	if is_instance_valid(_suspended_world): _suspended_world.queue_free()
	_suspended_page = null
	_suspended_world = null
	_suspended_screen = ""

func show_start_menu():
	if is_instance_valid(exploration_session):
		exploration_session.suspend_session()
		_run_active = false
		load_progress()
	page.visible = true
	close_overlay()
	combat.set_paused(true)
	if screen != "start_menu" and _run_active and not is_instance_valid(_suspended_page):
		_suspended_screen = screen
		_suspended_page = Control.new()
		_suspended_page.visible = false
		_suspended_page.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(_suspended_page)
		for child in page.get_children(): child.reparent(_suspended_page)
		if is_instance_valid(battle_world):
			_suspended_world = battle_world
			battle_world.reparent(_suspended_page)
			battle_world = null
	else:
		for child in page.get_children():
			page.remove_child(child)
			child.queue_free()
		if is_instance_valid(battle_world):
			battle_world.queue_free()
			battle_world = null
	scenery.visible = false
	screen = "start_menu"
	start_menu = StartMenu.new()
	page.add_child(start_menu)
	start_menu.set_continue_available(is_instance_valid(_suspended_page) or bool(store.data.get("exploration_run",{}).get("active",false)))
	start_menu.action_requested.connect(_start_menu_action)

func _start_menu_action(action: String):
	match action:
		"new": begin_expedition(false)
		"continue": continue_session_exploration()
		"authority":
			_collection_from_menu = true
			show_collection()
		"journal": show_journal()
		"quit": get_tree().quit()

func continue_session_exploration():
	if is_instance_valid(exploration_session) and not is_instance_valid(_suspended_page):
		page.visible = false
		scenery.visible = false
		screen = "exploration"
		exploration_session.resume_session()
		return
	if store.data.get("exploration_run",{}).get("active",false) and not is_instance_valid(_suspended_page):
		start_exploration_session(false)
		return
	if not is_instance_valid(_suspended_page): return
	close_overlay()
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	for child in _suspended_page.get_children():
		if child == _suspended_world: continue
		child.reparent(page)
	if is_instance_valid(_suspended_world):
		_suspended_world.reparent(self)
		battle_world = _suspended_world
		_suspended_world = null
	screen = _suspended_screen
	scenery.mode = screen
	scenery.visible = true
	_suspended_page.queue_free()
	_suspended_page = null
	_suspended_screen = ""
	if screen == "battle" and not battle_finished: combat.set_paused(false)

func start_exploration_session(new_exploration: bool):
	close_overlay()
	_discard_suspended_run()
	if is_instance_valid(exploration_session):
		exploration_session.suspend_session()
		remove_child(exploration_session)
		exploration_session.queue_free()
	if is_instance_valid(battle_world):
		battle_world.queue_free()
		battle_world = null
	combat.set_paused(true)
	_run_active = false
	page.visible = false
	scenery.visible = false
	screen = "exploration"
	exploration_session = ExplorationSession.new()
	add_child(exploration_session)
	exploration_session.return_to_menu.connect(show_start_menu)
	exploration_session.configure(store,new_exploration)

func style(bg: Color, border: Color, radius = 8):
	var box = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

func panel(rect: Rect2, parent = page, bg = Color("122033")):
	var p = Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", style(bg, BATTLE_COPPER, 4))
	parent.add_child(p)
	return p

func label_text(text_value: String, rect: Rect2, font_size = 20, color = PAPER, parent = page):
	var l = Label.new()
	l.text = text_value
	l.position = rect.position
	l.size = rect.size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if screen == "battle":
		l.add_theme_constant_override("outline_size", 3)
		l.add_theme_color_override("font_outline_color", Color("0b1423"))
	parent.add_child(l)
	return l

func button(text_value: String, rect: Rect2, callback: Callable, parent = page, primary = false):
	var b = Button.new()
	b.text = text_value
	b.focus_mode = Control.FOCUS_NONE
	b.position = rect.position
	b.size = rect.size
	b.add_theme_color_override("font_color", INK if primary else PAPER)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_stylebox_override("normal", style(GOLD if primary else Color("172b3b"), GOLD if primary else Color("7f694b")))
	b.add_theme_stylebox_override("hover", style(Color("ecd09c") if primary else Color("274557"), GOLD))
	b.add_theme_stylebox_override("pressed", style(Color("af8555") if primary else Color("102231"), PAPER))
	b.add_theme_stylebox_override("disabled", style(Color("122033"), Color("274557")))
	if screen == "battle":
		b.add_theme_color_override("font_color", Color("f0e2c9"))
		b.add_theme_stylebox_override("normal", style(BATTLE_INK, BATTLE_COPPER, 4))
		b.add_theme_stylebox_override("hover", style(Color("203e50"), BATTLE_TEAL, 4))
		b.add_theme_stylebox_override("pressed", style(Color("285365"), Color("edbe78"), 4))
		b.add_theme_stylebox_override("disabled", style(Color("101b2b"), Color("655742"), 4))
		b.add_theme_color_override("font_disabled_color", Color("b7b7ae"))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func illustrated_card(data: Dictionary, rect: Rect2, callback: Callable, parent = page, collection_face = false):
	var face = BattleCard.new()
	face.position = rect.position
	face.size = rect.size
	face.custom_minimum_size = rect.size
	face.pressed.connect(callback)
	parent.add_child(face)
	face.configure(data, collection_face)
	return face

func clear_page(new_screen: String):
	if is_instance_valid(exploration_session): exploration_session.suspend_session()
	page.visible = true
	close_overlay()
	if is_instance_valid(battle_world):
		remove_child(battle_world)
		battle_world.queue_free()
		battle_world = null
	scenery.visible = true
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	screen = new_screen
	scenery.mode = new_screen
	scenery.phase = 0
	if new_screen != "battle":
		var path = "res://assets/chapter1/observatory_courtyard.png"
		if ResourceLoader.exists(path):
			var backdrop = TextureRect.new()
			backdrop.texture = load(path)
			backdrop.position = Vector2.ZERO
			backdrop.size = Vector2(1440, 900)
			backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			backdrop.modulate = Color(0.35, 0.42, 0.50, 0.65)
			backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
			page.add_child(backdrop)
		var header = panel(Rect2(0, 0, 1440, 80))
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if new_screen == "battle": return
	label_text("未尽之诗", Rect2(34, 20, 230, 40), 26, PAPER)
	var menu_return = button("", Rect2(24, 12, 215, 55), show_start_menu)
	menu_return.tooltip_text = "返回主菜单"
	menu_return.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	menu_return.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	menu_return.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	label_text("第一章  /  失刻星台", Rect2(250, 27, 530, 30), 18, GOLD)
	button("日志", Rect2(1054, 23, 92, 36), show_journal)
	button("设置", Rect2(1158, 23, 92, 36), show_settings)
	button("操作", Rect2(1262, 23, 144, 36), show_help)

func portrait(rect: Rect2):
	var image_node = TextureRect.new()
	image_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_node.texture = PORTRAIT
	image_node.position = rect.position
	image_node.size = rect.size
	image_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(image_node)

func show_intro():
	clear_page("intro")
	label_text("凝固的黄昏\n失刻星台", Rect2(80, 153, 780, 175), 55)
	label_text("时间对所有人都是公平的，神也无一幸存。\n所以，试着掌握时间吧。", Rect2(84, 345, 710, 110), 27, GOLD)
	label_text("现实的末日将近。与尤格索托斯的赌约已经成立。\n\n克洛诺斯作为祂的化身，引导月璃走进文明的预演。这里的人格映像有值得认真对待的经历。月璃已持有克洛诺斯授予的时间权柄；接下来的试炼，是学习如何使用它。", Rect2(84, 485, 760, 170), 21)
	button("翻开魔法书", Rect2(84, 720, 262, 58), show_hub, page, true)
	button("快速试炼 · 完整Boss战", Rect2(366, 720, 320, 58), func(): begin_expedition(true))
	label_text("初版可玩原型  ·  永久收藏 / 选牌减速 / 独立冷却\n战斗数值为首轮待测提案", Rect2(84, 811, 810, 55), 16, MUTED)

func show_hub():
	_run_active = false
	combat.set_paused(true)
	clear_page("hub")
	portrait(Rect2(70, 130, 330, 600))
	label_text("魔法书据点", Rect2(455, 125, 840, 70), 40)
	label_text("洛笺把空白书页推向你：\n“带回真实发生过的记录。明天不会从抹除昨天开始。”", Rect2(458, 205, 850, 95), 23, GOLD)
	label_text("本关公开目标\n调查断桥与撤离钟 → 接受克洛诺斯·试炼相的考核 → 亲手拨针。\n\n公开通关奖励\n时间权柄进阶、魔法、空间、生命、以太、真我五个中层权柄区域开放，可自选顺序。\n第一章已经持有时间权柄，通关不会重复授予。", Rect2(458, 340, 870, 195), 21)
	if chapter_completed:
		label_text("已完成首章  ·  保存的原件：" + record_choice, Rect2(458, 558, 855, 35), 22, GOLD)
		label_text("魔法 / 空间 / 生命 / 以太 / 真我  已开放\n中层权柄区域可自由选择顺序 · 后续区域尚未制作", Rect2(458, 609, 870, 70), 21)
	button("进入失刻星台", Rect2(458, 747, 250, 56), func(): begin_expedition(false), page, true)
	button("快速试炼", Rect2(726, 747, 218, 56), func(): begin_expedition(true))
	button("永久收藏 / 装备", Rect2(458, 677, 350, 48), show_collection)
	button("五个中层权柄区域入口" if chapter_completed else "收藏与装备", Rect2(962, 747, 330, 56), show_regions if chapter_completed else show_collection)
	label_text("已收集证据 %d / 3  ·  再访 %d 次  ·  原件选择保存后不可改写" % [evidence.size(), visits], Rect2(458, 827, 840, 30), 16, MUTED)

func begin_expedition(quick = false):
	if not quick:
		start_exploration_session(true)
		return
	if is_instance_valid(exploration_session):
		exploration_session.suspend_session()
		remove_child(exploration_session)
		exploration_session.queue_free()
		exploration_session = null
	_discard_suspended_run()
	_run_active = true
	_collection_from_menu = false
	quick_mode = quick
	run_hp = 50
	upgrades = {}
	coins = 0
	visits += 1
	save_progress()
	route_index = 7 if quick else 0
	if quick:
		show_event("快速试炼", "本次试炼只使用你永久收藏中已装备的实体卡。\n每张卡独立冷却，未装备的收藏不参与战斗。\n\n克洛诺斯·试炼相保留三阶段、时间锚与回收规则。", [{"text": "战前装配", "action": func(): start_encounter("boss")}])
	else:
		enter_route()

func route_header():
	label_text("远征  %02d / 08  ·  %s" % [route_index + 1, ROUTE[route_index]], Rect2(40, 96, 970, 40), 21, GOLD)
	label_text("生命 %d / 50  ·  书页 %d张  ·  结晶 %d" % [run_hp, equipped_ids.size(), coins], Rect2(940, 96, 465, 38), 18, MUTED)

func show_event(title_value: String, body: String, choices: Array, event_mode = "event"):
	clear_page(event_mode)
	route_header()
	label_text(title_value, Rect2(92, 189, 1200, 85), 43)
	label_text(body, Rect2(96, 310, 1100, 330), 24)
	var index = 0
	for item in choices:
		button(item.text, Rect2(96 + index * 400, 744, 378, 65), item.action, page, index == 0)
		index += 1
	label_text("八节点远征  ·  本次生命与装备跨战保留  ·  调查无资源消耗", Rect2(96, 838, 1160, 30), 17, MUTED)

func enter_route():
	match route_index:
		0:
			show_event("观测环外缘", "黄昏在灾难前不断重播，失刻残像从刻度阴影中走来。月璃展开魔法书，完成入战变身。\n\n克洛诺斯：“敌人的时间仍在前进。选择书页时，用有限的专注延缓它；护幕接住攻击，灵性之火给出你的回答。”\n\n选牌后战场降至0.2倍。专注按真实秒消耗，冷却与行动随战斗时钟推进。", [{"text": "进入教学战", "action": func(): start_encounter("tutorial")}])
		1:
			show_event("星台阶梯", "阶梯上的巡刻卫兵反复沿同一条路线巡行。\n\n“减速不是让世界停下。”克洛诺斯提醒你，“施放过的书页留在原装备位置，独立冷却。留意生命、护盾与敌人的行动意图。”", [{"text": "穿过巡刻卫兵", "action": func(): start_encounter("stairs")}])
		2:
			investigation_seen = []
			show_investigation(false)
		3:
			var lamp_note = "最后一盏灯已经亮起，在之后的循环中仍然亮着。" if store.data.get("lamp_lit", false) else "那盏未点亮的灯里，有一段迟迟没有抵达的残响。"
			show_event("灯廊岔路", "提灯照亮三条路径。补给可以减轻下一战的压力；正面的巡逻会留下书页。" + lamp_note + "\n\n每条路都会通往观测环，调查证据不会被绕过。", [{"text": "补给 · 结晶商店", "action": show_supply}, {"text": "普通战 · 奖励20结晶", "action": func(): start_encounter("patrol")}, {"text": "未点亮的灯 · 永久卡奖励", "action": func(): start_encounter("lamp")}])
		4:
			add_evidence("值守名单")
			show_event("暮笙的证词", "观测员暮笙记得每一次循环，她启动时间锚，是想留住没有失去任何人的黄昏。\n\n《观测环刻录》：桥先断，钟后响。\n《暮笙手记》：钟先响，众人想看完星升。\n\n已取得“值守名单”。两份记录均标记为待核对；月璃此时不替你决定哪份记录应被带走。", [{"text": "已记录 · 跳过并继续" if visits > 1 else "保留两份待核对记录", "action": next_route}, {"text": "查看调查日志", "action": show_journal}])
		5:
			show_event("钟楼下层", "钟楼里的工作台仍然亮着。商店可领取一次性购卡奖励；收藏永久保留，卸装免费。\n\n休整可免费回复15生命或升级一张；再支付20结晶可两项都做。\n精英战奖励两种时间卡中任选一张，并免费升级一张，不发额外结晶。", [{"text": "补给 · 书页工坊", "action": show_supply}, {"text": "休整 · 回复或升级", "action": show_rest}, {"text": "挑战精英", "action": func(): start_encounter("elite")}])
		6:
			show_event("钟楼回廊", "钟声从回廊深处传来。每一秒都属于所有人，月璃与卫兵都无法独占它。\n\n穿过最后的巡逻，带着本次远征的生命与全部书页面对考核。", [{"text": "进入回廊战", "action": func(): start_encounter("corridor")}])
		7:
			add_evidence("锚的钥匙")
			show_event("时间锚 · 考官现身", "克洛诺斯：“从这一刻起，我将作为考官。刻度、锚定、残响——让我看见你如何继续前进、保留状态、保存记忆。”\n\n已自动取得“锚的钥匙”。本次战斗面对克洛诺斯·试炼相，胜利是通过考核。\n\n时间锚可被任何单体攻击击破。全灭本轮锚，可以截断回收并清空当前蓄力；基础减速始终可用。", [{"text": "接受克洛诺斯的考核", "action": func(): start_encounter("boss")}])

func next_route():
	route_index += 1
	if route_index < ROUTE.size():
		enter_route()
	else:
		show_dial()

func show_investigation(after_bell: bool):
	var slice_name = "钟鸣后" if after_bell else "落日前"
	if not investigation_seen.has(slice_name):
		investigation_seen.append(slice_name)
	clear_page("investigate")
	scenery.broken = after_bell
	route_header()
	label_text("事故点  /  " + slice_name, Rect2(90, 175, 1180, 65), 39)
	label_text("石桥已经断裂，撤离提灯摔碎。救援的失败是既成经历，切换切片只是观察。" if after_bell else "石桥仍然完好，撤离提灯在桥上等待。这一片黄昏还没有抵达钟鸣。", Rect2(95, 281, 1100, 95), 24)
	button("落日前 · 完好的桥", Rect2(95, 674, 380, 55), func(): show_investigation(false), page, not after_bell)
	button("钟鸣后 · 断桥与碎灯", Rect2(495, 674, 380, 55), func(): show_investigation(true), page, after_bell)
	var done = button("取得断桥刻痕 · 继续", Rect2(895, 674, 420, 55), func(): add_evidence("断桥刻痕"); next_route(), page, true)
	done.disabled = investigation_seen.size() < 2 and not evidence.has("断桥刻痕")
	if evidence.has("断桥刻痕"):
		done.text = "已调查 · 跳过并继续"
	label_text("自由切换切片，无资源消耗；观察两段后可取得证据。", Rect2(95, 758, 1220, 40), 19, MUTED)
	if visits > 1:
		button("再访切片 · 锚定时", Rect2(95, 818, 380, 47), func(): show_event("锚定时", "观察日志：暮笙的手停在撤离钟的刻度前，时间锚已经启动。\n\n这一切片说明锚在循环中的存在，不能单独裁定两份记录的先后关系。", [{"text": "返回事故点", "action": func(): show_investigation(after_bell)}], "investigate"))

func start_encounter(encounter: String):
	if encounter == "boss" and not quick_mode: add_evidence("锚的钥匙")
	current_encounter = encounter
	combat.set_paused(true)
	show_loadout(false)

func show_collection():
	if store.data.get("active_ruleset", "") == "time_authority_v2":
		show_time_authority_collection()
		return
	show_loadout(true)

func show_time_authority_collection():
	clear_page("collection")
	label_text("时间权柄", Rect2(110, 140, 1220, 80), 42)
	var gifts: Array = store.get_authority_loadout()
	if gifts.is_empty():
		label_text("权柄尚未显现。", Rect2(112, 292, 900, 60), 24, PAPER)
	else:
		var catalog = preload("res://scripts/authority/temporal_controller.gd").card_catalog()
		for i in gifts.size():
			var face = preload("res://scripts/authority/time_card.gd").new()
			face.position = Vector2(258+i*315, 310)
			face.size = Vector2(282, 260)
			page.add_child(face)
			for entry in catalog:
				if entry.id == gifts[i].type: face.configure(entry)
	loadout_confirm = button("返回主菜单", Rect2(550, 743, 340, 62), show_start_menu, page, true)

func show_loadout(only_collection = false):
	collection_only = only_collection
	clear_page("collection" if only_collection else "equip")
	loadout_buttons.clear()
	label_text("永久收藏" if only_collection else "战前装配 · " + ROUTE[route_index], Rect2(76, 118, 1260, 60), 36)
	loadout_message = label_text("", Rect2(80, 195, 1250, 70), 20, GOLD)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(78, 281)
	scroll.size = Vector2(1280, 413)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var catalog = combat.get_card_catalog()
	for card in collection:
		var id = str(card.id)
		var b = illustrated_card(catalog[card.type].merged({"type": card.type, "id": id}), Rect2(0, 0, 196, 126), func(): toggle_equipped(id), grid, true)
		b.custom_minimum_size = Vector2(196, 126)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.set_meta("card_type", card.type)
		loadout_buttons[id] = b
	var collection_return = show_start_menu if _collection_from_menu else show_hub
	loadout_confirm = button(("返回主菜单" if _collection_from_menu else "返回据点") if only_collection else "确认装备 · 开战", Rect2(966, 752, 390, 58), collection_return if only_collection else confirm_loadout, page, true)
	button("全部装备", Rect2(78, 752, 240, 58), func(): set_all_equipped(true))
	button("全部卸装 · 免费", Rect2(338, 752, 290, 58), func(): set_all_equipped(false))
	if not only_collection: button("返回据点", Rect2(649, 752, 286, 58), show_hub)
	label_text("同名卡是独立实体 · 装备不限数量 · 新奖励不自动装备 · 收藏永久保留", Rect2(78, 840, 1250, 32), 18, MUTED)
	update_loadout()

func set_all_equipped(enabled: bool):
	var ids = []
	if enabled:
		for card in collection: ids.append(card.id)
	store.set_equipped(ids)
	update_loadout()

func toggle_equipped(card_id: String):
	var ids = equipped_ids
	if ids.has(card_id): ids.erase(card_id)
	else: ids.append(card_id)
	store.set_equipped(ids)
	update_loadout()

func update_loadout():
	var catalog = combat.get_card_catalog()
	loadout_message.text = "收藏 %d 张 / 已装备 %d 张。点击实体卡装备或免费卸装；配置即时保存。" % [collection.size(), equipped_ids.size()]
	if not store.last_error.is_empty(): loadout_message.text += "\n" + store.last_error
	for id in loadout_buttons:
		var b = loadout_buttons[id]
		var card = catalog[b.get_meta("card_type")]
		b.configure(card.merged({"type": b.get_meta("card_type"), "id": id}), true, equipped_ids.has(id))
	loadout_confirm.disabled = not collection_only and equipped_ids.is_empty()

func confirm_loadout():
	if screen != "equip": return false
	if not combat.start_battle(current_encounter, {"hp": run_hp, "loadout": store.get_loadout(), "upgrades": upgrades.duplicate(), "relaxed_focus": relaxed_focus}):
		loadout_message.text = "至少装备一张真实收藏卡；无法启动战斗。"
		return false
	battle_finished = false
	log_lines = []
	snapshot = combat.get_snapshot()
	show_battle()
	return true

func bar(rect: Rect2, color: Color, parent = page):
	var b = ProgressBar.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.position = rect.position
	b.show_percentage = false
	b.add_theme_font_size_override("font_size", 1)
	var background = style(BATTLE_INK if screen == "battle" else Color("202020"), BATTLE_COPPER if screen == "battle" else Color("555555"), 0)
	var fill = style(color, color, 0)
	for box in [background, fill]:
		box.content_margin_top = 0
		box.content_margin_bottom = 0
		box.content_margin_left = 0
		box.content_margin_right = 0
	b.add_theme_stylebox_override("background", background)
	b.add_theme_stylebox_override("fill", fill)
	parent.add_child(b)
	b.size = rect.size
	return b

func show_battle():
	clear_page("battle")
	_activate_battle_world()
	card_buttons.clear()
	card_labels.clear()
	target_buttons.clear()
	target_labels.clear()
	target_bars.clear()
	target_hp_bars.clear()
	target_debuffs.clear()
	active_enemy_ids = []
	deck_open = false
	if not is_instance_valid(battle_world):
		portrait(Rect2(40, 190, 300, 358))
	time_label = label_text("", Rect2(40, 94, 355, 60), 18, MUTED)
	focus_label = label_text("", Rect2(299, 875, 510, 25), 15)
	focus_bar = bar(Rect2(1230, 859, 160, 6), BATTLE_TEAL)
	pending_label = label_text("", Rect2(816, 875, 580, 25), 14, MUTED)
	pending_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	pending_label.clip_text = true
	pending_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pending_label.mouse_filter = Control.MOUSE_FILTER_PASS
	recovery_label = label_text("", Rect2(740, 201, 650, 70), 18)
	message_label = label_text("", Rect2(40, 174, 305, 104), 17)
	log_label = label_text("", Rect2(370, 498, 276, 66), 14, MUTED)
	# Detailed history remains in the existing Log panel, leaving the spell path clear.
	log_label.visible = false
	_battle_label_surface(message_label)
	_battle_label_surface(log_label)
	_battle_label_surface(time_label)
	log_label.max_lines_visible = 3
	log_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	log_label.clip_text = true
	confirm_button = button("确认自身卡 [空格]", Rect2(370, 452, 265, 42), confirm_selected)
	confirm_button.visible = false
	pause_button = button("暂停 [Esc]", Rect2(40, 581, 190, 42), show_pause)
	# A fixed six-column grid; the scroll viewport shows exactly two rows.
	deck_scroll = ScrollContainer.new()
	deck_scroll.position = Vector2(299, 572)
	deck_scroll.size = Vector2(1097, 270)
	deck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(deck_scroll)
	var grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	deck_scroll.add_child(grid)
	for card in snapshot.cards:
		var card_id = str(card.id)
		var b = illustrated_card(card, Rect2(0, 0, 168, 128), func(): choose_card(card_id), grid)
		b.custom_minimum_size = Vector2(168, 128)
		var l = label_text("", Rect2(8, 6, 152, 116), 14, PAPER, b)
		card_buttons[card_id] = b
		l.visible = false # Compatibility status text; the illustrated face owns the visible labels.
		card_labels.append(l)
	authority_button = button("", Rect2(172, 643, 98, 100), toggle_deck)
	var face = ClockIcon.new()
	face.position = Vector2(9, 9)
	face.size = Vector2(80, 80)
	authority_button.add_child(face)
	authority_button.tooltip_text = "时间权柄：展开或收起卡牌库；收起取消选牌"
	resources_label = label_text("", Rect2(298, 846, 885, 31), 19)
	hp_bar = bar(Rect2(299, 851, 510, 8), BATTLE_TEAL)
	energy_bar = bar(Rect2(816, 843, 580, 2), BATTLE_COPPER)
	deck_scroll.visible = false
	update_battle()

func _process(delta):
	if screen != "battle" or battle_finished:
		return
	var previous_battle_time := float(snapshot.get("time", 0.0))
	combat.tick(delta)
	snapshot = combat.get_snapshot()
	var events = combat.take_events()
	if is_instance_valid(battle_world):
		battle_world.sync_snapshot(snapshot)
		battle_world.consume_events(events)
		battle_world.advance(delta, float(snapshot.get("time", 0.0)) - previous_battle_time)
	for event in events:
		if not event.get("message", "").is_empty():
			log_lines.append(event.message)
			if log_lines.size() > 3:
				log_lines.pop_front()
		if event.get("type", "") in ["cast", "hit", "phase", "anchor"]:
			scenery.pulse = 1.0
	status_refresh += delta
	if status_refresh > 0.06 or not events.is_empty():
		status_refresh = 0
		update_battle()
	if snapshot.get("status", "active") != "active":
		battle_finished = true
		run_hp = int(snapshot.get("hp", 0))
		combat.set_paused(true)
		if snapshot.status == "won":
			coins += 10 if current_encounter == "tutorial" else (20 if current_encounter in ["stairs", "patrol"] else 0)
			if current_encounter == "lamp": store.save_metadata({"lamp_lit": true})
			if current_encounter == "boss" and quick_mode:
				show_event("试炼通过", "你使用已收藏并装备的实体卡完成了克洛诺斯的三阶段战斗练习。\n\n返回据点后，可以沿完整八节点路线探索失刻星台。", [{"text": "返回据点", "action": show_hub}, {"text": "再次试炼", "action": func(): begin_expedition(true)}], "practice_result")
			elif current_encounter == "boss":
				show_event("考核通过", "刻度环缓缓展开。克洛诺斯认可月璃对时间的进阶掌握。\n\n“时间不能抹去所有失去。但你已经知道，留下记忆与继续前进并不矛盾。”\n\n战前取得的“锚的钥匙”仍由月璃保管。暮笙站在星台指针旁，等待你一起迎接夜晚。", [{"text": "走向指针", "action": show_dial}], "ending")
			elif current_encounter == "tutorial":
				show_event("教学完成", "已取得10结晶；教学战不取卡。\n\n你已经尝试选牌减速、护幕防守与实体卡独立冷却。生命和已装备实体继续保留。", [{"text": "继续前往星台阶梯", "action": next_route}])
			else:
				show_rewards()
		else:
			show_event("本次远征撤离", "月璃合上魔法书，退回据点。\n\n本次路线、生命和实体升级将重置。已经取得的证据与已保存的原件选择继续保留。\n\n重新出发时，永久收藏与已保存装备继续保留。", [{"text": "返回据点", "action": show_hub}, {"text": "重新挑战本次路线", "action": func(): begin_expedition(quick_mode)}])

func update_battle():
	if screen != "battle": return
	if is_instance_valid(battle_world): battle_world.sync_snapshot(snapshot)
	resources_label.text = "月璃  生命 %d/%d   护盾 %d   灵能 %d/%d   装备 %d张" % [snapshot.hp, snapshot.max_hp, snapshot.shield, snapshot.energy, snapshot.max_energy, snapshot.cards.size()]
	hp_bar.max_value = snapshot.max_hp
	hp_bar.value = snapshot.hp
	energy_bar.max_value = snapshot.max_energy
	energy_bar.value = snapshot.energy
	focus_label.text = "专注 %.1f / %.1f 真实秒   ·   开关与滚动不减速" % [snapshot.focus, snapshot.max_focus]
	focus_bar.max_value = snapshot.max_focus
	focus_bar.value = snapshot.focus
	time_label.text = "战斗时钟 %.1f秒  ×%.1f\n%s" % [snapshot.time, snapshot.time_scale, "选牌减速中" if snapshot.time_scale < 1 else "敌人持续行动"]
	var items = []
	for item in snapshot.pending: items.append("%s %.1f秒" % [item.label, item.remaining])
	pending_label.text = "待结算：" + (" / ".join(items) if not items.is_empty() else "无")
	pending_label.tooltip_text = "\n".join(items)
	log_label.text = "\n".join(log_lines)
	message_label.text = snapshot.get("last_message", "")
	confirm_button.visible = false
	for i in range(snapshot.cards.size()):
		var card = snapshot.cards[i]
		var b = card_buttons[card.id]
		# Unavailable cards remain in their stable slot with an explicit reason.
		b.disabled = not card.playable and not card.selected
		card_labels[i].text = "%s\n灵能 %d  /  冷却 %.0f秒\n\n%s" % [card.name, card.cost, card.cooldown, "剩余 %.1f秒" % card.remaining if card.remaining > 0 else card.reason]
		b.configure(card)
		if card.selected and card.target == "self": confirm_button.visible = true
	var ids = []
	for enemy in snapshot.enemies: ids.append(enemy.id)
	if ids != active_enemy_ids: rebuild_targets()
	for enemy in snapshot.enemies:
		if is_instance_valid(battle_world): _position_world_status(enemy)
		target_labels[enemy.id].text = "%s  HP %d/%d  盾 %d\n%s" % [enemy.name + (" · 阶段%d/3" % snapshot.phase if enemy.kind == "boss" else ""), enemy.hp, enemy.max_hp, enemy.shield, "时间锚 · 无行动条" if enemy.is_anchor else "%s · 剩余 %.1f秒" % [enemy.intent, maxf(0, enemy.duration - enemy.charge)]]
		target_debuffs[enemy.id].sync_state(enemy, snapshot.get("pending", []))
		_position_debuffs(enemy)
		var enemy_hp = target_hp_bars[enemy.id]
		enemy_hp.max_value = enemy.max_hp
		enemy_hp.value = enemy.hp
		var action_bar = target_bars[enemy.id]
		action_bar.visible = false
		action_bar.max_value = maxf(1, enemy.duration)
		action_bar.value = enemy.charge
	var recovery = snapshot.recovery
	if recovery.is_empty():
		recovery_label.text = "阶段 %d/3 · 基础减速全程可用" % snapshot.phase if current_encounter == "boss" else ""
	else:
		recovery_label.text = "锚回收 %.1f秒 · 存活 %d/%d · 记录生命%d\n每破一锚恢复量减半，全灭截断回收。" % [recovery.remaining, recovery.living_anchors, recovery.total_anchors, recovery.recorded_hp]

	_apply_health_only_hud()

# Retain compatibility references and model updates while exposing only health.
# Apply after every refresh, including target rebuilds and recovery phase changes.
func _apply_health_only_hud() -> void:
	for control in [resources_label, energy_bar, focus_label, focus_bar, time_label, pending_label, recovery_label, message_label, log_label, pause_button]:
		control.visible = false
	for id in active_enemy_ids:
		target_labels[id].visible = false
		target_bars[id].visible = false
		target_debuffs[id].visible = false
		target_hp_bars[id].visible = true
	hp_bar.visible = true

func rebuild_targets():
	for target in target_buttons.values():
		page.remove_child(target)
		target.queue_free()
	for target in target_labels.values():
		page.remove_child(target)
		target.queue_free()
	for target in target_bars.values():
		page.remove_child(target)
		target.queue_free()
	for target in target_debuffs.values():
		page.remove_child(target)
		target.queue_free()
	for target in target_hp_bars.values():
		page.remove_child(target)
		target.queue_free()
	target_buttons.clear()
	target_labels.clear()
	target_bars.clear()
	target_hp_bars.clear()
	target_debuffs.clear()
	active_enemy_ids = []
	var index = 0
	var normal_index = 0
	var anchor_index = 0
	for enemy in snapshot.enemies:
		active_enemy_ids.append(enemy.id)
		var enemy_id = str(enemy.id)
		var is_boss = enemy.kind == "boss"
		var x = 675 + normal_index * 238
		var status_rect = Rect2(x, 265, 225, 78)
		var target_rect = Rect2(x, 357, 225, 76)
		if enemy.is_anchor:
			status_rect = Rect2(675 + anchor_index * 360, 440, 340, 55)
			target_rect = Rect2(675 + anchor_index * 360, 504, 340, 42)
			anchor_index += 1
		else: normal_index += 1
		if current_encounter == "boss":
			if is_boss:
				status_rect = Rect2(430, 143, 580, 48)
				target_rect = Rect2(810, 286, 390, 147)
			else:
				status_rect = Rect2(653 + (index - 1) * 380, 440, 355, 54)
				target_rect = Rect2(653 + (index - 1) * 380, 500, 355, 45)
		if not is_instance_valid(battle_world):
			var b = button("", target_rect, func(): confirm_selected(enemy_id))
			for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
				b.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
			target_buttons[enemy.id] = b
		var l = label_text("", status_rect, 16)
		_battle_label_surface(l)
		var action_rect = Rect2(status_rect.position.x, status_rect.end.y + 8, status_rect.size.x, 5)
		var hp_rect = Rect2(status_rect.position.x, status_rect.position.y - 10, status_rect.size.x, 7)
		if is_boss:
			action_rect = Rect2(430, 194, 580, 5)
			hp_rect = Rect2(430, 90, 580, 8)
		var action_bar = bar(action_rect, BATTLE_COPPER)
		var enemy_hp = bar(hp_rect, BATTLE_TEAL)
		target_labels[enemy.id] = l
		target_bars[enemy.id] = action_bar
		target_hp_bars[enemy.id] = enemy_hp
		var icons = DebuffIcons.new()
		icons.icon_size = 36 if is_boss else 24
		page.add_child(icons)
		target_debuffs[enemy.id] = icons
		index += 1

# Call this only with the chosen production manifest. An empty or incomplete
# manifest leaves the existing UI available while art is still being approved.
func set_battle_visual_assets(manifest: Dictionary) -> bool:
	battle_visual_assets = manifest.duplicate(true)
	battle_visual_missing_assets = []
	if screen == "battle":
		var was_open: bool = deck_open
		var scroll_position := int(deck_scroll.scroll_vertical)
		show_battle()
		deck_open = was_open
		deck_scroll.visible = was_open
		deck_scroll.scroll_vertical = scroll_position
		return is_instance_valid(battle_world)
	return not battle_visual_assets.is_empty()

func _activate_battle_world() -> void:
	if battle_visual_assets.is_empty(): return
	var presenter = BattleWorldPresenter.new()
	presenter.z_index = 50
	add_child(presenter)
	move_child(presenter, page.get_index())
	if not presenter.configure(current_encounter, battle_visual_assets, snapshot):
		battle_visual_missing_assets = presenter.missing_assets.duplicate()
		remove_child(presenter)
		presenter.queue_free()
		return
	battle_visual_missing_assets = presenter.missing_assets.duplicate()
	battle_world = presenter
	battle_world.target_selected.connect(confirm_selected)
	scenery.visible = false

func get_battle_target_rect(id: String) -> Rect2:
	if is_instance_valid(battle_world): return battle_world.get_target_rect(id)
	return target_buttons[id].get_global_rect() if target_buttons.has(id) else Rect2()

func _position_world_status(enemy: Dictionary) -> void:
	var status_rect: Rect2 = battle_world.get_status_rect(enemy)
	var status_label: Label = target_labels[enemy.id]
	status_label.position = status_rect.position
	status_label.size = status_rect.size
	var hp_rect := Rect2(status_rect.position.x, status_rect.position.y - 10, status_rect.size.x, 7)
	var action_rect := Rect2(status_rect.position.x, status_rect.end.y + 8, status_rect.size.x, 5)
	if enemy.kind == "boss":
		hp_rect = Rect2(430, 90, 580, 8)
		action_rect = Rect2(430, 194, 580, 5)
	target_hp_bars[enemy.id].position = hp_rect.position
	target_hp_bars[enemy.id].size = hp_rect.size
	target_bars[enemy.id].position = action_rect.position
	target_bars[enemy.id].size = action_rect.size

func choose_card(card_id: String):
	if screen != "battle" or is_instance_valid(overlay) or not deck_open: return false
	var accepted = combat.select_card(card_id)
	snapshot = combat.get_snapshot()
	update_battle()
	return accepted

func toggle_deck():
	if screen != "battle" or is_instance_valid(overlay): return
	deck_open = not deck_open
	if not deck_open: combat.cancel_selection()
	deck_scroll.visible = deck_open
	snapshot = combat.get_snapshot()
	update_battle()

func confirm_selected(target_id = ""):
	if screen != "battle" or is_instance_valid(overlay):
		return
	combat.play_selected(str(target_id))
	snapshot = combat.get_snapshot()
	update_battle()

func _unhandled_input(event):
	if screen == "exploration": return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(overlay): close_overlay()
			elif screen == "battle":
				if not str(snapshot.get("selected_card_id", "")).is_empty():
					combat.cancel_selection()
					snapshot = combat.get_snapshot()
					update_battle()
				elif deck_open: toggle_deck()
				else: show_pause()
			get_viewport().set_input_as_handled()
		elif screen == "battle" and not is_instance_valid(overlay) and event.keycode == KEY_SPACE:
			confirm_selected()
			get_viewport().set_input_as_handled()

func modal(title_value: String, pause_battle = true):
	close_overlay()
	overlay_pauses = screen == "battle" and pause_battle
	if overlay_pauses:
		combat.set_paused(true)
	overlay = Control.new()
	overlay.z_index = 200
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim = ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.05, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	panel(Rect2(190, 115, 1060, 685), overlay, BATTLE_INK)
	label_text(title_value, Rect2(225, 140, 920, 57), 32, PAPER, overlay)
	button("关闭  [Esc]", Rect2(1028, 734, 183, 44), close_overlay, overlay)
	return overlay

func close_overlay():
	var resume = overlay_pauses
	overlay_pauses = false
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
		overlay = null
	if resume and screen == "battle" and not battle_finished:
		combat.set_paused(false)

func show_pause():
	var p = modal("时间暂停")
	label_text("暂停菜单冻结全部战斗计时。\n\n继续时，行动、冷却、专注与待结算项从原位置恢复。", Rect2(229, 224, 936, 177), 23, PAPER, p)
	button("继续战斗", Rect2(232, 492, 284, 57), close_overlay, p, true)
	button("操作说明", Rect2(536, 492, 283, 57), show_help, p)
	button("设置", Rect2(232, 566, 284, 57), show_settings, p)
	button("调查日志", Rect2(536, 566, 283, 57), show_journal, p)
	button("撤离本次远征", Rect2(839, 492, 343, 57), show_hub, p)
	button("返回主菜单", Rect2(839, 566, 343, 57), show_start_menu, p)

func show_settings():
	var p = modal("设置")
	label_text("宽松专注：每战提供更宽松的专注条件，下次开战生效。", Rect2(230, 231, 940, 147), 23, PAPER, p)
	button("宽松专注：" + ("开" if relaxed_focus else "关"), Rect2(230, 421, 900, 64), func(): relaxed_focus = not relaxed_focus; save_progress(); show_settings(), p)

func show_help():
	var p = modal("操作与战斗规则")
	label_text("点击左侧时钟展开卡牌库；鼠标选择可用卡，点击敌人施放攻击。\n自身卡点击确认按钮或按空格。选牌后牌库保持展开。\nEsc依次：取消选牌 → 收起卡牌库 → 暂停。点击时钟收起也取消选牌。\n\n敌人持续行动。只有选牌、瞄准与短施放可减速至0.2倍。\n开关卡牌库与滚动不消耗专注、不减速。暂停冻结所有战斗计时。\n\n成功施放才支付费用；实体卡留在原位独立冷却。\n永久收藏支持不限数量的战前装备，新奖励不会自动装备。\n\nBoss二阶段起有时间锚，单体攻击可击破。全灭可截断回收。", Rect2(229, 220, 959, 460), 21, PAPER, p)

func show_deck():
	toggle_deck()

func show_regions():
	var p = modal("已解锁的中层权柄区域")
	label_text("魔法 / 空间 / 生命 / 以太 / 真我\n\n五个中层权柄区域已开放，可以自选顺序。\n后续区域尚未制作。这里是区域入口，不是五个房间。", Rect2(230, 228, 940, 370), 25, PAPER, p)

func show_rewards():
	clear_page("reward")
	route_header()
	reward_source = "chapter1:battle:" + current_encounter
	label_text("战斗结束 · 永久收藏奖励", Rect2(88, 181, 1250, 70), 36)
	if claimed_rewards.has(reward_source):
		label_text("该来源已经领取。永久收藏与已装备配置继续保留。", Rect2(94, 300, 1230, 100), 23)
		button("继续远征", Rect2(518, 772, 404, 53), next_route, page, true)
		return
	label_text(("最后一盏灯在之后的循环中亮起。\n" if current_encounter == "lamp" else "") + "从该来源领取一张实体卡，永久加入收藏。\n新奖励不自动装备；下场战斗前可以免费装配。", Rect2(94, 280, 1230, 118), 21)
	var reward_types = ["ember", "ember_shield", "ignite"]
	if current_encounter == "stairs": reward_types = ["ignite", "heavy_shield", "charge"]
	elif current_encounter in ["lamp", "elite"]: reward_types = TIME_TYPES
	elif current_encounter == "corridor": reward_types = ["fire", "shield", "ember"]
	var catalog = combat.get_card_catalog()
	var start_x = (1440.0 - reward_types.size() * 423 + 22) / 2
	for i in range(reward_types.size()):
		var type = reward_types[i]
		var card = catalog[type]
		illustrated_card(card.merged({"type": type}), Rect2(start_x + i * 423, 423, 401, 236), func(): claim_battle_reward(type))
		button("永久收藏 · 领取", Rect2(start_x + 20 + i * 423, 680, 358, 52), func(): claim_battle_reward(type), page, true)
	button("跳过奖励 · 继续", Rect2(518, 772, 404, 53), finish_reward)

func claim_battle_reward(type: String):
	if not store.claim_reward(reward_source, type):
		show_rewards()
		return
	finish_reward()

func finish_reward():
	if current_encounter == "elite": show_upgrade(next_route)
	else: next_route()

func show_supply():
	clear_page("supply")
	route_header()
	label_text("书页工坊 · 一次性来源", Rect2(78, 159, 1230, 70), 37)
	label_text("结晶 %d · 购卡30–45结晶，每个来源只领取一次，永久收藏；新卡不自动装备。" % coins, Rect2(82, 242, 1250, 48), 20)
	var catalog = combat.get_card_catalog()
	for i in range(TYPES.size()):
		var type = TYPES[i]
		var source = "chapter1:shop:%d:%s" % [route_index, type]
		var claimed = claimed_rewards.has(source)
		var price = 45 if type in ["echo", "delay"] else (40 if type == "heavy_shield" else (35 if type in ["ember", "ignite", "ember_shield"] else 30))
		var b = button(catalog[type].name + (" · 已领取" if claimed else " · 购买%d" % price), Rect2(82 + i % 3 * 429, 316 + int(i / 3) * 101, 405, 80), func():
			if coins >= price and store.claim_reward(source, type): coins -= price
			show_supply())
		b.disabled = claimed or coins < price
	button("升级单个实体 · 20结晶", Rect2(82, 666, 398, 55), func(): show_upgrade(func(): show_supply(), 20))
	button("离开工坊 · 继续", Rect2(952, 666, 405, 55), next_route, page, true)
	label_text("收藏不删除。卸装免费；装备配置在下场战前调整。升级仅作用于当前远征的指定实体。", Rect2(82, 780, 1270, 74), 19, MUTED)

func show_rest():
	show_event("休整", "免费回复15生命或升级一个已装备实体。\n支付20结晶可同时回复与升级；升级只作用于本次远征。", [{"text": "回复15生命", "action": func(): run_hp = mini(50, run_hp + 15); next_route()}, {"text": "免费升级一张", "action": func(): show_upgrade(next_route)}, {"text": "两项都做 · 20结晶", "action": func(): if coins >= 20: coins -= 20; run_hp = mini(50, run_hp + 15); show_upgrade(next_route)}])

func show_upgrade(callback: Callable, price = 0):
	upgrade_callback = callback
	var p = modal("当前远征 · 按实体升级")
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(232, 221)
	scroll.size = Vector2(975, 452)
	p.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var catalog = combat.get_card_catalog()
	for card in store.get_loadout():
		var id = str(card.id)
		var b = button(catalog[card.type].name + "\n" + id + ("\n已升级" if upgrades.has(id) else "\n升级"), Rect2(0, 0, 225, 100), func():
			if not upgrades.has(id) and coins >= price:
				coins -= price
				upgrades[id] = 1
				close_overlay()
				callback.call(), grid)
		b.custom_minimum_size = Vector2(225, 100)
		b.disabled = upgrades.has(id) or coins < price
	button("跳过升级", Rect2(230, 729, 280, 44), func(): close_overlay(); callback.call(), p)

func show_catalog():
	var p = modal("九类权柄卡牌")
	var catalog = combat.get_card_catalog()
	for i in range(TYPES.size()):
		var card = catalog[TYPES[i]]
		var x = 232 + i % 3 * 326
		var y = 216 + int(i / 3) * 154
		label_text(card.name + " · 灵能%d" % card.cost, Rect2(x, y, 303, 34), 20, GOLD, p)
		label_text(card.description + "\n冷却 %.0f秒" % card.cooldown, Rect2(x, y + 39, 303, 112), 16, PAPER, p)

func show_dial():
	show_event("拨向明天", "暮笙与月璃站在指针旁。\n\n“我们还是没能救回那一次失去。”\n“但他们终于可以过完黄昏，认真道别，然后走进夜色。”\n\n请亲手拨动指针。这个操作不会失败，失去的经历也不会被改写。", [{"text": "拨针 · 让第一个夜晚到来", "action": show_record_choice}], "ending")

func show_record_choice():
	if not record_choice.is_empty():
		show_epilogue()
		return
	show_event("带走一份原件", "星台的第一个夜晚到来。两份记录仍有无法消除的差异。\n\n《观测环刻录》：桥先断，钟后响。\n《暮笙手记》：钟先响，众人想看完星升。\n\n请选择带走的一份原件。另一份由洛笺保留不完整摘录。\n选择写入存档，回访不能改写；这不是对居民经历真假的裁决。", [{"text": "保留《观测环刻录》原件", "action": func(): select_record("观测环刻录")}, {"text": "保留《暮笙手记》原件", "action": func(): select_record("暮笙手记")}], "ending")

func select_record(value: String):
	if record_choice.is_empty():
		record_choice = value
	chapter_completed = true
	save_progress()
	show_epilogue()

func show_epilogue():
	chapter_completed = true
	save_progress()
	show_event("失刻星台 · 第一章完成", "克洛诺斯的刻度环收拢，仍是那个引导月璃的人。\n\n月璃掌握了时间的进阶用法，也留下无法替代的记忆。\n带回原件：《%s》。另一份由洛笺保留不完整摘录。\n\n魔法书据点的魔法、空间、生命、以太、真我五个中层权柄区域开放。\n后续章节尚未制作；第一章可以再次进入。" % record_choice, [{"text": "返回魔法书据点", "action": show_hub}], "ending")

func add_evidence(value: String):
	if not evidence.has(value):
		evidence.append(value)
		save_progress()

func show_journal():
	var p = modal("调查日志 · 保留差异")
	var proof = "已证实\n" + ("\n".join(evidence) if not evidence.is_empty() else "尚未取得证据")
	proof += "\n\n已证实：切片是观察，同一次救援失败没有被改写。" if evidence.has("断桥刻痕") else ""
	label_text(proof, Rect2(232, 229, 435, 405), 22, PAPER, p)
	var records = "转述 / 待核对\n《观测环刻录》：桥先断，钟后响。\n《暮笙手记》：钟先响，众人想看完星升。\n\n月璃的推测\n凝固的黄昏留住了人，也使道别无从发生。\n\n原件选择：" + (record_choice if not record_choice.is_empty() else "尚未决定")
	label_text(records, Rect2(707, 229, 492, 430), 20, GOLD, p)
	label_text("日志区分事实、转述与推测，不把冲突记录擅自判成真伪。", Rect2(232, 667, 955, 51), 18, MUTED, p)

func save_progress():
	return store.save_metadata({"evidence": evidence, "record_choice": record_choice, "chapter_completed": chapter_completed, "visits": visits, "reduced_feedback": reduced_feedback, "relaxed_focus": relaxed_focus})

func load_progress():
	if not store.initialize_time_authority(save_path):
		push_error(store.last_error)
		return
	var saved = store.data
	evidence = saved.get("evidence", [])
	record_choice = saved.get("record_choice", "")
	chapter_completed = saved.get("chapter_completed", false)
	visits = saved.get("visits", 0)
	reduced_feedback = saved.get("reduced_feedback", false)
	relaxed_focus = saved.get("relaxed_focus", false)


func _position_debuffs(enemy: Dictionary) -> void:
	var icons = target_debuffs[enemy.id]
	var health_rect: Rect2 = target_hp_bars[enemy.id].get_rect()
	icons.position = Vector2(health_rect.position.x, health_rect.end.y + 5) if enemy.kind == "boss" else Vector2(health_rect.position.x, health_rect.position.y - icons.icon_size - 5)

func _battle_backdrop() -> StyleBoxFlat:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.045, 0.075, 0.13, 0.82)
	background.border_color = Color(0.72, 0.54, 0.33, 0.38)
	background.set_border_width_all(1)
	background.set_corner_radius_all(3)
	return background

func _battle_label_surface(label: Label) -> void:
	label.add_theme_stylebox_override("normal", _battle_backdrop())
