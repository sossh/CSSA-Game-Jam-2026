class_name ClassroomTeacher
extends CharacterBody3D

# --- Attributes ---
var suspicion: float = 0.0
var alertness: float = 0.0
var drugs: int = 0

# --- Timers & Cooldowns ---
var next_check: float = 0.0
var last_check: float = -100.0
var next_coffee: float = 0.0
var scan_time: float = 0.0
var lecture_sound_at: float = 0.0

# --- Targeting & Navigation ---
var target: String = ""
var noise_position := Vector3.ZERO
var path: PackedVector3Array = []
var destination := Vector3.ZERO
var desired_yaw: float = 0.0
var aim_point := Vector3.ZERO
var board := Vector3(0, 0, -7.0)
var lounge := Vector3(-7, 0, -8.8)

# --- Combat ---
var shot_fired: bool = false

# --- Node References ---
@onready var label: Label3D = $StateLabel
@onready var gun: Node3D = $Shotgun
@onready var laser: Node3D = $AimLaser
@onready var fsm: TeacherFiniteStateMachine = %FSM

func _ready() -> void:
	global_position = lounge
	destination = lounge
	NoiseBus.noise_made.connect(hear)

func start_class() -> void:
	suspicion = 0.0
	alertness = 0.0
	target = ""
	global_position = lounge
	next_coffee = Game.elapsed + randf_range(20, 35) / (1.0 + drugs * 0.5)
	fsm.force_change_state("EnteringState")

func leave() -> void:
	fsm.force_change_state("LeavingState")

func _physics_process(delta: float) -> void:
	if Game.is_host():
		# Global stat decay
		suspicion = maxf(0.0, suspicion - delta * 4)
		alertness = maxf(0.0, alertness - delta * 0.008)
	else:
		_process_client_interpolation(delta)
		
	_update_visuals()

func _process_client_interpolation(delta: float) -> void:
	var lerp_speed := minf(1.0, delta * 15.0)
	global_position = global_position.lerp(destination, lerp_speed)
	rotation.y = lerp_angle(rotation.y, desired_yaw, lerp_speed)

func _update_visuals() -> void:
	var current = fsm.current_state
	if not current or current.name.to_lower() == "awaystate":
		visible = false
		return
		
	visible = true
	label.text = current.display_name + ("  !" if suspicion > 30 else "")
	label.modulate = Color(1, 0.3, 0.2) if current.is_alert_state else Color.WHITE
	
	laser.visible = (current.name.to_lower() == "shootstate")
	if laser.visible:
		var origin := global_position + Vector3(0, 1.5, 0)
		laser.global_position = (origin + aim_point) * 0.5
		
		if origin.distance_to(aim_point) > 0.1:
			laser.look_at(aim_point)
			laser.scale.z = origin.distance_to(aim_point)

# --- Senses & Interaction ---

func get_current_state_name() -> String:
	if fsm and fsm.current_state:
		return fsm.current_state.name.to_lower()
	return ""

func hear(at: Vector3, loudness: float, source: String, _kind: String) -> void:
	var current = get_current_state_name()
	var ignore_states = ["awaystate", "enteringstate", "leavingstate", "shootstate"]
	
	if Game.phase != "class" or current in ignore_states: 
		return
		
	var multiplier := 1.0
	if current == "coffeestate":
		multiplier = 0.28
	elif current in ["checkstate", "investigatestate"]:
		multiplier = 1.5
		
	var distance := global_position.distance_to(at)
	var perceived := loudness * multiplier / (1.0 + distance * 0.09)
	
	suspicion = minf(150.0, suspicion + perceived)
	noise_position = at
	
	# Remember who was actually seen throwing; otherwise frame nearby student
	target = choose_blame(at, source)
	
	var check_cooldown_met := (Game.elapsed - last_check >= Game.config.check_cooldown)
	
	if perceived >= Game.config.hearing_threshold or suspicion >= 100.0:
		if target != "" and clear_sight(Game.world.target_position(target) + Vector3.UP):
			catch_target(target)
		else: 
			fsm.force_change_state("InvestigateState")
	elif suspicion >= 55.0 and current != "investigatestate":
		fsm.force_change_state("InvestigateState")
	elif suspicion >= 25.0 and current in ["lecturestate", "coffeestate"] and check_cooldown_met:
		fsm.force_change_state("WarningState")

func choose_blame(at: Vector3, source: String) -> String:
	if source != "":
		var source_pos = Game.world.target_position(source)
		if source_pos != null and can_see(source) and Game.world.is_violating(source): 
			return source
			
	var best_score := -INF
	var choice := ""
	
	for candidate: String in Game.world.targets():
		var point: Vector3 = Game.world.target_position(candidate)
		var distance := at.distance_to(point)
		
		if distance > 5.5: 
			continue
			
		var score := 12.0 - (distance * 2.0) + randf_range(0, 3)
		if Game.world.is_violating(candidate): 
			score += 4.0
			
		if score > best_score:
			best_score = score
			choice = candidate
			
	return choice

func provoked(source: String, at: Vector3) -> void:
	if Game.phase == "class": 
		hear(at, 200.0, source, "impact")

func scan(delta: float) -> void:
	var visible_culprit := ""
	for candidate: String in Game.world.targets():
		if Game.world.is_violating(candidate) and can_see(candidate):
			visible_culprit = candidate
			break
			
	if visible_culprit == "": 
		scan_time = 0.0
	else:
		scan_time += delta
		if scan_time > 0.35: 
			catch_target(visible_culprit)

func catch_target(id: String) -> void:
	target = id
	fsm.force_change_state("ShootState")
	Game.event.rpc("sound", {"position": global_position, "key": "shotgun_pump"})

func fire() -> void:
	var origin := global_position + Vector3(0, 1.55, 0)
	var direction := (aim_point - origin).normalized()
	
	Game.event.rpc("shot", {"position": origin, "end": aim_point})
	Game.event.rpc("sound", {"position": origin, "key": "shotgun", "loudness": 100.0})
	
	# Host raycast prevents shots through walls
	var collision_mask := 1 | 2 | 8
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + direction * 40, collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	
	if not hit.is_empty():
		var knockback := direction * 11.0 + Vector3.UP * 5.0
		Game.world.hit_body(hit.collider, Game.config.shotgun_damage, knockback, "was expelled by shotgun")

func can_see(id: String) -> bool:
	var point = Game.world.target_position(id)
	if point == null:
		return false
		
	var head_pos: Vector3 = global_position + Vector3.UP
	var target_head: Vector3 = point + Vector3.UP
	var offset: Vector3 = target_head - head_pos
	
	var is_in_range: bool = offset.length() < 25.0
	var is_in_fov: bool = (-global_basis.z).dot(offset.normalized()) > 0.48
	
	return is_in_range and is_in_fov and clear_sight(target_head)

func clear_sight(point: Vector3) -> bool:
	var head_pos := global_position + Vector3(0, 1.9, 0)
	var query := PhysicsRayQueryParameters3D.create(head_pos, point, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func turn(yaw: float, delta: float, speed: float) -> void:
	rotation.y = rotate_toward(rotation.y, yaw, speed * delta)

func face_point(point: Vector3, delta: float, speed: float) -> void:
	var direction := point - global_position
	if direction.length() > 0.05: 
		turn(atan2(-direction.x, -direction.z), delta, speed)

func follow_path(delta: float) -> void:
	if path.is_empty(): 
		return
		
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
		if path.is_empty(): 
			path = Game.world.walk_path(global_position, board)
		follow_path(delta)

func serialize() -> Dictionary:
	return {
		"position": global_position, 
		"yaw": rotation.y, 
		"state_name": get_current_state_name(), 
		"suspicion": suspicion, 
		"aim": aim_point, 
		"drugs": drugs
	}

func receive(data: Dictionary) -> void:
	destination = data.position
	desired_yaw = data.yaw
	suspicion = data.suspicion
	aim_point = data.aim
	drugs = data.drugs
	
	# Force the client FSM to mirror the host's state so visuals render!
	if fsm:
		fsm.force_change_state(data.state_name)
