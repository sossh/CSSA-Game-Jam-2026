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

func physics_update(delta: float) -> void:
	super(delta)
	var tuning := Game.config.teacher
	
	var at_desk := teacher.global_position.distance_to(teacher.desk) <= 0.85
	if not drank and not at_desk:
		if state_time > tuning.coffee_travel_timeout or (teacher.path.is_empty() and state_time > tuning.coffee_blocked_timeout):
			at_desk = true
		else:
			teacher.walk_to_desk(delta)
			return

	teacher.turn(0, delta, tuning.coffee_turn_speed)

	if not drank:
		drank = true
		drink_time = 0.0
		teacher.path.clear()
		if Game.is_host():
			Game.event.rpc("banner", {"text": "Professor X-PEL takes a very loud sip. SNACK WINDOW!"})
			Game.event.rpc("sound", {"position": teacher.global_position, "key": "coffee"})
			Game.event.rpc("sound", {"position": teacher.global_position, "key": "teacher_yawn"})
	else:
		drink_time += delta
		var coffee_duration := tuning.coffee_seconds + teacher.drugs * tuning.coffee_extra_seconds_per_tablet
		if drink_time >= coffee_duration:
			var delay := randf_range(tuning.coffee_delay.x, tuning.coffee_delay.y)
			teacher.next_coffee = Game.elapsed + delay / (1.0 + teacher.drugs * tuning.coffee_tablet_scale)
			teacher.path.clear()
			state_transition.emit(self, "LectureState")
