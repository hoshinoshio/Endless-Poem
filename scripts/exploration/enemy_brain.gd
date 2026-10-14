extends RefCounted
## Per-instance movement intent. The combat model alone decides when actions commit.
var kind := "guard"
var state := "approach"
var state_time := 0.0
var velocity := Vector2.ZERO
var facing := -1.0
var locked := false
var orbit_sign := 1.0
var preferred_distance := 135.0
var speed := 72.0
var recovery_duration := 0.45

func configure(enemy_kind: String, instance_index: int) -> void:
	kind = enemy_kind
	orbit_sign = -1.0 if instance_index % 2 == 0 else 1.0
	match kind:
		"guard":
			preferred_distance = 145.0
			speed = 82.0
		"elite":
			preferred_distance = 170.0
			speed = 48.0
			recovery_duration = 0.75
		"boss":
			preferred_distance = 185.0
			speed = 62.0
			recovery_duration = 0.65
		"instrument", "observer":
			preferred_distance = 290.0
			speed = 58.0
			state = "position"

func transition(next_state: String) -> void:
	if state == next_state: return
	state = next_state
	state_time = 0.0

func prepare(position: Vector2, player: Vector2, remaining: float, is_anchor: bool) -> void:
	if is_anchor:
		transition("position")
		velocity = Vector2.ZERO
		return
	if state in ["strike", "recovery"]: return
	if remaining <= 0.8:
		if not locked:
			facing = 1.0 if player.x >= position.x else -1.0
			locked = true
		transition("telegraph")
		velocity = Vector2.ZERO
	elif state == "telegraph":
		# Interrupted charges release the aim lock; successful attacks call commit.
		locked = false
		transition("approach")

func commit() -> void:
	locked = true
	velocity = Vector2.ZERO
	transition("strike")

func advance(delta: float, position: Vector2, player: Vector2, bounds: Vector2, is_anchor: bool) -> Vector2:
	state_time += delta
	velocity = Vector2.ZERO
	if is_anchor: return position
	if state == "strike":
		if state_time >= 0.32: transition("recovery")
		return position
	if state == "recovery":
		if state_time >= recovery_duration:
			locked = false
			transition("approach")
		return position
	if state == "telegraph": return position
	var distance := player.x-position.x
	facing = 1.0 if distance >= 0 else -1.0
	var absolute := absf(distance)
	# Hysteresis prevents frame-by-frame toggling at the preferred range.
	if state == "approach" and absolute <= preferred_distance: transition("position")
	elif state == "position" and absolute > preferred_distance+35.0: transition("approach")
	if state == "approach":
		velocity.x = facing*speed
	elif absolute < preferred_distance-45.0:
		velocity.x = -facing*speed*0.6
	elif kind in ["instrument", "observer"]:
		# Slow horizontal orbit within the same supported surface; no extra attack.
		velocity.x = orbit_sign*speed*0.25
		if position.x <= bounds.x+8.0 or position.x >= bounds.y-8.0: orbit_sign *= -1.0
	var next := position
	next.x = clampf(position.x+velocity.x*delta,bounds.x,bounds.y)
	velocity.x = (next.x-position.x)/delta if delta > 0 else 0.0
	return next

func motion_state() -> String:
	match state:
		"telegraph": return "windup"
		"strike": return "attack"
		"recovery": return "recovery"
	return "walk" if absf(velocity.x) > 0.1 else "idle"
