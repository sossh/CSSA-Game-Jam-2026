extends TeacherState

func physics_update(delta: float) -> void:
	super(delta)
	teacher.global_position = teacher.global_position.move_toward(teacher.lounge, delta * 4)
	
	if teacher.global_position.distance_to(teacher.lounge) < 0.1: 
		state_transition.emit(self, "AwayState")
