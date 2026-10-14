extends SceneTree
const Player = preload("res://scripts/exploration/exploration_player.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _run() -> void:
	var player = Player.new()
	root.add_child(player)
	player.set_authority_unlocked(true)
	player.grounded = true
	player.animation = "idle"
	player._advance_authority_gesture(0.1)
	player.refresh_authority_presentation()
	_check(not player.authority_dial.visible, "resting baseline is fully hidden")
	player.authority_idle_elapsed = 3.99
	player._advance_authority_gesture(0.02)
	player.refresh_authority_presentation()
	_check(player.authority_gesture_elapsed >= 0.0 and player.authority_dial.visible, "idle gesture manifests dial")
	_check(player.action_remaining == 0.0, "idle gesture does not create an action")
	player._advance_authority_gesture(0.6)
	player._advance_authority_gesture(0.3)
	player.refresh_authority_presentation()
	_check(player.authority_intensity == 0.0 and not player.authority_dial.visible, "gesture fades completely")
	player.action_animation = "cast"
	player.action_remaining = 0.4
	player._advance_authority_gesture(0.1)
	player.refresh_authority_presentation()
	var dial: Dictionary = player.authority_dial.presentation_state()
	_check(dial.visible and dial.intensity == 1.0, "actual casting manifests readable clock")
	_check(dial.tickcount == 60 and dial.hour_marks == 12 and dial.hands == 3, "clock has clear graduations and hands")
	_check(dial.radius >= 88.0 and dial.radius <= 110.0, "clock respects body-sized radius bounds")
	player.action_remaining = 0.0
	player.animation = "walk"
	player._advance_authority_gesture(0.3)
	player.refresh_authority_presentation()
	_check(not player.authority_dial.visible, "cast fades while moving")
	player.set_authority_unlocked(false)
	_check(not player.authority_dial.visible and player.authority_intensity == 0.0, "locked authority remains hidden")
	print("Authority dial: ", checks - failures.size(), "/", checks, " passed")
	for failure in failures: push_error(failure)
	player.queue_free()
	quit(0 if failures.is_empty() else 1)
