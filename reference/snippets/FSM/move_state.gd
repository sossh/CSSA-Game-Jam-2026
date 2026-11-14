extends PlayerState

@export var anim_name:String="move"
@export var fall_grace_time: float = 0.2 # Seconds before fall state triggers

func enter() -> void:
	player.can_jump = true
	play_animation()

func physics_update(_delta: float) -> void:
	super(_delta)
	play_animation()
	apply_gravity(_delta)
	
	 # TODO make a more realisitic change in velocity for the player
	player.velocity = player.velocity.lerp(Vector2((Input.get_action_strength("right") - Input.get_action_strength("left")) * player.max_movement_speed, 0).rotated(player.global_rotation), 0.2)
	update_movement()
	
	if is_jumping():
		state_transition.emit(self, "JumpState")
		return
		
	if is_in_idle():
		state_transition.emit(self, "IdleState")
		return
	
	if is_falling(fall_grace_time):
		state_transition.emit(self, "FallState")
		return
	
	if player.cockpit:
		state_transition.emit(self, "SeatedState")
		return

func play_animation():
	# Flip the sprite if needed
	player.sprite.flip_h = player.facing_left
	player.sprite.play(anim_name)
	
