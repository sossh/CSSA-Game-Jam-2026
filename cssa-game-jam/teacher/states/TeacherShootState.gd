extends TeacherState

func physics_update(delta: float) -> void:
	super(delta)
	var point = Game.world.target_position(teacher.target)
	
	if point != null:
		teacher.aim_point = point + Vector3.UP
		teacher.face_point(point, delta, 8.0)
		
	if state_time > 1.1 and not teacher.shot_fired:
		teacher.shot_fired = true
		if point != null and teacher.clear_sight(point + Vector3.UP): 
			teacher.fire()
			
	if state_time > 2.2: 
		state_transition.emit(self, "LectureState")
