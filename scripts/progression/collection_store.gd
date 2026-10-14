extends RefCounted

var save_path = "user://chapter_one.json"
var data: Dictionary = {}
var last_error = ""

const TIME_RULESET = "time_authority_v2"
const TIME_SOURCE = "authority:stalled_device"
const AUTHORITY_FIELDS = ["authority_collection", "authority_equipped_ids", "authority_granted", "active_ruleset", "claimed_rewards"]

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
	# Saves from any other ruleset are discarded; there are no players to migrate.
	if str(loaded.get("active_ruleset", "")) != TIME_RULESET: loaded = {}
	var candidate = loaded.duplicate(true)
	for field in ["claimed_rewards", "authority_collection", "authority_equipped_ids"]:
		if not candidate.has(field): candidate[field] = []
	if not candidate.has("authority_granted"): candidate["authority_granted"] = false
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

func save_metadata(metadata: Dictionary) -> bool:
	var candidate = data.duplicate(true)
	for key in metadata:
		if key in AUTHORITY_FIELDS: continue
		# A chosen record cannot be changed by a subsequent expedition.
		if key == "record_choice" and not str(candidate.get(key, "")).is_empty(): continue
		candidate[key] = metadata[key]
	return _commit(candidate)

func commit_exploration(run: Dictionary, checkpoint: Dictionary, metadata: Dictionary = {}) -> bool:
	# Metadata and the exploration checkpoint are one write.
	var candidate = data.duplicate(true)
	for key in metadata:
		if key in AUTHORITY_FIELDS: continue
		if key == "record_choice" and not str(candidate.get(key, "")).is_empty(): continue
		candidate[key] = metadata[key]
	candidate["exploration_run"] = run.duplicate(true)
	candidate["exploration_checkpoint"] = checkpoint.duplicate(true)
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
