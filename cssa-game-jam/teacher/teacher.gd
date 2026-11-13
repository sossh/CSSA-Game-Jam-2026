class_name ClassroomTeacher
extends CharacterBody3D

enum State {AWAY, ENTERING, LECTURE, WARNING, CHECK, INVESTIGATE, COFFEE, SHOOT, LEAVING}
const NAMES := ["Away", "Entering", "Lecturing", "CHALK STOPPED…", "Checking", "Investigating", "LOUD COFFEE SIP", "CAUGHT", "Leaving"]
var state: State = State.AWAY
var state_time: float = 0
var suspicion: float = 0
var alertness: float = 0
var next_check: float = 0
var last_check: float = -100
var next_coffee: float = 0
var drugs: int = 0
var target: String = ""
var noise_position := Vector3.ZERO
var path: PackedVector3Array = []
var shot_fired: bool = false
var scan_time: float = 0
var lecture_sound_at: float = 0
@onready var label: Label3D = $StateLabel
@onready var gun: Node3D = $Shotgun
@onready var laser: Node3D = $AimLaser
var destination := Vector3.ZERO
var desired_yaw: float = 0
var aim_point := Vector3.ZERO
var board := Vector3(0, 0, -7.0)
var lounge := Vector3(-7, 0, -8.8)

func _ready() -> void:
	global_position = lounge
	destination = lounge
	NoiseBus.noise_made.connect(hear)

func set_state(next: State) -> void:
	state = next
	state_time = 0
	scan_time = 0
	shot_fired = false
	if next == State.WARNING:
		last_check = Game.elapsed
		Game.event.rpc("banner", {"text": "The chalk stops. GET TO YOUR SEAT."})
		Game.event.rpc("sound", {"position": global_position, "key": "teacher_warning"})
	if next == State.COFFEE:
		Game.event.rpc("banner", {"text": "Professor X-PEL takes a very loud sip. SNACK WINDOW!"})
		Game.event.rpc("sound", {"position": global_position, "key": "coffee"})
		Game.event.rpc("sound", {"position": global_position, "key": "teacher_yawn"})
	if next == State.LECTURE:
		next_check = Game.elapsed + randf_range(Game.config.check_min_seconds, Game.config.check_max_seconds) / (1 + alertness * 0.5 + (Game.grade - 1) * 0.08)
	if next == State.INVESTIGATE:
		path = Game.world.walk_path(global_position, noise_position)
		alertness = minf(2, alertness + 0.5)

func start_class() -> void:
	suspicion = 0
	alertness = 0
	target = ""
	global_position = lounge
	next_coffee = Game.elapsed + randf_range(20, 35) / (1 + drugs * 0.5)
	set_state(State.ENTERING)

func leave() -> void:
	set_state(State.LEAVING)

func _physics_process(delta: float) -> void:
	if Game.is_host():
		state_time += delta
		suspicion = maxf(0, suspicion - delta * 4)
		alertness = maxf(0, alertness - delta * 0.008)
		match state:
			State.ENTERING:
				global_position = global_position.move_toward(board, delta * 3)
				if global_position.distance_to(board) < 0.1: set_state(State.WARNING)
			State.LECTURE:
				if Game.elapsed >= lecture_sound_at:
					lecture_sound_at = Game.elapsed + 8
					Game.event.rpc("sound", {"position": global_position, "key": "lecture"})
				walk_to_board(delta)
				turn(0, delta, 4)
				if Game.elapsed >= next_coffee: set_state(State.COFFEE)
				elif Game.elapsed >= next_check and Game.elapsed - last_check >= Game.config.check_cooldown: set_state(State.WARNING)
			State.WARNING:
				if state_time >= Game.config.turn_warning_seconds: set_state(State.CHECK)
			State.CHECK:
				turn(PI + sin(state_time * 0.8) * 0.3, delta, 1.5)
				if state_time > 0.5: scan(delta)
				if state == State.CHECK and state_time > 5:
					suspicion *= 0.5
					set_state(State.LECTURE)
			State.INVESTIGATE:
				follow_path(delta)
				scan(delta)
				if state == State.INVESTIGATE and (path.is_empty() or state_time > 10):
					turn(PI + sin(state_time * 2) * 1.2, delta, 2)
					if target != "" and suspicion > 35 and can_see(target): catch_target(target)
					elif state_time > 12: set_state(State.LECTURE)
			State.COFFEE:
				turn(0, delta, 2)
				if state_time >= 5 + drugs * 3:
					next_coffee = Game.elapsed + randf_range(30, 50) / (1 + drugs * 0.7)
					set_state(State.LECTURE)
			State.SHOOT:
				var point = Game.world.target_position(target)
				if point != null:
					aim_point = point + Vector3.UP
					face_point(point, delta, 8)
				if state_time > 1.1 and not shot_fired:
					shot_fired = true
					if point != null and clear_sight(point + Vector3.UP): fire()
				if state_time > 2.2: set_state(State.LECTURE)
			State.LEAVING:
				global_position = global_position.move_toward(lounge, delta * 4)
				if global_position.distance_to(lounge) < 0.1: set_state(State.AWAY)
	else:
		global_position = global_position.lerp(destination, minf(1, delta * 15))
		rotation.y = lerp_angle(rotation.y, desired_yaw, minf(1, delta * 15))
	visible = state != State.AWAY
	label.text = NAMES[state] + ("  !" if suspicion > 30 else "")
	label.modulate = Color(1, 0.3, 0.2) if state in [State.WARNING, State.CHECK, State.INVESTIGATE, State.SHOOT] else Color.WHITE
	laser.visible = state == State.SHOOT
	if laser.visible:
		var origin := global_position + Vector3(0, 1.5, 0)
		laser.global_position = (origin + aim_point) * 0.5
		if origin.distance_to(aim_point) > 0.1:
			laser.look_at(aim_point)
			laser.scale.z = origin.distance_to(aim_point)

func hear(at: Vector3, loudness: float, source: String, _kind: String) -> void:
	if Game.phase != "class" or state in [State.AWAY, State.ENTERING, State.LEAVING, State.SHOOT]: return
	var multiplier := 0.28 if state == State.COFFEE else (1.5 if state in [State.CHECK, State.INVESTIGATE] else 1.0)
	var perceived := loudness * multiplier / (1.0 + global_position.distance_to(at) * 0.09)
	suspicion = minf(150, suspicion + perceived)
	noise_position = at
	# Remember who was actually seen throwing; otherwise location + behaviour +
	# a small random term can frame an innocent nearby student.
	target = choose_blame(at, source)
	if perceived >= Game.config.hearing_threshold or suspicion >= 100:
		if target != "" and clear_sight(Game.world.target_position(target) + Vector3.UP):
			catch_target(target) # Lecturing is NOT a safe state above this threshold.
		else: set_state(State.INVESTIGATE)
	elif suspicion >= 55 and state != State.INVESTIGATE:
		set_state(State.INVESTIGATE)
	elif suspicion >= 25 and state in [State.LECTURE, State.COFFEE] and Game.elapsed - last_check >= Game.config.check_cooldown:
		set_state(State.WARNING)

func choose_blame(at: Vector3, source: String) -> String:
	if source != "" and Game.world.target_position(source) != null and can_see(source) and Game.world.is_violating(source): return source
	var best := -INF
	var choice := ""
	for candidate: String in Game.world.targets():
		var point: Vector3 = Game.world.target_position(candidate)
		var distance := at.distance_to(point)
		if distance > 5.5: continue
		var score := 12 - distance * 2 + randf_range(0, 3)
		if Game.world.is_violating(candidate): score += 4
		if score > best:
			best = score
			choice = candidate
	return choice

func provoked(source: String, at: Vector3) -> void:
	if Game.phase == "class": hear(at, 200, source, "impact")

func scan(delta: float) -> void:
	var visible_culprit := ""
	for candidate: String in Game.world.targets():
		if Game.world.is_violating(candidate) and can_see(candidate):
			visible_culprit = candidate
			break
	if visible_culprit == "": scan_time = 0
	else:
		scan_time += delta
		if scan_time > 0.35: catch_target(visible_culprit)

func catch_target(id: String) -> void:
	target = id
	set_state(State.SHOOT)
	Game.event.rpc("sound", {"position": global_position, "key": "shotgun_pump"})

func fire() -> void:
	var origin := global_position + Vector3(0, 1.55, 0)
	var direction := (aim_point - origin).normalized()
	Game.event.rpc("shot", {"position": origin, "end": aim_point})
	Game.event.rpc("sound", {"position": origin, "key": "shotgun", "loudness": 100.0})
	# Host raycast prevents shots through walls; the first actual body takes damage.
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + direction * 40, 1 | 2 | 8, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		Game.world.hit_body(hit.collider, Game.config.shotgun_damage, direction * 11 + Vector3.UP * 5, "was expelled by shotgun")

func can_see(id: String) -> bool:
	var point = Game.world.target_position(id)
	if point == null: return false
	var offset: Vector3 = point + Vector3.UP - (global_position + Vector3.UP)
	return offset.length() < 25 and (-global_basis.z).dot(offset.normalized()) > 0.48 and clear_sight(point + Vector3.UP)

func clear_sight(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.9, 0), point, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func turn(yaw: float, delta: float, speed: float) -> void:
	rotation.y = rotate_toward(rotation.y, yaw, speed * delta)

func face_point(point: Vector3, delta: float, speed: float) -> void:
	var direction := point - global_position
	if direction.length() > 0.05: turn(atan2(-direction.x, -direction.z), delta, speed)

func follow_path(delta: float) -> void:
	if path.is_empty(): return
	var point := path[0]
	if global_position.distance_to(point) < 0.3:
		path.remove_at(0)
		return
	face_point(point, delta, 4)
	velocity = (point - global_position).normalized() * 2.5
	velocity.y = -1
	move_and_slide()

func walk_to_board(delta: float) -> void:
	if global_position.distance_to(board) > 0.3:
		if path.is_empty(): path = Game.world.walk_path(global_position, board)
		follow_path(delta)

func serialize() -> Dictionary:
	return {"position": global_position, "yaw": rotation.y, "state": state, "suspicion": suspicion, "aim": aim_point, "drugs": drugs}

func receive(data: Dictionary) -> void:
	destination = data.position
	desired_yaw = data.yaw
	state = data.state
	suspicion = data.suspicion
	aim_point = data.aim
	drugs = data.drugs
