extends Node3D

## All emission, mesh, motion and colour settings are authored in the scenes.
## This script only starts the existing emitter and lets its scene timer clean up.
@onready var particles: CPUParticles3D = $Particles

func _ready() -> void:
	particles.restart()
