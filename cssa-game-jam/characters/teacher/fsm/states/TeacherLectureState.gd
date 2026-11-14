extends TeacherState

func enter() -> void:
	super()
	teacher.path.clear()
	var tuning := Game.config.teacher
	var cooldown := randf_range(tuning.check_min_seconds, tuning.check_max_seconds)
	var urgency_modifier := 1.0 + (teacher.alertness * tuning.check_alertness_scale) + ((Game.grade - 1) * tuning.check_grade_scale)
	teacher.next_check = Game.elapsed + (cooldown / urgency_modifier)
	if DisplayServer.get_name() != "headless" and teacher.chalk_audio.stream and not teacher.chalk_audio.playing:
		teacher.chalk_audio.play()

func exit() -> void:
	super()
	if teacher.chalk_audio and teacher.chalk_audio.playing:
		teacher.chalk_audio.stop()

func close() -> void:
	super()
	if teacher.chalk_audio and teacher.chalk_audio.playing:
		teacher.chalk_audio.stop()

func physics_update(delta: float) -> void:
	super(delta)
	teacher.walk_to_board(delta)
	teacher.turn(0, delta, Game.config.teacher.walk_turn_speed)
	
	var check_cooldown_met := (Game.elapsed - teacher.last_check >= Game.config.teacher.check_cooldown)
	
	if Game.elapsed >= teacher.next_coffee: 
		state_transition.emit(self, "CoffeeState")
	elif Game.elapsed >= teacher.next_check and check_cooldown_met: 
		state_transition.emit(self, "WarningState")
