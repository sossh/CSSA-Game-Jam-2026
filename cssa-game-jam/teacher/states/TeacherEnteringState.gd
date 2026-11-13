extends TeacherState

func enter() -> void:
	super()
	if Game.is_host():
		Game.event.rpc("sound", {"position": teacher.global_position, "key": "door", "loudness": 60.0})

func physics_update(delta: float) -> void:
	super(delta)
	teacher.global_position = teacher.global_position.move_toward(teacher.board, delta * 3)
	teacher.step_timer -= delta
	if teacher.step_timer <= 0.0:
		teacher.step_timer = 0.5
		if Game.is_host():
			Game.event.rpc("sound", {"position": teacher.global_position, "key": "teacher_step", "loudness": 55.0})
	
	if teacher.global_position.distance_to(teacher.board) < 0.1: 
		state_transition.emit(self, "WarningState")
