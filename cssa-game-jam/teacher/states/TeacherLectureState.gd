extends TeacherState

func enter() -> void:
	super()
	var cooldown := randf_range(Game.config.check_min_seconds, Game.config.check_max_seconds)
	var urgency_modifier := 1.0 + (teacher.alertness * 0.5) + ((Game.grade - 1) * 0.08)
	teacher.next_check = Game.elapsed + (cooldown / urgency_modifier)
	if teacher.chalk_audio and not teacher.chalk_audio.playing:
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
	teacher.turn(0, delta, 4)
	
	var check_cooldown_met := (Game.elapsed - teacher.last_check >= Game.config.check_cooldown)
	
	if Game.elapsed >= teacher.next_coffee: 
		state_transition.emit(self, "CoffeeState")
	elif Game.elapsed >= teacher.next_check and check_cooldown_met: 
		state_transition.emit(self, "WarningState")
