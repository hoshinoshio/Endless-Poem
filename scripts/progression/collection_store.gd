extends RefCounted

const VALID_TYPES = ["fire", "shield", "charge", "ember", "ignite", "ember_shield", "heavy_shield", "echo", "delay"]
const STARTER_TYPES = ["fire", "fire", "fire", "fire", "shield", "shield", "shield", "shield", "charge", "charge"]
var save_path = "user://chapter_one.json"
var data: Dictionary = {}
var last_error = ""
var collection: Array:
	get: return data.get("collection", []).duplicate(true)
var equipped_ids: Array:
	get: return data.get("equipped_ids", []).duplicate()
var claimed_rewards: Array:
	get: return data.get("claimed_rewards", []).duplicate()

const TIME_RULESET = "time_authority_v2"
const TIME_SOURCE = "authority:stalled_device"
const AUTHORITY_FIELDS = ["authority_collection", "authority_equipped_ids", "authority_granted", "active_ruleset"]

func initialize_time_authority(path: String = "") -> bool:
	if not path.is_empty(): save_path = path
	var absolute = ProjectSettings.globalize_path(save_path)
	if not FileAccess.file_exists(absolute) and FileAccess.file_exists(absolute + ".bak"):
		DirAccess.rename_absolute(absolute + ".bak", absolute)
	var loaded: Dictionary = {}
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		if file == null:
			last_error = "无法读取存档"
			return false
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if not parsed is Dictionary:
			last_error = "存档格式无效，原文件已保留"
			return false
		loaded = parsed.duplicate(true)
	var candidate = loaded.duplicate(true)
	# Preserve legacy entities and all metadata verbatim; new cards have their own namespace.
	for field in ["collection", "equipped_ids", "claimed_rewards", "authority_collection", "authority_equipped_ids"]:
		if not candidate.has(field): candidate[field] = []
	if not candidate.has("authority_granted"): candidate["authority_granted"] = false
	if str(candidate.get("active_ruleset", "")) != TIME_RULESET:
		if candidate.has("exploration_run"):
			candidate["archive_exploration_run"] = candidate["exploration_run"].duplicate(true)
		if candidate.has("exploration_checkpoint"):
			candidate["archive_exploration_checkpoint"] = candidate["exploration_checkpoint"].duplicate(true)
		candidate["exploration_run"] = {}
		candidate["exploration_checkpoint"] = {}
		candidate["active_ruleset"] = TIME_RULESET
	if candidate != loaded and not _write(candidate):
		data = loaded
		return false
	data = candidate
	last_error = ""
	return true

func get_authority_loadout() -> Array:
	var by_id: Dictionary = {}
	for card in data.get("authority_collection", []):
		by_id[str(card.get("id", ""))] = card
	var result: Array = []
	for id in data.get("authority_equipped_ids", []):
		if by_id.has(id): result.append(by_id[id].duplicate(true))
	return result

func unlock_time_authority(run: Dictionary, checkpoint: Dictionary) -> bool:
	if str(data.get("active_ruleset", "")) != TIME_RULESET:
		last_error = "时间权柄存档尚未初始化"
		return false
	# Idempotent retries must not roll a later checkpoint back to the repair device.
	if bool(data.get("authority_granted", false)):
		last_error = ""
		return true
	var candidate = data.duplicate(true)
	candidate["authority_collection"] = [
		{"id": "stop", "type": "stop", "title": "停止时间", "source": TIME_SOURCE},
		{"id": "fast_forward", "type": "fast_forward", "title": "快进时间", "source": TIME_SOURCE},
		{"id": "reverse", "type": "reverse", "title": "倒退时间", "source": TIME_SOURCE},
	]
	candidate["authority_equipped_ids"] = ["stop", "fast_forward", "reverse"]
	candidate["authority_granted"] = true
	if not candidate["claimed_rewards"].has(TIME_SOURCE): candidate["claimed_rewards"].append(TIME_SOURCE)
	var repaired_run = run.duplicate(true)
	var repaired_checkpoint = checkpoint.duplicate(true)
	for value in [repaired_run, repaired_checkpoint]:
		value["authority_unlocked"] = true
		value["authority_granted"] = true
	candidate["exploration_run"] = repaired_run
	candidate["exploration_checkpoint"] = repaired_checkpoint
	return _commit(candidate)

func initialize(path: String = "") -> bool:
	if not path.is_empty(): save_path = path
	var absolute = ProjectSettings.globalize_path(save_path)
	# A backup exists only while replacement is in flight; recover after interruption.
	if not FileAccess.file_exists(absolute) and FileAccess.file_exists(absolute + ".bak"):
		DirAccess.rename_absolute(absolute + ".bak", absolute)
	var loaded: Dictionary = {}
	if FileAccess.file_exists(save_path):
		var f = FileAccess.open(save_path, FileAccess.READ)
		if f == null:
			last_error = "无法读取存档"
			return false
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if not parsed is Dictionary:
			last_error = "存档格式无效，原文件已保留"
			return false
		loaded = parsed.duplicate(true)
	var candidate = loaded.duplicate(true)
	candidate["collection"] = _valid_collection(candidate.get("collection", []))
	candidate["claimed_rewards"] = _unique_strings(candidate.get("claimed_rewards", []))
	if not candidate.get("starter_granted", false):
		# Legacy progress has no persistent collection. Grant and save the ten entities once.
		for type in STARTER_TYPES:
			candidate.collection.append({"id": _next_id(candidate), "type": type})
		candidate["starter_granted"] = true
		candidate["equipped_ids"] = candidate.collection.map(func(card): return card.id)
		if not candidate.claimed_rewards.has("initial:starter_v1"):
			candidate.claimed_rewards.append("initial:starter_v1")
	candidate["equipped_ids"] = _valid_equipped(candidate.get("equipped_ids", []), candidate.collection)
	candidate["schema_version"] = 3
	if candidate != loaded:
		if not _write(candidate):
			data = loaded
			return false
	data = candidate
	last_error = ""
	return true

func claim_reward(source: String, type: String) -> bool:
	if source.is_empty() or not VALID_TYPES.has(type):
		last_error = "奖励来源或卡牌无效"
		return false
	if claimed_rewards.has(source):
		last_error = "该来源已领取"
		return false
	var candidate = data.duplicate(true)
	candidate.collection.append({"id": _next_id(candidate), "type": type})
	candidate.claimed_rewards.append(source)
	# The new entity and its source marker are one transaction; equipment stays as chosen.
	return _commit(candidate)

func set_equipped(ids: Array) -> bool:
	var clean = _valid_equipped(ids, collection)
	if clean.size() != ids.size():
		last_error = "装备包含重复或不存在的实体"
		return false
	var candidate = data.duplicate(true)
	candidate["equipped_ids"] = clean
	return _commit(candidate)

func save_metadata(metadata: Dictionary) -> bool:
	var candidate = data.duplicate(true)
	for key in metadata:
		if key in AUTHORITY_FIELDS: continue
		if key in ["collection", "equipped_ids", "claimed_rewards", "starter_granted", "next_id", "schema_version"]: continue
		# A chosen record cannot be changed by a subsequent expedition.
		if key == "record_choice" and not str(candidate.get(key, "")).is_empty(): continue
		candidate[key] = metadata[key]
	return _commit(candidate)

func get_loadout() -> Array:
	var by_id = {}
	for card in collection: by_id[card.id] = card
	var result = []
	for id in equipped_ids:
		if by_id.has(id): result.append(by_id[id].duplicate())
	return result

func commit_exploration(run: Dictionary, checkpoint: Dictionary, metadata: Dictionary = {}, source: String = "", card_type: String = "") -> bool:
	# Currency, source marker, permanent entity and exploration checkpoint are one write.
	var candidate = data.duplicate(true)
	if not source.is_empty():
		if not VALID_TYPES.has(card_type) or candidate.claimed_rewards.has(source):
			last_error = "该来源已领取或卡牌无效"
			return false
		candidate.collection.append({"id": _next_id(candidate), "type": card_type})
		candidate.claimed_rewards.append(source)
	if int(run.get("coins", 0)) < 0:
		last_error = "结晶不足"
		return false
	for key in metadata:
		if key in AUTHORITY_FIELDS: continue
		if key in ["collection", "equipped_ids", "claimed_rewards", "starter_granted", "next_id", "schema_version"]: continue
		if key == "record_choice" and not str(candidate.get(key, "")).is_empty(): continue
		candidate[key] = metadata[key]
	candidate["exploration_run"] = run.duplicate(true)
	candidate["exploration_checkpoint"] = checkpoint.duplicate(true)
	candidate["schema_version"] = 3
	return _commit(candidate)

func _commit(candidate: Dictionary) -> bool:
	if not _write(candidate): return false
	data = candidate
	last_error = ""
	return true

func _write(candidate: Dictionary) -> bool:
	var absolute = ProjectSettings.globalize_path(save_path)
	var temporary = absolute + ".tmp"
	var backup = absolute + ".bak"
	var f = FileAccess.open(temporary, FileAccess.WRITE)
	if f == null:
		last_error = "存档写入失败：%s" % error_string(FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(candidate))
	f.flush()
	var write_error = f.get_error()
	f.close()
	if write_error != OK:
		last_error = "存档写入失败：%s" % error_string(write_error)
		DirAccess.remove_absolute(temporary)
		return false
	var had_previous = FileAccess.file_exists(absolute)
	if had_previous:
		if FileAccess.file_exists(backup): DirAccess.remove_absolute(backup)
		var backup_error = DirAccess.rename_absolute(absolute, backup)
		if backup_error != OK:
			last_error = "旧存档无法安全备份"
			DirAccess.remove_absolute(temporary)
			return false
	var replace_error = DirAccess.rename_absolute(temporary, absolute)
	if replace_error != OK:
		if had_previous: DirAccess.rename_absolute(backup, absolute)
		DirAccess.remove_absolute(temporary)
		last_error = "存档替换失败：%s" % error_string(replace_error)
		return false
	if had_previous: DirAccess.remove_absolute(backup)
	return true

func _next_id(candidate: Dictionary) -> String:
	var serial = int(candidate.get("next_id", 1))
	var existing = candidate.collection.map(func(card): return card.id)
	while existing.has("card_%06d" % serial): serial += 1
	candidate["next_id"] = serial + 1
	return "card_%06d" % serial

func _valid_collection(value) -> Array:
	var result = []
	var seen = []
	if not value is Array: return result
	for card in value:
		if card is Dictionary and card.has("id") and card.has("type") and VALID_TYPES.has(str(card.type)):
			var id = str(card.id)
			if not id.is_empty() and not seen.has(id):
				seen.append(id)
				result.append({"id": id, "type": str(card.type)})
	return result

func _unique_strings(value) -> Array:
	var result = []
	if value is Array:
		for item in value:
			if not str(item).is_empty() and not result.has(str(item)): result.append(str(item))
	return result

func _valid_equipped(value, owned: Array) -> Array:
	var available = owned.map(func(card): return card.id)
	var result = []
	for id in _unique_strings(value):
		if available.has(id): result.append(id)
	return result
