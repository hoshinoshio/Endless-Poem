extends Node2D
## Authored raster frames, sampled exclusively from the caller's local clock.
const MANIFEST := "res://assets/pixel_v1/manifest.json"
var clock := 0.0
var phase := 0.0
var state := "idle"
var speed := 0.0
var facing := 1.0
var state_time := 0.0
var movement_blend := 0.0
var vertical_speed := 0.0
var authority_pulse := 0.0
var visual_accumulator := 0.0
var render_enabled := true
var authority_unlocked := true
var actor_key := ""
var mechanical := false
var frames_ready := false
var display_scale := 3
var source_scale := 1.0
## Manifest frame_anchor shifts the fixed raster canvas relative to the foot origin.
## E.g. [32,64] reserves 32 pixels behind a right-facing asymmetric hairstyle.
var frame_anchor := Vector2(24,64)
var sprite: Sprite2D
var textures: Array[Texture2D] = []
var animations: Dictionary = {}
var frame_index := 0
var sampled_animation := "idle"
## Both gait strips start at the same foot contact and share this normalized phase.
var walk_cycle_distance := 100.0
var run_cycle_distance := 160.0
var transition := ""
var transition_time := 0.0

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite = Sprite2D.new()
	sprite.name = "PixelFrames48x64"
	sprite.centered = false
	sprite.position = Vector2(-24,-64)
	add_child(sprite)

func configure_key(key: String) -> bool:
	if not FileAccess.file_exists(MANIFEST): return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not data is Dictionary or not bool(data.get("ready",false)): return false
	var size_data = data.get("frame_size",[])
	# JSON numbers are floats; normalize the two dimensions before comparison.
	if not size_data is Array or size_data.size()!=2 or int(size_data[0])!=48 or int(size_data[1])!=64: return false
	var config = data.get("actors",{}).get(key)
	if not config is Dictionary: return false
	actor_key = key
	return configure(config)

func configure(config: Dictionary) -> bool:
	frames_ready = false
	textures.clear()
	var entries = config.get("source_frames",[])
	if not entries is Array or entries.is_empty(): return false
	var crops: Array[Image] = []
	var anchors: Array[Vector2] = []
	var sources: Dictionary = {}
	var extent := Vector2.ZERO
	var configured_anchor = config.get("frame_anchor",[24,64])
	if not configured_anchor is Array or configured_anchor.size()!=2: return false
	frame_anchor = Vector2(float(configured_anchor[0]),float(configured_anchor[1]))
	if frame_anchor.x<0 or frame_anchor.x>48 or frame_anchor.y<0 or frame_anchor.y>64: return false
	for i in entries.size():
		var entry = entries[i]
		var rect_data = entry.get("rect",[]) if entry is Dictionary else entry
		var path := str(entry.get("sheet",config.get("sheet",""))) if entry is Dictionary else str(config.get("sheet",""))
		if not rect_data is Array or rect_data.size()!=4 or not FileAccess.file_exists(path): return false
		if not sources.has(path): sources[path] = Image.load_from_file(ProjectSettings.globalize_path(path))
		var image: Image = sources[path]
		if image == null or image.is_empty(): return false
		var rect := Rect2i(int(rect_data[0]),int(rect_data[1]),int(rect_data[2]),int(rect_data[3]))
		if rect.size.x<=0 or rect.size.y<=0 or not Rect2i(Vector2i.ZERO,image.get_size()).encloses(rect): return false
		var crop := image.get_region(rect)
		crop.convert(Image.FORMAT_RGBA8)
		crops.append(crop)
		var anchor_data = entry.get("anchor",config.get("source_anchor",[])) if entry is Dictionary else config.get("source_anchors",[])[i] if config.get("source_anchors",[]).size()>i else config.get("source_anchor",[])
		var anchor := Vector2(float(anchor_data[0]),float(anchor_data[1])) if anchor_data is Array and anchor_data.size()==2 else Vector2(rect.size.x*.5,rect.size.y)
		anchors.append(anchor)
		extent.x = maxf(extent.x,maxf(anchor.x,rect.size.x-anchor.x)*2.0)
		extent.y = maxf(extent.y,maxf(anchor.y,rect.size.y))
	source_scale = float(config.get("source_scale",minf(48.0/maxf(1,extent.x),64.0/maxf(1,extent.y))))
	if source_scale<=0: return false
	for i in crops.size():
		var crop: Image = crops[i]
		crop.resize(maxi(1,roundi(crop.get_width()*source_scale)),maxi(1,roundi(crop.get_height()*source_scale)),Image.INTERPOLATE_NEAREST)
		var canvas := Image.create(48,64,false,Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		var destination := Vector2i(roundi(frame_anchor.x),roundi(frame_anchor.y))-Vector2i(roundi(anchors[i].x*source_scale),roundi(anchors[i].y*source_scale))
		canvas.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),destination)
		textures.append(ImageTexture.create_from_image(canvas))
	animations = config.get("animations",{}).duplicate(true)
	if not animations.has("idle"): return false
	for key in animations:
		var animation = animations[key]
		if not animation is Dictionary or not animation.get("frames") is Array or animation.frames.is_empty() or float(animation.get("fps",0))<=0: return false
		for index in animation.frames:
			if int(index)<0 or int(index)>=textures.size(): return false
	display_scale = maxi(1,int(config.get("scale",3)))
	walk_cycle_distance = maxf(1.0,float(config.get("walk_cycle_distance",100.0)))
	run_cycle_distance = maxf(1.0,float(config.get("run_cycle_distance",160.0)))
	transition = ""
	transition_time = 0.0
	mechanical = bool(config.get("mechanical",false))
	scale = Vector2.ONE*display_scale
	frames_ready = true
	_sample()
	return true

func set_motion_state(value: String, velocity: Vector2, direction: float) -> void:
	var previous := state
	var moving := value in ["walk","run","pursue","patrol"]
	var was_moving := previous in ["walk","run","pursue","patrol"]
	var turned := direction != 0 and signf(direction) != facing
	# Transition strips never delay physics. Actions and airborne states interrupt them.
	if value in ["jump","fall","cast","attack","hurt","defeat"]:
		transition = ""
	elif previous in ["jump","fall"] and value in ["idle","walk","run"]:
		_begin_transition("land")
	elif moving and turned:
		_begin_transition("turn")
	elif moving and not was_moving:
		_begin_transition("start")
	elif value == "idle" and was_moving:
		_begin_transition("stop")
	if state != value: state_time = 0.0
	state = value
	speed = absf(velocity.x)
	vertical_speed = velocity.y
	if direction != 0: facing = signf(direction)

func _begin_transition(name: String) -> void:
	transition = name if animations.has(name) and not mechanical else ""
	transition_time = 0.0

## Supplying real displacement avoids skating against walls and while airborne.
## Other callers retain a velocity-driven fallback.
func advance(delta: float, traveled_distance: float = -1.0) -> void:
	if delta<=0: return
	clock += delta
	state_time += delta
	movement_blend = move_toward(movement_blend,1.0 if state in ["walk","run","pursue","patrol"] else 0.0,delta*8)
	if state in ["walk","run","pursue","patrol"]:
		var distance := maxf(0.0,traveled_distance) if traveled_distance >= 0 else delta*speed
		phase = fposmod(phase+distance/(run_cycle_distance if state=="run" else walk_cycle_distance),1.0)
	if not transition.is_empty():
		transition_time += delta
		var strip: Dictionary = animations[transition]
		if transition_time >= strip.frames.size()/float(strip.fps):
			transition = ""
	visual_accumulator += delta
	_sample()

func _sample() -> void:
	if not frames_ready: return
	var requested := state
	if requested in ["pursue","patrol"]: requested = "walk"
	if requested in ["recovery","recover"]: requested = "recover"
	if mechanical and requested in ["walk","run","jump"]: requested = "hover"
	if requested == "jump" and vertical_speed>=0 and animations.has("fall"): requested = "fall"
	if not transition.is_empty(): requested = transition
	sampled_animation = requested if animations.has(requested) else "idle"
	var animation: Dictionary = animations[sampled_animation]
	var frames: Array = animation.frames
	var raw := floori(clock*float(animation.fps))
	if sampled_animation in ["walk","run"]: raw = floori(fposmod(phase,1.0)*frames.size())
	elif not transition.is_empty(): raw = floori(transition_time*float(animation.fps))
	elif not bool(animation.get("loop",true)): raw = floori(state_time*float(animation.fps))
	# Start/stop/turn/land always play once, even if loop was omitted in metadata.
	frame_index = posmod(raw,frames.size()) if bool(animation.get("loop",true)) and transition.is_empty() else clampi(raw,0,frames.size()-1)
	sprite.texture = textures[int(frames[frame_index])]
	sprite.scale = Vector2(facing,1)
	sprite.position = Vector2(-frame_anchor.x*facing,-frame_anchor.y)
	sprite.visible = render_enabled
	authority_pulse = pow(maxf(0,sin(clock*1.7)),8) if authority_unlocked and state=="idle" else 0.0

func presentation_state() -> Dictionary:
	return {"renderer":"pixel_frames","actor":actor_key,"state":state,"animation":sampled_animation,"frame":frame_index,"clock":clock,"phase":phase,"movement_blend":movement_blend,"authority_pulse":authority_pulse,"frame_size":Vector2i(48,64),"scale":display_scale,"source_scale":source_scale}
