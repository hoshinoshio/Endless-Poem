extends Control

var mode = "intro"
var phase = 0
var muted = false
var pulse = 0.0
var broken = false

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw():
	# Functional placeholder only. Final scenery and palette await the user's artwork.
	draw_rect(Rect2(0, 0, 1440, 900), Color("202020"))
	draw_rect(Rect2(0, 0, 1440, 80), Color("171717"))
	draw_line(Vector2(34, 79), Vector2(1406, 79), Color("666666"), 1)
