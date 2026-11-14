class_name State
extends Node

# Emit this when you want the StateMachine to swap to a different state
@warning_ignore("unused_signal")
signal state_transition(state: State, new_state_name: String)

# Called exactly once when the state machine enters this state. 
# Good for starting animations or resetting variables.
func enter() -> void:
	pass

# Called exactly once right before the state machine swaps to a new state.
# Good for cleaning up stuff like visual effects or timers.
func exit() -> void:
	pass

# The absolute bare minimum that needs to be cleaned up to end a State.
# Called when a state is forcfully closed.
func close() -> void:
	pass

# Corresponds to _process(). Good for timers, UI updates, etc.
func update(_delta: float) -> void:
	pass

# Corresponds to _physics_process(). All your movement code goes here.
func physics_update(_delta: float) -> void:
	pass

# Corresponds to _unhandled_input(). 
# This completely eliminates the need to poll Input.is_action_just_pressed() in your update loops.
func handle_input(_event: InputEvent) -> void:
	pass
