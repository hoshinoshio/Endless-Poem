extends Node2D
## Isolated authored-frame preview. No session or save-system dependency.
const World = preload("res://scripts/exploration/exploration_world.gd")
const PixelActor = preload("res://scripts/visuals/pixel_actor.gd")
const START := Vector2(2200,1900)
var world
var paused := false
var ready_for_preview := false
var pause_label: Label

func _ready() -> void:
	world = World.new()
	add_child(world)
	world.configure({"ruleset":"time_authority_v2","authority_unlocked":false,"position":[2200,1900],"completed":[],"interactions":[]})
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PixelActor.MANIFEST))
	var pixel := PixelActor.new()
	if not parsed is Dictionary or not parsed.get("actors",{}).has("player") or not pixel.configure(parsed.actors.player):
		pixel.free()
		push_error("Pixel preview requires valid authored player frames")
		return
	var previous = world.player.continuous_motion
	if previous != null:
		world.player.remove_child(previous)
		previous.queue_free()
	world.player.continuous_motion = pixel
	pixel.name = "PixelPreviewPlayer"
	pixel.authority_unlocked = false
	world.player.add_child(pixel)
	world.player.visual.visible = false
	if world.player.side_sprite != null: world.player.side_sprite.visible = false
	for child in world.player.get_children():
		if child is CollisionShape2D and child.shape is CapsuleShape2D:
			child.shape = child.shape.duplicate()
			child.shape.height = 130.0
			child.position.y = -65.0
	ready_for_preview = true
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var label := Label.new()
	label.position = Vector2(24,20)
	label.text = "月璃 · 像素动作样段"
	label.add_theme_font_override("font",load("res://assets/fonts/SourceHanSansSC-Regular.otf"))
	label.add_theme_font_size_override("font_size",19)
	label.modulate = Color(0.82,0.86,0.92)
	canvas.add_child(label)
	var guide := Label.new()
	guide.position = Vector2(24,50)
	guide.text = "A / D 或 ← / → 移动   Shift 奔跑   空格 跳跃   Esc 暂停   R 重置"
	guide.add_theme_font_override("font",load("res://assets/fonts/SourceHanSansSC-Regular.otf"))
	guide.add_theme_font_size_override("font_size",13)
	guide.modulate = Color(0.66,0.72,0.81)
	canvas.add_child(guide)
	pause_label = Label.new()
	pause_label.position = Vector2(24,74)
	pause_label.text = "已暂停"
	pause_label.visible = false
	pause_label.add_theme_font_override("font",load("res://assets/fonts/SourceHanSansSC-Regular.otf"))
	canvas.add_child(pause_label)

func _physics_process(delta: float) -> void:
	if not ready_for_preview: return
	var axis := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	world.set_movement_input(axis,false,Input.is_physical_key_pressed(KEY_SHIFT))
	world.advance_simulation(delta)

func _unhandled_key_input(event: InputEvent) -> void:
	if not ready_for_preview or not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_ESCAPE:
		paused = not paused
		world.set_paused(paused)
		# Keep the frozen world camera active while pausing this standalone preview.
		world.camera.enabled = true
		pause_label.visible = paused
	elif event.physical_keycode == KEY_SPACE:
		world.set_movement_input(world.player.axis,true,world.player.running)
	elif event.physical_keycode == KEY_R:
		world.set_player_position(START)
		world.player.velocity = Vector2.ZERO
		world.player.set_input(0,false)
