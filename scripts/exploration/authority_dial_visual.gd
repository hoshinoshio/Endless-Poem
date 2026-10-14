extends Node2D
## Caller-owned presentation: no independent clock or simulation changes.
var source := Vector2.ZERO
var radius := 100.0
var intensity := 0.0
var phase := 0.0

## Origin is player.casting_presentation().origin in this node's coordinates.
func configure_presentation(origin: Vector2, height: float, strength: float, local_phase: float) -> void:
	source = origin.round()
	radius = clampf(height * 0.82, 88.0, 110.0)
	intensity = clampf(strength, 0.0, 1.0)
	phase = local_phase
	visible = intensity > 0.001
	queue_redraw()

func presentation_state() -> Dictionary:
	return {"visible":visible,"intensity":intensity,"radius":radius,"source":source,"phase":phase,"tickcount":60,"hour_marks":12,"hands":3}

func _draw() -> void:
	if intensity <= 0.001:
		return
	var ivory := Color(0.94, 0.98, 1.0, intensity * 0.96)
	var cyan := Color(0.39, 0.88, 1.0, intensity * 0.82)
	var halo := Color(0.30, 0.77, 1.0, intensity * 0.14)
	# A narrow outline echo keeps the face legible without filling the playfield.
	draw_arc(source, radius, 0.0, TAU, 120, halo, 6.0, false)
	draw_arc(source, radius, 0.0, TAU, 120, cyan, 2.0, false)
	draw_arc(source, radius * 0.91, 0.0, TAU, 120, cyan, 1.0, false)
	for index in 60:
		var direction := Vector2.from_angle(float(index) * TAU / 60.0 - PI / 2.0)
		var major := index % 5 == 0
		var outer := source + direction * radius * 0.86
		var inner := source + direction * radius * (0.70 if major else 0.80)
		draw_line(inner.round(), outer.round(), ivory if major else cyan, 3.0 if major else 1.0, false)
	# Separate broad hour/minute hands and a fine cyan sweep hand.
	_draw_hand(-PI / 2.0 + 0.72 + phase * 0.018, radius * 0.46, 4.0, ivory)
	_draw_hand(-PI / 2.0 + 2.30 + phase * 0.075, radius * 0.68, 2.5, ivory)
	var sweep := Vector2.from_angle(-PI / 2.0 + phase * 0.55)
	draw_line((source - sweep * radius * 0.16).round(), (source + sweep * radius * 0.76).round(), cyan, 1.0, false)
	draw_circle(source, 4.0, ivory)
	draw_circle(source, 1.5, cyan)

func _draw_hand(angle: float, length: float, width: float, color: Color) -> void:
	var direction := Vector2.from_angle(angle)
	var side := direction.orthogonal()
	var tip := source + direction * length
	draw_line(source, tip, Color(0.30, 0.77, 1.0, intensity * 0.14), width * 2.5, false)
	draw_colored_polygon(PackedVector2Array([
		(source - direction * 7.0).round(),
		(source + side * width).round(),
		tip.round(),
		(source - side * width).round()
	]), color)
