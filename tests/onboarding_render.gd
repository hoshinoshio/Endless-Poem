extends SceneTree
const Opening = preload("res://scripts/onboarding/opening_sequence.gd")
const Tutorial = preload("res://scripts/onboarding/exploration_tutorial.gd")
var opening
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	await process_frame
	await process_frame
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var path = "res://docs/verification/onboarding_%s.png" % label
	var result = image.save_png(ProjectSettings.globalize_path(path))
	if result != OK:
		push_error("Cannot save " + path)
		quit(1)
	print("ONBOARDING_FRAME=" + path)
func click_button(key: String) -> void:
	var button: Button = opening.buttons[key]
	var pointer = button.get_global_rect().get_center()
	var down = InputEventMouseButton.new()
	down.position = pointer
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down)
	await process_frame
	var up = InputEventMouseButton.new()
	up.position = pointer
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	root.push_input(up)
	await process_frame
func run() -> void:
	root.size = Vector2i(1440, 900)
	opening = Opening.new()
	root.add_child(opening)
	opening.set_process(false)
	opening.advance(1.8)
	await capture("01_awakening")
	opening.advance(2.7)
	await capture("02_collapse")
	opening.advance(1.1)
	await capture("03_fracture")
	opening.advance(3.2)
	await capture("04_survivor")
	opening.advance(5.0)
	opening.advance(0.4)
	await capture("05_question")
	await click_button("no")
	opening.advance(0.4)
	await capture("06_refusal")
	for index in range(3):
		await click_button("refuse_again")
		opening.advance(0.4)
	await capture("07_final_acceptance")
	if opening.presentation_state().refusal_count != 3:
		push_error("Actual mouse UI did not reach three refusals")
		quit(1)
		return
	var acceptance_count = [0]
	opening.accepted.connect(func(): acceptance_count[0] += 1)
	await click_button("accept_refusal")
	if acceptance_count[0] != 1:
		push_error("Actual mouse acceptance did not emit accepted")
		quit(1)
		return
	opening.queue_free()
	await process_frame
	var tutorial = Tutorial.new()
	root.add_child(tutorial)
	for step in range(4):
		tutorial.configure(step)
		await capture("tutorial_%d" % step)
	print("ONBOARDING_RENDER_PASS")
	quit(0)




