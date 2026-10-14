extends Node2D
## Each visual has an explicit local phase; no shader TIME or independent process.
var world: Node2D
var objects: Dictionary = {}
func _init() -> void:
	for index in 9:
		objects["cloud_"+str(index)] = {"label":"云层 "+str(index+1),"kind":"cloud","origin":Vector2(500+index*2900,1200+(index%3)*25),"phase":0.0}
	for id in ["stalled_device","lamp_bridge","lamp_tower"]:
		var origin := Vector2(1900,1690) if id == "stalled_device" else Vector2(6970,1476) if id == "lamp_bridge" else Vector2(16600,1450)
		objects[id] = {"label":"停摆装置" if id == "stalled_device" else "灯光","kind":"device" if id == "stalled_device" else "lamp","origin":origin,"phase":0.0}
func capture(id: String) -> Dictionary:
	return objects[id].duplicate(true)
func restore(id: String,state: Dictionary) -> void:
	objects[id] = state.duplicate(true)
	queue_redraw()
func advance_local(id: String,delta: float) -> void:
	if delta <= 0: return
	var pulse: float = world.player.idle_authority_pulse if world.temporal.is_unlocked else 0.0
	var state: Dictionary = objects[id]
	if state.kind != "device" or world.temporal.is_unlocked:
		state.phase += delta*(1.0+pulse*0.6)
	queue_redraw()
func object_rect(id: String) -> Rect2:
	var state: Dictionary = objects[id]
	var origin: Vector2 = state.origin
	if state.kind == "cloud":
		origin.y += world.camera.position.y-1540.0
		origin.x += sin(float(state.phase)*0.035)*260.0
		return Rect2(origin-Vector2(230,70),Vector2(460,140))
	return Rect2(origin-Vector2(55,205),Vector2(110,205))
func _draw() -> void:
	if world == null or not world._authority_mode(): return
	var pulse: float = world.player.idle_authority_pulse if world.temporal.is_unlocked else 0.0
	for id in objects:
		var state: Dictionary = objects[id]
		var p: Vector2 = state.origin
		var phase: float = state.phase
		if absf(p.x-world.player.position.x)>1900: continue
		if state.kind == "cloud":
			p.y += world.camera.position.y-1540.0
			p.x += sin(phase*0.035)*260.0
			for i in 7:
				_draw_cloud_ellipse(p+Vector2((i-3)*55,sin(i*2.3)*12),Vector2(90,27),Color(0.86,0.88,0.96,0.055+pulse*0.015))
		elif state.kind == "lamp":
			draw_line(p,p-Vector2(0,170),Color("8a745a"),7)
			draw_circle(p-Vector2(0,170),24,Color(1,0.78,0.46,0.20+sin(phase*1.7)*0.025+pulse*0.035))
		else:
			var center := p-Vector2(0,92)
			draw_circle(center,45,Color(0.17,0.22,0.30,0.95))
			draw_arc(center,44,0,TAU,64,Color(0.5,0.76,0.87,0.7),3,true)
			draw_line(center,center+Vector2(sin(phase),-cos(phase))*31,Color(0.78,0.94,1),3,true)
			draw_line(p,center+Vector2(0,44),Color("8a745a"),8)
func _draw_cloud_ellipse(center: Vector2,size: Vector2,color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		points.append(center+Vector2(cos(i*TAU/32)*size.x,sin(i*TAU/32)*size.y))
	draw_colored_polygon(points,color)
