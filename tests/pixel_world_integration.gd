extends SceneTree
const World = preload("res://scripts/exploration/exploration_world.gd")
const Pixel = preload("res://scripts/visuals/pixel_actor.gd")
const Store = preload("res://scripts/progression/collection_store.gd")
var failures := 0
func check(value: bool,label: String) -> void:
	print(("PASS " if value else "FAIL ")+label)
	if not value: failures += 1
func _initialize() -> void:
	call_deferred("test_world")
func test_world() -> void:
	var path := "user://pixel_world_fresh_%s.json" % Time.get_ticks_usec()
	var store := Store.new()
	check(store.initialize_time_authority(path),"fresh normal store initializes")
	check(store.get_authority_loadout().is_empty() and not store.data.authority_granted,"default integration grants no abilities")
	var world := World.new()
	root.add_child(world)
	world.configure({"ruleset":"time_authority_v2","position":[200,1900],"authority_unlocked":false,"authority_tutorial_step":0})
	await physics_frame
	check(not world.temporal.is_unlocked and not world.temporal.select_card("stop"),"fresh world retains tutorial lock")
	check(world.player.continuous_motion is Pixel,"ready manifest activates default hero")
	check(world.observer_npc is Pixel,"ready manifest activates authored Musheng")
	if not world.player.continuous_motion is Pixel or not world.observer_npc is Pixel:
		world.free()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		quit(failures)
		return
	var hero = world.player.continuous_motion
	check(world.player.hitbox().size==Vector2(46,130),"hero hitbox matches approved compact body")
	var body: CollisionShape2D = world.player.find_children("*","CollisionShape2D",false,false)[0]
	var capsule: CapsuleShape2D = body.shape
	check(capsule.height==130 and capsule.radius==22 and body.position.y==-65,"capsule matches compact body and foot origin")
	for i in 20:
		world.advance_simulation(1.0/60)
		await physics_frame
	check(world.player.grounded and absf(world.player.position.y-1900)<1,"compact hero stands on the actual floor")
	var npc = world.observer_npc
	var npc_scale: Vector2 = npc.scale
	var npc_position: Vector2 = npc.position
	check(world._npc_world_rect().end.y==npc.position.y,"NPC target rectangle ends at fixed feet")
	world.play_player_action("cast")
	check(hero.state=="cast" and hero.sampled_animation=="cast","existing action immediately samples authored cast")
	var hero_saved: Dictionary = world._capture_player()
	var cast_pose: Dictionary = hero.presentation_state()
	world._advance_player_local(.1)
	world._restore_player(hero_saved)
	check(hero.presentation_state()==cast_pose and world.player.action_remaining==hero_saved.action_remaining,"rewind restores cast pose and duration")
	world.player.position = npc.position + Vector2(-60,0)
	world.interact()
	check(npc.state=="talk" and npc.sampled_animation=="talk","testimony samples authored talk")
	var recorded := []
	for i in 8:
		world.advance_simulation(.03)
		recorded.append(world._capture_npc())
	check(npc.scale==npc_scale and npc.position==npc_position,"NPC frames animate without deformation or position drift")
	world.temporal.set_unlocked(true)
	check(world.temporal.apply_card("stop","musheng"),"existing stop card accepts NPC target")
	var frozen: Dictionary = world._capture_npc()
	world.advance_simulation(.2)
	check(world._capture_npc()==frozen,"stop freezes NPC local clock and authored pose")
	world.temporal.reset_target("musheng")
	world.advance_simulation(.06)
	world.temporal.apply_card("reverse","musheng")
	world.advance_simulation(.06)
	check(world._capture_npc()==frozen,"reverse resamples exact previously recorded NPC frame")
	world.temporal.reset_target("musheng")
	world.set_paused(true)
	var paused_npc: Dictionary = world._capture_npc()
	var paused_hero: Dictionary = hero.presentation_state()
	world.advance_simulation(.5)
	check(world._capture_npc()==paused_npc and hero.presentation_state()==paused_hero,"world pause freezes both authored actors")
	check(store.get_authority_loadout().is_empty() and not store.data.authority_granted,"visual actions and target test leave progression store unchanged")
	world.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PIXEL WORLD INTEGRATION failures=",failures)
	quit(failures)
