extends FiniteStateMachine
class_name PlayerFiniteStateMachine

@export var character:Character

func _ready():
	if character == null:
		push_error("No player object was given to FiniteStateMachine: " + name)
	
	if not character.is_node_ready():
		await character.ready
	
	for child in get_children():
		if child is FSMState:
			states[child.name.to_lower()] = child
			child.state_transition.connect(change_state)
			child.player = character
	super()

func _physics_process(delta: float) -> void: 
	super(delta)
	#print(current_state.name)
