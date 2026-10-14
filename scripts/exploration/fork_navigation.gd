extends RefCounted
const Map = preload("res://scripts/exploration/chapter_map.gd")
const LABELS := {"tutorial_upper":"星台上径", "stairs_terrace":"阶梯平台", "lamp_middle":"中层巡逻桥", "lamp_upper":"上层补给", "ring_inner":"观测环内径", "tower_upper":"钟楼上层", "corridor_gallery":"回廊平台"}
var active: Dictionary = {}
var selected: Dictionary = {}
var manual_axis := 0.0

func proximity(position: Vector2, grounded: bool) -> Dictionary:
	if not grounded or not active.is_empty(): return {"visible":false}
	var nearest: Dictionary = {"visible":false}
	var distance := 180.0
	for path in Map.fork_paths():
		var points: PackedVector2Array = path.points
		for side in [0,1]:
			var endpoint: Vector2 = points[0] if side == 0 else points[-1]
			var along := 1.0 if side == 0 else -1.0
			var x := clampf(position.x,points[0].x,points[-1].x)
			var surface := surface_y(points,x)
			var on_ramp := selected.has(path.id) and absf(position.x-endpoint.x)<310.0 and absf(position.y-surface)<32.0
			var gap: float = position.distance_to(endpoint)
			if on_ramp: gap = absf(position.x-endpoint.x)*0.4
			if gap >= distance: continue
			# Upper lamp joins the middle bridge; its endpoints are genuine common floors.
			if path.id == "lamp_upper" and not selected.has("lamp_middle") and not selected.has("lamp_upper"): continue
			if not on_ramp and absf(position.y-endpoint.y)>35.0: continue
			distance = gap
			nearest = {"visible":true,"id":str(path.id),"world_position":endpoint-Vector2(0,220),"up_label":str(LABELS[path.id]),"down_label":"中层巡逻桥" if path.id == "lamp_upper" else "下层道路","points":points,"side":side,"on_ramp":on_ramp,"along":along}
	return nearest

func begin(hint: Dictionary, direction: int, position: Vector2) -> bool:
	if not hint.get("visible",false) or direction not in [-1,1]: return false
	var points: PackedVector2Array = hint.points
	var side: int = hint.side
	var endpoint: Vector2 = points[0] if side == 0 else points[-1]
	if direction == 1 and not hint.on_ramp:
		# Explicit lower choice follows the common ground rather than a ramp.
		active = {"id":hint.id,"direction":direction,"target_x":endpoint.x+float(hint.along)*330.0,"axis":float(hint.along),"lower":true}
		selected.erase(hint.id)
	else:
		var target_x: float = endpoint.x if direction == 1 else endpoint.x+float(hint.along)*280.0
		active = {"id":hint.id,"direction":direction,"target_x":target_x,"axis":signf(target_x-position.x),"lower":direction == 1}
		selected[hint.id] = true
	return true

func surface_y(points: PackedVector2Array, x: float) -> float:
	for i in range(points.size()-1):
		if x >= points[i].x and x <= points[i+1].x:
			return lerpf(points[i].y,points[i+1].y,(x-points[i].x)/(points[i+1].x-points[i].x))
	return INF

func cancel() -> void:
	active.clear()

func capture() -> Dictionary:
	return {"active":active.duplicate(true),"selected":selected.duplicate(true),"manual_axis":manual_axis}

func restore(value: Dictionary) -> void:
	active = value.get("active",{}).duplicate(true)
	selected = value.get("selected",{}).duplicate(true)
	manual_axis = float(value.get("manual_axis",0.0))

func adopt_position(position: Vector2) -> void:
	selected.clear()
	for path in Map.fork_paths():
		if absf(surface_y(path.points,position.x)-position.y)<45.0:
			selected[path.id] = true
	if selected.has("lamp_upper"): selected["lamp_middle"] = true

func release_departed(position: Vector2, grounded: bool) -> bool:
	if not grounded or not active.is_empty(): return false
	var changed := false
	for path in Map.fork_paths():
		if not selected.has(path.id): continue
		if path.id == "lamp_middle" and selected.has("lamp_upper"): continue
		if absf(surface_y(path.points,position.x)-position.y)>90.0:
			selected.erase(path.id)
			changed = true
	return changed
