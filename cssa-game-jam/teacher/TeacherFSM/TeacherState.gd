extends State
class_name TeacherState

var teacher: ClassroomTeacher
var state_time: float = 0.0
@export var display_name: String = "Unknown"
@export var is_alert_state: bool = false

func enter() -> void:
	state_time = 0.0
	teacher.scan_time = 0.0
	teacher.shot_fired = false

func physics_update(delta: float) -> void:
	state_time += delta
