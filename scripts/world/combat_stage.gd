extends Node2D
## Reusable visual battle adapter; owns no combat values and writes no saves.
signal target_selected(id: String)
signal presentation_event(event: Dictionary)

const Actor = preload("res://scripts/world/combat_actor.gd")
const EnvironmentMotion = preload("res://scripts/world/environment_motion.gd")
const AuthorityFX = preload("res://scripts/world/time_authority_fx.gd")
const FIELD := Rect2(0, 80, 1440, 488)
const APPROVED_PLAYER_SEED := "res://assets/moonli_battle_v1.png"
var actors: Dictionary = {}
var missing_assets: Array = []
var layers: Array[Sprite2D] = []
var camera: Camera2D
var encounter := ""
var snapshot: Dictionary = {}
var real_elapsed := 0.0
var battle_elapsed := 0.0
var _manifest: Dictionary = {}
var _retiring: Dictionary = {}
var _placements: Dictionary = {}
var _regular_slots: Dictionary = {}
var _anchor_slots: Dictionary = {}
var _configured := false
var environment_motion: Node2D
var authority_fx: Node2D
var _target_positions: Dictionary = {}

func _init() -> void:
	name = "CombatStage"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	camera = Camera2D.new()
	camera.name = "BattleCamera"
	camera.position = Vector2(720, 450)
	camera.position_smoothing_enabled = false
	add_child(camera)

func configure(value: String, assets: Dictionary) -> void:
	if environment_motion != null:
		_remove_node(environment_motion)
	environment_motion = null
	encounter = value
	_manifest = assets.duplicate(true)
	if authority_fx != null:
		_remove_node(authority_fx)
		authority_fx = null
	_target_positions.clear()
	if bool(_manifest.get("time_authority", false)):
		authority_fx = AuthorityFX.new()
		authority_fx.name = "TimeAuthority"
		authority_fx.z_index = 9
		add_child(authority_fx)
	_configured = true
	for actor in actors.values():
		_remove_node(actor)
	for entry in _retiring.values():
		_remove_node(entry.actor)
	actors.clear()
	_retiring.clear()
	_placements.clear()
	_regular_slots.clear()
	_anchor_slots.clear()
	for layer in layers:
		_remove_node(layer)
	layers.clear()
	missing_assets.clear()
	real_elapsed = 0.0
	battle_elapsed = 0.0
	var info: Dictionary = _encounter_manifest()
	var descriptions: Array = info.get("layers", _manifest.get("layers", []))
	if descriptions.is_empty():
		_missing("scene:" + encounter)
	for i in descriptions.size():
		var description: Dictionary = descriptions[i]
		var texture := _texture(description.get("texture"))
		if texture == null:
			_missing("layer:" + str(description.get("id", i)))
			continue
		var layer := Sprite2D.new()
		layer.name = "Layer_" + str(i)
		layer.texture = texture
		layer.z_index = int(description.get("z_index", -20 + i))
		layer.position = _vector(description.get("position"), FIELD.get_center())
		if description.has("scale"):
			layer.scale = _vector(description.scale, Vector2.ONE)
		elif description.has("size"):
			layer.scale = _vector(description.size, FIELD.size) / texture.get_size()
		else:
			layer.scale = FIELD.size / texture.get_size()
		layer.centered = bool(description.get("centered", true))
		add_child(layer)
		layers.append(layer)
		if bool(_manifest.get("ambient_motion", false)):
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/courtyard_motion.gdshader")
			layer.material = material
	if bool(_manifest.get("ambient_motion", false)):
		environment_motion = EnvironmentMotion.new()
		environment_motion.z_index = -10
		add_child(environment_motion)
	# No procedural background or replacement enemy art is created when a slot is missing.

func sync_snapshot(value: Dictionary) -> void:
	if not _configured:
		configure("", {})
	snapshot = value.duplicate(true)
	var living := {"player": true}
	var player: Dictionary = _manifest.get("player", {"texture": APPROVED_PLAYER_SEED})
	_sync_actor("player", {"id":"player", "hp":value.get("hp", 50), "max_hp":value.get("max_hp", 50)}, player, Vector2(270, 552), 217.0, 300.0)
	if authority_fx != null:
		var visual_height: float = actors.player.get_visual_height()
		authority_fx.set_source(actors.player.position + Vector2(-35, -visual_height * 0.62), visual_height)
	var enemies: Array = value.get("enemies", [])
	var count := enemies.size()
	var regular_count := 0
	for enemy in enemies:
		if not enemy.get("is_anchor", false) and enemy.get("kind", "") != "boss":
			regular_count += 1
	for i in count:
		var enemy: Dictionary = enemies[i]
		var id := str(enemy.get("id", ""))
		if id == "" or id == "player":
			continue
		living[id] = true
		var placement := _placement(enemy, regular_count)
		_sync_actor(id, enemy, _enemy_asset(enemy), placement.position, placement.height, placement.width)
	for id in actors.keys():
		if not living.has(id):
			var actor = actors[id]
			actors.erase(id)
			_regular_slots.erase(id)
			_anchor_slots.erase(id)
			actor.set_interactive(false)
			if actor.has_art:
				actor.play_animation("defeat")
				_retiring[id] = {"actor": actor, "remaining": 0.65}
			else:
				_remove_node(actor)
	if value.get("status", "") == "lost" and actors.player.animation_state != "defeat":
		actors.player.play_animation("defeat")

func consume_events(events: Array) -> void:
	for raw in events:
		if not raw is Dictionary:
			continue
		var event: Dictionary = raw
		var type := str(event.get("type", ""))
		var target := str(event.get("target", ""))
		if authority_fx != null:
			var destination: Vector2 = _target_positions.get(target, authority_fx.source)
			if type == "cast":
				authority_fx.cast(target, destination)
			elif type in ["hit", "burn"]:
				if target != "player" and target != "" and not authority_fx.has_beam(target):
					authority_fx.cast(target, destination)
				authority_fx.impact(target, destination)
		var actor = actors.get(target, null)
		if actor == null and _retiring.has(target):
			actor = _retiring[target].actor
		match type:
			"cast":
				if actors.has("player"):
					actors.player.play_animation("cast")
			"hit":
				if actor != null and actor.animation_state != "defeat":
					actor.play_animation("hurt")
			"death":
				if actor != null:
					actor.play_animation("defeat")
			"loss":
				if actors.has("player"):
					actors.player.play_animation("defeat")
			"phase":
				for active in actors.values():
					if active.snapshot.get("kind", "") == "boss":
						active.play_animation("cast")
		# Events have no attacker field. Incoming hits cannot infer an enemy cast actor.
		presentation_event.emit(event.duplicate(true))

func advance(real_delta: float, battle_delta: float) -> void:
	real_elapsed += maxf(0.0, real_delta)
	battle_elapsed += maxf(0.0, battle_delta)
	if environment_motion != null:
		environment_motion.advance(maxf(0.0, battle_delta))
		for layer in layers:
			if layer.material is ShaderMaterial:
				layer.material.set_shader_parameter("battle_time", battle_elapsed)
	if authority_fx != null:
		authority_fx.advance(maxf(0.0, battle_delta))
	for actor in actors.values():
		actor.advance(maxf(0.0, battle_delta))
	for id in _retiring.keys():
		var entry: Dictionary = _retiring[id]
		entry.actor.advance(maxf(0.0, battle_delta))
		entry.remaining -= maxf(0.0, battle_delta)
		if entry.remaining <= 0.0:
			_remove_node(entry.actor)
			_retiring.erase(id)

func get_target_rect(id: String) -> Rect2:
	if not actors.has(id):
		return Rect2()
	return actors[id].get_target_rect().intersection(FIELD)

func _sync_actor(id: String, data: Dictionary, asset: Dictionary, place: Vector2, height: float, width: float) -> void:
	if not actors.has(id):
		if _retiring.has(id):
			_remove_node(_retiring[id].actor)
			_retiring.erase(id)
		var resolved := asset.duplicate(true)
		resolved["texture"] = _texture(asset.get("texture"))
		resolved["sprite_frames"] = _sprite_frames(asset.get("sprite_frames"))
		var actor = Actor.new()
		actor.name = "Actor_" + id
		actor.z_index = 10
		add_child(actor)
		actor.configure(id, resolved, minf(360, float(asset.get("height", height))), width)
		actor.selected.connect(func(selected_id: String): target_selected.emit(selected_id))
		actors[id] = actor
		if not actor.has_art:
			_missing("actor:" + id + ":" + str(data.get("kind", "player")))
		else:
			var missing_states: Array[String] = []
			for state in ["idle", "cast", "hurt", "defeat"]:
				if not actor.has_animation(state):
					missing_states.append(state)
			if not missing_states.is_empty():
				_missing("animation:" + id + ":" + ",".join(missing_states))
	var actor = actors[id]
	actor.fit_dimensions(minf(360, float(asset.get("height", height))), width)
	actor.position = _vector(asset.get("position"), place)
	actor.position.x = clampf(actor.position.x, 160, 1280)
	actor.position.y = clampf(actor.position.y, 440, 558)
	# action_index is authoritative and is the only available enemy-action identity.
	# Seed the first snapshot without playing a fictitious attack.
	if actor.snapshot.has("action_index") and int(data.get("action_index", 0)) > int(actor.snapshot.action_index):
		actor.play_animation("attack" if actor.has_animation("attack") else "cast")
	actor.sync(data)
	_target_positions[id] = actor.get_visual_center()

func _placement(enemy: Dictionary, regular_count: int) -> Dictionary:
	var id := str(enemy.id)
	if _placements.has(id):
		return _placements[id]
	var result: Dictionary
	if enemy.get("kind", "") == "boss":
		result = {"position":Vector2(1030, 552), "height":320.0, "width":330.0}
	elif enemy.get("is_anchor", false):
		var slot := _first_free_slot(_anchor_slots)
		_anchor_slots[id] = slot
		var x := 750.0 if slot % 2 == 0 else 1270.0
		var y := 552.0 - (slot / 2) * 165.0
		result = {"position":Vector2(x, y), "height":145.0, "width":120.0}
	else:
		var slot := _first_free_slot(_regular_slots)
		_regular_slots[id] = slot
		var spacing := 500.0 / maxf(1.0, regular_count - 1.0)
		var x := 1030.0 if regular_count == 1 else 740.0 + slot * spacing
		var width := minf(300.0, spacing * 0.86) if regular_count > 1 else 330.0
		result = {"position":Vector2(x, 552), "height":245.0, "width":width}
	_placements[id] = result
	return result

func _first_free_slot(slots: Dictionary) -> int:
	var slot := 0
	while slots.values().has(slot):
		slot += 1
	return slot

func _enemy_asset(enemy: Dictionary) -> Dictionary:
	var id := str(enemy.id)
	var kind := str(enemy.get("kind", ""))
	var mappings: Dictionary = _encounter_manifest().get("enemies", {})
	var key := str(mappings.get(id, mappings.get(kind, kind)))
	var catalog: Dictionary = _manifest.get("enemies", {})
	var entry = catalog.get(id, catalog.get(key, _manifest.get(id, {})))
	if entry is Dictionary:
		return entry
	if entry is Texture2D or entry is String:
		return {"texture":entry}
	return {}

func _encounter_manifest() -> Dictionary:
	return _manifest.get("encounters", {}).get(encounter, {})

func _texture(value: Variant) -> Texture2D:
	if value is Texture2D:
		return value
	if value is String and value != "" and ResourceLoader.exists(value):
		return load(value) as Texture2D
	return null

func _sprite_frames(value: Variant) -> SpriteFrames:
	if value is SpriteFrames:
		return value
	if value is String and value != "" and ResourceLoader.exists(value):
		return load(value) as SpriteFrames
	return null

func _vector(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback

func _missing(key: String) -> void:
	if not missing_assets.has(key):
		missing_assets.append(key)

func _remove_node(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()


