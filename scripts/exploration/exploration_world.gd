extends Node2D
signal branch_chosen(id: String, direction: int)
const ForkNavigation = preload("res://scripts/exploration/fork_navigation.gd")
var fork_navigation = ForkNavigation.new()
var _fork_bodies: Dictionary = {}
signal encounter_requested(encounter_id: String)
signal interaction_requested(event_id: String)
signal tutorial_event(event: String, data: Dictionary)
signal checkpoint_requested(position: Vector2, region: int)
signal enemy_attack_hit(enemy_id: String, attack_id: String, damage: int)
const Map = preload("res://scripts/exploration/chapter_map.gd")
const Player = preload("res://scripts/exploration/exploration_player.gd")
const Actor = preload("res://scripts/world/combat_actor.gd")
const Assets = preload("res://scripts/visuals/chapter1_assets.gd")
const Temporal = preload("res://scripts/authority/temporal_controller.gd")
const Ambient = preload("res://scripts/exploration/map_ambient.gd")
const PixelActor = preload("res://scripts/visuals/pixel_actor.gd")
var temporal = Temporal.new()
var ambient: Node2D
var _enemy_states: Dictionary = {}
var _enemy_initial: Dictionary = {}
var _enemy_attack_serials: Dictionary = {}
var player: CharacterBody2D
var camera: Camera2D
var run: Dictionary = {}
var elapsed := 0.0
var paused := false
var current_region := 0
var active_encounter := ""
var nearest_interaction := ""
var time_slice := "before"
var chapter_night := false
var night_mix := 0.0
var observer_npc: Node2D
var _npc_size := Vector2.ZERO
var _npc_fit := 1.0
var _npc_clock := 0.0
var terrain: Array = []
var gate_bodies: Array = []
var previews: Dictionary = {}
var suppressed: Dictionary = {}
var tutorial_seen: Dictionary = {}
var branch_visits: Dictionary = {}
var missing_assets: Array = []
var _encounters := Map.encounters()
var _interactions := Map.interactions()
var _gates := Map.gates()
var _configured := false
var _last_landings := 0
var _camera_position := Vector2.ZERO
var _font = preload("res://assets/msyh.ttc")
var _module: Texture2D
var _background_material: ShaderMaterial
var _backgrounds: Array[Sprite2D] = []
func configure(value: Dictionary) -> void:
	if _configured:
		apply_run(value)
		var pos: Array = value.get("position",[200,1900])
		set_player_position(Vector2(pos[0],pos[1]))
		return
	_configured = true
	run = value.duplicate(true)
	chapter_night = bool(run.get("chapter_night",false))
	night_mix = 1.0 if chapter_night else 0.0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var background_path := "res://assets/exploration/dusk_panorama.png"
	if not ResourceLoader.exists(background_path):
		background_path = "res://assets/chapter1/observatory_courtyard.png"
	var texture := load(background_path) as Texture2D
	if background_path.ends_with("observatory_courtyard.png"):
		_background_material = ShaderMaterial.new()
		_background_material.shader = preload("res://shaders/courtyard_motion.gdshader")
	else:
		_background_material = ShaderMaterial.new()
		_background_material.shader = preload("res://scripts/exploration/map_night.gdshader")
		_background_material.set_shader_parameter("night_amount",night_mix)
	var backdrop_width := 1300.0*texture.get_width()/texture.get_height()
	for i in range(ceili(24000.0/backdrop_width)+1):
		var bg := Sprite2D.new()
		bg.texture = texture
		bg.position = Vector2(i*backdrop_width+backdrop_width/2,1500)
		bg.scale = Vector2(backdrop_width+2,1300)/texture.get_size()
		bg.z_index = -30
		bg.modulate = Color(0.72,0.77,0.9)
		bg.material = _background_material
		add_child(bg)
		_backgrounds.append(bg)
	if ResourceLoader.exists("res://assets/exploration/terrace_modules.png"):
		_module = load("res://assets/exploration/terrace_modules.png")
	_add_terrain("ground",Map.ground_points(),false)
	if _authority_mode():
		_add_terrain("device_low_terrace",PackedVector2Array([Vector2(1760,1690),Vector2(2050,1690)]),true)
	for path in Map.platform_paths():
		_add_terrain(path.id,path.points,true)
	for gate in _gates:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(24,2700)
		shape.shape = rect
		body.position = Vector2(gate.x,1350)
		body.add_child(shape)
		add_child(body)
		gate_bodies.append(body)
	player = Player.new()
	add_child(player)
	_sync_fork_collisions()
	camera = Camera2D.new()
	camera.position_smoothing_enabled = false
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 24000
	camera.limit_bottom = 2700
	add_child(camera)
	var position_data: Array = run.get("position",[200,1900])
	set_player_position(Vector2(position_data[0],position_data[1]))
	_create_previews()
	_create_observer_npc()
	_setup_time_targets()
	apply_run(value)
func _add_terrain(id: String, points: PackedVector2Array, platform: bool) -> void:
	terrain.append({"id":id,"points":points,"platform":platform})
	for i in range(points.size()-1):
		var a := points[i]
		var b := points[i+1]
		var body := StaticBody2D.new()
		body.name = id+"_"+str(i)
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionPolygon2D.new()
		var depth := 45.0 if platform else 800.0
		shape.polygon = PackedVector2Array([a,b,b+Vector2(0,depth),a+Vector2(0,depth)])
		shape.one_way_collision = platform
		shape.one_way_collision_margin = 10.0
		body.add_child(shape)
		add_child(body)
		for fork in Map.fork_paths():
			if fork.id == id:
				if not _fork_bodies.has(id): _fork_bodies[id] = []
				_fork_bodies[id].append(body)
func _create_previews() -> void:
	var assets := Assets.build()
	for id in _encounters:
		var actor := Actor.new()
		var kind := "boss" if id == "boss" else "elite" if id == "elite" else "guard"
		actor.configure("preview_"+id,assets.enemies[kind],280.0 if id == "boss" else 210.0,260.0)
		actor.set_interactive(false)
		actor.position = _encounters[id].spawns[0]
		actor.modulate.a = 0.62
		add_child(actor)
		previews[id] = actor
func apply_run(value: Dictionary) -> void:
	run = value.duplicate(true)
	if _authority_mode():
		_interactions.erase("tutorial_lantern")
		_interactions["stalled_device"] = Vector2(1900,1690)
	else:
		_interactions = Map.interactions()
	temporal.set_unlocked(_authority_mode() and bool(run.get("authority_unlocked",false)))
	if player != null: player.set_authority_unlocked(temporal.is_unlocked)
	if run.has("chapter_night"):
		set_chapter_night(bool(run.chapter_night))
	if run.has("time_slice"):
		set_time_slice(str(run.time_slice))
	var complete: Array = run.get("completed",[])
	for id in previews:
		previews[id].visible = not id in complete and id != active_encounter
	for i in _gates.size():
		gate_bodies[i].get_child(0).disabled = _gate_open(_gates[i])
	queue_redraw()
func _gate_open(gate: Dictionary) -> bool:
	for id in ([] if _authority_mode() else gate.completed):
		if not id in run.get("completed",[]):
			return false
	for id in gate.interactions:
		if not id in run.get("interactions",[]):
			return false
	return true
func set_paused(value: bool) -> void:
	paused = value
	temporal.set_paused(value)
	if camera != null:
		camera.enabled = not value
	if player != null and value:
		player.set_input(0,false)
		player.jump_queued = false
	queue_redraw()
func set_movement_input(axis: float, jump_pressed: bool, running: bool = false) -> void:
	if player != null and not paused:
		fork_navigation.manual_axis = axis
		if not fork_navigation.active.is_empty():
			if jump_pressed or (absf(axis)>0.01 and axis*float(fork_navigation.active.axis)<0):
				fork_navigation.cancel()
			else:
				axis = float(fork_navigation.active.axis)
		player.set_input(axis,jump_pressed,running)
func advance_simulation(sim_delta: float) -> void:
	if paused or player == null or sim_delta <= 0:
		return
	# Substeps preserve collision accuracy and external battle-clock slowdown.
	var remaining := 0.0 if _authority_mode() else sim_delta
	if _authority_mode():
		for id in previews:
			previews[id].visible = not id in run.get("completed",[]) and absf(previews[id].position.x-player.position.x)<1800
		temporal.advance(sim_delta)
	while remaining > 0.000001:
		var dt := minf(remaining,1.0/120.0)
		_advance_fork_player(dt)
		if active_encounter != "":
			var boundary: Rect2 = _encounters[active_encounter].rect
			player.position.x = clampf(player.position.x,boundary.position.x+28,boundary.end.x-28)
		player.position.x = clampf(player.position.x,30,23970)
		remaining -= dt
	elapsed += sim_delta
	night_mix = move_toward(night_mix,1.0 if chapter_night else 0.0,sim_delta/3.0)
	if observer_npc != null:
		if not _authority_mode():
			_advance_npc(sim_delta)
		observer_npc.modulate.a = clampf((player.position.x-12400.0)/500.0,0,1)
	if _background_material != null:
		_background_material.set_shader_parameter("battle_time",elapsed)
		_background_material.set_shader_parameter("night_amount",night_mix)
	for actor in previews.values():
		if actor.visible and not _authority_mode():
			actor.advance(sim_delta)
			actor.modulate.a = 0.62
	var camera_y: float = player.position.y-320.0 if player.grounded else clampf(camera.position.y,player.position.y-370.0,player.position.y+120.0)
	if _authority_mode():
		# Keep the character and interactable scenery above the authority card panel.
		camera_y = player.position.y-170.0 if player.grounded else clampf(camera.position.y,player.position.y-220.0,player.position.y+120.0)
	var camera_x: float = player.position.x+100.0
	camera.zoom = Vector2.ONE
	if active_encounter != "":
		camera.zoom = Vector2.ONE * minf(1.0,1440.0/(_encounters[active_encounter].rect.size.x+260.0))
		camera_x = _encounters[active_encounter].rect.get_center().x
		camera_y = float(_encounters[active_encounter].floor_y)-100.0/camera.zoom.y if player.grounded else clampf(camera.position.y,player.position.y-100.0,player.position.y+150.0)
	_camera_position = Vector2(camera_x,camera_y)
	camera.position = _camera_position
	for bg in _backgrounds:
		bg.position.y = 1500.0+(camera.position.y-1580.0)*0.6
	if player.position.y > 2600:
		set_player_position(Vector2(maxf(200,player.position.x-200),Map.ground_y(player.position.x)-5))
	_update_tutorial()
	_update_regions_and_triggers()
	queue_redraw()
func _update_tutorial() -> void:
	var p := player.position
	if p.x >= 650 and not tutorial_seen.has("walked"):
		tutorial_seen.walked = true
		tutorial_event.emit("walked",{"position":p})
	if player.landed_count > _last_landings and p.x >= 650 and not tutorial_seen.has("jump_landed") and tutorial_seen.has("walked"):
		# Initial spawn contact does not qualify as a tutorial jump.
		if tutorial_seen.has("airborne") and (not _authority_mode() or (p.x>=1760 and p.x<=2050 and absf(p.y-1690)<10)):
			tutorial_seen.jump_landed = true
			tutorial_event.emit("jump_landed",{"position":p})
	if player.velocity.y < -100 and tutorial_seen.has("walked"):
		tutorial_seen.airborne = true
	_last_landings = player.landed_count
	if p.x > 2300 and p.x < 2680:
		branch_visits["tutorial_upper" if p.y<1800 else "tutorial_lower"] = true
	if p.x >= 2700 and int(run.get("tutorial_step",0)) >= 3 and not tutorial_seen.has("fork_completed") and "tutorial_lantern" in run.get("interactions",[]) and (branch_visits.has("tutorial_upper") or branch_visits.has("tutorial_lower")):
		tutorial_seen.fork_completed = true
		tutorial_event.emit("fork_completed",{"position":p,"routes":branch_visits.keys()})
func _update_regions_and_triggers() -> void:
	var p := player.position
	var next_region := clampi(int(p.x/3000.0),0,7)
	if next_region != current_region:
		current_region = next_region
		if not is_branch_travelling(): checkpoint_requested.emit(p,current_region)
	nearest_interaction = available_interaction_id()
	# Only physical floor contact inside the route counts as a visit.
	if player.grounded and p.x > 9800 and p.x < 10800:
		var route := "upper" if p.y < 1550 else "middle" if p.y < 1900 else "lower"
		branch_visits["lamp_"+route] = true
	if player.grounded and p.x > 15600 and p.x < 17000:
		branch_visits["tower_upper" if p.y < 1750 else "tower_lower"] = true
	for id in suppressed.keys():
		if p.distance_to(_encounters[id].trigger)>800:
			suppressed.erase(id)
	if _authority_mode() or active_encounter != "" or int(run.get("tutorial_step",0)) < 4:
		return
	for id in _encounters:
		if id in run.get("completed",[]) or suppressed.has(id):
			continue
		if p.distance_to(_encounters[id].trigger)<145 and player.grounded:
			suppressed[id] = true
			encounter_requested.emit(id)
			break
func _interaction_position(id: String) -> Vector2:
	if id == "testimony" and observer_npc != null:
		return observer_npc.position
	return _interactions.get(id,Vector2.ZERO)

func _interaction_available(id: String) -> bool:
	if _authority_mode() and id == "stalled_device":
		if int(run.get("authority_tutorial_step",0)) < 2 or not player.grounded or absf(player.position.y-1690)>10 or player.position.x<1760 or player.position.x>2050: return false
	if id == "final_dial" and not _authority_mode() and not "boss" in run.get("completed",[]):
		return false
	return true

func available_interaction_id() -> String:
	if paused or player == null or active_encounter != "": return ""
	var nearest := ""
	var distance_limit := 180.0
	for id in _interactions:
		if not _interaction_available(id): continue
		var distance: float = player.position.distance_to(_interaction_position(id))
		if distance < distance_limit:
			nearest = id
			distance_limit = distance
	return nearest

func proximity_interaction() -> Dictionary:
	var id := available_interaction_id()
	if id.is_empty(): return {"visible":false,"id":"","key":"","world_position":Vector2.ZERO}
	var offset := 250.0
	if id == "testimony": offset = 157.0
	elif id == "stalled_device": offset = 172.0
	return {"visible":true,"id":id,"key":"E","world_position":_interaction_position(id)-Vector2(0,offset)}

func interact() -> void:
	# Recheck physical proximity on the input frame; a cached hint cannot authorize interaction.
	var id := available_interaction_id()
	nearest_interaction = id
	if id.is_empty(): return
	if id == "testimony" and observer_npc is PixelActor:
		observer_npc.set_motion_state("talk",Vector2.ZERO,observer_npc.facing)
		observer_npc._sample()
	interaction_requested.emit(id)
	if id == "tutorial_lantern":
		tutorial_event.emit("investigated",{"interaction":id,"position":player.position})
func get_player_position() -> Vector2:
	return player.position if player != null else Vector2(200,1900)
func set_player_position(value: Vector2) -> void:
	if player == null:
		return
	fork_navigation.cancel()
	fork_navigation.adopt_position(value)
	_sync_fork_collisions()
	player.position = value
	current_region = clampi(int(value.x/3000.0),0,7)
	player.velocity = Vector2.ZERO
	player.grounded = false
	if camera != null:
		camera.position = value+Vector2(100,-320)
func get_player_hitbox() -> Rect2:
	return player.hitbox() if player != null else Rect2()
func get_encounter_spec(id: String) -> Dictionary:
	return _encounters.get(id,{}).duplicate(true)
func set_encounter_active(id: String, active: bool) -> void:
	active_encounter = id if active else ""
	if active and camera != null and _encounters.has(id):
		camera.zoom = Vector2.ONE * minf(1.0,1440.0/(_encounters[id].rect.size.x+260.0))
		camera.position = Vector2(_encounters[id].rect.get_center().x,float(_encounters[id].floor_y)-100.0/camera.zoom.y)
	if previews.has(id):
		previews[id].visible = not active and not id in run.get("completed",[])
	queue_redraw()
func finish_encounter(id: String) -> void:
	var complete: Array = run.get("completed",[]).duplicate()
	if not id in complete:
		complete.append(id)
	run.completed = complete
	active_encounter = ""
	camera.zoom = Vector2.ONE
	apply_run(run)
func leave_encounter(id: String) -> void:
	active_encounter = ""
	camera.zoom = Vector2.ONE
	suppressed[id] = true
	apply_run(run)
func get_player_visual():
	return player.visual if player != null else null
func play_player_action(action: String) -> void:
	if player != null:
		player.play_action(action)
func get_gate_state() -> Array:
	var out := []
	for gate in _gates:
		out.append({"x":gate.x,"open":_gate_open(gate),"label":gate.label})
	return out
func presentation_state() -> Dictionary:
	return {"region":current_region,"region_name":Map.NAMES[current_region],"position":get_player_position(),"grounded":player.grounded if player!=null else false,"animation":(player.visual.animation_state if player.action_remaining>0 else player.animation) if player!=null else "idle","platforms":terrain.size(),"branches":branch_visits.duplicate(),"nearest_interaction":nearest_interaction,"active_encounter":active_encounter,"gates":get_gate_state(),"missing_resources":missing_assets,"elapsed":elapsed,"paused":paused,"side_frame":player.side_frame if player!=null else -1,"side_motion":player.side_sprite!=null if player!=null else false,"authored_terrain":_module!=null,"time_slice":time_slice,"chapter_night":chapter_night,"night_mix":night_mix,"npc_ready":observer_npc!=null,"camera_position":camera.position if camera!=null else Vector2.ZERO}
func _draw() -> void:
	# Stone silhouettes follow exactly the physics surfaces, including slopes.
	for entry in terrain:
		var pts: PackedVector2Array = entry.points
		for i in range(pts.size()-1):
			var a := pts[i]
			var b := pts[i+1]
			var depth := 45.0 if entry.platform else 800.0
			draw_colored_polygon(PackedVector2Array([a,b,b+Vector2(0,depth),a+Vector2(0,depth)]),Color("333747"))
			draw_colored_polygon(PackedVector2Array([a,b,b+Vector2(0,18),a+Vector2(0,18)]),Color("8a8190"))
			draw_line(a,b,Color("c4b6a0"),4.0)
			var count := maxi(1,int((b.x-a.x)/120))
			for j in range(count):
				var at := a.lerp(b,float(j)/count)
				draw_line(at+Vector2(0,20),at+Vector2(0,depth),Color("252939"),2)
				if not entry.platform:
					for layer in 5:
						draw_line(at+Vector2(0,70+layer*120),at+Vector2(110,70+layer*120),Color("555264"),2)
	if _module != null:
		_draw_authored_terrain()
	# Reuse the approved module's actual lamp; the encounter changes its light only.
	var lamp_position := Vector2(10650,2100)
	var lamp_lit := bool(run.get("lamp_lit",false))
	if _module != null:
		draw_texture_rect_region(_module,Rect2(lamp_position-Vector2(30,216),Vector2(68,216)),Rect2(385,387,149,474),Color.WHITE if lamp_lit else Color(0.32,0.34,0.42))
	else:
		draw_line(lamp_position,lamp_position+Vector2(0,-175),Color("776b63"),8)
	if lamp_lit:
		draw_circle(lamp_position+Vector2(0,-175),25,Color(0.98,0.75,0.42,0.45+0.15*sin(elapsed*2)))
		draw_arc(lamp_position+Vector2(0,-175),34,0,TAU,24,Color(0.95,0.8,0.55,0.65),2)
	for sign in [{"position":Vector2(9070,1520),"text":"↑ 上层补给"},{"position":Vector2(9600,1650),"text":"中层巡逻桥 →"},{"position":Vector2(9480,2200),"text":"下层未点亮的灯 →"},{"position":Vector2(6800,2260),"text":"桥下检修通道 →"},{"position":Vector2(15080,1510),"text":"↑ 补给 · 休整"},{"position":Vector2(15630,2200),"text":"整点卫兵 →"}]:
		draw_string(_font,sign.position,sign.text,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("d6c9a8"))
	for id in _interactions:
		var p: Vector2 = _interactions[id]
		if id == "testimony" and observer_npc != null:
			continue
		if _authority_mode() and id == "stalled_device": continue
		if _module != null:
			draw_texture_rect_region(_module,Rect2(p-Vector2(30,216),Vector2(68,216)),Rect2(385,387,149,474))
		else:
			draw_line(p,p+Vector2(0,-130),Color("8a745a"),8)
		if _authority_mode(): continue
		var glow := 0.4+0.2*sin(elapsed*2+p.x)
		draw_circle(p+Vector2(0,-175),20,Color(0.98,0.75,0.42,glow))
		draw_arc(p+Vector2(0,-175),29,0,TAU,24,Color(0.95,0.8,0.55,0.65),2)
	for i in _gates.size():
		if _module != null:
			var pillar_pos := Vector2(_gates[i].x,Map.ground_y(_gates[i].x))
			draw_texture_rect_region(_module,Rect2(pillar_pos-Vector2(170,300),Vector2(134,300)),Rect2(1228,373,219,490))
			draw_texture_rect_region(_module,Rect2(pillar_pos+Vector2(36,-300),Vector2(134,300)),Rect2(1228,373,219,490))
		if not _gate_open(_gates[i]):
			var p := Vector2(_gates[i].x,Map.ground_y(_gates[i].x))
			draw_line(p,p+Vector2(0,-420),Color(0.55,0.72,0.9,0.35),10)
			if player != null and absf(player.position.x-p.x)<550:
				draw_string(_font,p+Vector2(-240,-430),_gates[i].label,HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("d6d6ea"))
	if active_encounter != "":
		var boundary: Rect2 = _encounters[active_encounter].rect
		for x in [boundary.position.x,boundary.end.x]:
			draw_line(Vector2(x,boundary.position.y),Vector2(x,boundary.end.y),Color(0.65,0.85,1,0.5),4)
	# Dust/star drift belongs to the same supplied clock as all other motion.
	if player != null:
		for i in 20:
			var x := floorf(player.position.x/1440)*1440+fmod(i*127+elapsed*13,1440)
			var y := player.position.y-600+sin(elapsed*.7+i)*180
			draw_circle(Vector2(x,y),1.5,Color(0.77,0.86,1,0.3+0.2*sin(elapsed+i)))
	_draw_interaction_key()

func _draw_interaction_key() -> void:
	var prompt := proximity_interaction()
	if not prompt.visible: return
	var center: Vector2 = prompt.world_position
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.035,0.065,0.105,0.88)
	box.border_color = Color("dce6ef")
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	draw_style_box(box,Rect2(center-Vector2(19,19),Vector2(38,38)))
	draw_string(_font,center+Vector2(-18,8),"E",HORIZONTAL_ALIGNMENT_CENTER,36,23,Color("eff4fa"))



func _draw_authored_terrain() -> void:
	var dimensions := _module.get_size()
	var uv := PackedVector2Array([Vector2(160,117)/dimensions,Vector2(735,117)/dimensions,Vector2(735,334)/dimensions,Vector2(160,334)/dimensions])
	for entry in terrain:
		var pts: PackedVector2Array = entry.points
		for i in range(pts.size()-1):
			var a := pts[i]
			var b := pts[i+1]
			var tiles := maxi(1,ceili((b.x-a.x)/460.0))
			for tile in tiles:
				var left := a.lerp(b,float(tile)/tiles)
				var right := a.lerp(b,float(tile+1)/tiles)
				var quad := PackedVector2Array([left,right,right+Vector2(0,180),left+Vector2(0,180)])
				draw_polygon(quad,PackedColorArray([Color.WHITE]),uv,_module)
	_draw_bridge_slice()
func set_time_slice(slice: String) -> void:
	time_slice = "after" if slice in ["after","bridge_after","钟鸣后"] else "anchored" if slice in ["anchored","anchor","锚定时"] else "before"
	queue_redraw()
func _draw_bridge_slice() -> void:
	# This historical bridge is safely behind the traversable terrace. Only art changes.
	if time_slice != "after":
		draw_texture_rect_region(_module,Rect2(Vector2(6500,1450),Vector2(1100,315)),Rect2(919,100,831,238))
		draw_texture_rect_region(_module,Rect2(Vector2(6970,1260),Vector2(68,216)),Rect2(385,387,149,474))
	else:
		draw_set_transform(Vector2(6500,1450),0.09)
		draw_texture_rect_region(_module,Rect2(Vector2.ZERO,Vector2(540,315)),Rect2(919,100,390,238))
		draw_set_transform(Vector2(7150,1535),-0.12)
		draw_texture_rect_region(_module,Rect2(Vector2.ZERO,Vector2(540,315)),Rect2(1360,100,390,238))
		draw_set_transform(Vector2.ZERO)
		for i in 5:
			var point := Vector2(7070+i*63,1680+i*37)
			draw_set_transform(point,float(i)*0.27-0.3)
			draw_texture_rect_region(_module,Rect2(Vector2.ZERO,Vector2(65,38)),Rect2(170+i*55,125,110,55))
			draw_set_transform(Vector2.ZERO)
		draw_set_transform(Vector2(7170,1805),1.1)
		draw_texture_rect_region(_module,Rect2(Vector2.ZERO,Vector2(42,70)),Rect2(407,430,88,150))
		draw_set_transform(Vector2.ZERO)
		for i in 7:
			var point := Vector2(7150+i*17,1855+(i%3)*9)
			draw_colored_polygon(PackedVector2Array([point,point+Vector2(13,-8),point+Vector2(18,3)]),Color(0.75,0.6,0.3,0.65))
	var label := "钟鸣后 · 断裂的事故石桥" if time_slice=="after" else "锚定时 · 留存的桥影" if time_slice=="anchored" else "落日前 · 完好的事故石桥"
	draw_string(_font,Vector2(6650,1390),label,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("e1d7bb"))
func _create_observer_npc() -> void:
	var pixel := PixelActor.new()
	if pixel.configure_key("musheng"):
		observer_npc = pixel
		pixel.name = "MushengPixelObserver"
		pixel.authority_unlocked = false
		pixel.position = Vector2(13280,1900)
		_npc_size = Vector2(48,64)
		_npc_fit = float(pixel.display_scale)
		add_child(pixel)
		return
	pixel.free()
	var path := "res://assets/exploration/observer_npc.png"
	if not ResourceLoader.exists(path):
		return
	var texture := load(path) as Texture2D
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var bounds := image.get_used_rect()
	if not bounds.has_area():
		return
	var frame := AtlasTexture.new()
	frame.atlas = texture
	frame.region = Rect2(bounds)
	frame.filter_clip = true
	var legacy := Sprite2D.new()
	observer_npc = legacy
	observer_npc.name = "MushengObserver"
	legacy.texture = frame
	legacy.centered = false
	_npc_size = Vector2(bounds.size)
	_npc_fit = 225.0/_npc_size.y
	observer_npc.scale = Vector2.ONE*_npc_fit
	observer_npc.position = Vector2(13280,1900)-Vector2(_npc_size.x*_npc_fit/2,225)
	add_child(observer_npc)






func set_chapter_night(value: bool = true) -> void:
	chapter_night = value
	run.chapter_night = value
	queue_redraw()


func _authority_mode() -> bool:
	return str(run.get("ruleset","")) == "time_authority_v2"

func _screen_rect(rect: Rect2) -> Rect2:
	var transform := get_canvas_transform()
	return Rect2(transform*rect.position, rect.size*transform.get_scale())

func _setup_time_targets() -> void:
	ambient = Ambient.new()
	ambient.world = self
	ambient.z_index = -10
	add_child(ambient)
	for id in previews:
		var actor = previews[id]
		var surface := _enemy_surface(actor.position)
		_enemy_states[id] = {"origin":actor.position,"phase":0.0,"velocity":Vector2.ZERO,"facing":-1.0,"state":"patrol","state_time":0.0,"serial":0,"hit":false,"patrol_direction":-1.0,"surface":surface}
		_enemy_attack_serials[id] = 0
		actor.set_motion_state("idle",Vector2.ZERO,-1.0)
		_enemy_initial[id] = _capture_enemy(id)
		temporal.register_target("enemy_"+id,"巡逻者 · "+id,func(): return _screen_rect(Rect2(actor.position-Vector2(90,220),Vector2(180,220))) if actor.visible else Rect2(),func(): return _capture_enemy(id),func(state): _restore_enemy(id,state),func(dt): _advance_enemy(id,dt))
	for id in ambient.objects:
		temporal.register_target(id,ambient.objects[id].label,func(): return _screen_rect(ambient.object_rect(id)),func(): return ambient.capture(id),func(state): ambient.restore(id,state),func(dt): ambient.advance_local(id,dt))
	temporal.register_target("musheng","暮笙",func(): return _screen_rect(_npc_world_rect()),func(): return _capture_npc(),func(value): _restore_npc(value),func(dt): _advance_npc(dt))
	temporal.register_target("player","月璃",func(): return _screen_rect(player.hitbox()),func(): return _capture_player(),func(state): _restore_player(state),func(dt): _advance_player_local(dt))

func _pose_npc() -> void:
	if observer_npc == null: return
	if observer_npc is PixelActor:
		observer_npc._sample()
		return
	var breath := 1.0+sin(_npc_clock*1.8)*0.007
	observer_npc.scale = Vector2(_npc_fit,_npc_fit*breath)
	observer_npc.position = Vector2(13280,1900)-Vector2(_npc_size.x*_npc_fit/2,_npc_size.y*_npc_fit*breath)

func _npc_world_rect() -> Rect2:
	if observer_npc == null: return Rect2()
	if observer_npc is PixelActor:
		var anchor: Vector2 = observer_npc.frame_anchor
		var fit := float(observer_npc.display_scale)
		var left: float = -anchor.x if observer_npc.facing>=0 else anchor.x-48.0
		return Rect2(observer_npc.position+Vector2(left,-anchor.y)*fit,Vector2(48,64)*fit)
	return Rect2(observer_npc.position,_npc_size*observer_npc.scale)

func _capture_npc() -> Dictionary:
	var value := {"clock":_npc_clock}
	if observer_npc is PixelActor:
		value["position"] = observer_npc.position
		value["rig"] = _capture_rig(observer_npc)
	return value

func _restore_npc(value: Dictionary) -> void:
	_npc_clock = float(value.clock)
	if observer_npc is PixelActor and value.has("rig"):
		observer_npc.position = value.get("position",observer_npc.position)
		_restore_rig(observer_npc,value.rig)
	else: _pose_npc()

func _advance_npc(delta: float) -> void:
	if delta<=0 or observer_npc==null: return
	_npc_clock += delta
	if observer_npc is PixelActor:
		if observer_npc.state=="talk":
			var clip: Dictionary = observer_npc.animations.get("talk",{})
			if clip.is_empty() or observer_npc.state_time>=clip.frames.size()/float(clip.fps):
				observer_npc.set_motion_state("idle",Vector2.ZERO,observer_npc.facing)
		observer_npc.advance(delta,0.0)
	else: _pose_npc()

func _capture_player() -> Dictionary:
	var state := {}
	for key in ["position","velocity","grounded","facing","stride_phase","elapsed","run_blend","animation","jump_elapsed","landing_remaining","idle_authority_phase","idle_authority_pulse","action_remaining","action_animation","authority_idle_elapsed","authority_gesture_elapsed","authority_intensity"]:
		state[key] = player.get(key)
	state["fork_navigation"] = fork_navigation.capture()
	if player.continuous_motion != null: state["rig"] = _capture_rig(player.continuous_motion)
	return state

func _restore_player(state: Dictionary) -> void:
	for key in state:
		if key not in ["rig","fork_navigation"]: player.set(key,state[key])
	if state.has("rig") and player.continuous_motion != null:
		_restore_rig(player.continuous_motion,state.rig)
	if state.has("fork_navigation"):
		fork_navigation.restore(state.fork_navigation)
		_sync_fork_collisions()
	player.refresh_authority_presentation()

func _advance_player_local(delta: float) -> void:
	var remaining := delta
	while remaining > 0.000001:
		var dt := minf(remaining,1.0/120.0)
		_advance_fork_player(dt)
		player.position.x = clampf(player.position.x,30,23970)
		remaining -= dt

func _capture_enemy(id: String) -> Dictionary:
	var state: Dictionary = _enemy_states[id].duplicate(true)
	state.position = previews[id].position
	state.feedback = {}
	for key in ["motion_state","motion_velocity","motion_facing","animation_state","animation_elapsed","feedback_remaining","_frame_clock","_frame_index","_idle_clock","_idle_index"]:
		state.feedback[key] = previews[id].get(key)
	if previews[id].continuous_motion != null: state.rig = _capture_rig(previews[id].continuous_motion)
	return state

func _restore_enemy(id: String,state: Dictionary) -> void:
	_enemy_states[id] = state.duplicate(true)
	var actor = previews[id]
	actor.position = state.position
	if state.has("feedback"):
		for key in state.feedback: actor.set(key,state.feedback[key])
	else: actor.set_motion_state("idle",state.velocity,state.facing)
	if actor.continuous_motion != null and state.has("rig"):
		_restore_rig(actor.continuous_motion,state.rig)

func _capture_rig(rig) -> Dictionary:
	var value := {}
	for key in ["clock","phase","state","speed","facing","state_time","movement_blend","vertical_speed","authority_pulse"]:
		value[key] = rig.get(key)
	if rig is PixelActor:
		value["transition"] = rig.transition
		value["transition_time"] = rig.transition_time
	return value

func _restore_rig(rig,value: Dictionary) -> void:
	for key in value: rig.set(key,value[key])
	# Restore has no simulation delta. Resample the recorded mesh or authored frame.
	rig.visual_accumulator = 1.0
	rig._sample()

func _advance_enemy(id: String,delta: float) -> void:
	var actor = previews[id]
	if delta <= 0 or not actor.visible or absf(actor.position.x-player.position.x)>1800: return
	# All hostile simulation, hit resolution and animation share this local clock.
	var remaining := delta
	while remaining > 0.000001 and not paused:
		var step := minf(remaining,1.0/120.0)
		_step_enemy(id,step)
		remaining -= step
	actor.modulate.a = 0.9

func _enemy_surface(origin: Vector2) -> PackedVector2Array:
	var best := Map.ground_points()
	var best_distance := absf(_surface_y(best,origin.x)-origin.y)
	for entry in terrain:
		var points: PackedVector2Array = entry.points
		if origin.x < points[0].x or origin.x > points[-1].x: continue
		var distance := absf(_surface_y(points,origin.x)-origin.y)
		if distance < best_distance:
			best = points
			best_distance = distance
	return best

func _surface_y(points: PackedVector2Array,x: float) -> float:
	for i in range(points.size()-1):
		if x >= points[i].x and x <= points[i+1].x:
			return lerpf(points[i].y,points[i+1].y,(x-points[i].x)/(points[i+1].x-points[i].x))
	return INF

func _enemy_bounds(state: Dictionary) -> Vector2:
	var points: PackedVector2Array = state.surface
	var bounds := Vector2(maxf(points[0].x+28,float(state.origin.x)-650),minf(points[-1].x-28,float(state.origin.x)+650))
	for gate in _gates:
		if _gate_open(gate): continue
		if float(gate.x)<float(state.origin.x): bounds.x = maxf(bounds.x,float(gate.x)+42)
		else: bounds.y = minf(bounds.y,float(gate.x)-42)
	return bounds

func _enemy_transition(id: String,next: String) -> void:
	var state: Dictionary = _enemy_states[id]
	state.state = next
	state.state_time = 0.0
	state.velocity = Vector2.ZERO
	if next == "windup":
		state.facing = 1.0 if player.position.x>=previews[id].position.x else -1.0
		_enemy_attack_serials[id] += 1
		state.serial = _enemy_attack_serials[id]
		state.hit = false
	if next in ["windup","strike","recover"]:
		previews[id].play_animation("attack" if next == "strike" else next)

func _step_enemy(id: String,delta: float) -> void:
	var actor = previews[id]
	var state: Dictionary = _enemy_states[id]
	state.state_time += delta
	var bounds := _enemy_bounds(state)
	var player_surface := _surface_y(state.surface,player.position.x)
	var same_layer := is_finite(player_surface) and absf(player.position.y-player_surface)<100.0
	var visible_player: bool = same_layer and player.position.x>=bounds.x and player.position.x<=bounds.y and absf(player.position.x-actor.position.x)<=580.0
	var distance: float = player.position.x-actor.position.x
	state.velocity = Vector2.ZERO
	match str(state.state):
		"patrol":
			if visible_player: _enemy_transition(id,"chase")
			else:
				var left := maxf(bounds.x,float(state.origin.x)-170)
				var right := minf(bounds.y,float(state.origin.x)+170)
				if actor.position.x<=left: state.patrol_direction = 1.0
				elif actor.position.x>=right: state.patrol_direction = -1.0
				state.velocity.x = float(state.patrol_direction)*48.0
		"chase":
			if not visible_player: _enemy_transition(id,"leash")
			elif absf(distance)<=125.0: _enemy_transition(id,"windup")
			else:
				state.facing = signf(distance)
				state.velocity.x = float(state.facing)*(62.0 if id=="boss" else 82.0)
		"windup":
			if float(state.state_time)>=0.65: _enemy_transition(id,"strike")
		"strike":
			if not state.hit and float(state.state_time)>=0.08:
				# Low directional swipe: jumping clear or crossing behind avoids it.
				state.hit = true
				var left: float = actor.position.x+20 if state.facing>0 else actor.position.x-165
				var swipe := Rect2(left,actor.position.y-75,145,65)
				if same_layer and player.position.x>=bounds.x and player.position.x<=bounds.y and swipe.intersects(get_player_hitbox()):
					enemy_attack_hit.emit(id,id+":"+str(state.serial),2 if id=="tutorial" else 3)
					if paused: return
			if float(state.state_time)>=0.32: _enemy_transition(id,"recover")
		"recover":
			if float(state.state_time)>=0.75: _enemy_transition(id,"chase" if visible_player else "leash")
		"leash":
			if visible_player: _enemy_transition(id,"chase")
			elif absf(actor.position.x-float(state.origin.x))<4: _enemy_transition(id,"patrol")
			else:
				state.facing = signf(float(state.origin.x)-actor.position.x)
				state.velocity.x = float(state.facing)*65.0
	var next_x := clampf(actor.position.x+float(state.velocity.x)*delta,bounds.x,bounds.y)
	actor.position = Vector2(next_x,_surface_y(state.surface,next_x))
	var motion := "walk" if absf(state.velocity.x)>0.1 else "idle"
	if state.state in ["windup","strike","recover"]:
		motion = "attack" if state.state == "strike" else str(state.state)
	actor.set_motion_state(motion,state.velocity,state.facing)
	actor.advance(delta)

func has_hostile_attention() -> bool:
	for id in _enemy_states:
		if previews[id].visible and _enemy_states[id].state in ["chase","windup","strike","recover"]: return true
	return false

func reset_enemy_encounters() -> void:
	for id in _enemy_initial:
		_enemy_attack_serials[id] = 0
		_restore_enemy(id,_enemy_initial[id].duplicate(true))
		temporal.reset_target_history("enemy_"+id)

func proximity_fork() -> Dictionary:
	if paused or player == null or active_encounter != "": return {"visible":false,"route_active":not fork_navigation.active.is_empty()}
	var value: Dictionary = fork_navigation.proximity(player.position,player.grounded)
	value["route_active"] = not fork_navigation.active.is_empty()
	return value

func choose_branch(direction: int) -> bool:
	var hint := proximity_fork()
	if player == null or not hint.get("visible",false): return false
	if not fork_navigation.begin(hint,direction,player.position): return false
	_sync_fork_collisions()
	player.set_input(float(fork_navigation.active.axis),false)
	branch_chosen.emit(str(hint.id),direction)
	return true

func _sync_fork_collisions() -> void:
	if player == null: return
	for id in _fork_bodies:
		for body in _fork_bodies[id]:
			if fork_navigation.selected.has(id): player.remove_collision_exception_with(body)
			else: player.add_collision_exception_with(body)

func _advance_fork_player(delta: float) -> void:
	if paused: return
	if not fork_navigation.active.is_empty():
		player.set_input(float(fork_navigation.active.axis),false)
	player.advance(delta)
	if fork_navigation.active.is_empty():
		if fork_navigation.release_departed(player.position,player.grounded): _sync_fork_collisions()
		return
	var route: Dictionary = fork_navigation.active
	if (player.position.x-float(route.target_x))*float(route.axis)>=0 and player.grounded:
		if route.lower: fork_navigation.selected.erase(route.id)
		fork_navigation.cancel()
		_sync_fork_collisions()
		player.set_input(fork_navigation.manual_axis,false)

func is_branch_travelling() -> bool:
	return not fork_navigation.active.is_empty()
