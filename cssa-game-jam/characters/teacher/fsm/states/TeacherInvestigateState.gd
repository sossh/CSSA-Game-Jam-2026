extends TeacherState

func enter() -> void:
	super()
	teacher.path = Game.world.walk_path(teacher.global_position, teacher.noise_position)
	teacher.alertness = minf(Game.config.teacher.maximum_alertness, teacher.alertness + Game.config.teacher.investigate_alertness_gain)

func physics_update(delta: float) -> void:
	super(delta)
	teacher.follow_path(delta)
	teacher.scan(delta)

	var tuning := Game.config.teacher
	if teacher.path.is_empty() or state_time > tuning.investigation_travel_seconds:
		var sweep_angle := PI + sin(state_time * tuning.investigation_sweep_rate) * tuning.investigation_sweep_angle
		teacher.turn(sweep_angle, delta, tuning.investigation_turn_speed)

		if teacher.target != "" and teacher.suspicion > tuning.investigation_catch_suspicion and teacher.can_see(teacher.target):
			teacher.catch_target(teacher.target)
		elif state_time > tuning.investigation_seconds:
			state_transition.emit(self, "LectureState")
