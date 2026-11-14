extends TeacherState

var drank: bool = false
var drink_time: float = 0.0

func enter() -> void:
	super()
	drank = false
	drink_time = 0.0
	teacher.path.clear()
	if teacher.chalk_audio and teacher.chalk_audio.playing:
		teacher.chalk_audio.stop()
	var at_desk := teacher.global_position.distance_to(teacher.desk) <= 0.85
	teacher.current_anim = "drink-animation" if at_desk else "walk"

func exit() -> void:
	super()
	drank = false
	drink_time = 0.0

func close() -> void:
	super()
	drank = false
	drink_time = 0.0

func physics_update(delta: float) -> void:
	super(delta)
	var tuning := Game.config.teacher
	var coffee_pos: Vector3 = Game.world.coffee_position if is_instance_valid(Game.world) else teacher.desk
	
	var at_desk := teacher.global_position.distance_to(teacher.desk) <= 0.85 or teacher.global_position.distance_to(coffee_pos) <= 1.0
	if not drank and not at_desk:
		if state_time > tuning.coffee_travel_timeout:
			teacher.path.clear()
			state_transition.emit(self, "LectureState")
			return
		teacher.current_anim = "walk"
		teacher.walk_to_desk(delta)
		return

	teacher.face_point(coffee_pos, delta, tuning.coffee_turn_speed)

	if not drank:
		drank = true
		drink_time = 0.0
		teacher.path.clear()
		teacher.current_anim = "drink-animation"
		if Game.is_host():
			Game.event.rpc("banner", {"text": "Professor X-PEL takes a very loud sip. SNACK WINDOW!"})
			Game.event.rpc("sound", {"position": teacher.global_position, "key": "coffee"})
			Game.event.rpc("sound", {"position": teacher.global_position, "key": "teacher_yawn"})
	else:
		drink_time += delta
		var coffee_duration := teacher.get_coffee_duration()
		if drink_time >= coffee_duration:
			var delay := randf_range(tuning.coffee_delay.x, tuning.coffee_delay.y)
			teacher.next_coffee = Game.elapsed + delay / (1.0 + teacher.drugs * tuning.coffee_tablet_scale)
			teacher.path.clear()
			state_transition.emit(self, "LectureState")
