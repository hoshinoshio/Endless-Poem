extends Node2D
## Local ornament motion aligned to the approved 1440 by 900 courtyard.
var battle_elapsed := 0.0
func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	battle_elapsed += delta
	queue_redraw()
func presentation_state() -> Dictionary:
	return {"battle_elapsed":battle_elapsed,"astrolabe_angle":battle_elapsed * 0.07,"star_alpha":0.18 + 0.12*sin(battle_elapsed*1.3)}
func _draw() -> void:
	# Existing upper suspended instrument and right instrument; sparse moving ticks.
	for instrument in [{"center":Vector2(622,103),"extent":Vector2(67,41)}, {"center":Vector2(1103,271),"extent":Vector2(96,26)}]:
		for i in 8:
			var angle := float(i)*TAU/8.0+battle_elapsed*0.07
			var direction := Vector2.from_angle(angle)
			var point: Vector2 = instrument.center + direction * instrument.extent
			draw_line(point.round(),(point + direction*3.0).round(),Color(.86,.63,.33,.48),1.0,false)
	for i in 11:
		var point := Vector2(322 + i*72, 43 + (i*31)%139)
		var alpha := .10 + .16*maxf(0.0,sin(battle_elapsed*.8+i*1.7))
		draw_rect(Rect2(point,Vector2(2,2)),Color(.65,.79,1.0,alpha))
