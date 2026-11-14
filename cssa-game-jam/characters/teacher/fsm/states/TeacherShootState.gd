extends TeacherState

const AIM_PEAK_TIME: float = 1.48
const TOTAL_ANIM_LENGTH: float = 2.5666

func enter() -> void:
	super()
	teacher.shot_fired = false
	teacher.actual_shot_fired = false
	teacher.shoot_aim_held = false
	teacher.current_anim = "shoot-animation"

func physics_update(delta: float) -> void:
	super(delta)
	var tuning := Game.config.teacher
	var point = Game.world.target_position(teacher.target)
	
	if point != null:
		teacher.aim_point = point + Vector3.UP
		teacher.face_point(point, delta, tuning.shotgun_aim_turn_speed)
		
	var fire_delay: float = maxf(tuning.shotgun_fire_delay, AIM_PEAK_TIME)

	if state_time >= fire_delay and not teacher.shot_fired:
		teacher.shot_fired = true
		if point != null and teacher.clear_sight(point + Vector3.UP): 
			teacher.fire()
		else:
			# Lost line of sight before shooting: do not shoot or play rest of animation!
			teacher.actual_shot_fired = false
			state_transition.emit(self, "InvestigateState")
			return
			
	if teacher.actual_shot_fired:
		# Teacher actually shot: calculate recovery duration based on slowed firing speed
		var recoil_speed: float = tuning.shotgun_recoil_anim_speed if "shotgun_recoil_anim_speed" in tuning else 0.5
		var recovery_after_shot: float = (TOTAL_ANIM_LENGTH - AIM_PEAK_TIME) / maxf(0.1, recoil_speed)
		if state_time >= fire_delay + recovery_after_shot:
			teacher.suspicion = 0.0
			teacher.relieve_irritation()
			teacher.last_check = Game.elapsed
			state_transition.emit(self, "LectureState")
	elif teacher.shot_fired:
		# Did not shoot: do not play rest of animation, return to LectureState
		state_transition.emit(self, "LectureState")
		state_transition.emit(self, "LectureState")

func exit() -> void:
	super()
	if not teacher.actual_shot_fired:
		teacher.shoot_aim_held = false
		if teacher.anim and teacher.anim.assigned_animation == "shoot-animation":
			teacher.anim.play("idle", -1, 1.0)
