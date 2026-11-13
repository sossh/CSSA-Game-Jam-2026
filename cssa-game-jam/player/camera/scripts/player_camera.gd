extends Camera3D

@export var mouse_sensitivity: float = 0.002
@export var pitch_limit: float = 89.0

func _ready() -> void:
	# Locks the cursor to the window center and hides it
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	# Only process camera movement if the mouse is currently captured
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		
		# Vertical rotation (Pitch) - looks up and down
		rotation.x -= event.relative.y * mouse_sensitivity
		
		# Clamp the X rotation so the camera doesn't flip upside down
		rotation.x = clamp(rotation.x, deg_to_rad(-pitch_limit), deg_to_rad(pitch_limit))
		
		# Horizontal rotation (Yaw) - looks left and right
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Reset Z rotation to prevent the camera from tilting sideways over time
		rotation.z = 0.0

	# Optional debug toggle: Press Escape to unlock the mouse cursor
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	# Left click to recapture the mouse if it was unlocked
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
