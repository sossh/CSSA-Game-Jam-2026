class_name GameConfig
extends Resource

@export_group("Rounds")
@export var preparation_seconds: float = 5.0
@export var class_seconds: float = 300.0
@export var break_seconds: float = 90.0
@export var maximum_players: int = 6
@export var npc_count: int = 10
@export_group("Stomach and economy")
@export var stomach_max: float = 100.0
@export var hunger_per_second: float = 0.42
@export var starting_bitcoin: int = 20
@export var attendance_allowance: int = 5
@export var bitcoin_per_food: float = 0.5
@export var cloning_fee: int = 10
@export_group("Teacher")
@export var check_min_seconds: float = 30.0
@export var check_max_seconds: float = 70.0
@export var check_cooldown: float = 6.0
@export var turn_warning_seconds: float = 0.75
@export var hearing_threshold: float = 65.0
@export var shotgun_damage: float = 65.0
@export var ragdoll_seconds: float = 2.5
@export_group("Population")
@export var food_spawns_per_player: int = 5
@export var max_loose_items: int = 90
