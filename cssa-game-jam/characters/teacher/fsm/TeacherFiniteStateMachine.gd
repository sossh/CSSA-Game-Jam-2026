extends Node
class_name TeacherFiniteStateMachine

@export var teacher: ClassroomTeacher
@export var initial_state: TeacherState

var states: Dictionary = {}
var current_state: TeacherState

func _ready() -> void:
	# Initialize immediately so it's ready before start_class() is called
	for child in get_children():
		if child is TeacherState:
			states[child.name.to_lower()] = child
			child.state_transition.connect(change_state)
			child.teacher = teacher

	if initial_state:
		initial_state.enter()
		current_state = initial_state

func _physics_process(delta: float) -> void:
	# ONLY the host runs the actual behavior logic
	if Game.is_host() and current_state:
		current_state.physics_update(delta)

func force_change_state(new_state_name: String) -> void:
	# Both host and client can use this (host for logic, clients for network syncing)
	var new_state = states.get(new_state_name.to_lower())
	if not new_state or current_state == new_state: return
	
	if current_state:
		current_state.close()
	new_state.enter()
	current_state = new_state

func change_state(source_state: State, new_state_name: String) -> void:
	# ONLY the host can trigger internal logic transitions
	if not Game.is_host(): return 
	if source_state != current_state: return
	
	var new_state = states.get(new_state_name.to_lower())
	if not new_state: return
		
	if current_state:
		current_state.exit()
	new_state.enter()
	current_state = new_state
