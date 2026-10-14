extends Node2D

# Explicitly supplied, approved assets are the only way to enable this presenter.
# Test textures live in tests; no procedural character or scenery fallback is used.
signal target_selected(id: String)

const Stage = preload("res://scripts/world/combat_stage.gd")
var stage
var missing_assets: Array = []
var last_snapshot: Dictionary = {}
var last_battle_delta := 0.0

func configure(encounter: String, assets: Dictionary, state: Dictionary) -> bool:
	missing_assets = validate_assets(encounter, assets, state)
	if not missing_assets.is_empty(): return false
	stage = Stage.new()
	add_child(stage)
	stage.configure(encounter, assets)
	stage.sync_snapshot(state)
	missing_assets = stage.missing_assets.duplicate()
	var required_missing := missing_assets.filter(func(key): return not str(key).begins_with("animation:"))
	if not required_missing.is_empty():
		remove_child(stage)
		stage.queue_free()
		stage = null
		return false
	stage.target_selected.connect(func(id): target_selected.emit(str(id)))
	last_snapshot = state.duplicate(true)
	return true

func validate_assets(encounter: String, assets: Dictionary, state: Dictionary) -> Array:
	var missing: Array = []
	if not _actor_has_art(assets.get("player", {})): missing.append("player")
	var encounters = assets.get("encounters", {})
	var config: Dictionary = encounters.get(encounter, {}) if encounters is Dictionary else {}
	var layers = config.get("layers", [])
	if not layers is Array or layers.is_empty():
		missing.append("encounters/%s/layers" % encounter)
	else:
		for i in layers.size():
			if not layers[i] is Dictionary or not _is_texture(layers[i].get("texture")):
				missing.append("encounters/%s/layers/%d" % [encounter, i])
	var enemy_assets = assets.get("enemies", {})
	var mapping = config.get("enemies", {})
	var needs_anchor := false
	for enemy in state.get("enemies", []):
		var kind := str(enemy.get("kind", ""))
		var key := str(mapping.get(str(enemy.id), mapping.get(kind, kind))) if mapping is Dictionary else kind
		var entry = enemy_assets.get(str(enemy.id), enemy_assets.get(key, {})) if enemy_assets is Dictionary else {}
		if not _actor_has_art(entry):
			missing.append("enemies/" + key)
		if kind in ["boss", "instrument"]: needs_anchor = true
	# These battles create targets later. Validate their art before accepting a
	# manifest, so a playable stage cannot silently lose a spawned time anchor.
	if needs_anchor and (not enemy_assets is Dictionary or not _actor_has_art(enemy_assets.get("anchor", {}))):
		missing.append("enemies/anchor")
	return missing

func _is_texture(value) -> bool:
	if value is Texture2D: return value.get_width() > 0 and value.get_height() > 0
	if value is String and not value.is_empty() and ResourceLoader.exists(value):
		var resource = load(value)
		return resource is Texture2D and resource.get_width() > 0 and resource.get_height() > 0
	return false

func _actor_has_art(config) -> bool:
	if _is_texture(config): return true
	if not config is Dictionary: return false
	if _is_texture(config.get("texture")): return true
	var frames = config.get("sprite_frames")
	if frames is String and not frames.is_empty() and ResourceLoader.exists(frames): frames = load(frames)
	if not frames is SpriteFrames: return false
	if frames.has_animation(&"idle"):
		for i in frames.get_frame_count(&"idle"):
			if _is_texture(frames.get_frame_texture(&"idle", i)): return true
	return false

func sync_snapshot(state: Dictionary) -> void:
	last_snapshot = state.duplicate(true)
	if is_instance_valid(stage): stage.sync_snapshot(state)

func consume_events(events: Array) -> void:
	if is_instance_valid(stage): stage.consume_events(events)

func advance(real_delta: float, battle_delta: float) -> void:
	last_battle_delta = maxf(0.0, battle_delta)
	if is_instance_valid(stage): stage.advance(real_delta, last_battle_delta)

func get_target_rect(id: String) -> Rect2:
	return stage.get_target_rect(id) if is_instance_valid(stage) else Rect2()

func get_status_rect(enemy: Dictionary) -> Rect2:
	if str(enemy.get("kind", "")) == "boss": return Rect2(430, 143, 580, 48)
	var target := get_target_rect(str(enemy.id))
	var width := 225.0
	var height := 78.0
	if enemy.get("is_anchor", false):
		width = 220.0
		height = 55.0
	return Rect2(clampf(target.get_center().x - width * 0.5, 10.0, 1430.0 - width), maxf(82.0, target.position.y - height - 16.0), width, height)
