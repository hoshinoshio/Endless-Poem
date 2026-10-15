extends "res://scripts/exploration/exploration_session.gd"
const PreviewWorld = preload("res://scripts/previews/drag_cast_world.gd")
const Store = preload("res://scripts/progression/collection_store.gd")
var debug_label: Label
var preview_path := ""
func _create_world(): return PreviewWorld.new()
func _ready() -> void:
	# Disposable save prevents sandbox attitude or gifts from touching chapter progress.
	preview_path = "user://drag_cast_preview_%d.json" % Time.get_ticks_usec()
	var preview_store := Store.new()
	preview_store.initialize_time_authority(preview_path)
	var fixture := {"active":true,"ruleset":"time_authority_v2","authority_unlocked":true,"authority_tutorial_step":3,"position":[350,600],"region":0,"hp":50,"completed":[],"interactions":[]}
	preview_store.unlock_time_authority(fixture,fixture)
	configure(preview_store,false)
	debug_label = _label("",Rect2(28,22,1100,160),canvas,18)
	if "--capture-preview" in OS.get_cmdline_user_args(): _capture.call_deferred()
func _process(_delta: float) -> void:
	if not is_instance_valid(debug_label): return
	var npc: Dictionary = attitude.entry("musheng")
	debug_label.text = "阶段 B · 拖拽施放预览     A/D 移动 · Space 跳跃 · E 交互\nworld_time_scale = %.2f     暮笙态度 %d · %s\n冷却  停止 %.1f   快进 %.1f   倒退 %.1f\nF1 / F2 / F3 / F4：施加 harm / debuff / neutral / buff（保留防刷冷却）" % [world.world_time_scale,npc.value,attitude.tier(int(npc.value)),world.temporal.cooldowns.stop,world.temporal.cooldowns.fast_forward,world.temporal.cooldowns.reverse]
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and mode == "explore":
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key in [KEY_F1,KEY_F2,KEY_F3,KEY_F4]:
			var result: Dictionary = attitude.apply("musheng", ["harm","debuff","neutral","buff"][key - KEY_F1])
			_persist_attitude()
			world.set_npc_hostile(bool(attitude.entry("musheng").hostile))
			if result.changed: hand.show_reaction(result.tier)
			return
	super._unhandled_input(event)
func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Preview capture requires rendering")
		get_tree().quit(1)
		return
	await get_tree().process_frame
	# Feed the same press/move input path used by a real mouse drag.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = hand.faces.stop.get_global_rect().get_center()
	hand._input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = world.temporal.get_presentation().targets.musheng.screen_rect.get_center()
	hand._input(motion)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://logs"))
	var error := get_viewport().get_texture().get_image().save_png("res://logs/drag_cast_preview.png")
	print("DRAG_CAST_PREVIEW_CAPTURE=",error_string(error))
	get_tree().quit(0 if error == OK else 1)
func _exit_tree() -> void:
	super._exit_tree()
	for suffix in ["", ".bak", ".tmp"]:
		var absolute := ProjectSettings.globalize_path(preview_path + suffix)
		if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)
