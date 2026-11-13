extends TeacherState

func physics_update(delta: float) -> void:
	super(delta)
	
	# Sine wave creates a sweeping left-to-right scanning animation
	var sweep_angle := PI + sin(state_time * 0.8) * 0.3
	teacher.turn(sweep_angle, delta, 1.5)
	
	if state_time > 0.5: 
		teacher.scan(delta)
		
	# fsm.current_state handles the 'state == State.CHECK' check naturally
	if state_time > 5.0:
		teacher.suspicion *= 0.5
		state_transition.emit(self, "LectureState")
