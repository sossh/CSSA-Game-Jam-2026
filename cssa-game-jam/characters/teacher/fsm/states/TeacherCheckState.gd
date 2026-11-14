extends TeacherState

func physics_update(delta: float) -> void:
	super(delta)
	var tuning := Game.config.teacher

	# Sine wave creates a sweeping left-to-right scanning animation
	var sweep_angle := PI + sin(state_time * tuning.check_sweep_rate) * tuning.check_sweep_angle
	teacher.turn(sweep_angle, delta, tuning.check_turn_speed)

	if state_time > tuning.check_scan_delay:
		teacher.scan(delta)

	if state_time > tuning.check_seconds:
		teacher.suspicion *= tuning.suspicion_after_check_scale
		state_transition.emit(self, "LectureState")
