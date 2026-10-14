extends Node2D
## Presentation only. Frames and feedback advance on the supplied combat clock.
signal selected(id: String)

const PixelActor = preload("res://scripts/visuals/pixel_actor.gd")
const ContinuousMotion = preload("res://scripts/visuals/continuous_motion.gd")
var continuous_motion: Node2D
var pixel_key := ""
var motion_state := "idle"
var motion_velocity := Vector2.ZERO
var motion_facing := 1.0
var actor_id := ""
var snapshot: Dictionary = {}
var animation_state := "idle"
var has_art := false
var uses_static_seed := true
var animation_elapsed := 0.0
var feedback_remaining := 0.0
var sprite: Sprite2D
var animated_sprite: AnimatedSprite2D
var pick_area: Area2D
var collision: CollisionShape2D
var _frames: SpriteFrames
var _height := 280.0
var _max_width := 300.0
var _frame_clock := 0.0
var _frame_index := 0
var _local_bounds := Rect2()
var _interactive := true
var _idle_clock := 0.0
var _idle_index := 0

func _init() -> void:
	sprite = Sprite2D.new()
	sprite.name = "StaticSeed"
	add_child(sprite)
	animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "FrameAnimation"
	# Playback is driven manually, so focus/paused clocks cannot diverge.
	animated_sprite.speed_scale = 0.0
	animated_sprite.visible = false
	add_child(animated_sprite)
	pick_area = Area2D.new()
	pick_area.name = "TargetPickArea"
	pick_area.collision_layer = 1
	pick_area.collision_mask = 0
	pick_area.input_pickable = false
	add_child(pick_area)
	collision = CollisionShape2D.new()
	collision.name = "SpriteBounds"
	pick_area.add_child(collision)
	pick_area.input_event.connect(_on_input_event)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func configure(id: String, asset: Dictionary, desired_height: float, max_width: float) -> void:
	actor_id = id
	pixel_key = str(asset.get("pixel_key",""))
	_height = desired_height
	_max_width = max_width
	_frames = asset.get("sprite_frames") as SpriteFrames
	sprite.texture = asset.get("texture") as Texture2D
	animated_sprite.sprite_frames = _frames
	sprite.flip_h = bool(asset.get("flip_h", false))
	animated_sprite.flip_h = sprite.flip_h
	has_art = sprite.texture != null or _valid_animation("idle")
	uses_static_seed = not _valid_animation("idle")
	sprite.visible = has_art and uses_static_seed
	animated_sprite.visible = has_art and not uses_static_seed
	_try_build_pixel(pixel_key)
	set_interactive(has_art)
	play_animation("idle")

func sync(data: Dictionary) -> void:
	snapshot = data.duplicate(true)
	if actor_id != "player" and continuous_motion == null: _build_continuous_motion()

func fit_dimensions(desired_height: float, max_width: float) -> void:
	if is_equal_approx(_height, desired_height) and is_equal_approx(_max_width, max_width):
		return
	_height = desired_height
	_max_width = max_width
	_fit_current_texture()

func has_animation(state: String) -> bool:
	if continuous_motion is PixelActor:
		return continuous_motion.animations.has(_pixel_state(state))
	return _valid_animation(state)

func set_interactive(value: bool) -> void:
	_interactive = value and has_art
	pick_area.input_pickable = _interactive
	if collision.shape != null:
		collision.set_deferred("disabled", not _interactive)

func play_animation(state: String) -> bool:
	if continuous_motion is PixelActor:
		animation_state = _pixel_state(state)
		animation_elapsed = 0.0
		feedback_remaining = _pixel_duration(animation_state) if animation_state in ["windup","attack","recover","hurt","cast"] else 0.0
		continuous_motion.set_motion_state(animation_state,motion_velocity,motion_facing)
		continuous_motion.state_time = 0.0
		continuous_motion._sample()
		_fit_current_texture()
		if state == "defeat": set_interactive(false)
		return has_animation(state)
	# Missing state falls back to the approved static seed or idle, never synthetic frames.
	if state == "idle" and animation_state == "idle" and _local_bounds.size.y > 0:
		return _valid_animation(state)
	if animation_state == "idle":
		_idle_clock = _frame_clock
		_idle_index = _frame_index
	animation_state = state
	animation_elapsed = 0.0
	_frame_clock = 0.0
	_frame_index = 0
	if state == "idle":
		_frame_clock = _idle_clock
		_frame_index = _idle_index
	feedback_remaining = 0.24 if state == "hurt" else (0.36 if state in ["cast", "attack"] else 0.0)
	var available := _valid_animation(state)
	if available:
		animated_sprite.animation = StringName(state)
		animated_sprite.frame = _frame_index
		animated_sprite.frame_progress = 0.0
		animated_sprite.visible = true
		sprite.visible = false
	elif sprite.texture != null:
		animated_sprite.visible = false
		sprite.visible = true
	elif _valid_animation("idle"):
		animated_sprite.animation = &"idle"
		animated_sprite.frame = _frame_index
		animated_sprite.visible = true
		sprite.visible = false
	_fit_current_texture()
	if state == "defeat":
		set_interactive(false)
	return available

func advance(battle_delta: float) -> void:
	if battle_delta <= 0.0:
		return
	if continuous_motion is PixelActor:
		_advance_pixel(battle_delta)
		return
	animation_elapsed += battle_delta
	feedback_remaining = maxf(0.0, feedback_remaining - battle_delta)
	modulate = Color(1.0, 0.68, 0.68) if animation_state == "hurt" and feedback_remaining > 0 else Color.WHITE
	if _valid_animation(animation_state):
		_advance_frames(battle_delta)
	elif animation_state in ["cast", "attack", "hurt"] and feedback_remaining <= 0.0:
		play_animation("idle")

	var feedback_offset := Vector2.ZERO
	if animation_state in ["cast", "attack"] and feedback_remaining > 0.0:
		feedback_offset.x = -2.0 * sin(animation_elapsed * PI / 0.18) if animation_elapsed < 0.18 else 3.0 * exp(-(animation_elapsed - 0.18) * 18.0)
	elif animation_state == "hurt" and feedback_remaining > 0.0:
		feedback_offset.x = sin(animation_elapsed * 65.0) * 3.0 * feedback_remaining / 0.24
	sprite.position = Vector2(0, -_local_bounds.size.y / 2.0) + feedback_offset.round()
	animated_sprite.position = sprite.position
	if continuous_motion != null:
		var presented := animation_state if feedback_remaining>0 or animation_state=="defeat" else motion_state
		continuous_motion.set_motion_state(presented,motion_velocity,motion_facing)
		continuous_motion.render_enabled = is_visible_in_tree()
		continuous_motion.advance(battle_delta)
		sprite.visible = false
		animated_sprite.visible = false

func _advance_frames(delta: float) -> void:
	var state := StringName(animation_state)
	var count := _frames.get_frame_count(state)
	var fps := _frames.get_animation_speed(state)
	if fps <= 0 or count <= 0:
		return
	_frame_clock += delta
	# Bound loop work for a large integration delta while keeping ordinary frame timing exact.
	var loop_duration := 0.0
	for i in count:
		loop_duration += _frames.get_frame_duration(state, i) / fps
	if _frames.get_animation_loop(state) and loop_duration > 0:
		_frame_clock = fmod(_frame_clock, loop_duration)
	while _frame_clock >= _frames.get_frame_duration(state, _frame_index) / fps:
		_frame_clock -= _frames.get_frame_duration(state, _frame_index) / fps
		if _frame_index + 1 >= count:
			if _frames.get_animation_loop(state):
				_frame_index = 0
			elif animation_state == "defeat":
				_frame_clock = 0.0
				break
			else:
				play_animation("idle")
				return
		else:
			_frame_index += 1
	animated_sprite.frame = _frame_index
	animated_sprite.frame_progress = _frame_clock / (_frames.get_frame_duration(state, _frame_index) / fps)
	_fit_current_texture()

func _valid_animation(state: String) -> bool:
	return _frames != null and _frames.has_animation(StringName(state)) and _frames.get_frame_count(StringName(state)) > 0

func _fit_current_texture() -> void:
	if continuous_motion is PixelActor:
		var extent: Vector2 = Vector2(48,64)*float(continuous_motion.display_scale)
		var anchor: Vector2 = continuous_motion.frame_anchor*float(continuous_motion.display_scale)
		var left: float = -anchor.x if continuous_motion.facing >= 0 else anchor.x-extent.x
		_local_bounds = Rect2(Vector2(left,-anchor.y),extent)
		if not collision.shape is RectangleShape2D: collision.shape = RectangleShape2D.new()
		collision.shape.size = extent
		collision.position = _local_bounds.get_center()
		collision.set_deferred("disabled",not _interactive)
		return
	var texture: Texture2D = sprite.texture
	if (animated_sprite.visible or continuous_motion != null) and _frames != null:
		# Fixed reference canvas keeps feet, fit, and picking stable across frames.
		texture = _frames.get_frame_texture(&"idle", 0) if _valid_animation("idle") else _frames.get_frame_texture(animated_sprite.animation, 0)
	if texture == null:
		_local_bounds = Rect2()
		collision.shape = null
		return
	var dimensions := texture.get_size()
	if dimensions.x <= 0 or dimensions.y <= 0:
		return
	var fit := minf(_height / dimensions.y, _max_width / dimensions.x)
	var extent := dimensions * fit
	sprite.scale = Vector2.ONE * fit
	animated_sprite.scale = Vector2.ONE * fit
	sprite.position = Vector2(0, -extent.y / 2.0)
	animated_sprite.position = sprite.position
	_local_bounds = Rect2(Vector2(-extent.x / 2.0, -extent.y), extent)
	if collision.shape == null or not collision.shape is RectangleShape2D:
		collision.shape = RectangleShape2D.new()
	collision.shape.size = extent
	collision.position = Vector2(0, -extent.y / 2.0)
	collision.set_deferred("disabled", not _interactive)

func get_target_rect() -> Rect2:
	if not has_art or not _interactive:
		return Rect2()
	if continuous_motion is PixelActor: _fit_current_texture()
	var top_left := to_global(_local_bounds.position)
	var bottom_right := to_global(_local_bounds.end)
	return Rect2(top_left, bottom_right - top_left).abs()

func get_visual_center() -> Vector2:
	if continuous_motion is PixelActor: _fit_current_texture()
	return position + _local_bounds.get_center()

func get_visual_height() -> float:
	return _local_bounds.size.y if _local_bounds.size.y > 0 else _height

func _on_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if _interactive and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(actor_id)
		get_viewport().set_input_as_handled()


func set_motion_state(state: String, velocity: Vector2, facing: float) -> void:
	motion_state = _pixel_state(state)
	motion_velocity = velocity
	motion_facing = facing
	if actor_id != "player" and continuous_motion == null: _build_continuous_motion()

func _build_continuous_motion() -> void:
	var kind := str(snapshot.get("kind",actor_id))
	var mapped := {"guardian":"guard","elite_guard":"elite","chronos":"boss"}
	var key := pixel_key if not pixel_key.is_empty() else str(mapped.get(kind,kind))
	if _try_build_pixel(key): return
	var texture: Texture2D = _frames.get_frame_texture(&"idle",0) if _valid_animation("idle") else sprite.texture
	if texture == null: return
	continuous_motion = ContinuousMotion.new()
	continuous_motion.name = "ContinuousActorRig"
	add_child(continuous_motion)
	continuous_motion.configure(texture,_local_bounds.size.y,{},kind in ["instrument","observer","anchor"])
	continuous_motion.authority_unlocked = false
	sprite.visible = false
	animated_sprite.visible = false

func _try_build_pixel(key: String) -> bool:
	if key.is_empty() or continuous_motion != null: return false
	var pixel := PixelActor.new()
	if pixel.configure_key(key):
		continuous_motion = pixel
		pixel.name = "PixelActor"
		add_child(pixel)
		pixel.authority_unlocked = false
		has_art = true
		uses_static_seed = false
		# Only the raster renderer mirrors authored right-facing frames.
		sprite.flip_h = false
		animated_sprite.flip_h = false
		sprite.visible = false
		animated_sprite.visible = false
		_fit_current_texture()
		return true
	pixel.free()
	return false

func _pixel_state(state: String) -> String:
	return "recover" if state == "recovery" else state

func _pixel_duration(state: String) -> float:
	var strip: Dictionary = continuous_motion.animations.get(state,{})
	return float(strip.get("frames",[]).size())/maxf(1.0,float(strip.get("fps",1)))

func _advance_pixel(delta: float) -> void:
	animation_elapsed += delta
	feedback_remaining = maxf(0.0,feedback_remaining-delta)
	var presented := animation_state if feedback_remaining>0 or animation_state=="defeat" else motion_state
	if feedback_remaining<=0 and animation_state!="defeat": animation_state = motion_state
	continuous_motion.set_motion_state(presented,motion_velocity,motion_facing)
	continuous_motion.render_enabled = is_visible_in_tree()
	continuous_motion.advance(delta)
	modulate = Color(1.0,0.68,0.68) if presented=="hurt" else Color.WHITE
	sprite.visible = false
	animated_sprite.visible = false
	_fit_current_texture()
