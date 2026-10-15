extends "res://scripts/exploration/exploration_world.gd"
## Isolated flat sandbox; no authored chapter terrain or opening changes.
var box: CharacterBody2D
func configure(value: Dictionary) -> void:
	if _configured:
		apply_run(value)
		return
	_configured = true
	run = value.duplicate(true)
	_encounters = {}
	_gates = []
	_interactions = {"testimony": Vector2(850, 600)}
	_add_terrain("preview_floor", PackedVector2Array([Vector2(0, 600), Vector2(1440, 600)]), false)
	player = Player.new()
	add_child(player)
	player.position = Vector2(350, 600)
	player.grounded = true
	camera = Camera2D.new()
	camera.position = Vector2(720, 450)
	add_child(camera)
	var actor := Actor.new()
	actor.configure("preview_patrol", Assets.build().enemies.guard, 210.0, 260.0)
	actor.set_interactive(false)
	actor.position = Vector2(1130, 600)
	add_child(actor)
	previews = {"tutorial": actor}
	_create_observer_npc()
	observer_npc.position = Vector2(790, 600)
	_setup_time_targets()
	ambient.z_index = 0
	for id in ambient.objects.keys():
		if id != "lamp_bridge":
			temporal.unregister_target(id)
			ambient.objects.erase(id)
	ambient.objects.lamp_bridge.origin = Vector2(170, 600)
	box = CharacterBody2D.new()
	box.position = Vector2(580, 600)
	box.collision_layer = 1
	box.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64, 64)
	shape.shape = rect
	shape.position = Vector2(0, -32)
	box.add_child(shape)
	add_child(box)
	temporal.register_target("crate", "可推动木箱", func(): return _screen_rect(Rect2(box.position - Vector2(32,64),Vector2(64,64))), func(): return {"position":box.position}, func(state): box.position = state.position, _advance_box, "item")
	apply_run(value)
func _advance_box(delta: float) -> void:
	if absf(player.position.x - box.position.x) < 65 and absf(player.position.y - box.position.y) < 70:
		box.move_and_collide(Vector2(player.axis * 150.0 * delta, 0))
	queue_redraw()
func advance_simulation(delta: float) -> void:
	super.advance_simulation(delta)
	camera.position = Vector2(720, 450)
	camera.force_update_scroll()
	observer_npc.modulate.a = 1.0
func _update_regions_and_triggers() -> void:
	pass
func _draw() -> void:
	draw_rect(Rect2(0,0,1440,900),Color("162237"))
	for i in 42: draw_circle(Vector2(fmod(i * 131.0,1440), 60 + fmod(i * 83.0,400)), 1.2, Color("82919f"))
	draw_rect(Rect2(0,600,1440,300),Color("2e3947"))
	draw_line(Vector2(0,600),Vector2(1440,600),Color("bfa276"),3)
	if box != null:
		var r := Rect2(box.position - Vector2(32,64),Vector2(64,64))
		draw_rect(r,Color("735438"))
		draw_rect(r,Color("bfa276"),false,3)
		draw_line(r.position,r.end,Color("bfa276"),3)
		draw_line(r.position+Vector2(64,0),r.position+Vector2(0,64),Color("bfa276"),3)
	_draw_interaction_key()
