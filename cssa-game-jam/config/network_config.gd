class_name NetworkConfig
extends Resource

@export_range(1, 65535) var game_port: int = 7777
@export_range(1, 65535) var discovery_port: int = 7778
@export var discovery_duration_ms: int = 1600
@export var discovery_retry_ms: int = 400
