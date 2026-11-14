class_name PlayerConfig
extends Resource

@export_group("Movement")
@export var walk_speed: float = 4.0
@export var sprint_speed: float = 6.5
@export var acceleration: float = 30.0
@export var lunar_acceleration: float = 11.0
@export var lunar_braking: float = 8.0
@export var gravity: float = 15.0
@export var jump_speed: float = 5.0
@export var lunar_jump_speed: float = 3.2
@export var lunar_step_hop_speed: float = 1.55
@export_range(0.0, 2.0, 0.05, "suffix:m") var floor_snap_length: float = 0.35
@export var spectate_speed: float = 8.0
@export var energy_speed_multiplier: float = 1.8
@export var energy_boost_seconds: float = 12.0

@export_group("Look and footsteps")
@export var mouse_sensitivity: float = 0.002
@export var walk_step_seconds: float = 0.5
@export var sprint_step_seconds: float = 0.32
@export var walk_step_loudness: float = 4.0
@export var sprint_step_loudness: float = 16.0
@export_range(0.01, 1.57, 0.01, "radians_as_degrees") var pitch_limit_radians: float = 1.45

@export_group("Carrying and recovery")
@export_range(0.01, 10.0, 0.01, "or_greater", "suffix:s") var throw_charge_seconds: float = 1.0
@export var ragdoll_seconds: float = 2.5
@export var struggle_presses: int = 3
@export var struggle_interval_seconds: float = 0.4
@export var struggle_impulse: float = 4.0
@export var aim_reach: float = 3.2
@export var interaction_reach: float = 4.0
