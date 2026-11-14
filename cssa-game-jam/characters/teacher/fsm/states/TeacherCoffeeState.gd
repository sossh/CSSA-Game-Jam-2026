extends TeacherState

var drank: bool = false
var drink_time: float = 0.0

func enter() -> void:
	super()
	drank = true
	drink_time = 0.0
	teacher.path.clear()
	if teacher.chalk_audio and teacher.chalk_audio.playing:
		teacher.chalk_audio.stop()
	teacher.current_anim = "drink-animation"
	if Game.is_host():
		Game.event.rpc("banner", {"text": "Professor X-PEL takes a very loud sip. SNACK WINDOW!"})
		Game.event.rpc("sound", {"position": teacher.global_position, "key": "coffee"})
		Game.event.rpc("sound", {"position": teacher.global_position, "key": "teacher_yawn"})

func exit() -> void:
	super()
	drank = false
	drink_time = 0.0

func close() -> void:
	super()
	drank = false
	drink_time = 0.0

func physics_update(delta: float) -> void:
	super(delta)
	var tuning := Game.config.teacher
	teacher.current_anim = "drink-animation"
	drink_time += delta
	var coffee_duration := teacher.get_coffee_duration()
	if drink_time >= coffee_duration:
		var delay := randf_range(tuning.coffee_delay.x, tuning.coffee_delay.y)
		teacher.next_coffee = Game.elapsed + delay
		teacher.path.clear()
		state_transition.emit(self, "LectureState")
