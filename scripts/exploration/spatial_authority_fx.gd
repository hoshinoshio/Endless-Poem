extends "res://scripts/world/time_authority_fx.gd"
## Retains approved dial and multi-stream drawing in unrestricted world coordinates.
func set_source(point: Vector2, _visual_height: float) -> void:
	source = point.round()
	radius = 150.0
	queue_redraw()

func cast(target_id: String, destination: Vector2) -> void:
	glow = 1.0
	pulses.append({"origin":source,"age":0.0})
	for i in STREAM_COUNT:
		var direction := Vector2.from_angle(float(i)*TAU/STREAM_COUNT-PI/2)
		var origin := source+direction*126
		beams.append({"target":target_id,"source":source,"origin":origin,"launch_direction":direction,"control":origin+direction*72,"arrival":destination+Vector2(-100,(i-3.5)*15),"end":destination,"age":0.0,"lane":i,"delay":i*0.008,"travel":0.48-i*0.008,"history":[]})

func path_point(beam: Dictionary, progress: float) -> Vector2:
	var t := clampf(progress,0,1)
	var launch: Vector2 = beam.origin+beam.launch_direction*22
	if t <= 0.18:
		return beam.origin.lerp(launch,t/0.18)
	t = (t-0.18)/0.82
	var inverse := 1.0-t
	return launch*pow(inverse,3)+(launch+beam.launch_direction*46)*3*inverse*inverse*t+beam.arrival*3*inverse*t*t+beam.end*pow(t,3)
