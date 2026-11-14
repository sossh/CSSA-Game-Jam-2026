extends TeacherState

func enter() -> void:
	super()
	teacher.last_check = Game.elapsed
	if Game.is_host():
		Game.event.rpc("banner", {"text": "The chalk stops. GET TO YOUR SEAT."})
		Game.event.rpc("sound", {"position": teacher.global_position, "key": "teacher_warning"})

func physics_update(delta: float) -> void:
	super(delta)
	if state_time >= Game.config.teacher.turn_warning_seconds:
		state_transition.emit(self, "CheckState")
