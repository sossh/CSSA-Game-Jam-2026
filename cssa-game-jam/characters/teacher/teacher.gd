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
var sound_grace_until: float = 0.0
var student_shot_grace: Dictionary = {}

# --- Targeting & Navigation ---
var target: String = ""
var noise_position := Vector3.ZERO
var path: PackedVector3Array = []
var destination := Vector3.ZERO
var desired_yaw: float = 0.0
var aim_point := Vector3.ZERO
var board := Vector3(0, 0, -7.0)
var lounge := Vector3(-7, 0, -8.8)
var desk := Vector3(3, 0, -7.5)

# --- Combat ---
var shot_fired: bool = false
var actual_shot_fired: bool = false
var shoot_aim_held: bool = false

# --- Animation Tracking ---
var current_anim: String = "idle"

# --- Node References ---
@onready var label: Label3D = $StateLabel
@onready var gun: Node3D = $Shotgun
@onready var laser: Node3D = $AimLaser
@onready var fsm: TeacherFiniteStateMachine = %FSM
@onready var visual: TeacherVisual = %Visual
@onready var anim: AnimationPlayer = $Visual.animation_player
@onready var chalk_audio: AudioStreamPlayer3D = %ChalkAudio
var step_timer: float = 0.0

func _ready() -> void:
	chalk_audio.stream = Sfx.config.lecture_chalk
	chalk_audio.volume_db = Sfx.config.lecture_chalk_db
	chalk_audio.unit_size = Sfx.config.lecture_chalk_unit_size
	chalk_audio.max_distance = Sfx.config.lecture_chalk_max_distance
	global_position = lounge
	destination = lounge
	NoiseBus.noise_made.connect(hear)

func _exit_tree() -> void:
	if chalk_audio and chalk_audio.playing:
		chalk_audio.stop()

func start_class() -> void:
	suspicion = 0.0
	alertness = 0.0
	target = ""
	student_shot_grace.clear()
	global_position = board
	destination = board
	rotation.y = 0.0
	var tuning := Game.config.teacher
	var delay := randf_range(tuning.first_coffee_delay.x, tuning.first_coffee_delay.y)
	next_coffee = Game.elapsed + delay / (1.0 + drugs * tuning.first_coffee_tablet_scale)
	last_check = Game.elapsed
	sound_grace_until = Game.elapsed + tuning.round_start_sound_grace_seconds
	fsm.force_change_state("LectureState")

func leave() -> void:
	student_shot_grace.clear()
	sound_grace_until = 0.0
	fsm.force_change_state("LeavingState")

func _physics_process(delta: float) -> void:
	if Game.is_host():
		# Global stat decay
		suspicion = maxf(0.0, suspicion - delta * Game.config.teacher.suspicion_decay_per_second)
		alertness = maxf(0.0, alertness - delta * Game.config.teacher.alertness_decay_per_second)
		
		# Host explicitly sets the animation based on its AI intent
		var state_name = get_current_state_name()
		match state_name:
			"investigatestate":
				current_anim = "run-mad" if not path.is_empty() else "idle"
			"lecturestate":
				current_anim = "walk" if global_position.distance_to(board) > 0.3 else "pointing-teaching"
			"coffeestate":
				var coffee = fsm.current_state
				if (coffee and "drank" in coffee and coffee.drank) or global_position.distance_to(desk) <= 0.85:
					current_anim = "drink-animation"
				else:
					current_anim = "walk"
			"enteringstate", "leavingstate":
				current_anim = "walk"
			"shootstate":
				current_anim = "shoot-animation"
			_:
				current_anim = "idle"
	else:
		_process_client_interpolation(delta)
		
	_update_visuals()

func _process_client_interpolation(delta: float) -> void:
	var lerp_speed := minf(1.0, delta * 15.0)
	global_position = global_position.lerp(destination, lerp_speed)
	rotation.y = lerp_angle(rotation.y, desired_yaw, lerp_speed)
	if global_position.distance_to(destination) > 0.1 and current_anim == "idle":
		current_anim = "walk"

func _update_visuals() -> void:
	var current = fsm.current_state
	if not current or current.name.to_lower() == "awaystate":
		visible = false
		return
		
	visible = true
	label.text = current.display_name + ("  !" if suspicion > 30 else "")
	label.modulate = Color(1, 0.3, 0.2) if current.is_alert_state else Color.WHITE
	
	var state_name := get_current_state_name()
	if visual:
		visual.set_gun_visible(state_name in ["investigatestate", "shootstate"])
		visual.set_coffee_mug_visible(state_name == "coffeestate")

	laser.visible = (current.name.to_lower() == "shootstate")
	if laser.visible:
		var origin := global_position + Vector3(0, 1.5, 0)
		laser.global_position = (origin + aim_point) * 0.5
		
		if origin.distance_to(aim_point) > 0.1:
			laser.look_at(aim_point)
			laser.scale.z = origin.distance_to(aim_point)

	# Play exactly what the string says
	if current_anim == "shoot-animation":
		if not actual_shot_fired:
			if not shoot_aim_held:
				if anim.assigned_animation != "shoot-animation" or (not anim.is_playing() and anim.current_animation_position == 0.0):
					anim.play("shoot-animation")
				if anim.current_animation_position >= 1.48:
					anim.seek(1.48, true)
					anim.pause()
					shoot_aim_held = true
		else:
			var recoil_speed: float = Game.config.teacher.shotgun_recoil_anim_speed if Game.config and Game.config.teacher else 0.5
			if shoot_aim_held:
				shoot_aim_held = false
				anim.play("shoot-animation", -1, recoil_speed)
			elif anim.assigned_animation != "shoot-animation":
				anim.play("shoot-animation", -1, recoil_speed)
	else:
		shoot_aim_held = false
		play_anim(current_anim)

func play_anim(anim_name: String) -> void:
	if anim and anim.current_animation != anim_name:
		if anim_name == "drink-animation":
			anim.play("drink-animation", -1, get_drink_anim_speed())
		else:
			anim.play(anim_name, -1, 1.0)

func get_coffee_duration() -> float:
	var tuning := Game.config.teacher if Game.config else null
	if tuning:
		return tuning.coffee_seconds + drugs * tuning.coffee_extra_seconds_per_tablet
	return 5.0

func get_drink_anim_speed() -> float:
	var duration: float = get_coffee_duration()
	var anim_len: float = 8.866667
	if anim and anim.has_animation("drink-animation"):
		var anim_res: Animation = anim.get_animation("drink-animation")
		if anim_res:
			anim_len = anim_res.length
	return anim_len / maxf(0.01, duration)

# --- Senses & Interaction ---

func get_current_state_name() -> String:
	if fsm and fsm.current_state:
		return fsm.current_state.name.to_lower()
	return ""

func is_actively_attacking() -> bool:
	return get_current_state_name() == "shootstate"

func interrupt_shot() -> void:
	if not is_actively_attacking():
		return
	shot_fired = true
	actual_shot_fired = false
	shoot_aim_held = false
	current_anim = "idle"
	if anim and anim.assigned_animation == "shoot-animation":
		anim.play("idle", -1, 1.0)
	fsm.force_change_state("InvestigateState")

func hear(at: Vector3, loudness: float, source: String, kind: String) -> void:
	if kind == "throw":
		return
	var current = get_current_state_name()
	if current == "shootstate":
		if kind in ["gunshot", "firework"]:
			interrupt_shot()
		return
	var ignore_states = ["awaystate", "enteringstate", "leavingstate"]
	
	if Game.phase != "class" or current in ignore_states: 
		return

	if is_actively_attacking():
		return

	var tuning := Game.config.teacher
	if Game.elapsed < sound_grace_until:
		if not (kind in ["gunshot", "firework"] or loudness >= tuning.lecture_extreme_loudness):
			return

	var multiplier := 1.0
	if current == "coffeestate":
		multiplier = tuning.coffee_hearing_scale
	elif current == "lecturestate":
		multiplier = tuning.lecture_hearing_scale
	elif current in ["checkstate", "investigatestate"]:
		multiplier = tuning.alert_hearing_scale
		
	var distance := global_position.distance_to(at)
	var perceived := loudness * multiplier / (1.0 + distance * tuning.distance_hearing_falloff)
	
	suspicion = minf(tuning.maximum_suspicion, suspicion + perceived)
	noise_position = at
	
	# Remember who was actually seen throwing; otherwise frame nearby student
	target = choose_blame(at, source)
	
	var check_cooldown_met := (Game.elapsed - last_check >= tuning.check_cooldown)
	
	# If in lecture with back turned, don't blind snap-shoot behind back unless catastrophic explosion
	if current == "lecturestate":
		if (kind in ["gunshot", "firework"] or loudness >= tuning.lecture_extreme_loudness) and perceived >= tuning.hearing_threshold * tuning.lecture_hearing_scale:
			fsm.force_change_state("InvestigateState")
		elif suspicion >= tuning.warning_suspicion and check_cooldown_met:
			fsm.force_change_state("WarningState")
		elif suspicion >= tuning.lecture_investigate_suspicion or perceived >= tuning.lecture_investigate_loudness:
			fsm.force_change_state("InvestigateState")
	elif perceived >= tuning.hearing_threshold or suspicion >= tuning.catch_suspicion:
		if target != "" and can_see(target):
			catch_target(target)
		else: 
			fsm.force_change_state("InvestigateState")
	elif suspicion >= tuning.alert_investigate_suspicion and current != "investigatestate":
		fsm.force_change_state("InvestigateState")
	elif suspicion >= tuning.warning_suspicion and current in ["lecturestate", "coffeestate"] and check_cooldown_met:
		fsm.force_change_state("WarningState")

func choose_blame(at: Vector3, source: String) -> String:
	if source != "":
		if student_shot_grace.get(source, 0.0) <= Game.elapsed:
			var source_pos = Game.world.target_position(source)
			if source_pos != null and can_see(source) and Game.world.is_violating(source):
				return source

	var tuning := Game.config.teacher
	var best_score := -INF
	var choice := ""
	
	for candidate: String in Game.world.targets():
		if student_shot_grace.get(candidate, 0.0) > Game.elapsed:
			continue
		var point: Vector3 = Game.world.target_position(candidate)
		var distance := at.distance_to(point)
		
		if distance > tuning.blame_radius:
			continue
			
		var score := 12.0 - (distance * tuning.blame_distance_penalty) + randf_range(0, tuning.blame_random_bonus)
		if Game.world.is_violating(candidate): 
			score += tuning.blame_violation_bonus
			
		if score > best_score:
			best_score = score
			choice = candidate
			
	return choice

func provoked(source: String, at: Vector3) -> void:
	if get_current_state_name() == "shootstate":
		interrupt_shot()
		return
	if Game.phase == "class": 
		hear(at, Game.config.teacher.provoked_loudness, source, "impact")

func scan(delta: float) -> void:
	var visible_culprit := ""
	for candidate: String in Game.world.targets():
		if student_shot_grace.get(candidate, 0.0) > Game.elapsed:
			continue
		if Game.world.is_violating(candidate) and can_see(candidate):
			visible_culprit = candidate
			break
			
	if visible_culprit == "": 
		scan_time = 0.0
	else:
		scan_time += delta
		if scan_time > Game.config.teacher.visible_violation_seconds:
			catch_target(visible_culprit)

func catch_target(id: String) -> void:
	if student_shot_grace.get(id, 0.0) > Game.elapsed:
		return
	target = id
	shot_fired = false
	actual_shot_fired = false
	shoot_aim_held = false
	current_anim = "shoot-animation"
	fsm.force_change_state("ShootState")
	if Game.is_host():
		Game.event.rpc("sound", {"position": global_position, "key": "shotgun_pump", "loudness": Game.config.teacher.shotgun_pump_volume})

func fire() -> void:
	actual_shot_fired = true
	if not Game.is_host():
		return
	var origin := global_position + Vector3(0, 1.55, 0)
	var direction := (aim_point - origin).normalized()
	var tuning := Game.config.teacher
	
	Game.event.rpc("shot", {"position": origin, "end": aim_point})
	Game.event.rpc("sound", {"position": origin, "key": "shotgun", "loudness": tuning.shotgun_volume})
	
	# Host raycast prevents shots through walls
	var ray_mask := 1 | 2 | 8
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + direction * tuning.shotgun_range, ray_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	
	if not hit.is_empty():
		var knockback := direction * tuning.shotgun_horizontal_impulse + Vector3.UP * tuning.shotgun_upward_impulse
		if hit.collider is StudentPlayer:
			student_shot_grace[str(hit.collider.peer_id)] = Game.elapsed + tuning.shot_grace_seconds
		elif target != "":
			student_shot_grace[target] = Game.elapsed + tuning.shot_grace_seconds
		Game.world.hit_body(hit.collider, tuning.shotgun_damage, knockback, "was expelled by shotgun")

func can_see(id: String) -> bool:
	var point = Game.world.target_position(id)
	if point == null:
		return false
		
	var head_pos: Vector3 = global_position + Vector3.UP
	var target_head: Vector3 = point + Vector3.UP
	var offset: Vector3 = target_head - head_pos
	
	var is_in_range: bool = offset.length() < Game.config.teacher.sight_range
	var is_in_fov: bool = (-global_basis.z).dot(offset.normalized()) > Game.config.teacher.sight_forward_dot
	
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
		
	face_point(point, delta, Game.config.teacher.walk_turn_speed)
	velocity = (point - global_position).normalized() * Game.config.teacher.walk_speed
	velocity.y = -1
	move_and_slide()
	step_timer -= delta
	if step_timer <= 0.0:
		step_timer = Game.config.teacher.walk_step_seconds
		if Game.is_host():
			Game.event.rpc("sound", {"position": global_position, "key": "teacher_step", "loudness": Game.config.teacher.footstep_volume})

func walk_to_board(delta: float) -> void:
	if global_position.distance_to(board) > 0.3:
		if path.is_empty(): 
			path = Game.world.walk_path(global_position, board)
		follow_path(delta)

func walk_to_desk(delta: float) -> void:
	if global_position.distance_to(desk) > 0.85:
		if path.is_empty():
			path = Game.world.walk_path(global_position, desk)
		follow_path(delta)

func serialize() -> Dictionary:
	return {
		"position": global_position, 
		"yaw": rotation.y, 
		"state_name": get_current_state_name(), 
		"suspicion": suspicion, 
		"aim": aim_point, 
		"drugs": drugs,
		"anim": current_anim,
		"shot_fired": actual_shot_fired
	}

func receive(data: Dictionary) -> void:
	destination = data.position
	desired_yaw = data.yaw
	suspicion = data.suspicion
	aim_point = data.aim
	drugs = data.drugs
	if data.has("anim"):
		current_anim = data.anim
	if data.has("shot_fired"):
		actual_shot_fired = data.shot_fired
	
	# Force the client FSM to mirror the host's state so visuals render!
	if not Game.is_host() and fsm and data.has("state_name") and data.state_name != "":
		fsm.force_change_state(data.state_name)
