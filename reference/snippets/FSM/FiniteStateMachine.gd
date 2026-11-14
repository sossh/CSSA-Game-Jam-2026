extends Node
class_name FiniteStateMachine
# Generic finite state machine that can be used for anything


@export var player:Player

var states : Dictionary = {}
var current_state : State
@export var initial_state : State


func _ready():
	if !player.is_multiplayer_authority(): return
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.state_transition.connect(change_state)

	if initial_state:
		initial_state.enter()
		current_state = initial_state

#-------------------------------#
# Call Update Methods
#-------------------------------#
func _process(delta: float) -> void:
	if !player.is_multiplayer_authority(): return
	if current_state and current_state is State:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if !player.is_multiplayer_authority(): return
	if current_state and current_state is State:
		current_state.physics_update(delta)

func _input(event: InputEvent) -> void:
	if !player.is_multiplayer_authority(): return
	if current_state and current_state is State:
		current_state.handle_input(event)







#-------------------------------#
# State Management
#-------------------------------#

#Use force_change_state cautiously, it immediately switches to a state regardless of any transitions.
#This is used to force us into a 'death state' when killed
func force_change_state(new_state : String):
	if !player.is_multiplayer_authority(): return
	
	var newState = states.get(new_state.to_lower())
	if !newState:
		print(new_state + " does not exist in the dictionary of states")
		return
	
	if current_state == newState:
		print("State is same, aborting")
		return
	
	if current_state:
		var close_method = Callable(current_state, "close")
		close_method.call_deferred()
	
	newState.enter()
	current_state = newState
	
func change_state(source_state : State, new_state_name : String):
	if !player.is_multiplayer_authority(): return
	
	if source_state != current_state:
		print("Invalid change_state trying from: " + source_state.name + " but currently in: " + current_state.name)
		return
	
	var new_state = states.get(new_state_name.to_lower())
	if !new_state:
		print(new_state_name + " does not exist in the dictionary of states")
		return
		
	if current_state:
		current_state.exit()
		
	new_state.enter()
	
	current_state = new_state
