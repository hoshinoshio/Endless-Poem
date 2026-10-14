extends SceneTree
## New functionality only. Run once after the Oct 12 session integration.
const Session = preload("res://scripts/exploration/exploration_session.gd")
const Store = preload("res://scripts/progression/collection_store.gd")
var failures := 0
var hits: Array = []
var world
var session
var save_path := ""

func verify(value: bool,label: String) -> void:
	if not value:
		failures += 1
		push_error(label)
	else: print("PASS: ",label)

func _init() -> void:
	call_deferred("exercise")

func tick(seconds: float) -> void:
	for i in ceili(seconds*120): world.temporal.advance(1.0/120.0)

func exercise() -> void:
	save_path = "user://oct12_enemy_time_delta_%d.json" % Time.get_ticks_usec()
	var store = Store.new()
	verify(store.initialize_time_authority(save_path),"isolated authority store initializes")
	var fixture := {"active":true,"ruleset":"time_authority_v2","authority_unlocked":true,"authority_tutorial_step":3,"position":[2700,1900],"region":0,"hp":50,"coins":0,"upgrades":{},"completed":[],"interactions":[],"tutorial_step":0,"pending_reward":"","pending_upgrade":false,"in_battle":false,"rest_used":false,"elite_upgrade_used":false}
	verify(store.unlock_time_authority(fixture,fixture),"fixture grants only three authority cards")
	var collection_before: Array = store.data.authority_collection.duplicate(true)
	session = Session.new()
	root.add_child(session)
	session.configure(store,false)
	session.set_physics_process(false)
	world = session.world
	world.temporal.apply_card("stop","player")
	world.enemy_attack_hit.connect(func(enemy_id,attack_id,damage): hits.append({"enemy":enemy_id,"attack":attack_id,"damage":damage}))
	world.previews.tutorial.visible = true
	tick(0.1)
	verify(world._enemy_states.tutorial.state=="chase" and world.has_hostile_attention(),"ordinary monster sees player and pursues")
	world.set_player_position(Vector2(2920,1900))
	tick(0.1)
	verify(world._enemy_states.tutorial.state=="windup","near player starts telegraphed attack")
	var enemy_rect: Rect2 = world.temporal.get_presentation().targets.enemy_tutorial.screen_rect
	var player_rect: Rect2 = world.temporal.get_presentation().targets.player.screen_rect
	var picked: String = world.temporal.target_at_point(enemy_rect.intersection(player_rect).get_center())
	verify(picked == "enemy_tutorial","enemy body remains selectable where player overlaps it")
	session.choose_card("stop")
	session.confirm_target(picked)
	var stopped: Dictionary = world._capture_enemy("tutorial")
	var actor = world.previews.tutorial
	var frame: int = actor.continuous_motion.frame_index
	var hp_before: int = session.run.hp
	tick(1.0)
	verify(world.temporal.get_target_mode("enemy_tutorial")=="stop" and world._capture_enemy("tutorial")==stopped and actor.continuous_motion.frame_index==frame and hits.is_empty() and session.run.hp==hp_before,"stop freezes position, frame, feedback, windup, hit resolution and HP")
	world.temporal.reset_target("enemy_tutorial")
	tick(0.8)
	verify(hits.size()==1 and hits[0].damage==2 and session.run.hp==hp_before-2 and session.hp_bar.value==session.run.hp,"resumed tutorial strike hits once and updates actual session HP")
	tick(0.1)
	verify(hits.size()==1,"single attack ID cannot hit repeatedly")
	var restored: Dictionary = world._capture_enemy("tutorial")
	var clock_before: float = world.temporal.get_presentation().targets.enemy_tutorial.local_clock
	world.temporal.apply_card("reverse","enemy_tutorial")
	tick(0.1)
	verify(world.temporal.get_presentation().targets.enemy_tutorial.local_clock<clock_before and world._capture_enemy("tutorial")!=restored,"reverse restores enemy action time")
	world.reset_enemy_encounters()
	verify(world.temporal.get_target_mode("enemy_tutorial")=="normal" and world.previews.tutorial.position==Vector2(3000,1900),"retry reset restores origin, timers and normal local time")
	world.set_player_position(Vector2(2920,1900))
	tick(0.1)
	world.set_player_position(Vector2(2700,1900))
	var count := hits.size()
	tick(0.85)
	verify(hits.size()==count,"stepping outside locked swipe avoids damage")
	world.reset_enemy_encounters()
	world.set_player_position(Vector2(2920,1900))
	tick(0.1)
	world.set_player_position(Vector2(2920,1700))
	tick(0.85)
	verify(hits.size()==count,"jumping above actual low swipe avoids damage")
	world.reset_enemy_encounters()
	session._authority_resolved_hits.clear()
	session.run.hp = 2
	world.set_player_position(Vector2(2920,1900))
	tick(0.95)
	verify(session.run.hp==0 and session.mode=="defeat" and world.paused,"lethal actual strike opens defeat and pauses remaining local callbacks")
	if session.ui_buttons.has("retry"):
		session.ui_buttons.retry.pressed.emit()
	verify(session.mode=="explore" and session.run.hp>0 and not world.paused and world.temporal.get_target_mode("enemy_tutorial")=="normal" and world.temporal.get_target_mode("player")=="normal","actual retry button restores safe checkpoint and local clocks")
	verify(store.data.authority_collection==collection_before,"death and retry preserve three authority entities")
	session.free()
	for suffix in ["",".bak",".tmp"]:
		var absolute := ProjectSettings.globalize_path(save_path+suffix)
		if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)
	print("Oct 12 enemy/time delta failures: ",failures)
	quit(0 if failures==0 else 1)
