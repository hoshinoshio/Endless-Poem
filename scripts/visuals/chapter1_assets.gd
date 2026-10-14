extends RefCounted
## Approved direction A, 2026-10-05. Runtime resources stay inside this project.
const Atlas = preload("res://scripts/visuals/sprite_atlas.gd")
const IdleMotion = preload("res://scripts/visuals/idle_motion_assets.gd")
const BASE := "res://assets/chapter1/"
static var _cached: Dictionary = {}

static func build() -> Dictionary:
	if not _cached.is_empty():
		return _cached.duplicate(true)
	var hero := _actor("moonli_authority", 217.0, [[0,0,627,673],[627,0,627,673],[0,673,627,581],[627,673,627,581]])
	hero["position"] = [270,552]
	# The generated guard thrust crosses the atlas midline. These source-space
	# masks follow the transparent gap; no artwork is painted over or rescaled separately.
	var west := PackedVector2Array([Vector2(0,0),Vector2(450,0),Vector2(450,330),Vector2(580,520),Vector2(580,615),Vector2(0,615)])
	var east := PackedVector2Array([Vector2(450,0),Vector2(1254,0),Vector2(1254,615),Vector2(580,615),Vector2(580,520),Vector2(450,330)])
	var guard := _actor("patrol_guard", 245.0, [[0,0,580,615],[450,0,804,615],[0,615,600,639],[600,615,654,639]], [west,east,null,null])
	var elite := _actor("hour_guard", 265.0, [[0,0,540,610],[540,0,714,610],[0,610,650,644],[650,610,604,644]])
	var instrument := _actor("brass_instrument", 210.0)
	var observer := _actor("echo_observer", 230.0)
	var boss := _actor("chronos_trial", 320.0)
	boss["flip_h"] = true
	var anchor := _actor("time_anchor", 145.0)
	# Explicit authored identities keep each creature's strips distinct.
	hero["pixel_key"] = "player"
	guard["pixel_key"] = "guard"
	elite["pixel_key"] = "elite"
	instrument["pixel_key"] = "instrument"
	observer["pixel_key"] = "observer"
	boss["pixel_key"] = "boss"
	anchor["pixel_key"] = "anchor"
	var musheng := {"pixel_key":"musheng","texture":load("res://assets/exploration/observer_npc.png"),"height":230.0}
	var layers := [{"id":"observatory_courtyard", "texture":BASE+"observatory_courtyard.png", "z_index":-20, "position":[720,450], "size":[1440,900]}]
	var encounters := {}
	for id in ["tutorial","stairs","patrol","lamp","elite","corridor","boss"]:
		encounters[id] = {"layers":layers.duplicate(true)}
	_cached = {"time_authority":true,"ambient_motion":true,"player":hero,"npcs":{"musheng":musheng},"enemies":{"tutorial":guard,"guard":guard,"elite":elite,"instrument":instrument,"observer":observer,"boss":boss,"anchor":anchor,"musheng":musheng},"encounters":encounters}
	return _cached.duplicate(true)

static func _actor(id: String, height: float, regions: Array = [], masks: Array = []) -> Dictionary:
	var poses := Atlas.build(BASE+id+"_atlas.png",regions,Vector2i.ZERO,masks)
	# Moonli's first-row feet extend below the exact half-height of this source.
	var idle_regions: Array = [[0,0,627,643],[627,0,627,643],[0,643,627,611],[627,643,627,611]] if id == "moonli_authority" else []
	poses = IdleMotion.apply(poses, BASE+"idle/"+id+"_atlas.png", idle_regions)
	return {"sprite_frames":poses,"height":height}
