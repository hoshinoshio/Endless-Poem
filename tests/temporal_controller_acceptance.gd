extends SceneTree
const Controller = preload("res://scripts/authority/temporal_controller.gd")
const Card = preload("res://scripts/authority/time_card.gd")
var failures: int = 0
var checks: int = 0

class Fixture:
	extends RefCounted
	var state: Dictionary = {"position": 0.0, "nested": {"ticks": 0}}
	var bounds := Rect2(0, 0, 20, 20)
	func capture() -> Dictionary:
		return state
	func restore(snapshot: Dictionary) -> void:
		state = snapshot
	func advance_local(delta: float) -> void:
		state["position"] += delta
		if delta > 0.0:
			state["nested"]["ticks"] += 1
	func rect() -> Rect2:
		return bounds

func verify(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
	else:
		print("PASS: ", label)

func _init() -> void:
	var controller = Controller.new({"history_limit": 4})
	var fixtures: Dictionary = {}
	for id in ["player", "cloud", "lamp", "platform", "creature"]:
		var fixture := Fixture.new()
		fixtures[id] = fixture
		verify(controller.register_target(id, id, fixture.rect, fixture.capture, fixture.restore, fixture.advance_local), "register arbitrary object " + id)
	verify(not controller.select_card("stop") and not controller.apply_card("stop", "player"), "authority gate blocks use")
	controller.advance(1.0)
	verify(fixtures.player.state.position == 1.0, "normal object time advances before unlock")
	controller.set_unlocked(true)
	verify(Controller.card_catalog().size() == 3 and Controller.card_catalog()[2].title == "倒退时间", "only three exact time cards")
	controller.select_card("stop")
	controller.select_target("player")
	controller.advance(1.0)
	verify(fixtures.player.state.position == 1.0 and fixtures.cloud.state.position == 2.0, "stop is independent from cloud")
	controller.apply_card("fast_forward", "lamp")
	controller.advance(0.5)
	verify(fixtures.lamp.state.position == 3.0, "fast forward uses configurable 2x demo")
	var previous = controller.get_presentation()
	verify(not controller.apply_card("reverse", "missing") and not controller.select_target("missing") and controller.get_presentation() == previous, "invalid target changes nothing")
	controller.set_paused(true)
	controller.advance(10)
	verify(controller.get_presentation().targets == previous.targets, "pause freezes clocks and history")
	controller.set_paused(false)
	controller.apply_card("reverse", "cloud")
	controller.advance(0.5)
	verify(fixtures.cloud.state.position == 2.0 and fixtures.cloud.state.nested.ticks == 2, "reverse restores deep historical state")
	controller.advance(100)
	verify(fixtures.cloud.state.position >= 0.0, "reverse clamps to recorded past")
	controller.cancel_selection()
	verify(controller.selected_card == "" and controller.selected_target == "", "cancel clears pending selection")
	verify(controller.reset_target("player"), "reset target accepts known object")
	controller.advance(1)
	verify(fixtures.player.state.position == 2.0, "reset resumes normal local time")
	for index in range(8):
		controller.advance(1)
	verify(controller.get_presentation().targets.player.history_count == 4, "history has configured bound")
	controller.apply_card("reverse", "player")
	controller.advance(100)
	verify(fixtures.player.state.position == 7.0, "bounded history cannot restore discarded earlier states")
	controller.reset_target("player")
	controller.advance(0.25)
	verify(fixtures.player.state.position == 7.25 and controller.get_presentation().targets.player.history_count == 2, "resume creates a new branch from restored state")
	var empty = Controller.new()
	var new_fixture := Fixture.new()
	empty.register_target("self", "self", new_fixture.rect, new_fixture.capture, new_fixture.restore, new_fixture.advance_local)
	empty.set_unlocked(true)
	empty.apply_card("reverse", "self")
	empty.advance(5)
	verify(new_fixture.state.position == 0.0 and empty.get_presentation().targets.self.history_count == 0, "empty history cannot invent past")
	verify(empty.target_at_point(Vector2(10, 10)) == "self", "screen selection supports self")
	var before_empty = empty.get_presentation()
	empty.advance(-1)
	verify(empty.get_presentation() == before_empty, "negative elapsed time is ignored")
	var ui = Card.new()
	ui.configure(Controller.card_catalog()[0])
	ui.set_selected(true)
	verify(ui.selected and ui.card.title == "停止时间", "time card exposes selection and exact title")
	ui.free()
	print("TEMPORAL_ACCEPTANCE checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
