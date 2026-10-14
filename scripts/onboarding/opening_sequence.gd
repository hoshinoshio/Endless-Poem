extends Control
signal accepted
const FONT = preload("res://assets/msyh.ttc")
const FIRST = "沉睡的神明即将苏醒"
const SECOND = "世界在崩坏"
const SURVIVOR = "你是最终的幸存者、亦是被寄以希望的无暇之人"
const QUESTION = "你是否愿意拯救这个世界？"
var buttons: Dictionary = {}
var _canvas: Control
var _first: Label
var _second: Label
var _survivor: Label
var _question: Label
var _refusal: Label
var _pieces: Array = []
var _time = 0.0
var _phase = "awakening"
var _refusals = 0
var _lock_until = 0.0
var _accepted = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var black = ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	_canvas = Control.new()
	_canvas.size = Vector2(1440, 900)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_first = _label(FIRST, 340, 45)
	_second = _label(SECOND, 435, 45)
	_survivor = _label(SURVIVOR, 407, 38)
	_question = _label(QUESTION, 340, 44)
	_refusal = _label("你真的想拒绝吗？", 340, 42)
	_button("yes", "是", Rect2(485, 480, 200, 65), _accept)
	_button("no", "否", Rect2(755, 480, 200, 65), _show_refusal)
	_button("accept_refusal", "好吧，那我别无选择", Rect2(350, 480, 350, 65), _accept)
	_button("refuse_again", "但是，我拒绝", Rect2(740, 480, 350, 65), _refuse_again)
	resized.connect(_layout)
	_layout()
	_update_presentation()

func _label(text: String, y: float, font_size: int) -> Label:
	var label = Label.new()
	label.text = text
	label.position = Vector2(100, y)
	label.size = Vector2(1240, 80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e3e8ef"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(label)
	return label

func _button(key: String, text: String, rect: Rect2, callback: Callable) -> void:
	var button = Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", Color("dae3ef"))
	for mode in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.25, 0.32, 0.13 if mode in ["hover", "focus"] else 0.0)
		style.border_width_bottom = 1
		style.border_color = Color(0.8, 0.86, 0.95, 0.7 if mode in ["hover", "focus"] else 0.27)
		button.add_theme_stylebox_override(mode, style)
	button.pressed.connect(func():
		if button.visible and not button.disabled and _time >= _lock_until and not _accepted:
			callback.call())
	_canvas.add_child(button)
	buttons[key] = button

func _layout() -> void:
	if not is_instance_valid(_canvas): return
	var factor = minf(size.x / 1440.0, size.y / 900.0)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (size - Vector2(1440, 900) * factor) * 0.5

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if delta <= 0.0 or _accepted: return
	_time += delta
	if _phase not in ["question", "refusal"]:
		if _time >= 12.5:
			_phase = "question"
			_lock_until = _time + 0.35
		elif _time >= 7.0: _phase = "survivor"
		elif _time >= 5.0:
			_phase = "fracture"
			if _pieces.is_empty():
				_fracture_text(FIRST, 340)
				_fracture_text(SECOND, 435)
		elif _time >= 2.2: _phase = "collapse"
	_update_presentation()

func _fracture_text(text: String, y: float) -> void:
	var glyph_width = 45.0
	var left = (1440.0 - text.length() * glyph_width) * 0.5
	for index in range(text.length()):
		for slice in range(3):
			var clip = Control.new()
			clip.clip_contents = true
			clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			clip.size = Vector2(glyph_width, 20)
			var origin = Vector2(left + index * glyph_width, y + 11 + slice * 20)
			clip.position = origin
			var glyph = Label.new()
			glyph.text = text[index]
			glyph.position = Vector2(0, -slice * 20)
			glyph.add_theme_font_override("font", FONT)
			glyph.add_theme_font_size_override("font_size", 45)
			glyph.add_theme_color_override("font_color", Color("e3e8ef"))
			clip.add_child(glyph)
			_canvas.add_child(clip)
			_pieces.append({"node": clip, "origin": origin, "index": index, "slice": slice})

func _update_presentation() -> void:
	_first.visible = _phase in ["awakening", "collapse"]
	_second.visible = _phase == "collapse"
	_first.modulate.a = clampf(_time / 1.3, 0, 1)
	_second.modulate.a = clampf((_time - 2.2) / 1.3, 0, 1)
	for piece in _pieces:
		var node: Control = piece.node
		node.visible = _phase == "fracture"
		var progress = clampf((_time - 5.0) / 2.0, 0, 1)
		var direction = -1.0 if (piece.index + piece.slice) % 2 == 0 else 1.0
		node.position = piece.origin + Vector2(direction * progress * (22 + piece.slice * 24), progress * progress * (35 + piece.index * 7))
		node.scale.x = 1.0 + direction * progress * 0.28
		node.modulate.a = 1.0 - progress
	_survivor.visible = _phase == "survivor"
	_survivor.modulate.a = minf(clampf((_time - 7.0) / 1.2, 0, 1), clampf((12.5 - _time) / 1.3, 0, 1))
	_question.visible = _phase == "question"
	_question.modulate.a = clampf((_time - 12.5) / 1.1, 0, 1)
	_refusal.visible = _phase == "refusal"
	buttons.yes.visible = _phase == "question"
	buttons.no.visible = _phase == "question"
	buttons.accept_refusal.visible = _phase == "refusal"
	buttons.refuse_again.visible = _phase == "refusal" and _refusals < 3
	buttons.accept_refusal.position.x = 545 if _refusals >= 3 else 350
	for button in buttons.values():
		button.disabled = _accepted or _time < _lock_until

func _show_refusal() -> void:
	_phase = "refusal"
	_lock_until = _time + 0.35
	_update_presentation()

func _refuse_again() -> void:
	_refusals += 1
	_lock_until = _time + 0.35
	_update_presentation()

func _accept() -> void:
	if _accepted: return
	_accepted = true
	_phase = "accepted"
	_update_presentation()
	accepted.emit()

func presentation_state() -> Dictionary:
	var visible_buttons: Array = []
	for key in buttons:
		if buttons[key].visible: visible_buttons.append(key)
	return {"phase": _phase, "elapsed": _time, "refusal_count": _refusals, "accepted": _accepted, "visible_buttons": visible_buttons, "fragment_count": _pieces.size(), "texts": [FIRST, SECOND, SURVIVOR, QUESTION], "interaction_locked": _time < _lock_until}
