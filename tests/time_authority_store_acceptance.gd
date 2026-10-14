extends SceneTree
const Store = preload("res://scripts/progression/collection_store.gd")
var checks: int = 0
var failures: int = 0
var paths: Array = []

func verify(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error(label)

func fresh_path(label: String) -> String:
	var path = "user://authority_acceptance_%s_%s.json" % [label, Time.get_ticks_usec()]
	paths.append(path)
	return path

func _init() -> void:
	var path = fresh_path("fresh")
	var store = Store.new()
	verify(store.initialize_time_authority(path), "fresh authority initialization")
	verify(store.get_authority_loadout().is_empty() and store.collection.is_empty() and not store.data.authority_granted, "new game grants no old or time cards")
	var run = {"segment": "device", "coins": 0, "extra": {"proof": 17}}
	var checkpoint = {"segment": "device", "position": [12, 34]}
	verify(store.unlock_time_authority(run, checkpoint), "repair commits successfully")
	verify(store.get_authority_loadout().map(func(card): return card.id) == ["stop", "fast_forward", "reverse"], "repair grants exactly three independent time IDs")
	verify(store.data.exploration_run.authority_unlocked and store.data.exploration_checkpoint.authority_granted and store.data.exploration_run.extra.proof == 17, "repair flags and caller metadata saved together")
	verify(not run.has("authority_unlocked") and not checkpoint.has("authority_granted"), "caller dictionaries stay untouched")
	var reloaded = Store.new()
	verify(reloaded.initialize_time_authority(path) and reloaded.get_authority_loadout().size() == 3, "reload retains exactly three cards")
	reloaded.save_metadata({"exploration_run": {"segment": "later", "authority_unlocked": true, "authority_granted": true}})
	var before_retry = reloaded.data.duplicate(true)
	verify(reloaded.unlock_time_authority(run, checkpoint) and reloaded.data == before_retry, "duplicate repair does not duplicate or rewind progress")
	verify(reloaded.claimed_rewards.count("authority:stalled_device") == 1, "unique repair source marker")
	var legacy_path = fresh_path("legacy")
	var legacy_data = {"collection": [{"id": "old", "type": "fire", "custom": {"quality": 9}}], "equipped_ids": ["old"], "claimed_rewards": ["legacy:proof"], "evidence": ["star"], "chapter_complete": true, "record_choice": "retain", "intro_accepted": true, "exploration_run": {"segment": "legacy", "coins": 99}, "exploration_checkpoint": {"segment": "legacy", "position": [44, 55]}}
	var file = FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy_data))
	file.close()
	# JSON's numeric representation is floating point; compare against the same disk format.
	legacy_data = JSON.parse_string(JSON.stringify(legacy_data))
	var migrated = Store.new()
	verify(migrated.initialize_time_authority(legacy_path), "legacy migration succeeds")
	verify(migrated.collection == legacy_data.collection and migrated.equipped_ids == legacy_data.equipped_ids and migrated.claimed_rewards == legacy_data.claimed_rewards, "legacy entities including custom metadata preserved verbatim")
	verify(migrated.data.evidence == legacy_data.evidence and migrated.data.chapter_complete and migrated.data.record_choice == "retain" and migrated.data.intro_accepted, "evidence chapter record and intro preserved")
	verify(migrated.data.archive_exploration_run == legacy_data.exploration_run and migrated.data.archive_exploration_checkpoint == legacy_data.exploration_checkpoint and migrated.data.exploration_run.is_empty() and migrated.data.exploration_checkpoint.is_empty(), "old exploration archived and fresh active guide starts empty")
	migrated.save_metadata({"exploration_run": {"segment": "new"}})
	verify(migrated.initialize_time_authority(legacy_path) and migrated.data.exploration_run.segment == "new" and migrated.data.archive_exploration_run == legacy_data.exploration_run, "migration runs only once")
	var failing = Store.new()
	var failure_path = fresh_path("failure")
	failing.initialize_time_authority(failure_path)
	var before_failure = failing.data.duplicate(true)
	failing.save_path = "user://authority_missing_parent_%s/save.json" % Time.get_ticks_usec()
	verify(not failing.unlock_time_authority(run, checkpoint) and failing.data == before_failure and failing.get_authority_loadout().is_empty(), "failed write leaves no half grant in memory")
	var disk = Store.new()
	verify(disk.initialize_time_authority(failure_path) and not disk.data.authority_granted and disk.get_authority_loadout().is_empty(), "failed transaction leaves original disk unchanged")
	var legacy_api = Store.new()
	verify(legacy_api.initialize(fresh_path("legacy_api")) and legacy_api.collection.size() == 10, "legacy initializer remains compatible")
	for cleanup_path in paths:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cleanup_path))
	print("TIME_AUTHORITY_STORE_ACCEPTANCE checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
