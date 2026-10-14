extends Control

const FONT = preload("res://assets/fonts/SourceHanSansSC-Regular.otf")
const Ui = preload("res://scripts/ui/ui_kit.gd")
const CollectionStore = preload("res://scripts/progression/collection_store.gd")
const StartMenu = preload("res://scripts/ui/start_menu.gd")
const ExplorationSession = preload("res://scripts/exploration/exploration_session.gd")
const Temporal = preload("res://scripts/authority/temporal_controller.gd")
const TimeCard = preload("res://scripts/authority/time_card.gd")
var exploration_session
var start_menu
var save_path = "user://chapter_one.json"
var store = CollectionStore.new()
var page
var overlay
var return_button
var screen = "start_menu"
var evidence = []
var record_choice = ""

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme_data = Theme.new()
	theme_data.default_font = FONT
	theme_data.default_font_size = 17
	theme = theme_data
	page = Control.new()
	page.z_index = 100
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	load_progress()
	show_start_menu()

func show_start_menu():
	if is_instance_valid(exploration_session):
		exploration_session.suspend_session()
		load_progress()
	clear_page("start_menu")
	start_menu = StartMenu.new()
	page.add_child(start_menu)
	start_menu.set_continue_available(is_instance_valid(exploration_session) or bool(store.data.get("exploration_run",{}).get("active",false)))
	start_menu.action_requested.connect(_start_menu_action)

func _start_menu_action(action: String):
	match action:
		"new": start_exploration_session(true)
		"continue": continue_session_exploration()
		"authority": show_time_authority_collection()
		"journal": show_journal()
		"quit": get_tree().quit()

func continue_session_exploration():
	if is_instance_valid(exploration_session):
		close_overlay()
		page.visible = false
		screen = "exploration"
		exploration_session.resume_session()
	elif store.data.get("exploration_run",{}).get("active",false):
		start_exploration_session(false)

func start_exploration_session(new_exploration: bool):
	close_overlay()
	if is_instance_valid(exploration_session):
		exploration_session.suspend_session()
		remove_child(exploration_session)
		exploration_session.queue_free()
	page.visible = false
	screen = "exploration"
	exploration_session = ExplorationSession.new()
	add_child(exploration_session)
	exploration_session.return_to_menu.connect(show_start_menu)
	exploration_session.configure(store,new_exploration)

func clear_page(new_screen: String):
	if is_instance_valid(exploration_session): exploration_session.suspend_session()
	page.visible = true
	close_overlay()
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	screen = new_screen
	if new_screen == "start_menu": return
	var backdrop = ColorRect.new()
	backdrop.color = Color("202020")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(backdrop)
	var path = "res://assets/chapter1/observatory_courtyard.png"
	if ResourceLoader.exists(path):
		var art = TextureRect.new()
		art.texture = load(path)
		art.size = Vector2(1440, 900)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.modulate = Color(0.35, 0.42, 0.50, 0.65)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(art)
	var header = Ui.panel(Rect2(0, 0, 1440, 80), page)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.label_text("未尽之诗", Rect2(34, 20, 230, 40), page, 26)
	Ui.label_text("第一章  /  失刻星台", Rect2(250, 27, 530, 30), page, 18, Ui.GOLD)
	Ui.button("日志", Rect2(1158, 23, 92, 36), show_journal, page)
	Ui.button("操作", Rect2(1262, 23, 144, 36), show_help, page)

func show_time_authority_collection():
	clear_page("collection")
	Ui.label_text("时间权柄", Rect2(110, 140, 1220, 80), page, 42)
	var gifts: Array = store.get_authority_loadout()
	if gifts.is_empty():
		Ui.label_text("权柄尚未显现。", Rect2(112, 292, 900, 60), page, 24)
	else:
		var catalog = Temporal.card_catalog()
		for i in gifts.size():
			var face = TimeCard.new()
			face.position = Vector2(258+i*315, 310)
			face.size = Vector2(282, 260)
			page.add_child(face)
			for entry in catalog:
				if entry.id == gifts[i].type: face.configure(entry)
	return_button = Ui.button("返回主菜单", Rect2(550, 743, 340, 62), show_start_menu, page, true)

func _unhandled_input(event):
	if screen == "exploration": return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_instance_valid(overlay): close_overlay()
		elif screen != "start_menu": show_start_menu()
		get_viewport().set_input_as_handled()

func modal(title_value: String):
	close_overlay()
	overlay = Control.new()
	overlay.z_index = 200
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim = ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.05, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	Ui.panel(Rect2(190, 115, 1060, 685), overlay, Ui.PANEL_INK)
	Ui.label_text(title_value, Rect2(225, 140, 920, 57), overlay, 32)
	Ui.button("关闭  [Esc]", Rect2(1028, 734, 183, 44), close_overlay, overlay)
	return overlay

func close_overlay():
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
		overlay = null

func show_help():
	var p = modal("操作说明")
	Ui.label_text("A / D 或 ← / → 移动，Shift 奔跑，空格跳跃，E 互动，W / S 在岔路选择方向。\nEsc 依次：取消选牌 → 收起权柄 → 暂停。\n\n修复停摆装置后取得三张时间权柄。点击左下角时钟展开权柄，选择一张后点击场景中的对象施放：\n\n停止时间 · 让对象停在当前状态。\n快进时间 · 让对象的时间加速流逝。\n倒退时间 · 让对象沿刚才的轨迹回退。\n\n权柄效果与数值仍在原型阶段。", Rect2(229, 220, 959, 460), p, 21)

func show_journal():
	var p = modal("调查日志 · 保留差异")
	var proof = "已证实\n" + ("\n".join(evidence) if not evidence.is_empty() else "尚未取得证据")
	proof += "\n\n已证实：切片是观察，同一次救援失败没有被改写。" if evidence.has("断桥刻痕") else ""
	Ui.label_text(proof, Rect2(232, 229, 435, 405), p, 22)
	var records = "转述 / 待核对\n《观测环刻录》：桥先断，钟后响。\n《暮笙手记》：钟先响，众人想看完星升。\n\n月璃的推测\n凝固的黄昏留住了人，也使道别无从发生。\n\n原件选择：" + (record_choice if not record_choice.is_empty() else "尚未决定")
	Ui.label_text(records, Rect2(707, 229, 492, 430), p, 20, Ui.GOLD)
	Ui.label_text("日志区分事实、转述与推测，不把冲突记录擅自判成真伪。", Rect2(232, 667, 955, 51), p, 18, Ui.MUTED)

func load_progress():
	if not store.initialize_time_authority(save_path):
		push_error(store.last_error)
		return
	evidence = store.data.get("evidence", [])
	record_choice = store.data.get("record_choice", "")
