extends Node2D
## Combat attack light is drawn above actor silhouettes, without collision overlays.
var runtime
func _draw_attack(attack: Dictionary, opacity: float = 1.0) -> void:
	var geometry: Dictionary = attack.geometry
	var origin: Vector2 = geometry.origin
	var direction: float = geometry.direction
	var color := Color(0.72,0.88,1.0,opacity) if attack.get("echo",false) else Color(1.0,0.79,0.39,opacity)
	if geometry.get("bell",false):
		var foot := origin+Vector2(direction*float(attack.age)*640,0)
		# A travelling low wave; the bright crest follows the unchanged collision core.
		for layer in 3:
			var height := 22.0+layer*8.0
			var points := PackedVector2Array()
			for i in 21:
				var t := float(i)/20.0
				points.append(foot+Vector2((t-0.5)*84,-sin(t*PI)*height))
			draw_polyline(points,Color(color.r,color.g,color.b,opacity*(0.7-layer*0.18)),3.0-layer*0.6,true)
		for i in 7:
			var start := foot+Vector2(-direction*(18+i*12),-4-i%3*6)
			draw_line(start,start-Vector2(direction*(20+i*4),0),Color(color.r,color.g,color.b,opacity*(0.5-i*0.055)),2,true)
		draw_circle(foot+Vector2(0,-18),9,Color(color.r,color.g,color.b,opacity*0.13))
	else:
		var tip := origin+Vector2(direction*(80+float(attack.age)*300),-54)
		var tail := tip-Vector2(direction*102,0)
		# Spear/clock-hand point with tapering luminous wake, no collision box drawing.
		draw_colored_polygon(PackedVector2Array([tail,tip-Vector2(direction*28,9),tip+Vector2(direction*26,0),tip-Vector2(direction*28,-9)]),Color(color.r,color.g,color.b,opacity*0.18))
		draw_line(tail,tip,Color(color.r,color.g,color.b,opacity*0.25),10,true)
		draw_line(tail+Vector2(direction*20,0),tip,Color(color.r,color.g,color.b,opacity*0.8),3,true)
		draw_line(tip-Vector2(direction*18,8),tip+Vector2(direction*26,0),color,2,true)
		draw_line(tip-Vector2(direction*18,-8),tip+Vector2(direction*26,0),color,2,true)
		var arc := PackedVector2Array()
		for i in 17:
			var t := float(i)/16.0
			arc.append(tip+Vector2(-direction*45*sin(t*PI),-42+t*84))
		draw_polyline(arc,Color(color.r,color.g,color.b,opacity*0.55),2,true)

func _draw() -> void:
	for entity in runtime.entities.values():
		if entity.windup:
			var start: Vector2 = entity.position+Vector2(0,-3)
			var end: Vector2 = start+Vector2(entity.direction*220,0)
			draw_line(start,end,Color(1,0.65,0.25,0.4),1.5,true)
			for i in 3:
				var point := start+Vector2(entity.direction*(70+i*65),0)
				draw_line(point-Vector2(entity.direction*8,4),point,Color(1,0.75,0.4,0.6),1.5,true)
	for attack in runtime.attacks:
		if attack.kind == "enemy": _draw_attack(attack)
	for trail in runtime.attack_trails:
		_draw_attack(trail,float(trail.fade)/0.24)

