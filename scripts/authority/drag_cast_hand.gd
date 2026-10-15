extends Control
const Card = preload("res://scripts/authority/time_card.gd")
const Config = preload("res://scripts/authority/time_card_config.gd")
var session
var faces: Dictionary = {}
var homes: Dictionary = {}
var pending := ""
var press_point := Vector2.ZERO
var pointer := Vector2.ZERO
var ghost: Control
var focus: ColorRect
var hovered := ""
var reaction := ""
var reaction_remaining := 0.0
const ICONS = {"敌对": "怒", "警惕": "疑", "中立": "平", "友善": "喜", "信赖": "心"}

class Highlights extends Control:
	var hand
	func _draw() -> void: hand.draw_targets(self)

class Cooldown extends Control:
	var ratio := 0.0
	var seconds := 0.0
	func _draw() -> void:
		if ratio <= 0.0: return
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.06, 0.45))
		var points := PackedVector2Array([size * 0.5])
		for i in range(65): points.append(size * 0.5 + Vector2.from_angle(-PI / 2 + TAU * ratio * i / 64.0) * size.length())
		draw_colored_polygon(points, Color(0.02, 0.04, 0.08, 0.6))
		draw_string(Card.FONT, Vector2(0, size.y * 0.6), "%.1f" % seconds, HORIZONTAL_ALIGNMENT_CENTER, size.x, 23, Color("f0dba8"))

func configure(owner_session) -> void:
	session = owner_session
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus = ColorRect.new()
	focus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/authority/drag_focus.gdshader")
	focus.material = mat
	focus.visible = false
	add_child(focus)
	var highlights := Highlights.new()
	highlights.hand = self
	highlights.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(highlights)
	for config in session.world.temporal.card_catalog():
		var face := Card.new()
		face.compact = true
		face.card_scale = 0.55
		face.configure(config)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.tooltip_text = ""
		add_child(face)
		faces[config.id] = face
		var mask := Cooldown.new()
		mask.name = "Cooldown"
		mask.clip_contents = true
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(mask)
	_layout()
func _layout() -> void:
	var i := 0
	for id in faces:
		homes[id] = Vector2(size.x * 0.5 - 218.25 + i * 149.5, size.y - 145)
		faces[id].position = homes[id]
		i += 1
func card_at(point: Vector2) -> String:
	if not hovered.is_empty() and faces[hovered].get_global_rect().has_point(point): return hovered
	for id in faces:
		if faces[id].get_global_rect().has_point(point): return id
	return ""
func _input(event: InputEvent) -> void:
	if session.suspended or session.mode != "explore": return
	if event is InputEventMouseMotion:
		pointer = event.position
		if not pending.is_empty() and session.drag_card.is_empty() and pointer.distance_to(press_point) > 6.0:
			if session.begin_drag(pending):
				_make_ghost(pending)
			pending = ""
	if event is InputEventMouseButton:
		pointer = event.position
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and (not session.drag_card.is_empty() or not pending.is_empty()):
			session.cancel_drag()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var id := card_at(pointer)
				if not id.is_empty():
					if session.world.temporal.can_cast(id):
						pending = id
						press_point = pointer
					get_viewport().set_input_as_handled()
			elif not session.drag_card.is_empty():
				session.release_drag(pointer)
				get_viewport().set_input_as_handled()
			else: pending = ""
func _make_ghost(id: String) -> void:
	if is_instance_valid(ghost): ghost.queue_free()
	ghost = Card.new()
	ghost.compact = true
	ghost.card_scale = 0.32
	ghost.configure(faces[id].card)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.position = pointer + Vector2(18, 18)
	add_child(ghost)
func finish(id: String, success: bool) -> void:
	pending = ""
	hovered = ""
	focus.hide()
	if not is_instance_valid(ghost): return
	if success:
		ghost.queue_free()
		ghost = null
	else:
		var returning_card := ghost
		var tween := create_tween()
		tween.tween_property(returning_card, "position", homes.get(id, returning_card.position), 0.16).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(returning_card.queue_free)
		ghost = null
func _process(delta: float) -> void:
	if session == null: return
	var active: bool = session.mode == "explore" and not session.suspended
	visible = active and session.run.get("authority_unlocked", false)
	if not visible: return
	if Vector2(homes.get("stop", Vector2.ZERO)).y != size.y - 145: _layout()
	var dragging: bool = not session.drag_card.is_empty()
	focus.visible = dragging
	pointer = get_viewport().get_mouse_position() if pending.is_empty() and not dragging else pointer
	hovered = "" if dragging else card_at(pointer)
	var near := Rect2(Vector2(size.x * 0.5 - 260, size.y - 220), Vector2(520, 220)).has_point(pointer) or not hovered.is_empty()
	var player_rect: Rect2 = session.world.temporal.get_presentation().targets.player.screen_rect
	var overlaps := player_rect.intersects(Rect2(Vector2(size.x * 0.5 - 220, size.y - 145), Vector2(440, 140)))
	for id in faces:
		var face: Control = faces[id]
		var hover: bool = id == hovered and not dragging
		var target_scale := 1.0 if hover else 0.55
		face.card_scale = move_toward(face.card_scale, target_scale, delta * 4.5)
		face.compact = not hover and face.card_scale <= 0.551
		var target: Vector2 = homes[id]
		if hover:
			target.x = clampf(target.x - (250.0 - 137.5) * 0.5, 4.0, maxf(4.0, size.x - 254.0))
			target.y = maxf(4.0, size.y - 365.0)
		face.position = face.position.move_toward(target, delta * 2400.0)
		face.z_index = 2 if hover else 0
		face.modulate.a = 0.3 if session.drag_card == id else (0.45 if overlaps and not near else 1.0)
		var mask = face.get_node("Cooldown")
		mask.size = face.size
		mask.seconds = session.world.temporal.cooldowns[id]
		mask.ratio = mask.seconds / Config.CARDS[id].cooldown
		mask.queue_redraw()
	if dragging:
		if not is_instance_valid(ghost): _make_ghost(session.drag_card)
		ghost.position = pointer + Vector2(18, 18)
		ghost.card_scale = 0.55 if Rect2(Vector2(size.x * 0.5 - 220, size.y - 145), Vector2(440,145)).has_point(pointer) else 0.32
	reaction_remaining = maxf(0.0, reaction_remaining - delta)
	for child in get_children():
		if child is Highlights: child.queue_redraw()
func show_reaction(tier: String) -> void:
	reaction = tier
	reaction_remaining = 2.0
func draw_targets(surface: Control) -> void:
	var targets: Dictionary = session.world.temporal.get_presentation().targets
	if not session.drag_card.is_empty():
		var picked: String = session.world.temporal.target_at_point(pointer)
		for id in targets:
			var rect: Rect2 = targets[id].screen_rect
			if not rect.has_area(): continue
			var chosen: bool = id == picked
			var color := Color("f4d18c") if chosen else Color(0.57, 0.84, 0.93, 0.6)
			surface.draw_rect(rect.grow(5), Color(color, 0.1), true)
			surface.draw_rect(rect.grow(5), color, false, 3.0 if chosen else 1.0)
		if not picked.is_empty():
			var target: Dictionary = targets[picked]
			var text: String = Config.CATEGORIES[target.category] + " · " + str(target.label)
			var at := Vector2(clampf(pointer.x + 24, 8, size.x - 340), clampf(pointer.y - 75, 8, size.y - 85))
			surface.draw_style_box(_label_box(), Rect2(at, Vector2(325, 65)))
			surface.draw_string(Card.FONT, at + Vector2(14, 26), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("f0dba8"))
			surface.draw_string(Card.FONT, at + Vector2(14, 51), Config.CARDS[session.drag_card].preview, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	if reaction_remaining > 0.0:
		var rect: Rect2 = targets.musheng.screen_rect
		var at := rect.position + Vector2(rect.size.x / 2.0 - 125, -85)
		surface.draw_style_box(_label_box(), Rect2(at, Vector2(250, 70)))
		surface.draw_circle(at + Vector2(28, 24), 18, Color("806949"))
		surface.draw_string(Card.FONT, at + Vector2(18, 31), ICONS.get(reaction, "平"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		surface.draw_string(Card.FONT, at + Vector2(56, 31), reaction, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		var line := "……你做了什么？" if reaction in ["敌对", "警惕"] else "谢谢，也许能聊聊。"
		surface.draw_string(Card.FONT, at + Vector2(12, 59), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
func _label_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.05, 0.09, 0.94)
	box.border_color = Color("c5a66c")
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	return box
