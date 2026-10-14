extends Control
var phase = 0.0
func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(delta):
	phase += delta * 0.12
	queue_redraw()
func _draw():
	var center = size / 2
	var radius = minf(size.x, size.y) * 0.44
	draw_circle(center + Vector2(0,2), radius + 2, Color("081420"))
	draw_circle(center, radius, Color("152e3c"))
	draw_arc(center, radius, 0, TAU, 64, Color("d5b173"), 2)
	draw_arc(center, radius * 0.87, 0, TAU, 64, Color("695a42"), 1)
	draw_arc(center, radius * 0.62, phase, phase + PI * 1.6, 48, Color("70cfd3"), 1)
	for i in range(48):
		var angle = float(i) * TAU / 48 - PI / 2 + phase * 0.25
		var direction = Vector2(cos(angle), sin(angle))
		draw_line(center + direction * radius * (0.74 if i % 4 == 0 else 0.83), center + direction * radius * 0.93, Color("c5a46f"), 2 if i % 4 == 0 else 1)
	draw_line(center, center + Vector2(sin(phase), -cos(phase)) * radius * 0.59, Color("b4f1ee"), 3)
	draw_line(center, center + Vector2(cos(phase * 0.35), sin(phase * 0.35)) * radius * 0.43, Color("edcd92"), 2)
	draw_circle(center, 4, Color("f1d194"))
	draw_circle(center, 2, Color("e6ffff"))
