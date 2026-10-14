extends Node
## Persistent chapter coordinator; world owns positions, model owns combat effects.
signal return_to_menu
const World = preload("res://scripts/exploration/exploration_world.gd")
const Spatial = preload("res://scripts/exploration/spatial_combat.gd")
const Combat = preload("res://scripts/combat/combat_model.gd")
const Opening = preload("res://scripts/onboarding/opening_sequence.gd")
const AuthorityTutorial = preload("res://scripts/onboarding/authority_tutorial.gd")
const TimeCard = preload("res://scripts/authority/time_card.gd")
const Temporal = preload("res://scripts/authority/temporal_controller.gd")
const Tutorial = preload("res://scripts/onboarding/exploration_tutorial.gd")
const Card = preload("res://scripts/ui/battle_card.gd")
const Clock = preload("res://scripts/ui/clock_icon.gd")
const FONT = preload("res://assets/msyh.ttc")
const ForkGuidance = preload("res://scripts/exploration/fork_guidance.gd")
const TYPES = ["fire","shield","charge","ember","ignite","ember_shield","heavy_shield","echo","delay"]
var store
var world
var spatial
var combat = Combat.new()
var hud: CanvasLayer
var canvas: Control
var battle_hud: Control
var dialog: Control
var opening
var tutorial
var mode = "opening"
var suspended = false
var run: Dictionary = {}
var checkpoint: Dictionary = {}
var encounter = ""
var card_buttons: Dictionary = {}
var target_bars: Dictionary = {}
var deck_scroll: ScrollContainer
var authority_button: Button
var hp_bar: ProgressBar
var deck_open = false
var _jump = false
var _autosave = 0.0
var _ui_elapsed = 0.0
var _pause_return = "explore"
var _restore_mode = "explore"
var _loadout_only = false
var _loadout_scroll = 0
var ui_buttons: Dictionary = {}
var last_error = ""
var save_notice: Label
var boot_error: Control
var _authority_resolved_hits: Dictionary = {}
var fork_guidance: Control
var _fork_narration_started := false
var _fork_guidance_seen := false

func _authority_mode() -> bool:
	return store != null and str(store.data.get("active_ruleset", "")) == "time_authority_v2"

func configure(collection_store, new_exploration: bool) -> void:
	store = collection_store
	hud = CanvasLayer.new()
	hud.layer = 150
	add_child(hud)
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme = Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 21
	canvas.theme = theme
	hud.add_child(canvas)
	if new_exploration and not store.data.get("intro_accepted", false) and not store.data.get("tutorial_completed", false):
		opening = Opening.new()
		canvas.add_child(opening)
		opening.accepted.connect(_accept_opening)
	elif new_exploration:
		_new_run()
	else:
		run = store.data.get("exploration_run", {}).duplicate(true)
		checkpoint = store.data.get("exploration_checkpoint", run).duplicate(true)
		if run.is_empty(): _new_run()
		else:
			if run.get("in_battle", false):
				run = checkpoint.duplicate(true)
				run.in_battle = false
			run.lamp_lit = run.get("lamp_lit",store.data.get("lamp_lit",false))
			_build_world()
			if not _authority_mode() and not str(run.get("pending_reward", "")).is_empty(): _show_reward()
			elif not _authority_mode() and run.get("pending_upgrade", false): _show_upgrade("elite",0)
			elif run.get("pending_ending", "") == "record": _show_records()

func _accept_opening() -> void:
	_new_run()

func _new_run() -> void:
	var step = 4 if store.data.get("tutorial_completed", false) else 0
	var candidate = {"active":true,"position":[200,1900],"region":0,"hp":50,"coins":0,"upgrades":{},"completed":[],"interactions":[],"tutorial_step":step,"pending_reward":"","pending_upgrade":false,"in_battle":false,"rest_used":false,"elite_upgrade_used":false}
	var metadata = {"intro_accepted":true,"visits":int(store.data.get("visits",0))+1}
	if _authority_mode():
		candidate.ruleset = "time_authority_v2"
		candidate.authority_unlocked = bool(store.data.get("authority_granted",false))
		candidate.authority_tutorial_step = 3 if candidate.authority_unlocked else 0
	candidate.lamp_lit = store.data.get("lamp_lit",false)
	if not _commit(candidate,metadata):
		if is_instance_valid(boot_error): boot_error.queue_free()
		boot_error = Control.new()
		canvas.add_child(boot_error)
		boot_error.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_label("进度尚未保存，请重试。",Rect2(410,560,700,60),boot_error)
		_button("retry_opening","重试保存",Rect2(550,650,340,65),_new_run,boot_error)
		return
	_build_world()
	if is_instance_valid(opening): opening.queue_free(); opening = null
	if is_instance_valid(boot_error): boot_error.queue_free(); boot_error = null

func _build_world() -> void:
	world = World.new()
	add_child(world)
	world.configure(run)
	world.encounter_requested.connect(request_encounter)
	world.interaction_requested.connect(_interact)
	world.enemy_attack_hit.connect(_authority_enemy_hit)
	world.branch_chosen.connect(_branch_chosen)
	world.tutorial_event.connect(_tutorial_event)
	world.checkpoint_requested.connect(func(_p,_r):
		if mode == "explore": _save_checkpoint())
	if not _authority_mode():
		spatial = Spatial.new()
		add_child(spatial)
		spatial.configure(combat,world)
		spatial.target_clicked.connect(confirm_target)
	tutorial = AuthorityTutorial.new() if _authority_mode() else Tutorial.new()
	canvas.add_child(tutorial)
	tutorial.configure(int(run.get("authority_tutorial_step" if _authority_mode() else "tutorial_step",0)))
	tutorial.step_changed.connect(_tutorial_step)
	mode = "explore"
	_fork_guidance_seen = bool(store.data.get("fork_guidance_seen",false))
	fork_guidance = ForkGuidance.new()
	canvas.add_child(fork_guidance)
	_build_hud()

func _commit(candidate: Dictionary, metadata: Dictionary = {}, source: String = "", kind: String = "", update_checkpoint = true) -> bool:
	var safe = candidate.duplicate(true) if update_checkpoint else checkpoint.duplicate(true)
	if not store.commit_exploration(candidate,safe,metadata,source,kind):
		last_error = store.last_error
		push_warning(last_error)
		if not is_instance_valid(save_notice): save_notice = _label(last_error,Rect2(350,105,800,65),canvas,20)
		else: save_notice.text = last_error
		return false
	run = candidate.duplicate(true)
	checkpoint = safe
	last_error = ""
	if is_instance_valid(save_notice): save_notice.queue_free(); save_notice = null
	if world != null: world.apply_run(run)
	return true

func _position_into(candidate: Dictionary) -> void:
	if world == null: return
	var p: Vector2 = world.get_player_position()
	candidate.position = [p.x,p.y]
	candidate.region = world.current_region

func _save_checkpoint() -> bool:
	if run.is_empty() or mode == "battle": return false
	if world != null and world.proximity_fork().get("route_active",false): return false
	# A hostile approach must not replace the last safe retry position with a hitbox.
	if _authority_mode() and (int(run.get("hp",50)) <= 0 or world.has_hostile_attention()): return false
	var candidate = run.duplicate(true)
	_position_into(candidate)
	candidate.in_battle = false
	return _commit(candidate)

func _tutorial_event(event: String, data: Dictionary) -> void:
	if tutorial != null: tutorial.observe(event,data)

func _tutorial_step(step: int) -> void:
	var candidate = run.duplicate(true)
	_position_into(candidate)
	var field = "authority_tutorial_step" if _authority_mode() else "tutorial_step"
	candidate[field] = step
	var metadata = {} if _authority_mode() else {"tutorial_completed":step == 4}
	if not _commit(candidate,metadata): tutorial.configure(int(run.get(field,0)))

func _physics_process(delta: float) -> void:
	if suspended or world == null: return
	if spatial != null: spatial.advance_feedback(minf(delta,0.1))
	if mode in ["explore","battle"]:
		var axis = Input.get_axis("explore_left","explore_right")
		world.set_movement_input(axis,_jump,Input.is_action_pressed("explore_run"))
		_jump = false
		if mode == "battle":
			spatial.advance(minf(delta,0.1))
			for event in combat.take_events():
				spatial.present_event(event)
				if event.type == "cast": world.play_player_action("cast")
				elif event.type == "hit" and event.get("target","") == "player": world.play_player_action("hurt")
			if combat.status in ["won","lost"]: _finish_battle()
		else:
			world.advance_simulation(minf(delta,0.1))
			_autosave += delta
			if _autosave >= 5.0 and world.player.grounded:
				_autosave = 0
				_save_checkpoint()
	elif mode in ["ending","complete"]:
		# The finale is a cinematic interaction, not a paused gameplay menu.
		world.set_paused(false)
		world.set_movement_input(0,false)
		world.advance_simulation(minf(delta,0.1))
	_ui_elapsed += delta
	_update_fork_guidance(delta)
	if _ui_elapsed > 0.05:
		_ui_elapsed = 0
		_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if suspended or mode == "opening": return
	if event is InputEventKey and event.pressed and not event.echo:
		var key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_ESCAPE:
			if _authority_mode() and mode == "explore" and not world.temporal.selected_card.is_empty():
				world.temporal.cancel_selection()
			elif _authority_mode() and mode == "explore" and deck_open: toggle_deck()
			elif mode == "battle" and not combat.selected_card_id.is_empty(): combat.cancel_selection()
			elif mode == "battle" and deck_open: toggle_deck()
			elif mode in ["pause", "dialog", "device", "device_complete", "inspection", "shop", "rest", "journal"]: _resume_dialog()
			elif mode in ["explore","battle"]: show_pause()
			get_viewport().set_input_as_handled()
		elif key == KEY_SPACE and mode in ["explore","battle"]:
			_jump = true
			get_viewport().set_input_as_handled()
		elif key == KEY_E and mode == "explore":
			world.interact()
			get_viewport().set_input_as_handled()
		elif key in [KEY_W,KEY_S] and mode == "explore":
			if world.choose_branch(-1 if key == KEY_W else 1):
				get_viewport().set_input_as_handled()
	if _authority_mode() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and mode == "explore":
		var target = world.temporal.target_at_point(event.position)
		if not target.is_empty():
			confirm_target(target)
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and mode == "battle":
		for enemy in combat.enemies:
			if spatial.get_target_rect(enemy.id).has_point(event.position):
				confirm_target(enemy.id)
				get_viewport().set_input_as_handled()
				break

func _update_fork_guidance(delta: float) -> void:
	if not is_instance_valid(fork_guidance) or world == null: return
	var context: Dictionary = world.proximity_fork()
	var active: bool = mode == "explore" and not suspended
	if active and context.get("visible",false) and not _fork_guidance_seen and not _fork_narration_started:
		_fork_narration_started = true
		fork_guidance.begin_narration()
	var point: Vector2 = world.get_viewport_transform() * Vector2(context.get("world_position",Vector2.ZERO))
	fork_guidance.advance(delta,context,point,active)
	if _fork_narration_started and not _fork_guidance_seen and fork_guidance.narration_remaining <= 0.0:
		_mark_fork_guidance_seen()

func _branch_chosen(_id: String, _direction: int) -> void:
	if _fork_narration_started: _mark_fork_guidance_seen()

func _mark_fork_guidance_seen() -> void:
	if _fork_guidance_seen: return
	# This presentation flag never overwrites a safe position with a connector midpoint.
	if store.save_metadata({"fork_guidance_seen":true}):
		_fork_guidance_seen = true

func _box(bg = Color(0.035,0.065,0.105,0.94)) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = Color("8499b4")
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	return box

func _label(text: String, rect: Rect2, parent: Control, font_size = 24) -> Label:
	var label = Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color",Color("e4ebf4"))
	label.add_theme_font_size_override("font_size",font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(id: String, text: String, rect: Rect2, callback: Callable, parent: Control) -> Button:
	var b = Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal",_box())
	b.add_theme_stylebox_override("hover",_box(Color(0.13,0.20,0.29,0.97)))
	b.add_theme_stylebox_override("pressed",_box(Color(0.2,0.27,0.35,0.98)))
	b.pressed.connect(callback)
	parent.add_child(b)
	ui_buttons[id] = b
	return b

func _bar(rect: Rect2, parent: Control) -> ProgressBar:
	var b = ProgressBar.new()
	b.position = rect.position
	b.size = rect.size
	b.show_percentage = false
	b.add_theme_font_size_override("font_size",1)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background = _box(Color("0b1725"))
	var fill = _box(Color("83d3dc"))
	fill.set_border_width_all(0)
	b.add_theme_stylebox_override("background",background)
	b.add_theme_stylebox_override("fill",fill)
	parent.add_child(b)
	# Apply geometry after its font and styles, avoiding the default text minimum height.
	b.size = rect.size
	return b

func _build_hud() -> void:
	if _authority_mode():
		_build_authority_hud()
		return
	if is_instance_valid(battle_hud):
		canvas.remove_child(battle_hud)
		battle_hud.queue_free()
	battle_hud = Control.new()
	battle_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(battle_hud)
	card_buttons.clear()
	target_bars.clear()
	hp_bar = _bar(Rect2(300,864,510,8),battle_hud)
	hp_bar.max_value = 50
	hp_bar.value = run.get("hp",50)
	deck_scroll = ScrollContainer.new()
	deck_scroll.position = Vector2(300,582)
	deck_scroll.size = Vector2(1098,268)
	deck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	battle_hud.add_child(deck_scroll)
	var grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",10)
	deck_scroll.add_child(grid)
	if mode == "battle":
		for card in combat.get_snapshot().cards:
			var id = str(card.id)
			var face = Card.new()
			face.custom_minimum_size = Vector2(168,128)
			grid.add_child(face)
			face.configure(card)
			face.pressed.connect(func(): choose_card(id))
			card_buttons[id] = face
	authority_button = _button("authority","",Rect2(182,655,96,96),toggle_deck,battle_hud)
	var clock = Clock.new()
	clock.position = Vector2(7,7)
	clock.size = Vector2(82,82)
	authority_button.add_child(clock)
	deck_open = false
	deck_scroll.visible = false
	authority_button.visible = mode == "battle"
	_update_hud()

func _update_hud() -> void:
	if not is_instance_valid(battle_hud): return
	if _authority_mode():
		if is_instance_valid(hp_bar): hp_bar.value = run.get("hp",50)
		for id in card_buttons:
			card_buttons[id].set_selected(world.temporal.selected_card == id)
		return
	hp_bar.value = combat.hp if mode == "battle" else run.get("hp",50)
	if mode != "battle": return
	var snapshot = combat.get_snapshot()
	world.camera.force_update_scroll()
	for card in snapshot.cards:
		if card_buttons.has(card.id): card_buttons[card.id].configure(card)
	var live = []
	for enemy in snapshot.enemies:
		live.append(enemy.id)
		if not target_bars.has(enemy.id): target_bars[enemy.id] = _bar(Rect2(0,0,140,7),battle_hud)
		var bar: ProgressBar = target_bars[enemy.id]
		var rect: Rect2 = spatial.get_target_rect(enemy.id)
		bar.position = Vector2(430,92) if enemy.kind == "boss" else rect.position+Vector2((rect.size.x-140)/2,-15)
		bar.size = Vector2(580,11) if enemy.kind == "boss" else Vector2(140,7)
		bar.max_value = enemy.max_hp
		bar.value = enemy.hp
		bar.visible = rect.intersects(Rect2(0,0,1440,575)) or enemy.kind == "boss"
	for id in target_bars.keys():
		if not id in live:
			target_bars[id].queue_free()
			target_bars.erase(id)

func toggle_deck() -> void:
	if _authority_mode():
		if mode != "explore" or not run.get("authority_unlocked",false): return
		deck_open = not deck_open
		deck_scroll.visible = deck_open
		if not deck_open: world.temporal.cancel_selection()
		return
	if mode != "battle": return
	deck_open = not deck_open
	deck_scroll.visible = deck_open
	if not deck_open: combat.cancel_selection()

func choose_card(id: String) -> void:
	if _authority_mode():
		if mode == "explore": world.temporal.select_card(id); _update_hud()
		return
	if mode != "battle": return
	if combat.selected_card_id == id:
		for card in combat.cards:
			if card.id == id and card.target == "self": combat.play_selected("")
	else: combat.select_card(id)
	_update_hud()

func confirm_target(id: String) -> void:
	if _authority_mode():
		if mode == "explore":
			if world.temporal.select_target(id): world.play_player_action("cast")
			_update_hud()
		return
	if mode == "battle":
		combat.play_selected(id)
		_update_hud()

func _clear_dialog() -> void:
	if is_instance_valid(dialog):
		canvas.remove_child(dialog)
		dialog.queue_free()
	dialog = null
	ui_buttons.clear()

func _panel(title: String, body: String = "") -> Control:
	_clear_dialog()
	if is_instance_valid(fork_guidance): fork_guidance.hide()
	_jump = false
	world.set_movement_input(0, false)
	if _authority_mode(): world.temporal.cancel_selection()
	deck_open = false
	if is_instance_valid(deck_scroll): deck_scroll.visible = false
	if is_instance_valid(battle_hud): battle_hud.visible = false
	if is_instance_valid(tutorial): tutorial.visible = false
	world.set_paused(true)
	if spatial != null and spatial.active: spatial.set_paused(true)
	# A modal freezes the world but retains its current camera composition.
	world.camera.enabled = true
	world.camera.force_update_scroll()
	dialog = Control.new()
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(dialog)
	var dim = ColorRect.new()
	dim.color = Color(0.01,0.025,0.05,0.4)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.add_child(dim)
	var panel = Panel.new()
	panel.position = Vector2(170,145)
	panel.size = Vector2(1100,610)
	panel.add_theme_stylebox_override("panel",_box(Color(0.025,0.05,0.09,0.9)))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.add_child(panel)
	_label(title,Rect2(210,178,1020,55),dialog,32)
	_label(body,Rect2(215,254,1010,290),dialog,23)
	return dialog

func _resume_dialog() -> void:
	_clear_dialog()
	mode = _pause_return if mode == "pause" else "explore"
	_jump = false
	world.set_movement_input(0, false)
	world.set_paused(false)
	if is_instance_valid(tutorial): tutorial.visible = not bool(tutorial.presentation_state().get("complete", false))
	if is_instance_valid(battle_hud): battle_hud.visible = true
	if mode == "battle": spatial.set_paused(false)
	else: _build_hud()

func request_encounter(id: String) -> void:
	if _authority_mode(): return
	if mode != "explore" or id in run.completed: return
	encounter = id
	var candidate = run.duplicate(true)
	_position_into(candidate)
	# Store a safe approach point, outside the automatic encounter trigger.
	var p: Vector2 = world.get_player_position()
	var trigger: Vector2 = world.get_encounter_spec(id).trigger
	candidate.position = [minf(p.x,trigger.x-175),p.y]
	if not _commit(candidate): return
	show_loadout(false)

func show_loadout(collection_only = false) -> void:
	if _authority_mode(): return
	_loadout_only = collection_only
	mode = "loadout"
	var p = _panel("显现权柄" if collection_only else "战前装备", "点击收藏中的卡牌装入或卸下。本次已装备 %d 张。" % store.equipped_ids.size())
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(215,315)
	scroll.size = Vector2(1010,305)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	scroll.add_child(grid)
	var catalog = combat.get_card_catalog()
	for card in store.collection:
		var id = str(card.id)
		var face = Card.new()
		face.custom_minimum_size = Vector2(156,132)
		grid.add_child(face)
		face.configure(catalog[card.type].merged({"id":id,"type":card.type}),true,store.equipped_ids.has(id))
		face.pressed.connect(func():
			var ids = store.equipped_ids
			if id in ids: ids.erase(id)
			else: ids.append(id)
			_loadout_scroll = scroll.scroll_vertical
			if store.set_equipped(ids): show_loadout(collection_only))
	scroll.set_deferred("scroll_vertical",_loadout_scroll)
	_button("equip_all","全部装备",Rect2(215,665,205,48),func(): store.set_equipped(store.collection.map(func(c): return c.id)); show_loadout(collection_only),p)
	_button("loadout_cancel","返回",Rect2(450,665,205,48),cancel_loadout,p)
	var confirm = _button("loadout_confirm","完成" if collection_only else "确认装备 · 开战",Rect2(895,665,330,48),cancel_loadout if collection_only else confirm_loadout,p)
	confirm.disabled = not collection_only and store.equipped_ids.is_empty()

func cancel_loadout() -> void:
	if not _loadout_only:
		world.leave_encounter(encounter)
		world.set_player_position(Vector2(run.position[0],run.position[1]))
	_resume_dialog()

func confirm_loadout() -> bool:
	if _authority_mode(): return false
	if mode != "loadout" or store.equipped_ids.is_empty(): return false
	var candidate = run.duplicate(true)
	candidate.in_battle = true
	if not _commit(candidate,{},"","",false): return false
	if not spatial.start(encounter,{"hp":int(run.hp),"loadout":store.get_loadout(),"upgrades":run.upgrades,"relaxed_focus":store.data.get("relaxed_focus",false)}): return false
	_clear_dialog()
	mode = "battle"
	_build_hud()
	return true

func _finish_battle() -> void:
	var victory = combat.status == "won"
	if not victory:
		spatial.set_paused(true)
		mode = "defeat"
		var p = _panel("重整脚步", "已获得的卡牌与记录仍然保留。")
		_button("retry","返回检查点",Rect2(425,645,290,58),retry_checkpoint,p)
		_button("menu","主界面",Rect2(745,645,270,58),leave_to_menu,p)
		return
	var candidate = run.duplicate(true)
	candidate.hp = combat.hp
	candidate.in_battle = false
	_position_into(candidate)
	if not encounter in candidate.completed:
		candidate.completed.append(encounter)
		candidate.coins += 10 if encounter == "tutorial" else (20 if encounter in ["stairs","patrol"] else 0)
	var source = "chapter1:battle:"+encounter
	candidate.pending_reward = encounter if encounter not in ["tutorial","boss"] and not source in store.claimed_rewards else ""
	candidate.pending_upgrade = encounter == "elite" and not candidate.get("elite_upgrade_used",false)
	var metadata = {"lamp_lit":true} if encounter == "lamp" else {}
	if encounter == "lamp": candidate.lamp_lit = true
	if not _commit(candidate,metadata):
		spatial.set_paused(true)
		mode = "save_error"
		var p = _panel("保存未完成",last_error)
		_button("retry_save","重试保存",Rect2(535,640,370,58),func(): mode="battle"; _finish_battle(),p)
		return
	spatial.finish(true)
	world.apply_run(run)
	mode = "explore"
	_build_hud()
	if not run.pending_reward.is_empty(): _show_reward()
	elif run.pending_upgrade: _show_upgrade("elite",0)

func retry_checkpoint() -> void:
	if spatial != null: spatial.finish()
	var candidate = checkpoint.duplicate(true)
	candidate.in_battle = false
	if not _commit(candidate): return
	world.configure(run)
	world.leave_encounter(encounter)
	if _authority_mode():
		_authority_resolved_hits.clear()
		world.reset_enemy_encounters()
		for target_id in world.temporal.get_presentation().targets:
			world.temporal.reset_target_history(target_id)
	_resume_dialog()

func _authority_enemy_hit(_enemy_id: String, attack_id: String, damage: int) -> void:
	if not _authority_mode() or mode != "explore" or suspended or damage <= 0:
		return
	if _authority_resolved_hits.has(attack_id): return
	_authority_resolved_hits[attack_id] = true
	run.hp = maxi(0,int(run.get("hp",50))-damage)
	world.play_player_action("hurt")
	_update_hud()
	if int(run.hp) == 0:
		mode = "defeat"
		var panel = _panel("重整脚步", "已获得的卡牌与记录仍然保留。")
		_button("retry","返回检查点",Rect2(425,645,290,58),retry_checkpoint,panel)
		_button("menu","主界面",Rect2(745,645,270,58),leave_to_menu,panel)

func _reward_types(id: String) -> Array:
	if id == "stairs": return ["ignite","heavy_shield","charge"]
	if id in ["lamp","elite"]: return ["echo","delay"]
	if id == "corridor": return ["fire","shield","ember"]
	return ["ember","ember_shield","ignite"]

func _show_reward() -> void:
	if _authority_mode(): return
	mode = "reward"
	var id = str(run.pending_reward)
	var p = _panel("新的权柄刻印", "选择一张卡牌，永久加入收藏。新卡可在下一场战斗前装备。")
	var types = _reward_types(id)
	var catalog = combat.get_card_catalog()
	for i in types.size():
		var kind = str(types[i])
		var card = Card.new()
		card.position = Vector2(270+i*310,360)
		card.size = Vector2(280,230)
		p.add_child(card)
		card.configure(catalog[kind].merged({"type":kind}))
		card.pressed.connect(func(): claim_reward(kind))
		_button("reward_"+kind,"收藏",Rect2(270+i*310,620,280,48),func(): claim_reward(kind),p)

func claim_reward(kind: String) -> bool:
	if _authority_mode(): return false
	var id = str(run.get("pending_reward",""))
	if id.is_empty() or not kind in _reward_types(id): return false
	var candidate = run.duplicate(true)
	candidate.pending_reward = ""
	if not _commit(candidate,{},"chapter1:battle:"+id,kind): return false
	if run.pending_upgrade: _show_upgrade("elite",0)
	else: _resume_dialog()
	return true

func _interact(id: String) -> void:
	if mode != "explore": return
	if _authority_mode() and id == "stalled_device":
		_show_device()
		return
	if _authority_mode() and (id.begins_with("supply_") or id == "rest"):
		_show_authority_inspection(id)
		return
	if id.begins_with("supply_"): _show_supply(id); return
	if id == "rest": _show_rest(); return
	if id == "final_dial": _show_dial(); return
	var candidate = run.duplicate(true)
	_position_into(candidate)
	if not id in candidate.interactions: candidate.interactions.append(id)
	var evidence: Array = store.data.get("evidence",[]).duplicate()
	if id.begins_with("bridge_") and "bridge_before" in candidate.interactions and "bridge_after" in candidate.interactions and not "断桥刻痕" in evidence: evidence.append("断桥刻痕")
	if id == "testimony" and not "值守名单" in evidence: evidence.append("值守名单")
	if id == "anchor_key" and not "锚的钥匙" in evidence: evidence.append("锚的钥匙")
	if id in ["bridge_before","bridge_after"]: candidate.time_slice = "before" if id == "bridge_before" else "after"
	if not _commit(candidate,{"evidence":evidence}): return
	if id in ["bridge_before","bridge_after"] and world.has_method("set_time_slice"):
		world.set_time_slice("before" if id == "bridge_before" else "after")
	var entries = {
		"tutorial_lantern":["观测灯","提灯仍在风中轻晃。石阶沿前方分成上下两条通路，最终重新汇合。"],
		"bridge_before":["落日前","石桥仍然完好，撤离提灯在桥上等待。这一片黄昏还没有抵达钟鸣。"],
		"bridge_after":["钟鸣后","石桥已经断裂，撤离提灯摔碎。救援的失败是既成经历；观察切片不会改写它。"],
		"testimony":["暮笙的证词","观测员暮笙记得每一次循环。她启动时间锚，是想留住没有失去任何人的黄昏。\n\n《观测环刻录》：桥先断，钟后响。\n《暮笙手记》：钟先响，众人想看完星升。\n\n已取得值守名单。两份记录仍待核对。"],
		"anchor_key":["锚的钥匙","克洛诺斯：从这一刻起，我将作为考官。刻度、锚定、残响——让我看见你如何继续前进、保留状态、保存记忆。\n\n已取得锚的钥匙。时间锚可被单体攻击击破。"]}
	if not entries.has(id): return
	mode = "dialog"
	var p = _panel(entries[id][0],entries[id][1])
	if id.begins_with("bridge_") and int(store.data.get("visits",0))>1:
		_button("anchored","观察锚定时",Rect2(220,655,350,55),_show_anchored_slice,p)
	_button("continue","继续探索",Rect2(860,655,340,55),_resume_dialog,p)

func _show_device(completed = false) -> void:
	mode = "device_complete" if completed else "device"
	var restored: bool = bool(run.get("authority_unlocked", false))
	var body = "装置已恢复运转。停止时间、快进时间、倒退时间三张时间权柄已收录。" if restored else "装置的刻度停滞。校准后可以恢复运转，并取得三张时间权柄。"
	if not restored and int(run.get("authority_tutorial_step", 0)) < 2:
		body = "装置的刻度停滞。先完成靠近与跳跃练习，再尝试校准。"
	var p = _panel("装置修复完成" if completed else "已恢复的装置" if restored else "停摆装置", body)
	if not restored and int(run.get("authority_tutorial_step", 0)) >= 2:
		_button("repair_device", "校准并修复", Rect2(220,655,350,55), _confirm_device_repair, p)
	_button("continue", "继续探索" if restored else "返回", Rect2(860,655,340,55), _resume_dialog, p)

func _confirm_device_repair() -> void:
	if mode != "device": return
	if _repair_device(): _show_device(true)

func _show_authority_inspection(id: String) -> void:
	mode = "inspection"
	var title = "补给点"
	var body = "补给架静静留在原处。月璃可以观察这里的陈设。"
	if id == "rest":
		title = "钟楼休整处"
		body = "钟楼下的休整处安静而稳固。稍作停留后，可以继续探索。"
	elif id == "final_dial":
		title = "钟楼表盘"
		body = "巨大的指针停在黄昏的刻度上。表盘等待后续的探索。"
	var p = _panel(title, body)
	_button("continue", "继续探索", Rect2(860,655,340,55), _resume_dialog, p)

func _show_anchored_slice() -> void:
	var candidate = run.duplicate(true)
	candidate.time_slice = "anchored"
	if not _commit(candidate): return
	if world.has_method("set_time_slice"): world.set_time_slice("anchored")
	var p = _panel("锚定时", "暮笙的手停在撤离钟的刻度前，时间锚已经启动。\n\n这一切片说明锚在循环中的存在，不能单独裁定两份记录的先后关系。")
	_button("continue","继续探索",Rect2(860,655,340,55),_resume_dialog,p)

func _price(kind: String) -> int:
	return 45 if kind in ["echo","delay"] else 40 if kind == "heavy_shield" else 35 if kind in ["ember","ignite","ember_shield"] else 30

func _show_supply(id: String) -> void:
	if _authority_mode(): return
	mode = "shop"
	var p = _panel("权柄工坊", "结晶 %d · 每个来源限购一次" % run.coins)
	var node = 3 if id == "supply_lamp" else 5
	var catalog = combat.get_card_catalog()
	for i in TYPES.size():
		var kind = str(TYPES[i])
		var claimed = "chapter1:shop:%d:%s" % [node,kind] in store.claimed_rewards
		var b = _button("buy_"+kind,catalog[kind].name+(" · 已领取" if claimed else " · %d" % _price(kind)),Rect2(215+i%3*342,330+int(i/3)*83,322,63),func(): buy_card(id,kind); _show_supply(id),p)
		b.disabled = claimed or int(run.coins)<_price(kind)
	_button("upgrade","升级实体 · 20结晶",Rect2(215,650,360,55),func(): _show_upgrade(id,20),p)
	_button("continue","继续探索",Rect2(865,650,360,55),_resume_dialog,p)

func buy_card(id: String, kind: String) -> bool:
	if _authority_mode(): return false
	if not kind in TYPES or int(run.coins)<_price(kind): return false
	var candidate = run.duplicate(true)
	_position_into(candidate)
	candidate.coins -= _price(kind)
	var source = "chapter1:shop:%d:%s" % [3 if id == "supply_lamp" else 5,kind]
	return _commit(candidate,{},source,kind)

func _show_rest() -> void:
	if _authority_mode(): return
	mode = "rest"
	var p = _panel("钟楼休整处", "此处已经休整过。" if run.rest_used else "回复15生命，或升级一个已装备实体。支付20结晶可以同时进行。")
	if not run.rest_used:
		_button("heal","回复生命",Rect2(215,560,300,55),rest_heal,p)
		_button("rest_upgrade","升级实体",Rect2(550,560,300,55),func(): _show_upgrade("rest",0),p)
		var b = _button("rest_both","同时进行 · 20结晶",Rect2(885,560,340,55),func(): _show_upgrade("rest_both",20),p)
		b.disabled = int(run.coins)<20
	_button("continue","继续探索",Rect2(865,660,360,55),_resume_dialog,p)

func rest_heal() -> bool:
	if _authority_mode(): return false
	if run.rest_used: return false
	var candidate = run.duplicate(true)
	_position_into(candidate)
	candidate.rest_used = true
	candidate.hp = mini(50,int(candidate.hp)+15)
	if not _commit(candidate): return false
	_resume_dialog()
	return true

func _show_upgrade(origin: String, price: int) -> void:
	if _authority_mode(): return
	mode = "upgrade"
	var p = _panel("雕刻权柄", "本次探索中，每张实体卡只可升级一次。")
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(215,330)
	scroll.size = Vector2(1010,285)
	p.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	scroll.add_child(grid)
	var catalog = combat.get_card_catalog()
	for card in store.get_loadout():
		var id = str(card.id)
		var b = _button("upgrade_"+id,catalog[card.type].name+(" · 已升级" if run.upgrades.has(id) else ""),Rect2(0,0,235,72),func(): upgrade_card(id,origin,price),grid)
		b.custom_minimum_size = Vector2(235,72)
		b.disabled = run.upgrades.has(id) or int(run.coins)<price
	_button("continue","稍后处理" if origin == "elite" else "返回",Rect2(865,665,360,48),_resume_dialog,p)

func upgrade_card(id: String, origin: String, price: int) -> bool:
	if _authority_mode(): return false
	if not id in store.equipped_ids or run.upgrades.has(id) or int(run.coins)<price: return false
	if origin in ["rest","rest_both"] and run.rest_used: return false
	if origin == "elite" and run.elite_upgrade_used: return false
	var candidate = run.duplicate(true)
	_position_into(candidate)
	candidate.coins -= price
	candidate.upgrades[id] = 1
	if origin in ["rest","rest_both"]: candidate.rest_used = true
	if origin == "rest_both": candidate.hp = mini(50,int(candidate.hp)+15)
	if origin == "elite":
		candidate.elite_upgrade_used = true
		candidate.pending_upgrade = false
	if not _commit(candidate): return false
	_resume_dialog()
	return true

func _show_dial() -> void:
	if _authority_mode() and not "boss" in run.completed:
		_show_authority_inspection("final_dial")
		return
	if not "boss" in run.completed: return
	mode = "ending"
	var p = _panel("拨向明天", "暮笙与月璃站在指针旁。\n\n“我们还是没能救回那一次失去。”\n“但他们终于可以过完黄昏，认真道别，然后走进夜色。”\n\n失去的经历不会被改写。")
	_button("dial","拨针 · 迎来第一个夜晚",Rect2(710,655,480,55),_show_records,p)

func _show_records() -> void:
	var candidate = run.duplicate(true)
	_position_into(candidate)
	candidate.chapter_night = true
	candidate.pending_ending = "record"
	if not _commit(candidate): return
	mode = "ending"
	if world.has_method("set_chapter_night"): world.set_chapter_night(true)
	if not str(store.data.get("record_choice","")).is_empty(): select_record(str(store.data.record_choice)); return
	var p = _panel("带走一份原件", "《观测环刻录》：桥先断，钟后响。\n《暮笙手记》：钟先响，众人想看完星升。\n\n另一份由洛笺保留不完整摘录。选择保存后不可改写。")
	_button("record_observatory","保留《观测环刻录》",Rect2(240,630,440,65),func(): select_record("观测环刻录"),p)
	_button("record_musheng","保留《暮笙手记》",Rect2(760,630,440,65),func(): select_record("暮笙手记"),p)

func select_record(record: String) -> bool:
	if not record in ["观测环刻录","暮笙手记"] or not "boss" in run.completed: return false
	var candidate = run.duplicate(true)
	_position_into(candidate)
	candidate.active = false
	candidate.pending_ending = ""
	if not _commit(candidate,{"record_choice":record,"chapter_completed":true}): return false
	mode = "complete"
	var p = _panel("失刻星台 · 第一章完成", "星台结束了黄昏的循环。克洛诺斯认可月璃对时间的进阶掌握。\n\n带回原件：《%s》。\n\n魔法、空间、生命、以太、真我五个中层权柄区域开放。后续章节尚未制作。" % store.data.record_choice)
	_button("menu","返回主界面",Rect2(825,645,360,60),leave_to_menu,p)
	return true

func show_pause() -> void:
	_pause_return = mode
	mode = "pause"
	var p = _panel("暂歇")
	_button("resume","继续探索",Rect2(485,310,470,55),_resume_dialog,p)
	if _pause_return == "explore":
		if not _authority_mode(): _button("collection","显现权柄",Rect2(485,385,470,55),func(): show_loadout(true),p)
		_button("journal","探索手札",Rect2(485,460,470,55),show_journal,p)
		if not _authority_mode() and run.pending_upgrade: _button("pending_upgrade","领取精英升级",Rect2(485,535,470,50),func(): _show_upgrade("elite",0),p)
	_button("menu","返回主界面",Rect2(485,625,470,55),leave_to_menu,p)

func show_journal() -> void:
	mode = "journal"
	var text = "已证实\n"+"、".join(store.data.get("evidence",[]))+"\n\n转述 / 待核对\n《观测环刻录》：桥先断，钟后响。\n《暮笙手记》：钟先响，众人想看完星升。\n\n观察时间切片不会改写救援的失败。"
	var p = _panel("探索手札",text)
	_button("continue","继续探索",Rect2(865,655,360,55),_resume_dialog,p)

func leave_to_menu() -> void:
	if mode == "pause": _resume_dialog()
	if mode not in ["battle","defeat","opening"] and not (_pause_return == "battle" and mode == "pause"): _save_checkpoint()
	suspend_session()
	return_to_menu.emit()

func suspend_session() -> void:
	if suspended: return
	suspended = true
	hud.visible = false
	if world != null:
		world.set_paused(true)
		world.visible = false
	if spatial != null:
		spatial.set_paused(true)
		spatial.visible = false
	if is_instance_valid(opening): opening.set_process(false)
	get_viewport().canvas_transform = Transform2D.IDENTITY

func resume_session() -> void:
	suspended = false
	hud.visible = true
	if world != null:
		world.visible = true
		world.set_paused(not mode in ["explore","battle"])
	if spatial != null:
		spatial.visible = true
		if mode == "battle": spatial.set_paused(false)
	if is_instance_valid(opening): opening.set_process(true)

func presentation_state() -> Dictionary:
	return {"mode":mode,"run":run.duplicate(true),"suspended":suspended,"deck_open":deck_open,"world":world.presentation_state() if world != null else {},"combat":combat.get_snapshot() if mode == "battle" else {},"last_error":last_error}

func _build_authority_hud() -> void:
	if is_instance_valid(battle_hud):
		canvas.remove_child(battle_hud)
		battle_hud.queue_free()
	battle_hud = Control.new()
	battle_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(battle_hud)
	card_buttons.clear()
	hp_bar = _bar(Rect2(300,854,490,8),battle_hud)
	hp_bar.max_value = 50
	hp_bar.value = run.get("hp",50)
	deck_open = false
	deck_scroll = ScrollContainer.new()
	deck_scroll.position = Vector2(300,700)
	deck_scroll.size = Vector2(490,135)
	deck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	deck_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	deck_scroll.visible = false
	battle_hud.add_child(deck_scroll)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",12)
	deck_scroll.add_child(grid)
	var catalog = {}
	for card in Temporal.card_catalog(): catalog[card.id] = card
	if run.get("authority_unlocked",false):
		for entity in store.get_authority_loadout():
			var kind = str(entity.get("type",""))
			if not catalog.has(kind): continue
			var face = TimeCard.new()
			grid.add_child(face)
			face.configure(catalog[kind])
			face.card_clicked.connect(choose_card)
			card_buttons[kind] = face
	authority_button = _button("authority","",Rect2(182,715,96,96),toggle_deck,battle_hud)
	var clock = SilverClock.new()
	clock.position = Vector2(7,7)
	clock.size = Vector2(82,82)
	authority_button.add_child(clock)
	authority_button.visible = bool(run.get("authority_unlocked",false))
	_update_hud()

func _repair_device() -> bool:
	if not _authority_mode() or run.get("authority_unlocked",false) or int(run.get("authority_tutorial_step",0)) < 2: return false
	var candidate = run.duplicate(true)
	_position_into(candidate)
	candidate.authority_tutorial_step = 3
	candidate.authority_unlocked = true
	if not "stalled_device" in candidate.interactions: candidate.interactions.append("stalled_device")
	if not store.unlock_time_authority(candidate,candidate):
		last_error = store.last_error
		if not is_instance_valid(save_notice): save_notice = _label("装置尚未修复，请重试。",Rect2(350,105,800,65),canvas,20)
		return false
	run = store.data.exploration_run.duplicate(true)
	checkpoint = store.data.exploration_checkpoint.duplicate(true)
	last_error = ""
	if is_instance_valid(save_notice): save_notice.queue_free(); save_notice = null
	world.apply_run(run)
	tutorial.configure(3)
	_build_hud()
	return true

class SilverClock extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var center = size * 0.5
		var radius = minf(size.x,size.y) * 0.43
		var silver = Color("e6edf4")
		draw_circle(center,radius,Color("101e30"))
		draw_arc(center,radius,0,TAU,64,silver,1.5,true)
		for index in 12:
			var direction = Vector2.from_angle(index * TAU / 12.0 - PI / 2.0)
			draw_line(center+direction*radius*0.78,center+direction*radius*0.9,silver,1,true)
		draw_line(center,center+Vector2(0,-radius*0.65),silver,2,true)
		draw_line(center,center+Vector2(radius*0.45,radius*0.2),silver,2,true)
		draw_circle(center,2,silver)
