extends Button
## Text-only celestial menu action with live pointer and keyboard feedback.
var featured := false
var highlight := 0.0
var press_amount := 0.0
var _pointer_inside := false

func _ready() -> void:
	highlight = 0.3 if featured else 0.0
	mouse_entered.connect(func(): _pointer_inside = true)
	mouse_exited.connect(func(): _pointer_inside = false)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 63.0
		empty.content_margin_bottom = 8.0
		add_theme_stylebox_override(state, empty)

func _process(delta: float) -> void:
	var target := 1.0 if not disabled and (_pointer_inside or has_focus()) else (0.3 if featured and not disabled else 0.0)
	highlight = move_toward(highlight, target, delta * 5.5)
	press_amount = move_toward(press_amount, 1.0 if is_pressed() else 0.0, delta * 12.0)
	queue_redraw()

func _draw() -> void:
	var opacity := 0.25 if disabled else 0.62 + highlight * 0.38
	var color := Color(0.77, 0.86, 1.0, opacity)
	var center := Vector2(25.0, 29.0 + press_amount * 2.0)
	var radius := 11.0 + highlight * 8.0
	if highlight > 0.01:
		for i in range(4, 0, -1):
			draw_circle(center, radius + i * 4.0, Color(0.35, 0.62, 1.0, highlight * 0.016))
		draw_arc(center, radius + 5.0, 0, TAU, 48, Color(0.78, 0.89, 1.0, highlight * 0.65), 1.0, true)
	var points := PackedVector2Array()
	for i in range(8):
		var angle := -PI / 2.0 + float(i) * PI / 4.0
		points.append(center + Vector2(cos(angle), sin(angle)) * (radius if i % 2 == 0 else radius * 0.24))
	draw_colored_polygon(points, Color(0.87, 0.93, 1.0, opacity))
	var line_y := size.y - 7.0 + press_amount * 2.0
	draw_line(Vector2(57, line_y), Vector2(size.x - 19, line_y), color, 1.0 + highlight, true)
	var tip := Vector2(size.x - 15, line_y)
	var diamond := PackedVector2Array([tip + Vector2(0, -5), tip + Vector2(5, 0), tip + Vector2(0, 5), tip + Vector2(-5, 0), tip + Vector2(0, -5)])
	draw_polyline(diamond, color, 1.0, true)
	if highlight > 0.01:
		draw_line(Vector2(57, line_y), Vector2(size.x - 19, line_y), Color(0.47, 0.71, 1.0, highlight * 0.16), 7.0, true)


