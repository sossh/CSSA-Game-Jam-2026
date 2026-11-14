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
@export var coffee_travel_timeout: float = 3.5
@export var coffee_blocked_timeout: float = 1.0
@export var coffee_turn_speed: float = 3.0

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
@export var shot_grace_seconds: float = 6.0
@export var round_start_sound_grace_seconds: float = 12.0
@export var shotgun_damage: float = 65.0
@export var shotgun_range: float = 40.0
@export var shotgun_horizontal_impulse: float = 11.0
@export var shotgun_upward_impulse: float = 5.0
@export var shotgun_fire_delay: float = 1.48
@export var shotgun_recoil_anim_speed: float = 0.5
@export var shotgun_aim_turn_speed: float = 8.0
@export var shotgun_recovery_seconds: float = 3.7
@export var shotgun_volume: float = 150.0
@export var shotgun_pump_volume: float = 85.0

@export_group("Irritation meter")
## Presentation-only mood meter. It never feeds suspicion or the AI state machine.
@export var irritation_maximum: float = 100.0
@export var irritation_decay_per_second: float = 2.5
@export var irritation_coffee_decay_scale: float = 3.0
## Noise within this many metres of the teacher counts fully; farther noise counts at the minimum.
@export var irritation_hearing_radius: float = 9.0
@export var irritation_min_proximity: float = 0.2
@export var irritation_noise_scale: float = 0.2
@export var irritation_noise_cap: float = 14.0
@export var irritation_default_weight: float = 0.7
@export var irritation_kind_weights: Dictionary[String, float] = {
	"burp": 1.4, "fart": 1.8, "sneeze": 1.2, "crunch": 1.0, "chew": 0.8, "splat": 1.3,
	"impact": 1.0, "punch": 1.0, "crush_can": 1.5, "vending_dispense": 0.8,
	"stomach_growl": 0.6, "pickup": 0.3, "footstep": 0.15,
}
@export var irritation_throw_radius: float = 4.5
@export var irritation_throw_gain: float = 9.0
@export var irritation_hit_gain: float = 30.0
@export var irritation_punch_gain: float = 40.0
## Collective din: noise energy that lingers and keeps pressing on the meter.
@export var irritation_din_decay_seconds: float = 6.0
@export var irritation_din_threshold: float = 90.0
@export var irritation_din_gain: float = 0.06
@export var irritation_din_cap: float = 400.0
@export var irritation_notable_gain: float = 6.0
@export var irritation_after_shot: float = 30.0
