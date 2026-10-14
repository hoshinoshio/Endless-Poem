extends Control
signal card_clicked(card_id: String)
const FONT = preload("res://assets/fonts/SourceHanSansSC-Regular.otf")

var card: Dictionary = {}
var selected: bool = false

func _init() -> void:
	custom_minimum_size = Vector2(148, 116)
	mouse_filter = Control.MOUSE_FILTER_STOP

func configure(value: Dictionary) -> void:
	card = value.duplicate(true)
	tooltip_text = str(card.get("description", ""))
	queue_redraw()

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		card_clicked.emit(str(card.get("id", "")))
		accept_event()

func _draw() -> void:
	var ink := Color("e6edf4")
	var accent := Color("8fd4f1") if selected else ink
	draw_style_box(_panel(accent), Rect2(Vector2.ZERO, size))
	var center := Vector2(size.x * 0.5, 40)
	draw_arc(center, 22, 0, TAU, 48, accent, 1.2, true)
	for index in range(12):
		var direction := Vector2.from_angle(index * TAU / 12.0 - PI / 2.0)
		draw_line(center + direction * 18, center + direction * 21, ink, 1, true)
	var mode := str(card.get("id", ""))
	if mode == "stop":
		draw_line(center + Vector2(-5, -8), center + Vector2(-5, 8), accent, 2, true)
		draw_line(center + Vector2(5, -8), center + Vector2(5, 8), accent, 2, true)
	else:
		var direction := -1.0 if mode == "reverse" else 1.0
		draw_line(center, center + Vector2(0, -13), accent, 1.5, true)
		draw_line(center, center + Vector2(12 * direction, 6), accent, 1.5, true)
		draw_polyline(PackedVector2Array([center + Vector2(7 * direction, -4), center + Vector2(14 * direction, 0), center + Vector2(7 * direction, 4)]), accent, 1.5, true)
	var font := FONT
	var title := str(card.get("title", ""))
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(font, Vector2((size.x - width) * 0.5, 88), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)

func _panel(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.045, 0.065, 0.105, 0.94)
	box.border_color = color
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(4)
	return box
