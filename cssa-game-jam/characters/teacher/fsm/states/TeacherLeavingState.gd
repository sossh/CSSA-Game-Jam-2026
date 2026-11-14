extends TeacherState

func physics_update(delta: float) -> void:
	super(delta)
	teacher.global_position = teacher.global_position.move_toward(teacher.lounge, delta * Game.config.teacher.exit_speed)
	teacher.step_timer -= delta
	if teacher.step_timer <= 0.0:
		teacher.step_timer = Game.config.teacher.exit_step_seconds
		if Game.is_host():
			Game.event.rpc("sound", {"position": teacher.global_position, "key": "teacher_step", "loudness": Game.config.teacher.footstep_volume})
	
	if teacher.global_position.distance_to(teacher.lounge) < 0.1:
		if Game.is_host():
			Game.event.rpc("sound", {"position": teacher.global_position, "key": "door", "loudness": Game.config.teacher.door_volume})
		state_transition.emit(self, "AwayState")
