extends Control
## Sparse stars brighten in place. Architecture and portrait never move.
var elapsed := 0.0
var stars: Array[Vector3] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 738291
	for i in range(38):
		# The upper sky remains clear of the lower-left action list.
		stars.append(Vector3(rng.randf_range(480, 1390), rng.randf_range(20, 360), rng.randf_range(0, TAU)))

func _draw() -> void:
	for star in stars:
		var brightness := pow(maxf(0.0, sin(elapsed * 0.62 + star.z)), 5.0)
		var point := Vector2(star.x, star.y)
		draw_circle(point, 1.0, Color(0.71, 0.85, 1.0, 0.08 + brightness * 0.3))
		if brightness > 0.65:
			var color := Color(0.64, 0.82, 1.0, (brightness - 0.65) * 0.65)
			draw_line(point - Vector2(3, 0), point + Vector2(3, 0), color, 1.0, true)
			draw_line(point - Vector2(0, 3), point + Vector2(0, 3), color, 1.0, true)
