extends Control
signal step_changed(step: int)
const FONT = preload("res://assets/msyh.ttc")
const HINTS = ["引路灯熄灭了。前方的装置也停摆了。", "停摆装置位于上方的低台。", "装置的齿轮卡住了。"]
var _step = 0
var _hint: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint = Label.new()
	_hint.position = Vector2(350,45)
	_hint.size = Vector2(740,50)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_override("font",FONT)
	_hint.add_theme_font_size_override("font_size",24)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_refresh()

func configure(step: int) -> void:
	_step = clampi(step,0,3)
	_refresh()

func observe(event: String, _data: Dictionary = {}) -> void:
	if (_step == 0 and event == "walked") or (_step == 1 and event == "jump_landed"):
		_step += 1
		_refresh()
		step_changed.emit(_step)

func _refresh() -> void:
	visible = _step < 3
	if is_instance_valid(_hint): _hint.text = HINTS[_step] if visible else ""

func presentation_state() -> Dictionary:
	return {"step":_step,"complete":_step == 3,"hint":HINTS[_step] if _step < 3 else ""}
