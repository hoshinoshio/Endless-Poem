extends SceneTree
const Session=preload("res://scripts/exploration/exploration_session.gd")
const Store=preload("res://scripts/progression/collection_store.gd")
var session
func _initialize(): call_deferred("run")
func capture(label):
	await process_frame
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	image.save_png("res://docs/verification/spatial_polished_"+label+".png")
	print("GPU_CAPTURE ",label," ",image.get_size())
func run():
	if DisplayServer.get_name()=="headless":
		printerr("GPU renderer required")
		quit(1)
		return
	var store=Store.new()
	store.initialize("user://_spatial_polish_visual.json")
	store.data["intro_accepted"]=true
	store.data["tutorial_completed"]=true
	session=Session.new()
	root.add_child(session)
	session.configure(store,true)
	session.set_process(false)
	session.run.tutorial_step=4
	session.world.set_player_position(Vector2(22330,1900))
	session.request_encounter("boss")
	if not session.confirm_loadout():
		printerr("Unable to start production spatial boss")
		quit(1)
		return
	await physics_frame
	session.spatial.advance(0.1)
	await capture("boss_ready")
	var target=session.combat.enemies[0].id
	session.combat.select_card(session.combat.cards[0].id)
	session.combat.play_selected(target)
	session.spatial.advance(0.76)
	await capture("fire_outward")
	session.spatial.advance(0.14)
	await capture("fire_converge")
	var boss=session.combat.enemies[0]
	boss.charge=boss.duration-0.45
	session.spatial.advance(0.03)
	await capture("pointer_warning")
	session.world.set_player_position(Vector2(22100,1900))
	session.spatial.advance(0.52)
	print("POINTER_ATTACKS ",session.spatial.presentation_state().attacks); await capture("pointer_slash")
	boss.action_index=2
	session.combat._set_intent(boss)
	boss.charge=boss.duration-0.05
	session.spatial.advance(0.44)
	await capture("bell_wave")
	print("SPATIAL_POLISHED_GPU display=",DisplayServer.get_name()," compatibility_backend hp=",session.combat.hp)
	session.queue_free()
	await process_frame
	quit(0)

