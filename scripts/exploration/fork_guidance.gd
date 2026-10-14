extends Control
## Contextual wayfinding only; the world remains responsible for route selection.
const NARRATION := "前面的路分开了。往上走，也许能看得更远；沿着下面走，说不定会有别的发现。慢慢来，不必急着决定。想回头看看另一条路，随时都可以。"
const FONT = preload("res://assets/fonts/SourceHanSansSC-Regular.otf")
var hint: Panel
var up_text: Label
var down_text: Label
var narration: Panel
var narration_text: Label
var narration_remaining := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint = _panel(Vector2(190,86))
	up_text = _label("",Vector2(13,8),Vector2(164,31),hint,20)
	down_text = _label("",Vector2(13,46),Vector2(164,31),hint,20)
	narration = _panel(Vector2(880,122))
	narration.position = Vector2(280,50)
	narration_text = _label(NARRATION,Vector2(24,17),Vector2(832,90),narration,22)
	narration_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narration_text.add_theme_constant_override("line_spacing",7)
	hint.hide()
	narration.hide()

func _panel(dimensions: Vector2) -> Panel:
	var node := Panel.new()
	node.size = dimensions
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.025,0.045,0.072,0.82)
	box.border_color = Color(0.72,0.80,0.89,0.65)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	node.add_theme_stylebox_override("panel",box)
	add_child(node)
	return node

func _label(text: String, origin: Vector2, dimensions: Vector2, parent: Control, font_size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.position = origin
	node.size = dimensions
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_override("font",FONT)
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",Color("e3edf6"))
	parent.add_child(node)
	return node

func begin_narration() -> void:
	narration_remaining = 12.0
	narration.modulate.a = 0.0
	narration.show()

func advance(delta: float, context: Dictionary, screen_position: Vector2, active: bool) -> void:
	visible = active
	if not active: return
	hint.visible = bool(context.get("visible",false))
	if hint.visible:
		hint.position = Vector2(clampf(screen_position.x+55,20,1230),clampf(screen_position.y-255,200,580))
		up_text.text = "W  ↑  " + str(context.get("up_label","上行"))
		down_text.text = "S  ↓  " + str(context.get("down_label","下行"))
		up_text.visible = not str(context.get("up_label","上行")).is_empty()
		down_text.visible = not str(context.get("down_label","下行")).is_empty()
	if narration_remaining > 0.0:
		narration_remaining = maxf(0.0,narration_remaining-delta)
		narration.modulate.a = minf(clampf((12.0-narration_remaining)/0.45,0,1),clampf(narration_remaining/0.7,0,1))
		narration.visible = narration_remaining > 0.0

func presentation_state() -> Dictionary:
	return {"visible":visible,"hint_visible":hint.visible and visible,"narration_visible":narration.visible and visible,"narration":narration_text.text,"remaining":narration_remaining,"up":up_text.text,"down":down_text.text}
