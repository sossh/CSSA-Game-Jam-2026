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
	
	var at_desk := teacher.global_position.distance_to(teacher.desk) <= 0.85
	if not drank and not at_desk:
		if state_time > 3.5 or (teacher.path.is_empty() and state_time > 1.0):
			at_desk = true
		else:
			teacher.walk_to_desk(delta)
			return

	teacher.turn(0, delta, 3.0)

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
		var coffee_duration := 5.0 + (teacher.drugs * 3.0)
		if drink_time >= coffee_duration:
			teacher.next_coffee = Game.elapsed + randf_range(30, 50) / (1.0 + teacher.drugs * 0.7)
			teacher.path.clear()
			state_transition.emit(self, "LectureState")
