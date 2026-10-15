extends SceneTree
const Attitude = preload("res://scripts/exploration/npc_attitude.gd")
const Session = preload("res://scripts/exploration/exploration_session.gd")
const Store = preload("res://scripts/progression/collection_store.gd")
var checks := 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ",label)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var a := Attitude.new()
	var changes := []
	for nature in ["harm","debuff","neutral","buff"]:
		a.apply(nature,nature)
		changes.append(a.entry(nature).value)
	check(changes == [-40,-25,-5,15], "four nature deltas")
	for i in 20:
		a.apply("low","harm")
		a.advance(60)
		a.apply("high","buff")
	check(a.entry("low").value == -100 and a.entry("high").value == 100, "attitude clamps both ends")
	var tiers := []
	for value in [-60,-59,-20,-19,19,20,59,60]: tiers.append(a.tier(value))
	check(tiers == ["敌对","警惕","警惕","中立","中立","友善","友善","信赖"], "eight tier boundaries")
	a.apply("farm","buff")
	a.advance(59.9)
	a.apply("farm","buff")
	var blocked: int = a.entry("farm").value
	a.advance(0.1)
	a.apply("farm","buff")
	check(blocked == 15 and a.entry("farm").value == 30, "buff cannot farm inside sixty world seconds")
	var path := "user://npc_attitude_%d.json" % Time.get_ticks_usec()
	var store := Store.new()
	store.initialize_time_authority(path)
	var fixture := {"active":true,"ruleset":"time_authority_v2","authority_unlocked":true,"authority_tutorial_step":3,"position":[13200,1900],"region":0,"hp":50,"completed":[],"interactions":[]}
	store.unlock_time_authority(fixture,fixture)
	var session := Session.new()
	root.add_child(session)
	session.configure(store,false)
	session.set_physics_process(false)
	session.attitude.entry("musheng").value = 20
	session._interact("testimony")
	session._resume_dialog()
	session._interact("testimony")
	check(store.data.evidence.count(Attitude.EXTRA) == 1 and session.attitude.entry("musheng").intel_received, "friendly intelligence awarded exactly once")
	session._resume_dialog()
	session.attitude.entry("musheng").value = 60
	session._interact("testimony")
	session._resume_dialog()
	session._interact("testimony")
	check(session.run.gifts_received == [Attitude.GIFT], "trusted gift awarded exactly once")
	session.queue_free()
	await process_frame
	var reloaded := Store.new()
	reloaded.initialize_time_authority(path)
	var resumed := Session.new()
	root.add_child(resumed)
	resumed.configure(reloaded,false)
	resumed.set_physics_process(false)
	resumed._interact("testimony")
	check(resumed.attitude.entry("musheng").value == 60 and resumed.run.gifts_received == [Attitude.GIFT] and reloaded.data.evidence.count(Attitude.EXTRA) == 1, "reload retains attitude and reward claims without duplication")
	resumed._resume_dialog()
	resumed.attitude.entry("musheng").value = -50
	resumed._card_applied("stop","musheng","npc")
	resumed._interact("testimony")
	check(not resumed.attitude.can_interact("musheng") and resumed.mode == "explore" and resumed.world.temporal.get_presentation().targets.musheng.category == "monster" and reloaded.data.exploration_run.npc_attitudes.musheng.hostile, "hostile refuses interaction and persists monster category")
	resumed.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("NPC_ATTITUDE_CHECKS=",checks," FAILURES=",failures.size())
	quit(0 if failures.is_empty() else 1)
