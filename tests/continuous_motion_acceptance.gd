extends SceneTree
const Player = preload("res://scripts/exploration/exploration_player.gd")
const Motion = preload("res://scripts/visuals/continuous_motion.gd")
var failures := 0
func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ")+label)
	if not value: failures += 1
func _initialize() -> void:
	var image := Image.create(160,240,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var rig := Motion.new()
	root.add_child(rig)
	rig.configure(ImageTexture.create_from_image(image),217)
	rig.set_motion_state("walk",Vector2(390,0),1)
	rig.advance(.113)
	var first: Dictionary = rig.presentation_state()
	var vertices_a: PackedVector2Array = rig.mesh_view.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	rig.advance(.017)
	var second: Dictionary = rig.presentation_state()
	check(first.joints.left_knee != second.joints.left_knee,"intermediate walk knee changes continuously")
	check(vertices_a != rig.mesh_view.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"intermediate UV mesh differs")
	check(second.joints.left_foot.y != second.joints.right_foot.y,"opposed support and swing feet")
	var frozen: Dictionary = rig.presentation_state()
	rig.advance(0)
	check(frozen == rig.presentation_state(),"pause freezes clock and joints")
	rig.set_motion_state("idle",Vector2.ZERO,1)
	rig.advance(1)
	check(rig.posed_joints.left_knee.is_equal_approx(rig.joints.left_knee),"stopping returns neutral knees")
	check(rig.posed_joints.left_foot.is_equal_approx(rig.joints.left_foot),"stopping returns planted feet")
	rig.authority_unlocked = false
	rig.advance(.1)
	check(rig.authority_pulse == 0,"locked authority has no idle pulse")
	for state in ["run","windup","attack","recover"]:
		rig.set_motion_state(state,Vector2(624,0),1)
		rig.advance(.063)
		var a: Dictionary = rig.presentation_state()
		rig.advance(.013)
		check(a.joints != rig.presentation_state().joints,state+" has continuous intermediate pose")
	check(rig.rest.size() == 925,"dense source UV mesh")
	var player := Player.new()
	root.add_child(player)
	await physics_frame
	await physics_frame
	var real_rig = player.continuous_motion
	check(real_rig.partitioned,"approved source uses independent leg UV partitions")
	real_rig.set_motion_state("run",Vector2(624,0),1)
	real_rig.advance(.173)
	for side in ["left","right"]:
		var source_vertices: PackedVector2Array = real_rig.leg_vertices[side]
		var posed_vertices: PackedVector2Array = real_rig.leg_views[side].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var boot_indices: Array[int] = []
		for i in source_vertices.size():
			if source_vertices[i].y>real_rig.ankle_joints[side].y+2: boot_indices.append(i)
		var a := boot_indices[0]
		var b := boot_indices[boot_indices.size()-1]
		check(is_equal_approx(source_vertices[a].distance_to(source_vertices[b]),posed_vertices[a].distance_to(posed_vertices[b])),side+" boot edge preserves rigid source length")
	real_rig.set_motion_state("jump",Vector2(0,-500),1)
	real_rig.advance(.02)
	check(real_rig.posed_joints.left_knee != real_rig.joints.left_knee,"jump has articulated takeoff knees")
	real_rig.set_motion_state("recovery",Vector2.ZERO,1)
	real_rig.advance(.02)
	check(real_rig.state=="recover","recovery state alias")
	player.set_input(1,false,true)
	player.advance(.01)
	check(player.velocity.x > 0 and player.velocity.x < 624,"Shift run accelerates toward 624 rather than teleporting velocity")
	player.advance(.14)
	check(is_equal_approx(player.velocity.x,624),"Shift run reaches configured 624 speed")
	var player_clock: float = player.elapsed
	var player_position: Vector2 = player.position
	player.advance(0)
	check(player.elapsed == player_clock and player.position == player_position,"player supplied zero clock freezes simulation")
	player.set_input(0,false,false)
	player.advance(.2)
	check(is_zero_approx(player.velocity.x),"release decelerates to stop")
	print("CONTINUOUS_MOTION_FAILURES=",failures)
	quit(failures)
