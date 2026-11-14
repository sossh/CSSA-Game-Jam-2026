class_name InteractionConfig
extends Resource

@export_group("Eating")
@export var eat_seconds: float = 1.5
@export var can_crush_loudness: float = 35.0

@export_group("Action cooldowns")
@export var interact_cooldown: float = 0.15
@export var throw_cooldown: float = 0.2
@export var use_cooldown: float = 0.5
@export var punch_cooldown: float = 0.6
@export var fart_cooldown: float = 0.5
@export var step_cooldown: float = 0.25
@export var buy_cooldown: float = 0.2

@export_group("Carrying and throwing")
@export var item_throw_speed: float = 8.0
@export var item_throw_charge_bonus: float = 12.0
@export var item_throw_lift: float = 2.0
@export var item_drop_speed: float = 1.5
@export var clone_throw_scale: float = 0.75
@export var player_throw_speed: float = 12.0
@export var player_throw_charge_bonus: float = 18.0
@export var player_throw_lift: float = 4.5
@export var player_throw_lift_charge_bonus: float = 3.5
@export var player_drop_speed: float = 2.0
@export var pickup_loudness: float = 10.0
@export var throw_loudness: float = 12.0
@export var pickup_violation_seconds: float = 1.5
@export var throw_violation_seconds: float = 2.0
@export var use_violation_seconds: float = 2.0

@export_group("Punch and weapons")
@export var punch_reach: float = 2.2
@export var punch_damage: float = 3.0
@export var punch_loudness: float = 35.0
@export var punch_impulse: float = 7.0
@export var punch_lift: float = 3.0
@export var clone_lethal_damage: float = 20.0

@export_group("Impacts and props")
@export var minimum_impact_speed: float = 1.8
@export var impact_cooldown: float = 0.2
@export var impact_loudness_cap: float = 110.0
@export var clone_impact_loudness: float = 45.0
@export_range(0.01, 100.0, 0.01, "or_greater") var impact_speed_reference: float = 7.0
@export var impact_loudness_scale: Vector2 = Vector2(0.3, 1.8)
@export var ragdoll_impact_speed: float = 5.0
@export var impact_impulse_cap: float = 12.0
@export var impact_impulse_scale: float = 0.7
@export var impact_lift: float = 3.0
@export var tomato_splat_speed: float = 4.0

@export_group("Vending")
@export var vending_reach: float = 4.5
@export var vending_loudness: float = 25.0
