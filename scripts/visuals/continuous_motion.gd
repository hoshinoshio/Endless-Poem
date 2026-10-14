extends Node2D
## A single source image, continuously skinned on the supplied simulation clock.
var mesh_view: MeshInstance2D
var rest := PackedVector2Array()
var uv := PackedVector2Array()
var indices := PackedInt32Array()
var skin_weights: Array[PackedFloat32Array] = []
var joint_keys: Array = []
var joints: Dictionary = {}
var posed_joints: Dictionary = {}
var clock := 0.0
var phase := 0.0
var state := "idle"
var speed := 0.0
var facing := 1.0
var authority_unlocked := true
var authority_pulse := 0.0
var mechanical := false
var source_size := Vector2.ONE
var anchor := Vector2.ZERO
var fit := 1.0
var state_time := 0.0
var movement_blend := 0.0
var vertical_speed := 0.0
var leg_views: Dictionary = {}
var leg_vertices: Dictionary = {}
var leg_uv: Dictionary = {}
var leg_indices: Dictionary = {}
var ankle_joints: Dictionary = {}
var hip_joints: Dictionary = {}
var foot_angles: Dictionary = {}
var partitioned := false
var visual_accumulator := 1.0
var render_enabled := true
var extended_arm := false
var arm_shoulder := Vector2.ZERO
var arm_angle := 0.0
var arm_weights := PackedFloat32Array()
var inner_cloak: MeshInstance2D
var cloak_rest := PackedVector2Array()
var cloak_uv := PackedVector2Array()
var cloak_indices := PackedInt32Array()

func configure(texture: Texture2D, height: float, config: Dictionary = {}, is_mechanical: bool = false) -> void:
	mechanical = is_mechanical
	# Mesh UVs address a texture directly; bake atlas regions into an in-memory texture.
	if texture is AtlasTexture:
		texture = ImageTexture.create_from_image(texture.get_image())
	var region := Rect2(Vector2.ZERO,texture.get_size())
	if config.get("rect") is Array:
		var r: Array = config.rect
		region = Rect2(r[0],r[1],r[2],r[3])
	var shown: Texture2D = texture
	if region.size != texture.get_size() or region.position != Vector2.ZERO:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = region
		shown = atlas
	source_size = region.size
	anchor = _point(config.get("anchor"),Vector2(source_size.x*0.5,source_size.y))
	fit = float(config.get("scale",height/source_size.y))
	var defaults := {"head":Vector2(.5,.16),"shoulder":Vector2(.5,.32),"hip":Vector2(.5,.59),"left_knee":Vector2(.44,.79),"right_knee":Vector2(.56,.79),"left_foot":Vector2(.44,.98),"right_foot":Vector2(.56,.98),"left_hand":Vector2(.28,.56),"right_hand":Vector2(.72,.56)}
	for key in defaults:
		joints[key] = (_point(config.get("joints",{}).get(key),defaults[key]*source_size)-anchor)*fit
	extended_arm = config.get("joints",{}).has("right_shoulder")
	arm_shoulder = (_point(config.get("joints",{}).get("right_shoulder"),Vector2(source_size.x*.55,source_size.y*.21))-anchor)*fit
	if mesh_view == null:
		mesh_view = MeshInstance2D.new()
		mesh_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(mesh_view)
	mesh_view.texture = shown
	rest.clear(); uv.clear(); indices.clear()
	var columns := 24
	var rows := 36
	for y in rows+1:
		for x in columns+1:
			var unit := Vector2(float(x)/columns,float(y)/rows)
			rest.append((unit*source_size-anchor)*fit)
			uv.append(unit)
	for y in rows:
		for x in columns:
			var a := y*(columns+1)+x
			indices.append_array(PackedInt32Array([a,a+1,a+columns+1,a+1,a+columns+2,a+columns+1]))
	joint_keys = joints.keys()
	skin_weights.clear()
	for v in rest:
		var weights := PackedFloat32Array()
		var total := 0.0
		for key in joint_keys:
			var radius := 26.0 if key.contains("foot") or key.contains("knee") else 38.0
			var weight := exp(-v.distance_squared_to(joints[key])/(radius*radius))
			if key.begins_with("left_") and (key.contains("knee") or key.contains("foot")):
				weight *= 1.0-smoothstep(joints.hip.x-3,joints.hip.x+3,v.x)
			elif key.begins_with("right_") and (key.contains("knee") or key.contains("foot")):
				weight *= smoothstep(joints.hip.x-3,joints.hip.x+3,v.x)
			weights.append(weight)
			total += weight
		for i in weights.size(): weights[i] /= maxf(total,.001)
		skin_weights.append(weights)
	arm_weights.clear()
	for v in rest:
		var segment := Geometry2D.get_closest_point_to_segment(v,arm_shoulder,joints.right_hand)
		var d := minf(v.distance_to(segment),v.distance_to(joints.right_hand)*.7)
		arm_weights.append(1.0-smoothstep(12.0,16.0,d))
	if config.has("joints") and source_size.x>900:
		_build_leg_partitions(shown,config)
	_sample()

func _point(value, fallback: Vector2) -> Vector2:
	return Vector2(value[0],value[1]) if value is Array and value.size()==2 else fallback

func set_motion_state(value: String, velocity: Vector2, direction: float) -> void:
	if state != value:
		state_time = 0.0
	state = value
	speed = absf(velocity.x)
	vertical_speed = velocity.y
	if state=="recovery": state="recover"
	facing = direction if direction != 0 else facing

func advance(delta: float) -> void:
	if delta <= 0: return
	clock += delta
	state_time += delta
	movement_blend = move_toward(movement_blend,1.0 if state in ["walk","run","pursue","patrol"] else 0.0,delta*8.0)
	phase = fposmod(phase+delta*(speed/340.0 if state=="run" else speed/220.0),1.0)
	visual_accumulator += delta
	_sample()

func _leg(side: String, offset: float, body: Vector2) -> void:
	var source_root: Vector2 = hip_joints.get(side,joints.hip)
	var source_ankle: Vector2 = ankle_joints.get(side,joints[side+"_foot"])
	var root: Vector2 = source_root+body
	var base: Vector2 = joints[side+"_foot"]
	var p := fposmod(phase+offset,1.0)
	var stride := (27.0 if state=="run" else 18.0)*movement_blend
	var lift := -sin((p-.5)*TAU)*(26.0 if state=="run" else 15.0)*movement_blend if p>=.5 else 0.0
	var foot := base+Vector2(lerpf(stride,-stride,p*2.0) if p<.5 else lerpf(-stride,stride,(p-.5)*2.0),lift)
	foot.y -= base.y*movement_blend
	var jumping := state=="jump"
	if jumping:
		foot = base+Vector2((12 if side=="left" else -9),-20 if vertical_speed<0 else -8)
	var ankle: Vector2 = source_ankle+foot-base
	var upper: float = source_root.distance_to(joints[side+"_knee"])
	var lower: float = joints[side+"_knee"].distance_to(source_ankle)
	var distance := clampf(root.distance_to(ankle),.01,upper+lower-.01)
	var direction := (ankle-root).normalized()
	# An unreachable foot is clamped to the chain length instead of stretching bones.
	ankle = root+direction*distance
	var along: float = (upper*upper-lower*lower+distance*distance)/(2*distance)
	var bend := sqrt(maxf(0,upper*upper-along*along))
	var knee := root+direction*along+Vector2(direction.y,-direction.x)*bend
	var blend := 1.0 if jumping else movement_blend
	posed_joints[side+"_hip"] = source_root.lerp(root,blend)
	posed_joints[side+"_knee"] = joints[side+"_knee"].lerp(knee,blend)
	posed_joints[side+"_ankle"] = source_ankle.lerp(ankle,blend)
	posed_joints[side+"_foot"] = base+posed_joints[side+"_ankle"]-source_ankle
	foot_angles[side] = sin((p-.5)*TAU)*.18*movement_blend if p>=.5 else 0.0
	if jumping: foot_angles[side] = -.18 if side=="left" else .13

func _bone_transform(point: Vector2, start: Vector2, end: Vector2, posed_start: Vector2, posed_end: Vector2) -> Vector2:
	return posed_start+(point-start).rotated((posed_end-posed_start).angle()-(end-start).angle())

func _build_leg_partitions(texture: Texture2D, config: Dictionary) -> void:
	partitioned = true
	# Source has no hidden pixels behind its close-set legs. Reuse the approved
	# inner-lining strip as an overlapping back layer, visible only through the cutouts.
	inner_cloak = MeshInstance2D.new()
	inner_cloak.texture = texture
	inner_cloak.z_index = 0
	inner_cloak.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	inner_cloak.modulate = Color(.6,.6,.7,1.0)
	var lining_material := ShaderMaterial.new()
	lining_material.shader = load("res://scripts/visuals/continuous_motion.gdshader")
	lining_material.set_shader_parameter("inner_lining",true)
	inner_cloak.material = lining_material
	add_child(inner_cloak)
	move_child(inner_cloak,0)
	for row in 13:
		for column in 3:
			var unit := Vector2(column/2.0,row/12.0)
			var width := 170.0*(1.0-.4*pow(unit.y,5))
			var source_point := Vector2(660+(unit.x-.5)*width,850+unit.y*450-sin(unit.x*PI)*14*pow(unit.y,5))
			cloak_rest.append((source_point-anchor)*fit)
			cloak_uv.append(Vector2(710+unit.x*30,970+unit.y*255)/source_size)
	for row in 12:
		for column in 2:
			var a := row*3+column
			cloak_indices.append_array(PackedInt32Array([a,a+1,a+3,a+1,a+4,a+3]))
	var regions := {
		"left":PackedVector2Array([Vector2(619,865),Vector2(654,850),Vector2(652,1040),Vector2(643,1220),Vector2(646,1260),Vector2(646,1320),Vector2(673,1385),Vector2(696,1440),Vector2(693,1465),Vector2(603,1458),Vector2(566,1434),Vector2(565,1360),Vector2(578,1280),Vector2(574,1230),Vector2(583,1170),Vector2(588,1045),Vector2(576,946)]),
		"right":PackedVector2Array([Vector2(682,735),Vector2(752,720),Vector2(716,950),Vector2(700,1150),Vector2(696,1235),Vector2(701,1320),Vector2(726,1380),Vector2(769,1415),Vector2(765,1446),Vector2(686,1442),Vector2(652,1412),Vector2(640,1350),Vector2(640,1260),Vector2(641,1170),Vector2(649,1080),Vector2(652,950),Vector2(663,810)])}
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/visuals/continuous_motion.gdshader")
	mesh_view.material = material
	for side in ["right","left"]:
		var region: PackedVector2Array = regions[side]
		var normalized := PackedVector2Array()
		for point in region: normalized.append(point/source_size)
		material.set_shader_parameter(side+"_count",normalized.size())
		while normalized.size()<20: normalized.append(Vector2.ZERO)
		material.set_shader_parameter(side+"_region",normalized)
		ankle_joints[side] = (Vector2(610,1235) if side=="left" else Vector2(672,1230))-anchor
		ankle_joints[side] *= fit
		hip_joints[side] = (Vector2(620,750) if side=="left" else Vector2(716,750))-anchor
		hip_joints[side] *= fit
		var points := PackedVector2Array()
		var texcoords := PackedVector2Array()
		var triangles := PackedInt32Array()
		# Independent dense UV patches can overlap after posing without welding trousers together.
		for row in 24:
			for column in 10:
				var corner := Vector2(540+column*24,700+row*32)
				var cell := PackedVector2Array([corner,corner+Vector2(24,0),corner+Vector2(24,32),corner+Vector2(0,32)])
				for clipped in Geometry2D.intersect_polygons(cell,region):
					var base := points.size()
					for point in clipped:
						points.append((point-anchor)*fit)
						texcoords.append(point/source_size)
					for index in Geometry2D.triangulate_polygon(clipped): triangles.append(base+index)
		leg_vertices[side] = points
		leg_uv[side] = texcoords
		leg_indices[side] = triangles
		var view := MeshInstance2D.new()
		view.texture = texture
		view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		view.name = side.capitalize()+"ArticulatedLeg"
		add_child(view)
		leg_views[side] = view

func _update_leg_meshes() -> void:
	for side in leg_views:
		var vertices := PackedVector2Array()
		var knee: Vector2 = joints[side+"_knee"]
		var ankle: Vector2 = ankle_joints[side]
		var hip: Vector2 = hip_joints[side]
		for v in leg_vertices[side]:
			var upper := _bone_transform(v,hip,knee,posed_joints[side+"_hip"],posed_joints[side+"_knee"])
			var lower := _bone_transform(v,knee,ankle,posed_joints[side+"_knee"],posed_joints[side+"_ankle"])
			var result := upper.lerp(lower,smoothstep(knee.y-5,knee.y+5,v.y))
			# Every boot vertex shares ONE rigid transform; no shoe size or shape drift.
			var boot: Vector2 = posed_joints[side+"_ankle"]+(v-ankle).rotated(foot_angles[side])
			result = result.lerp(boot,smoothstep(ankle.y-12,ankle.y-3,v.y))
			vertices.append(result*Vector2(facing,1))
		leg_views[side].mesh = _make_mesh(vertices,leg_uv[side],leg_indices[side])

func _make_mesh(vertices: PackedVector2Array, texcoords: PackedVector2Array, triangles: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = texcoords
	arrays[Mesh.ARRAY_INDEX] = triangles
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _sample() -> void:
	if mesh_view == null: return
	authority_pulse = pow(maxf(0,sin(clock*1.7)),8.0) if state=="idle" and authority_unlocked else 0.0
	var body := Vector2(0,((7.0 if state=="run" else 4.0)+absf(sin(phase*TAU))*3.0)*movement_blend+sin(clock*2)*.7*(1-movement_blend))
	posed_joints = joints.duplicate()
	posed_joints.hip = joints.hip+body
	posed_joints.shoulder = joints.shoulder+body*.7
	posed_joints.head = joints.head+body*.18
	_leg("left",0,body)
	_leg("right",.5,body)
	var action := sin(clampf(state_time/(.3 if state=="windup" else .2),0,1)*PI*.5)
	var arm := sin(phase*TAU)*16*movement_blend
	posed_joints.left_hand = joints.left_hand+Vector2(-arm,-authority_pulse*12)
	posed_joints.right_hand = joints.right_hand+Vector2(arm,-authority_pulse*18)
	if state in ["windup","attack","cast","recover"]:
		posed_joints.right_hand += Vector2((-20 if state=="windup" else 38 if state in ["attack","cast"] else 15)*action,-12*action)
	arm_angle = sin(phase*TAU)*.06*movement_blend+sin(clock*1.8)*.003*(1-movement_blend)-authority_pulse*.008
	if state=="windup": arm_angle -= .12*action
	elif state in ["attack","cast"]: arm_angle += .16*action
	elif state=="recover": arm_angle += .07*exp(-state_time*5.0)
	var arm_body := body*(.25 if state=="idle" else .7)
	if extended_arm:
		posed_joints.right_hand = arm_shoulder+(joints.right_hand-arm_shoulder).rotated(arm_angle)+arm_body
	if not render_enabled or visual_accumulator < 1.0/60.0: return
	visual_accumulator = fmod(visual_accumulator,1.0/60.0)
	var vertices := PackedVector2Array()
	for vertex_index in rest.size():
		var v: Vector2 = rest[vertex_index]
		var displaced := Vector2.ZERO
		var weights: PackedFloat32Array = skin_weights[vertex_index]
		for i in joint_keys.size():
			var key: String = joint_keys[i]
			if partitioned and (key.contains("knee") or key.contains("foot")): continue
			displaced += (posed_joints[key]-joints[key])*weights[i]
		var result := v+displaced
		if extended_arm:
			var arm_position := arm_shoulder+(v-arm_shoulder).rotated(arm_angle)+arm_body
			result = result.lerp(arm_position,arm_weights[vertex_index])
		# Hair and loose hems lag the body independently of the joint pose.
		var normalized := (v/fit+anchor)/source_size
		result.x += sin(clock*3.7-normalized.y*5)*1.8*maxf(0,absf(normalized.x-.5)-.2)*(1+movement_blend*2)
		if mechanical:
			var center := Vector2(0,-source_size.y*fit*.5)
			var local := v-center
			var ring_weight := smoothstep(25.0,70.0,local.length())
			result = center+local.rotated(sin(clock*.8)*.16*ring_weight)+Vector2(sin(clock*1.3)*2, sin(clock*2.1)*4)
		vertices.append(result*Vector2(facing,1))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh_view.mesh = mesh
	if partitioned:
		_update_leg_meshes()
		var cloak_vertices := PackedVector2Array()
		for v in cloak_rest:
			var hem_weight := smoothstep(-85.0,-20.0,v.y)
			cloak_vertices.append((v+body*.7+Vector2(sin(clock*3.7-1)*hem_weight*2*movement_blend,0))*Vector2(facing,1))
		inner_cloak.mesh = _make_mesh(cloak_vertices,cloak_uv,cloak_indices)

func presentation_state() -> Dictionary:
	return {"state":state,"phase":phase,"joints":posed_joints.duplicate(),"authority_pulse":authority_pulse,"clock":clock,"movement_blend":movement_blend,"vertex_count":rest.size()}
