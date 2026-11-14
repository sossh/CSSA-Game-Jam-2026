extends Camera3D

@export var mouse_sensitivity: float = 0.002

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		
		# 1. Rotate the camera up and down (Pitch)
		rotation.x -= event.relative.y * mouse_sensitivity
		
		# Clamp to prevent the camera from flipping upside down
		rotation.x = clamp(rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
		
		# 2. Rotate the entire CharacterBody3D left and right (Yaw)
		# get_parent() targets the CharacterBody3D in your hierarchy
		get_parent().rotate_y(-event.relative.x * mouse_sensitivity)

	# Unlock mouse to close/debug the game
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
