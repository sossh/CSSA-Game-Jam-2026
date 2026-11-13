extends TeacherState

func enter() -> void:
	super()
	teacher.path = Game.world.walk_path(teacher.global_position, teacher.noise_position)
	teacher.alertness = minf(2.0, teacher.alertness + 0.5)

func physics_update(delta: float) -> void:
	super(delta)
	teacher.follow_path(delta)
	teacher.scan(delta)
	
	if teacher.path.is_empty() or state_time > 10.0:
		var sweep_angle := PI + sin(state_time * 2.0) * 1.2
		teacher.turn(sweep_angle, delta, 2.0)
		
		if teacher.target != "" and teacher.suspicion > 35 and teacher.can_see(teacher.target): 
			teacher.catch_target(teacher.target)
		elif state_time > 12.0: 
			state_transition.emit(self, "LectureState")
