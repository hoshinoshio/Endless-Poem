extends Node2D
## Collision runtime sharing the exploration player, camera and combat clock.
signal target_clicked(id: String)
const EnemyBrain = preload("res://scripts/exploration/enemy_brain.gd")
const Actor = preload("res://scripts/world/combat_actor.gd")
const Assets = preload("res://scripts/visuals/chapter1_assets.gd")
const FX = preload("res://scripts/exploration/spatial_authority_fx.gd")
const AttackFX = preload("res://scripts/exploration/spatial_attack_fx.gd")
const STEP := 1.0/120.0
var model
var world
var active := false
var paused := false
var encounter := ""
var entities: Dictionary = {}
var retiring_actors: Array = []
var attacks: Array = []
var attack_trails: Array = []
var resolved_hits := 0
var missed_attacks := 0
var _spec: Dictionary = {}
var _assets: Dictionary = {}
var authority_fx
var attack_fx

func configure(combat_model, exploration_world) -> void:
	model = combat_model
	world = exploration_world
	_assets = Assets.build()
	authority_fx = FX.new()
	authority_fx.z_index = 9
	add_child(authority_fx)
	attack_fx = AttackFX.new()
	attack_fx.runtime = self
	attack_fx.z_index = 10
	add_child(attack_fx)

func start(id: String, config: Dictionary = {}) -> bool:
	if model == null or world == null:
		return false
	finish()
	_spec = world.get_encounter_spec(id)
	if _spec.is_empty():
		return false
	var options := config.duplicate(true)
	options["spatial_mode"] = true
	if not model.start_battle(id, options):
		return false
	encounter = id
	active = true
	paused = false
	resolved_hits = 0
	missed_attacks = 0
	world.set_encounter_active(id,true)
	world.set_paused(false)
	_sync_entities()
	return true

func set_paused(value: bool) -> void:
	paused = value
	if model != null: model.set_paused(value)
	if world != null: world.set_paused(value)

func finish(preserve_feedback: bool = false) -> void:
	if not preserve_feedback:
		for retired in retiring_actors: retired.actor.queue_free()
		retiring_actors.clear()
	for attack in attacks:
		if model != null: model.expire_spatial_action(attack.action_id)
	attacks.clear()
	attack_trails.clear()
	for entity in entities.values():
		entity.actor.queue_free()
	entities.clear()
	if active and world != null:
		if model.status == "won": world.finish_encounter(encounter)
		else: world.leave_encounter(encounter)
		world.set_paused(false)
	if authority_fx != null:
		authority_fx.beams.clear()
		authority_fx.pulses.clear()
		authority_fx.impacts.clear()
		authority_fx.sparks.clear()
	active = false

func advance(real_delta: float) -> void:
	if not active or paused or model.paused or model.status != "active":
		return
	var remaining := maxf(0,real_delta)
	while remaining > 0.000001 and model.status == "active":
		var step := minf(STEP,remaining)
		_prepare_windups()
		var before: float = model.time
		model.tick(step)
		var delta: float = model.time-before
		world.advance_simulation(delta)
		_sync_entities()
		_advance_entities(delta)
		for action in model.drain_spatial_actions(): _spawn_attack(action)
		var source := _player_casting_presentation()
		authority_fx.set_source(source.origin,source.height)
		authority_fx.advance(delta)
		_advance_attacks(delta)
		for trail in attack_trails: trail.fade -= delta
		attack_trails = attack_trails.filter(func(trail): return trail.fade > 0)
		remaining -= step
	attack_fx.queue_redraw()

func _sync_entities() -> void:
	var live: Dictionary = {}
	for enemy in model.enemies:
		live[enemy.id] = true
		if not entities.has(enemy.id):
			var actor = Actor.new()
			add_child(actor)
			var asset: Dictionary = _assets.enemies.get(enemy.kind,{})
			actor.configure(enemy.id,asset,float(asset.get("height",180)),340)
			actor.selected.connect(func(id): target_clicked.emit(id))
			var spawns: Array = _spec.get("spawns",[])
			var point: Vector2 = spawns[entities.size()%spawns.size()] if not spawns.is_empty() else _spec.rect.get_center()
			if enemy.is_anchor:
				point = Vector2(_spec.rect.get_center().x+(-170 if entities.size()%2==0 else 170),float(_spec.floor_y)-110)
			var brain = EnemyBrain.new()
			brain.configure(enemy.kind,entities.size())
			var bounds := _supported_bounds(point)
			point.x = clampf(point.x,bounds.x,bounds.y)
			entities[enemy.id] = {"actor":actor,"position":point,"locked":false,"direction":-1.0,"windup":false,"brain":brain,"bounds":bounds,"action_index":int(enemy.get("action_index",0))}
		var entity: Dictionary = entities[enemy.id]
		if int(enemy.get("action_index",0)) > int(entity.action_index) and enemy.kind in ["instrument","observer"]:
			entity.actor.play_animation("cast")
		entity.action_index = int(enemy.get("action_index",0))
		entities[enemy.id].actor.position = entities[enemy.id].position
		entities[enemy.id].actor.sync(enemy)
	for id in entities.keys():
		if not live.has(id):
			var actor = entities[id].actor
			actor.play_animation("defeat")
			var duration := 0.65
			if actor.continuous_motion is Actor.PixelActor:
				duration = maxf(duration,actor._pixel_duration("defeat"))
			retiring_actors.append({"actor":actor,"remaining":duration})
			entities.erase(id)

func present_event(event: Dictionary) -> void:
	if event.get("type","") == "hit" and entities.has(event.get("target","")):
		entities[event.target].actor.play_animation("hurt")

func advance_feedback(delta: float) -> void:
	# Retired actors have no model membership or hitbox; this clock is cosmetic.
	if (active and paused) or (world != null and world.get("paused") == true): return
	for retired in retiring_actors.duplicate():
		retired.actor.advance(maxf(0,delta))
		retired.remaining -= maxf(0,delta)
		if retired.remaining <= 0:
			retired.actor.queue_free()
			retiring_actors.erase(retired)

func _supported_bounds(point: Vector2) -> Vector2:
	var bounds := Vector2(_spec.rect.position.x+45,_spec.rect.end.x-45)
	# Keep feet on the flat authored segment that contains this spawn.
	# Test worlds without terrain retain their declared arena bounds.
	if not "terrain" in world: return bounds
	for entry in world.terrain:
		var points: PackedVector2Array = entry.points
		for i in range(points.size()-1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i+1]
			if absf(a.y-point.y) < 1.0 and absf(b.y-point.y) < 1.0 and point.x >= a.x and point.x <= b.x:
				return Vector2(maxf(bounds.x,a.x+24),minf(bounds.y,b.x-24))
	return bounds

func _prepare_windups() -> void:
	for enemy in model.enemies:
		if not entities.has(enemy.id): continue
		var entity: Dictionary = entities[enemy.id]
		entity.brain.prepare(entity.position,world.get_player_position(),float(enemy.duration)-float(enemy.charge),enemy.is_anchor)
		entity.locked = entity.brain.locked
		entity.windup = entity.brain.state == "telegraph"
		entity.direction = entity.brain.facing

func _advance_entities(delta: float) -> void:
	for enemy in model.enemies:
		var entity: Dictionary = entities[enemy.id]
		entity.position = entity.brain.advance(delta,entity.position,world.get_player_position(),entity.bounds,enemy.is_anchor)
		entity.locked = entity.brain.locked
		entity.windup = entity.brain.state == "telegraph"
		entity.direction = entity.brain.facing
		entity.actor.position = entity.position
		if entity.actor.has_method("set_motion_state"):
			entity.actor.set_motion_state(entity.brain.motion_state(),entity.brain.velocity,entity.direction)
		entity.actor.advance(delta)

func _player_casting_presentation() -> Dictionary:
	if "player" in world and world.player != null and world.player.has_method("casting_presentation"):
		return world.player.casting_presentation()
	return {"origin":world.get_player_position()+Vector2(0,-180),"height":217.0}

func _spawn_attack(action: Dictionary) -> void:
	var attack := action.duplicate(true)
	attack["age"] = 0.0
	if action.kind == "fire":
		if not entities.has(action.target):
			model.expire_spatial_action(action.action_id)
			return
		world.play_player_action("cast")
		var source := _player_casting_presentation()
		attack["origin"] = source.origin
		attack["end"] = get_target_world_position(action.target)
		attack["travel"] = 0.48
		authority_fx.set_source(attack.origin,source.height)
		authority_fx.cast(action.target,attack.end)
	else:
		var geometry: Dictionary = action.get("geometry",{})
		if geometry.is_empty():
			if not entities.has(action.attacker):
				model.expire_spatial_action(action.action_id)
				return
			var entity: Dictionary = entities[action.attacker]
			geometry = {"origin":entity.position,"direction":entity.direction,"bell":action.get("bell",false)}
			entity.brain.commit()
			entity.actor.play_animation("attack")
		attack["geometry"] = geometry
		attack["travel"] = 1.8 if geometry.get("bell",false) else 0.32
	attacks.append(attack)

func _enemy_rect(attack: Dictionary) -> Rect2:
	var geometry: Dictionary = attack.geometry
	var origin: Vector2 = geometry.origin
	var direction: float = geometry.direction
	if geometry.get("bell",false):
		var center := origin+Vector2(direction*float(attack.age)*640,-22)
		return Rect2(center-Vector2(42,22),Vector2(84,44))
	var center := origin+Vector2(direction*(80+float(attack.age)*300),-54)
	return Rect2(center-Vector2(65,42),Vector2(130,84))

func _advance_attacks(delta: float) -> void:
	for attack in attacks.duplicate():
		attack.age += delta
		var hit := false
		if attack.kind == "fire":
			if attack.age >= attack.travel and entities.has(attack.target):
				hit = _target_world_rect(attack.target).grow(12).has_point(attack.end)
		else:
			hit = _enemy_rect(attack).intersects(world.get_player_hitbox())
		if hit:
			if model.resolve_spatial_hit(attack.action_id,attack.get("geometry",{})):
				resolved_hits += 1
				if attack.kind == "fire":
					authority_fx.impact(attack.target,attack.end)
					present_event({"type":"hit","target":attack.target})
					_sync_entities()
				else:
					world.play_player_action("hurt")
					var trail: Dictionary = attack.duplicate(true)
					trail["fade"] = 0.24
					attack_trails.append(trail)
			attacks.erase(attack)
		elif attack.age >= attack.travel:
			model.expire_spatial_action(attack.action_id)
			missed_attacks += 1
			attacks.erase(attack)

func _target_world_rect(id: String) -> Rect2:
	if id == "player": return world.get_player_hitbox()
	if not entities.has(id): return Rect2()
	return entities[id].actor.get_target_rect()

func get_target_rect(id: String) -> Rect2:
	var rect := _target_world_rect(id)
	if rect.size == Vector2.ZERO: return Rect2()
	var transform := get_global_transform_with_canvas()*global_transform.affine_inverse()
	return Rect2(transform*rect.position,transform*rect.end-transform*rect.position).abs()

func get_target_world_position(id: String) -> Vector2:
	if id == "player": return world.get_player_hitbox().get_center()
	return _target_world_rect(id).get_center()

func presentation_state() -> Dictionary:
	var actors: Array = []
	for id in entities:
		actors.append({"id":id,"position":entities[id].position,"windup":entities[id].windup,"direction":entities[id].direction,"animated":not entities[id].actor.uses_static_seed,"ai_state":entities[id].brain.state,"state_time":entities[id].brain.state_time,"velocity":entities[id].brain.velocity,"motion_state":entities[id].brain.motion_state(),"bounds":entities[id].bounds})
	return {"active":active,"paused":paused,"encounter":encounter,"entities":actors,"attacks":attacks.duplicate(true),"hit_count":resolved_hits,"miss_count":missed_attacks,"authority":authority_fx.presentation_state() if authority_fx != null else {}}

