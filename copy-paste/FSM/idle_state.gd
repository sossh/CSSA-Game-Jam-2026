extends PlayerState

@export var anim_name:String="idle"
@export var fall_grace_time: float = 0.15 # Seconds before fall state triggers

func enter() -> void:
	player.can_jump = true
	play_animation()

func physics_update(_delta: float) -> void:
	super(_delta)
	play_animation()
	apply_gravity(_delta)
	
	# Slow the player down
	player.velocity.x = lerp(player.velocity.x, 0.0, player.friction)
	update_movement()
	
	# check for move state
	if is_in_move():
		state_transition.emit(self, "MoveState")
		return
	
	if is_jumping():
		state_transition.emit(self, "JumpState")
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
