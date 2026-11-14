extends TeacherState

func physics_update(delta: float) -> void:
	super(delta)
	var tuning := Game.config.teacher
	var point = Game.world.target_position(teacher.target)
	
	if point != null:
		teacher.aim_point = point + Vector3.UP
		teacher.face_point(point, delta, tuning.shotgun_aim_turn_speed)
		
	if state_time > tuning.shotgun_fire_delay and not teacher.shot_fired:
		teacher.shot_fired = true
		if point != null and teacher.clear_sight(point + Vector3.UP): 
			teacher.fire()
			
	if state_time > tuning.shotgun_recovery_seconds:
		state_transition.emit(self, "LectureState")
