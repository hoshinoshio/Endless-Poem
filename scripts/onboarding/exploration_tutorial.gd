extends Control
signal step_changed(step: int)
signal completed
const FONT = preload("res://assets/msyh.ttc")
const EVENTS = ["walked", "jump_landed", "investigated", "fork_completed"]
const HINTS = ["前方的引路灯熄灭了。", "低台挡住了通路。", "灯台似乎留有痕迹。", "沿岔路探索，找到回归的道路"]
var _step = 0
var _hint: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint = Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint.position = Vector2(-330, 45)
	_hint.size = Vector2(660, 50)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_override("font", FONT)
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", Color("e4ebf4"))
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_refresh()

func configure(step: int) -> void:
	_step = clampi(step, 0, EVENTS.size())
	_refresh()

func observe(event: String, _data: Dictionary = {}) -> void:
	if _step >= EVENTS.size() or event != EVENTS[_step]: return
	_step += 1
	_refresh()
	step_changed.emit(_step)
	if _step == EVENTS.size(): completed.emit()

func _refresh() -> void:
	visible = _step < EVENTS.size()
	if is_instance_valid(_hint): _hint.text = HINTS[_step] if visible else ""

func presentation_state() -> Dictionary:
	return {"step": _step, "complete": _step == EVENTS.size(), "hint": HINTS[_step] if _step < EVENTS.size() else ""}

