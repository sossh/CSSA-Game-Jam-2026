extends TeacherState

func enter() -> void:
	super()
	if Game.is_host():
		Game.event.rpc("banner", {"text": "Professor X-PEL takes a very loud sip. SNACK WINDOW!"})
		Game.event.rpc("sound", {"position": teacher.global_position, "key": "coffee"})
		Game.event.rpc("sound", {"position": teacher.global_position, "key": "teacher_yawn"})

func physics_update(delta: float) -> void:
	super(delta)
	teacher.turn(0, delta, 2)
	
	var coffee_duration := 5.0 + (teacher.drugs * 3.0)
	if state_time >= coffee_duration:
		teacher.next_coffee = Game.elapsed + randf_range(30, 50) / (1.0 + teacher.drugs * 0.7)
		state_transition.emit(self, "LectureState")
