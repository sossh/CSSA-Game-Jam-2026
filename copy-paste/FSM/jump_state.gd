extends PlayerState

@export var anim_name:String="jump"

func enter() -> void:
	player.can_jump = false
	play_animation()

func physics_update(_delta: float) -> void:
	super(_delta)
	play_animation()
	player.velocity += Vector2(0, -30000 * _delta).rotated(player.global_rotation)
	update_movement()
	
	state_transition.emit(self, "FallState")

func play_animation():
	
	# Flip the sprite if needed
	player.sprite.flip_h = player.facing_left
	player.sprite.play(anim_name)
