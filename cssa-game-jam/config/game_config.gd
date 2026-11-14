class_name GameConfig
extends Resource

@export_group("Rounds")
@export var preparation_seconds: float = 20.0
@export var class_seconds: float = 120.0
@export var break_seconds: float = 90.0
@export_range(2, 6) var maximum_players: int = 6

@export_group("Stomach")
@export var stomach_max: float = 100.0
@export var hunger_per_second: float = 0.70
@export var hunger_per_grade: float = 0.06
@export var growl_stomach_threshold: float = 25.0
@export var growl_interval: Vector2 = Vector2(10, 18)
@export var growl_loudness: float = 32.0
@export_range(1.0, 1000.0, 1.0, "or_greater") var gas_capacity: float = 100.0
@export_range(0.0, 1.0) var gas_warning_fraction: float = 0.85
@export var auto_gas_cooldown: float = 0.8
@export var gas_relief: Vector2 = Vector2(40, 50)
@export var burp_loudness: float = 45.0
@export var fart_loudness: float = 50.0

@export_group("Economy")
@export var starting_bitcoin: int = 20
@export var attendance_allowance: int = 5
@export var bitcoin_per_food: float = 0.5
@export var cloning_fee: int = 10

@export_group("Population")
@export var npc_count: int = 10
@export var food_spawns_per_player: int = 5
@export var base_loot_spawns: int = 5
@export var mixed_loot_spawns: int = 4
@export var max_loose_items: int = 90
@export var food_drop_min_seconds: float = 6.0
@export var food_drop_max_seconds: float = 14.0
@export var food_drop_marker_scatter: float = 0.4
@export var food_drop_player_distance: Vector2 = Vector2(1, 2)
@export var food_drop_side_scatter: float = 0.5
@export var prep_loot_scatter: Vector2 = Vector2(0.25, 0.12)
@export var prep_loot_base_height: float = 0.1
@export var prep_loot_stack_height: float = 0.3
@export var npc_first_noise_delay: Vector2 = Vector2(80, 150)
@export var npc_noise_interval: Vector2 = Vector2(130, 180)
@export var npc_noise_loudness: Vector2 = Vector2(18, 30)
@export var clone_mass: float = 12.0
@export var clone_return_delay: float = 6.0
@export var clone_return_max_speed: float = 1.5
@export var fall_out_height: float = -15.0

@export_group("Presentation")
@export_range(0, 500) var activity_limit: int = 60
@export var active_effect_limit: int = 100
@export var bell_volume: float = 100.0
@export var clone_volume: float = 55.0
@export var banner_seconds: float = 5.0
@export var hurt_flash_alpha: float = 0.35
@export var splat_flash_alpha: float = 0.65
@export var flash_fade_per_second: float = 0.25

@export_group("Gameplay resources")
@export var player: PlayerConfig
@export var teacher: TeacherConfig
@export var interactions: InteractionConfig
