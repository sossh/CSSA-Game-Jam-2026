extends PlayerState

@export var anim_name:String="fall"
@export var coyote_jump_time:float = 0.1 # Amount of time player can be off floor but still be able to jump

func enter() -> void:
	play_animation()

func physics_update(_delta: float) -> void:
	super(_delta)
	play_animation()
	
	var direction = Input.get_action_strength("right") - Input.get_action_strength("left")
	
	if direction != 0:
		var target_x = direction * player.max_air_speed
		
		# Let player steer if slower than normal air speed, or are trying to stop
		if abs(player.velocity.x) <= abs(target_x) or sign(player.velocity.x) != sign(direction):
			player.velocity.x = lerp(player.velocity.x, target_x, 0.1)
	else:
		# Only apply air resistance if pressing nothing
		player.velocity.x = lerp(player.velocity.x, 0.0, player.air_friction)
	
	apply_gravity(_delta)
	update_movement()
	
	if is_in_idle():
		state_transition.emit(self, "IdleState")
		return
		
	if is_in_move():
		state_transition.emit(self, "MoveState")
		return
	
	if is_jumping(coyote_jump_time):
		state_transition.emit(self, "JumpState")
		return
	
	if player.cockpit:
		state_transition.emit(self, "SeatedState")
		return

func play_animation():
	
	# Flip the sprite if needed
	player.sprite.flip_h = player.facing_left
	player.sprite.play(anim_name)
