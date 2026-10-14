extends CharacterBody2D
const Actor = preload("res://scripts/world/combat_actor.gd")
const Assets = preload("res://scripts/visuals/chapter1_assets.gd")
const PixelActor = preload("res://scripts/visuals/pixel_actor.gd")
const ContinuousMotion = preload("res://scripts/visuals/continuous_motion.gd")
const AuthorityDial = preload("res://scripts/exploration/authority_dial_visual.gd")
var authority_dial: Node2D
var authority_idle_elapsed := 0.0
var authority_gesture_elapsed := -1.0
var authority_intensity := 0.0
var continuous_motion: Node2D
var idle_authority_phase := 0.0
var idle_authority_pulse := 0.0
var visual: Node2D
var axis := 0.0
var running := false
var stride_phase := 0.0
var moved_distance := 0.0
var run_blend := 0.0
var locomotion_frames: Dictionary = {}
var locomotion_anchors: Dictionary = {}
var locomotion_scale := 217.0/429.0
var locomotion_ready := false
var locomotion_idle: Dictionary = {}
var locomotion_textures: Dictionary = {}
var jump_queued := false
var grounded := false
var animation := "idle"
var facing := 1.0
var elapsed := 0.0
var landed_count := 0
var action_remaining := 0.0
var action_animation := ""
var collision_height := 175.0
var collision_radius := 24.0
var foot_padding: Dictionary = {}
var side_sprite: Sprite2D
var side_frames: Array[AtlasTexture] = []
var side_anchors: Array[Vector2] = []
var landing_remaining := 0.0
var jump_elapsed := 0.0
var side_frame := 0
var floor_normal := Vector2.UP
const SPEED := 390.0
const RUN_SPEED := 624.0
const ACCELERATION := 4800.0
const DECELERATION := 6200.0
const WALK_CYCLE_DISTANCE := 220.0
const RUN_CYCLE_DISTANCE := 340.0
const GRAVITY := 1600.0
const JUMP_SPEED := 950.0
func _init() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 24.0
	capsule.height = 175.0
	shape.shape = capsule
	shape.position = Vector2(0,-87.5)
	add_child(shape)
	visual = Actor.new()
	visual.configure("player",Assets.build().player,217.0,240.0)
	visual.set_interactive(false)
	add_child(visual)
	_build_side_motion()
	_build_locomotion()
	_build_continuous_motion()
	authority_dial = AuthorityDial.new()
	authority_dial.show_behind_parent = true
	authority_dial.visible = false
	add_child(authority_dial)
	move_child(authority_dial, 0)
func set_input(value: float, jump: bool, is_running: bool = false) -> void:
	axis = clampf(value,-1,1)
	running = is_running and absf(axis)>0.01
	jump_queued = jump_queued or jump
func advance(delta: float) -> void:
	if delta <= 0:
		return
	elapsed += delta
	if action_remaining<=0 and visual.animation_state in ["cast","attack","hurt"] and visual.feedback_remaining>0:
		action_remaining = visual.feedback_remaining
		action_animation = visual.animation_state
	action_remaining = maxf(0,action_remaining-delta)
	var was_grounded := grounded
	if jump_queued and grounded:
		velocity.y = -JUMP_SPEED
		grounded = false
		jump_elapsed = 0.0
	jump_queued = false
	var target_speed := axis*(RUN_SPEED if running else SPEED)
	velocity.x = move_toward(velocity.x,target_speed,(DECELERATION if absf(target_speed)<absf(velocity.x) or velocity.x*target_speed<0 else ACCELERATION)*delta)
	var previous_position := position
	velocity.y = minf(1100,velocity.y+GRAVITY*delta)
	if absf(axis) > 0.01:
		facing = signf(axis)
	var motion := velocity*delta
	grounded = false
	for _i in 5:
		var hit := move_and_collide(motion)
		if hit == null:
			break
		var normal := hit.get_normal()
		if normal.y < -0.5:
			grounded = true
			floor_normal = normal
		motion = hit.get_remainder().slide(normal)
		velocity = velocity.slide(normal)
		if motion.length_squared() < 0.00001:
			break
	# Small real collision sweep retains ground adhesion on descending slopes.
	if not grounded and velocity.y >= 0 and was_grounded:
		var snap := move_and_collide(Vector2(0,12),true)
		if snap != null and snap.get_normal().y < -0.5:
			move_and_collide(Vector2(0,12))
			grounded = true
			floor_normal = snap.get_normal()
			velocity.y = 0
	if grounded and not was_grounded:
		landed_count += 1
		landing_remaining = 0.13
	moved_distance = absf(position.x-previous_position.x)
	var actually_moving := moved_distance > 0.02
	run_blend = move_toward(run_blend,1.0 if running and actually_moving else 0.0,delta*7.0)
	if grounded and actually_moving:
		stride_phase = fposmod(stride_phase + moved_distance/lerpf(WALK_CYCLE_DISTANCE,RUN_CYCLE_DISTANCE,run_blend),1.0)
	var next := "jump" if not grounded else (("run" if run_blend>0.5 else "walk") if actually_moving else "idle")
	animation = next
	_advance_authority_gesture(delta)
	if action_remaining <= 0:
		if visual.animation_state != ("idle" if next in ["walk","run","jump"] else next):
			visual.play_animation("idle")
	visual.advance(delta)
	# Visible stride/suspension while provisional seed has no side motion strip.
	visual.scale.x = facing
	visual.rotation = (sin(stride_phase*TAU)*0.025 if next in ["walk","run"] else -facing*0.055 if next == "jump" else 0.0)
	visual.position.y = _visible_foot_padding()
	_advance_side_motion(delta)
	if continuous_motion != null:
		var motion_state: String = animation
		if continuous_motion is PixelActor and motion_state == "jump" and velocity.y >= 0:
			motion_state = "fall"
		if action_remaining > 0: motion_state = action_animation if not action_animation.is_empty() else visual.animation_state
		elif authority_gesture_elapsed >= 0.0:
			motion_state = "cast"
		continuous_motion.set_motion_state(motion_state,velocity,facing)
		if authority_gesture_elapsed >= 0.0 and action_remaining <= 0.0:
			continuous_motion.state_time = maxf(0.0, authority_gesture_elapsed - delta)
		if continuous_motion is PixelActor:
			continuous_motion.advance(delta,moved_distance if grounded else 0.0)
			stride_phase = continuous_motion.phase
		else:
			continuous_motion.advance(delta)
		idle_authority_phase = continuous_motion.clock
		# Ambient response follows the displayed idle hand gesture, not a sine clock.
		idle_authority_pulse = sin(clampf(authority_gesture_elapsed / _authority_gesture_duration(), 0.0, 1.0) * PI) if authority_gesture_elapsed >= 0.0 and action_remaining <= 0.0 else 0.0
		visual.visible = false
		if side_sprite != null: side_sprite.visible = false
	refresh_authority_presentation()

func _authority_gesture_duration() -> float:
	if continuous_motion is PixelActor:
		var clip: Dictionary = continuous_motion.animations.get("cast", {})
		if not clip.is_empty():
			return float(clip.frames.size()) / float(clip.fps)
	return 0.5

func _advance_authority_gesture(delta: float) -> void:
	var unlocked: bool = continuous_motion != null and continuous_motion.authority_unlocked
	if not unlocked:
		authority_idle_elapsed = 0.0
		authority_gesture_elapsed = -1.0
		authority_intensity = 0.0
		return
	var casting := action_remaining > 0.0 and action_animation == "cast"
	var resting := grounded and animation == "idle" and action_remaining <= 0.0
	if not resting:
		authority_idle_elapsed = 0.0
		authority_gesture_elapsed = -1.0
	elif authority_gesture_elapsed >= 0.0:
		authority_gesture_elapsed += delta
		if authority_gesture_elapsed >= _authority_gesture_duration():
			authority_gesture_elapsed = -1.0
	else:
		authority_idle_elapsed += delta
		if authority_idle_elapsed >= 4.0:
			authority_idle_elapsed = 0.0
			authority_gesture_elapsed = 0.0
	var manifesting := casting or authority_gesture_elapsed >= 0.0
	authority_intensity = move_toward(authority_intensity, 1.0 if manifesting else 0.0, delta * (12.0 if manifesting else 4.5))

## Called after local advance and after temporal history restores.
func refresh_authority_presentation() -> void:
	if authority_dial == null: return
	var anchor := casting_presentation()
	var unlocked: bool = continuous_motion != null and continuous_motion.authority_unlocked
	authority_dial.configure_presentation(to_local(anchor.origin), anchor.height, authority_intensity if unlocked else 0.0, idle_authority_phase)
func _visible_foot_padding() -> float:
	var texture: Texture2D = visual.sprite.texture
	var fit: float = visual.sprite.scale.y
	if visual.animated_sprite.visible:
		texture = visual.animated_sprite.sprite_frames.get_frame_texture(visual.animated_sprite.animation,visual.animated_sprite.frame)
		fit = visual.animated_sprite.scale.y
	if texture == null:
		return 0.0
	var key := texture.get_instance_id()
	if not foot_padding.has(key):
		var image := texture.get_image()
		if image.is_compressed():
			image.decompress()
		foot_padding[key] = float(image.get_height()-image.get_used_rect().end.y)
	return float(foot_padding[key])*fit
func play_action(action: String) -> void:
	visual.play_animation(action)
	action_animation = action
	action_remaining = 0.4
	if continuous_motion is PixelActor:
		var strip: Dictionary = continuous_motion.animations.get(action,{})
		if not strip.is_empty():
			action_remaining = float(strip.frames.size())/float(strip.fps)
		continuous_motion.set_motion_state(action,velocity,facing)
		continuous_motion.state_time = 0.0
		continuous_motion._sample()

func casting_presentation() -> Dictionary:
	if continuous_motion is PixelActor and continuous_motion.sprite.texture != null:
		var used: Rect2i = continuous_motion.sprite.texture.get_image().get_used_rect()
		var height: float = float(used.size.y)*continuous_motion.display_scale
		if height > 0:
			var bottom: float = (continuous_motion.sprite.position.y+used.end.y)*continuous_motion.display_scale
			# Preserve the original relative casting height using the visible raster body.
			return {"origin":to_global(Vector2(0,bottom-height*180.0/217.0)),"height":height}
	return {"origin":global_position+Vector2(0,-180),"height":217.0}
func hitbox() -> Rect2:
	return Rect2(global_position+Vector2(-collision_radius-1,-collision_height),Vector2((collision_radius+1)*2,collision_height))

func _build_side_motion() -> void:
	var path := "res://assets/exploration/side_motion.png"
	if not ResourceLoader.exists(path):
		return
	var sheet := load(path) as Texture2D
	var bounds := [[42,25,448,452],[507,23,850,452],[916,24,1269,452],[1370,24,1744,452],[32,548,430,863],[494,454,870,789],[934,473,1285,864],[1335,572,1742,863]]
	var anchors := [Vector2(320,452),Vector2(750,452),Vector2(1180,452),Vector2(1620,452),Vector2(350,863),Vector2(780,789),Vector2(1180,864),Vector2(1620,863)]
	for i in bounds.size():
		var box: Array = bounds[i]
		var region := Rect2(box[0]-1,box[1]-1,box[2]-box[0]+2,box[3]-box[1]+2)
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = region
		frame.filter_clip = true
		side_frames.append(frame)
		side_anchors.append(anchors[i]-region.position)
	side_sprite = Sprite2D.new()
	side_sprite.name = "AuthoredSideMotion"
	side_sprite.centered = false
	side_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(side_sprite)
	_advance_side_motion(0.0)
func _advance_side_motion(delta: float) -> void:
	if side_sprite == null:
		return
	landing_remaining = maxf(0,landing_remaining-delta)
	jump_elapsed += delta
	if action_remaining<=0 and visual.animation_state in ["cast","attack","hurt"] and visual.feedback_remaining>0:
		action_remaining = visual.feedback_remaining if not grounded else 0.0
	if not grounded:
		side_frame = 4 if jump_elapsed < 0.1 else 5 if velocity.y<0 else 6
	elif landing_remaining>0:
		side_frame = 7
	elif animation in ["walk","run"]:
		side_frame = int(stride_phase*4.0)%4
	else:
		side_frame = 0
	var fit := 217.0/429.0
	var frame_texture: AtlasTexture = side_frames[side_frame]
	var anchor: Vector2 = side_anchors[side_frame]
	if locomotion_ready and grounded and landing_remaining<=0 and animation in ["walk","run"]:
		var gait := "run" if run_blend>0.5 else "walk"
		var frame_index := int(stride_phase*8.0)%8
		frame_texture = locomotion_frames[gait][frame_index]
		anchor = locomotion_anchors[gait][frame_index]
		fit = locomotion_scale
	elif locomotion_ready and grounded and landing_remaining<=0 and animation=="idle" and not locomotion_idle.is_empty():
		frame_texture = locomotion_idle.frame
		anchor = locomotion_idle.anchor
		fit = locomotion_scale
	side_sprite.texture = frame_texture
	side_sprite.scale = Vector2(facing*fit,fit)
	side_sprite.position = -anchor*Vector2(facing*fit,fit)
	if grounded and absf(floor_normal.y)>0.01:
		var forward_foot := (frame_texture.region.size.x-anchor.x-8.0)*fit*facing
		side_sprite.position.y += -floor_normal.x/floor_normal.y*forward_foot
	side_sprite.visible = action_remaining<=0
	visual.visible = not side_sprite.visible
	# Side authored frames own movement; combat retains the existing actor actions.
	if side_sprite.visible:
		visual.rotation = 0.0




func _build_locomotion() -> void:
	var metadata_path := "res://assets/exploration/locomotion_frames.json"
	if not FileAccess.file_exists(metadata_path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not data is Dictionary or float(data.get("scale",0.0))<=0:
		return
	var default_texture := str(data.get("texture",""))
	for gait in ["walk","run"]:
		if not data.get(gait) is Array or data[gait].size()!=8:
			return
		var frames: Array[AtlasTexture] = []
		var anchors: Array[Vector2] = []
		for item in data[gait]:
			var entry := _locomotion_entry(item,default_texture)
			if entry.is_empty(): return
			frames.append(entry.frame)
			anchors.append(entry.anchor)
		locomotion_frames[gait] = frames
		locomotion_anchors[gait] = anchors
	if data.has("idle"):
		locomotion_idle = _locomotion_entry(data.idle,default_texture)
	locomotion_scale = float(data.scale)
	locomotion_ready = true

func _locomotion_entry(item,default_texture: String) -> Dictionary:
	if not item is Dictionary or not item.get("rect") is Array or item.rect.size()!=4 or not item.get("anchor") is Array or item.anchor.size()!=2:
		return {}
	var texture_path := str(item.get("texture",default_texture))
	if not ResourceLoader.exists(texture_path): return {}
	if not locomotion_textures.has(texture_path):
		locomotion_textures[texture_path] = load(texture_path) as Texture2D
	var sheet: Texture2D = locomotion_textures[texture_path]
	if sheet == null: return {}
	var region := Rect2(item.rect[0],item.rect[1],item.rect[2],item.rect[3])
	if region.size.x<=0 or region.size.y<=0 or region.position.x<0 or region.position.y<0 or region.end.x>sheet.get_width() or region.end.y>sheet.get_height(): return {}
	var frame := AtlasTexture.new()
	frame.atlas = sheet
	frame.region = region
	frame.filter_clip = true
	return {"frame":frame,"anchor":Vector2(item.anchor[0],item.anchor[1])}

func _build_continuous_motion() -> void:
	var pixel := PixelActor.new()
	if pixel.configure_key("player"):
		continuous_motion = pixel
		collision_height = 130.0
		collision_radius = 22.0
		for child in get_children():
			if child is CollisionShape2D and child.shape is CapsuleShape2D:
				child.shape.height = collision_height
				child.shape.radius = collision_radius
				child.position = Vector2(0,-collision_height*.5)
		pixel.name = "PixelPlayer"
		add_child(pixel)
		visual.visible = false
		if side_sprite != null: side_sprite.visible = false
		return
	pixel.free()
	var config: Dictionary = {}
	var path := "res://assets/exploration/continuous_rig.json"
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary: config = parsed
	var texture: Texture2D = null
	if ResourceLoader.exists(str(config.get("texture",""))):
		texture = load(str(config.texture)) as Texture2D
	elif FileAccess.file_exists(str(config.get("texture",""))):
		var source_image := Image.load_from_file(ProjectSettings.globalize_path(str(config.texture)))
		if source_image != null: texture = ImageTexture.create_from_image(source_image)
	if texture == null and not side_frames.is_empty():
		texture = side_frames[0]
		config = {"anchor":[side_anchors[0].x,side_anchors[0].y],"scale":217.0/429.0}
	if texture == null: return
	continuous_motion = ContinuousMotion.new()
	continuous_motion.name = "ContinuousCharacterRig"
	add_child(continuous_motion)
	continuous_motion.configure(texture,217.0,config)
	visual.visible = false
	if side_sprite != null: side_sprite.visible = false

func set_authority_unlocked(value: bool) -> void:
	if continuous_motion != null: continuous_motion.authority_unlocked = value
	if not value:
		authority_idle_elapsed = 0.0
		authority_gesture_elapsed = -1.0
		authority_intensity = 0.0
		idle_authority_pulse = 0.0
	refresh_authority_presentation()

func presentation_state() -> Dictionary:
	return continuous_motion.presentation_state() if continuous_motion != null else {}
