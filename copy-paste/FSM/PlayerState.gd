extends FSMState
class_name PlayerState

# To be set via finite state machine
var player:Character

var off_floor_time: float = 0.0 # The amount of time the player has spent off the floor

# State Methods
func physics_update(_delta: float) -> void:
	# Keep track of how long the player has been off the ground
	if player.is_on_floor():
		off_floor_time = 0.0
	else:
		off_floor_time += _delta

func handle_input(_event: InputEvent):
	if _event.is_action_pressed("left"):
		player.facing_left = true
	if _event.is_action_pressed("right"):
		player.facing_left = false

# Some state detection helper methods
func is_in_idle() -> bool:
	return Input.get_axis("left", "right") == 0 and player.is_on_floor()
	
func is_in_move() -> bool:
	return Input.get_axis("left", "right") != 0 and player.is_on_floor()
	
func is_jumping(coyote_grace_time:float=0) -> bool:
	return player.can_jump and Input.is_action_pressed("jump") and (player.is_on_floor() or off_floor_time < coyote_grace_time)
	
func is_falling(fall_grace_time:float=0) -> bool:
	return (not player.is_on_floor()) and (off_floor_time > fall_grace_time)


# General helper methods
func apply_gravity(delta:float):
	player.velocity = player.get_real_velocity() + (Game.WORLD.gravity_at_pos(player.global_position) * delta)

# To be called each time after the player is moved in any way
func update_movement():
	player.move_and_slide()
