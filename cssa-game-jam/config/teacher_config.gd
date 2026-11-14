class_name TeacherConfig
extends Resource

@export_group("Checking")
@export var check_min_seconds: float = 30.0
@export var check_max_seconds: float = 70.0
@export var check_cooldown: float = 6.0
@export var turn_warning_seconds: float = 0.75
@export var check_seconds: float = 5.0
@export var check_scan_delay: float = 0.5
@export var check_sweep_rate: float = 0.8
@export var check_sweep_angle: float = 0.3
@export var check_turn_speed: float = 1.5
@export var visible_violation_seconds: float = 0.35
@export var check_alertness_scale: float = 0.5
@export var check_grade_scale: float = 0.08
@export var suspicion_after_check_scale: float = 0.5

@export_group("Hearing")
@export var hearing_threshold: float = 65.0
@export var coffee_hearing_scale: float = 0.28
@export var lecture_hearing_scale: float = 0.35
@export var alert_hearing_scale: float = 1.5
@export var distance_hearing_falloff: float = 0.09
@export var suspicion_decay_per_second: float = 4.0
@export var alertness_decay_per_second: float = 0.008
@export var maximum_suspicion: float = 150.0
@export var warning_suspicion: float = 25.0
@export var lecture_investigate_suspicion: float = 70.0
@export var lecture_investigate_loudness: float = 60.0
@export var lecture_extreme_loudness: float = 120.0
@export var alert_investigate_suspicion: float = 55.0
@export var catch_suspicion: float = 100.0
@export var provoked_loudness: float = 200.0

@export_group("Investigation and blame")
@export var blame_radius: float = 5.5
@export var blame_distance_penalty: float = 2.0
@export var blame_random_bonus: float = 3.0
@export var blame_violation_bonus: float = 4.0
@export var investigate_alertness_gain: float = 0.5
@export var maximum_alertness: float = 2.0
@export var investigation_travel_seconds: float = 10.0
@export var investigation_seconds: float = 12.0
@export var investigation_catch_suspicion: float = 35.0
@export var investigation_sweep_rate: float = 2.0
@export var investigation_sweep_angle: float = 1.2
@export var investigation_turn_speed: float = 2.0
@export var sight_range: float = 25.0
@export var sight_forward_dot: float = 0.48

@export_group("Coffee")
@export var first_coffee_delay: Vector2 = Vector2(20, 35)
@export var coffee_delay: Vector2 = Vector2(30, 50)
@export var coffee_seconds: float = 5.0
@export var coffee_extra_seconds_per_tablet: float = 3.0
@export var first_coffee_tablet_scale: float = 0.5
@export var coffee_tablet_scale: float = 0.7
@export var coffee_travel_timeout: float = 3.5
@export var coffee_blocked_timeout: float = 1.0
@export var coffee_turn_speed: float = 3.0
@export var maximum_tablets: int = 3

@export_group("Movement")
@export var walk_speed: float = 2.5
@export var walk_turn_speed: float = 4.0
@export var enter_speed: float = 3.0
@export var exit_speed: float = 4.0
@export var walk_step_seconds: float = 0.55
@export var enter_step_seconds: float = 0.5
@export var exit_step_seconds: float = 0.45
@export var footstep_volume: float = 55.0
@export var door_volume: float = 60.0

@export_group("Shotgun")
@export var shotgun_damage: float = 65.0
@export var shotgun_range: float = 40.0
@export var shotgun_horizontal_impulse: float = 11.0
@export var shotgun_upward_impulse: float = 5.0
@export var shotgun_fire_delay: float = 1.1
@export var shotgun_aim_turn_speed: float = 8.0
@export var shotgun_recovery_seconds: float = 2.2
@export var shotgun_volume: float = 150.0
@export var shotgun_pump_volume: float = 85.0
