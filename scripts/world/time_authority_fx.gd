extends Node2D
## Presentation clock only; model damage timing remains authoritative.
const STREAM_COUNT := 8
const TRAIL_LIFE := 0.16
var source := Vector2.ZERO
var battle_elapsed := 0.0
var glow := 0.0
var beams: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var pulses: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var radius := 150.0

func set_source(point: Vector2, _visual_height: float) -> void:
	source = Vector2(point.x, minf(point.y, 416.0)).round()
	radius = 150.0
	queue_redraw()

func cast(target_id: String, destination: Vector2) -> void:
	glow = 1.0
	pulses.append({"origin":source,"age":0.0})
	if target_id != "" and target_id != "player":
		for i in STREAM_COUNT:
			var direction := Vector2.from_angle(float(i) * TAU / STREAM_COUNT - PI / 2.0)
			var origin := source + direction * 126.0
			var control := origin + direction * 72.0
			# The downward tangent remains outward, then turns above the deck.
			control.y = minf(control.y, 570.0)
			control.x = maxf(control.x, 24.0)
			var arrival := destination + Vector2(-165.0, (float(i) - 3.5) * 19.0)
			arrival.y = clampf(arrival.y, 110.0, 530.0)
			beams.append({"target":target_id,"source":source,"origin":origin,"launch_direction":direction,"control":control,"arrival":arrival,"end":destination.round(),"age":0.0,"lane":i,"delay":i * 0.008,"travel":0.36 + float(i % 3) * 0.02,"history":[]})
	queue_redraw()

func impact(_target_id: String, destination: Vector2) -> void:
	var arrival_delay := 0.0
	for beam in beams:
		if beam.target == _target_id:
			arrival_delay = maxf(arrival_delay, float(beam.delay) + float(beam.travel) - float(beam.age))
	impacts.append({"origin":destination.round(),"age":-arrival_delay})
	for i in 24:
		sparks.append({"origin":destination.round(),"age":0.0,"direction":Vector2.from_angle(float(i) * TAU / 24.0 + 0.22),"speed":55.0 + float(i % 5) * 25.0})
	queue_redraw()

func has_beam(target_id: String) -> bool:
	for beam in beams:
		if beam.target == target_id:
			return true
	return false

func path_point(beam: Dictionary, progress: float) -> Vector2:
	var t := clampf(progress, 0.0, 1.0)
	# A separate launch segment guarantees a visible outward stroke on every lane.
	var launch: Vector2 = beam.origin + beam.launch_direction * 22.0
	launch.x = maxf(launch.x, 24.0)
	launch.y = minf(launch.y, 566.0)
	if t <= 0.18:
		return beam.origin.lerp(launch, t / 0.18).round()
	t = (t - 0.18) / 0.82
	var inverse := 1.0 - t
	var control: Vector2 = launch + beam.launch_direction * 46.0
	control.x = maxf(control.x, 24.0)
	control.y = minf(control.y, 566.0)
	return (launch * pow(inverse,3) + control * 3.0 * inverse * inverse * t + beam.arrival * 3.0 * inverse * t * t + beam.end * pow(t,3)).round()

func trail_alpha(beam: Dictionary, point: Dictionary) -> float:
	return clampf(1.0 - (float(beam.age) - float(point.born)) / TRAIL_LIFE, 0.0, 1.0)

func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	battle_elapsed += delta
	glow = maxf(0.0, glow - delta * 1.5)
	for beam in beams:
		var previous := float(beam.age)
		beam.age += delta
		var sample_time := maxf(float(beam.delay), previous)
		while sample_time < minf(float(beam.age), float(beam.delay) + float(beam.travel)):
			beam.history.append({"point":path_point(beam,(sample_time - float(beam.delay)) / float(beam.travel)),"born":sample_time})
			sample_time += 0.009
		beam.history = beam.history.filter(func(point: Dictionary): return trail_alpha(beam, point) > 0.0)
	beams = beams.filter(func(beam: Dictionary): return beam.age < beam.delay + beam.travel + TRAIL_LIFE)
	for spark in sparks:
		spark.age += delta
	sparks = sparks.filter(func(spark: Dictionary): return spark.age < 0.48)
	for pulse in pulses:
		pulse.age += delta
	pulses = pulses.filter(func(pulse: Dictionary): return pulse.age < 0.65)
	for burst in impacts:
		burst.age += delta
	impacts = impacts.filter(func(burst: Dictionary): return burst.age < 0.48)
	queue_redraw()

func presentation_state() -> Dictionary:
	var streams: Array = []
	var targets: Array[String] = []
	for beam in beams:
		if not targets.has(beam.target):
			targets.append(beam.target)
		var progress := clampf((float(beam.age) - float(beam.delay)) / float(beam.travel), 0.0, 1.0)
		var alpha: Array = []
		for point in beam.history:
			alpha.append(trail_alpha(beam, point))
		streams.append({"progress":progress,"head":path_point(beam,progress),"tail_alpha":alpha,"history_count":beam.history.size(),"arrived":progress >= 1.0,"origin":beam.origin,"launch_direction":beam.launch_direction,"direction":beam.launch_direction,"lane":beam.lane,"control":beam.control,"arrival":beam.arrival,"end":beam.end})
	return {"source":source,"radius":radius,"beam_count":beams.size(),"targets":targets,"battle_elapsed":battle_elapsed,"glow":glow,"spark_count":sparks.size(),"streams":streams,"pulses":pulses.duplicate(true),"impacts":impacts.duplicate(true),"clock_projection":{"hour_marks":12,"minute_marks":60,"hands":3,"subdials":3,"phase":battle_elapsed,"opacity":0.38+glow*0.18}}

func _draw_clock_projection() -> void:
	# Translucent light mapping: no opaque dial plate or solid mechanical body.
	var bronze := Color(0.67,0.48,0.28,0.38+glow*0.18)
	var light := Color(0.35,0.87,1.0,0.38+glow*0.22)
	var ghost := Color(0.18,0.65,0.85,0.10+glow*0.08)
	for offset in [Vector2(-3,-2),Vector2(3,1)]:
		draw_arc(source+offset,144,0,TAU,120,ghost,2,false)
		draw_arc(source+offset,112,0,TAU,96,ghost,1,false)
	for ring in [148.0,143.0,133.0,116.0,110.0]:
		draw_arc(source,ring,0,TAU,120,bronze if ring>132 else light,2 if ring==143 else 1,false)
	# Fixed dial graduations remain readable while the inner mappings drift.
	for i in 60:
		var direction := Vector2.from_angle(float(i)*TAU/60-PI/2)
		var major := i%5==0
		draw_line(source+direction*(118 if major else 128),source+direction*139,light if major else bronze,3 if major else 1,false)
		if major:
			var tangent := direction.orthogonal()
			var tip := source+direction*104
			draw_colored_polygon(PackedVector2Array([tip-direction*5,tip+tangent*3,tip+direction*5,tip-tangent*3]),Color(0.64,0.91,0.91,0.48+glow*0.22))
	for index in 3:
		var center := source+Vector2.from_angle(-PI/2+index*TAU/3)*65
		var spin := battle_elapsed*(0.10 if index%2==0 else -0.08)
		draw_arc(center,24,0,TAU,48,bronze,1,false)
		draw_arc(center,20,0,TAU,40,light,1,false)
		for tooth in 12:
			var direction := Vector2.from_angle(tooth*TAU/12+spin)
			draw_line(center+direction*24,center+direction*28,bronze,2,false)
			draw_line(center+direction*17,center+direction*20,light,1,false)
		draw_line(center,center+Vector2.from_angle(spin-PI/2)*17,light,2,false)
		draw_circle(center,2,light)
	# Three distinct hands, with a slight offset projection echo.
	var angles := [-PI/2+0.72+battle_elapsed*0.018,-PI/2+2.3+battle_elapsed*0.075,-PI/2+battle_elapsed*0.55]
	var lengths := [59.0,94.0,106.0]
	for index in 3:
		var direction := Vector2.from_angle(angles[index])
		var tangent := direction.orthogonal()
		var tip: Vector2 = source+direction*float(lengths[index])
		draw_line(source+Vector2(3,-2),tip+Vector2(3,-2),ghost,3,false)
		if index<2:
			var width := 3.0 if index==0 else 2.0
			draw_colored_polygon(PackedVector2Array([source-direction*9,source+tangent*width,tip,source-tangent*width]),light)
		else:
			draw_line(source-direction*20,tip,Color(0.84,0.66,0.36,0.62+glow*0.2),1,false)
			draw_circle(source-direction*16,4,bronze)
		draw_line(tip-direction*7+tangent*3,tip,light,1,false)
		draw_line(tip-direction*7-tangent*3,tip,light,1,false)
	draw_arc(source,8,0,TAU,24,bronze,2,false)
	draw_circle(source,3,light)
	if glow>0:
		for i in 4:
			var angle := battle_elapsed*0.7+i*TAU/4
			draw_arc(source,137,angle,angle+0.22,12,Color(0.6,0.95,1,glow*0.52),3,false)

func _draw() -> void:
	_draw_clock_projection()
	var copper := Color(0.67, 0.48, 0.28, 0.48 + glow * 0.32)
	var blue := Color(0.35, 0.87, 1.0, 0.34 + glow * 0.56)
	for layer in 3:
		var ring: float = radius * [1.0, 0.83, 0.63][layer]
		var angle := battle_elapsed * (0.035 if layer % 2 == 0 else -0.065)
		for i in 48:
			var a := float(i) * TAU / 48.0 + angle
			var b := a + TAU / 48.0 * 0.76
			draw_line((source + Vector2.from_angle(a) * ring).round(), (source + Vector2.from_angle(b) * ring).round(), copper if layer == 0 else blue, 2.0, false)
	for i in 60:
		var direction := Vector2.from_angle(float(i) * TAU / 60.0 - battle_elapsed * 0.04)
		var length := 12.0 if i % 5 == 0 else 5.0
		draw_line((source + direction * (radius - length)).round(), (source + direction * radius).round(), blue if i % 5 == 0 else copper, 2.0, false)
	for pulse in pulses:
		var fade: float = 1.0 - pulse.age / 0.65
		var ring: float = 95.0 + pulse.age * 78.0
		draw_arc(pulse.origin,ring,0,TAU,96,Color(0.12,0.62,0.86,fade*0.18),12,false)
		draw_arc(pulse.origin,ring,0,TAU,96,Color(0.51,0.96,1,fade*0.65),2,false)
		for i in STREAM_COUNT:
			var direction := Vector2.from_angle(float(i) * TAU / STREAM_COUNT - PI / 2.0)
			var side := direction.orthogonal()
			var node: Vector2 = pulse.origin + direction * 126.0
			var activation := clampf((float(pulse.age) - i * 0.008) * 40.0,0.0,1.0) * fade
			draw_circle(node,8,Color(0.16,0.69,0.88,activation*0.3))
			draw_line(node-direction*7,node+direction*7,Color(0.75,1,1,activation),3,false)
			draw_line(node-side*5,node+side*5,Color(0.95,0.71,0.36,activation),2,false)
	for beam in beams:
		for i in range(1, beam.history.size()):
			var point: Dictionary = beam.history[i]
			var alpha := trail_alpha(beam, point)
			var previous: Vector2 = beam.history[i-1].point
			draw_line(previous,point.point,Color(0.08,0.38,0.68,alpha*0.22),alpha*17+1,false)
			draw_line(previous,point.point,Color(0.10,0.82,0.92,alpha*0.46),alpha*9+1,false)
			draw_line(previous,point.point,Color(0.64,0.97,1,alpha*0.92),alpha*4+1,false)
			draw_line(previous,point.point,Color(0.94,1,1,alpha),1,false)
			if i % 3 == 0:
				var drift := Vector2(sin(float(i)*2.4+beam.lane)*8,cos(float(i)*1.7)*6) * (1-alpha)
				draw_rect(Rect2((point.point+drift).round(),Vector2(2,2)),Color(0.44,0.91,1,alpha*0.8))
		var progress := (float(beam.age) - float(beam.delay)) / float(beam.travel)
		if progress >= 0.0 and progress < 1.0:
			var head := path_point(beam,progress)
			draw_circle(head,9,Color(0.22,0.9,1,0.24))
			draw_rect(Rect2(head-Vector2(4,3),Vector2(8,6)),Color(0.9,1,1))
			draw_line(head-Vector2(8,0),head+Vector2(8,0),Color(0.56,0.96,1,0.8),2,false)
	for burst in impacts:
		if burst.age < 0.0:
			continue
		var fade: float = 1.0-burst.age/0.48
		for layer in 2:
			draw_arc(burst.origin,6+burst.age*(110+layer*60),0,TAU,40,Color(0.35+layer*0.3,0.9,1,fade*(0.65-layer*0.18)),3-layer,false)
	for spark in sparks:
		var point: Vector2 = spark.origin + spark.direction * spark.speed * spark.age
		var fade: float = 1.0-spark.age/0.48
		draw_line(point-spark.direction*5,point,Color(0.43,0.91,1,fade),2,false)
		draw_rect(Rect2(point.round(),Vector2(3,3)),Color(0.9,1,1,fade))

