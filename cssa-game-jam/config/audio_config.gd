class_name AudioConfig
extends Resource

@export_group("Sound library")
@export_dir var event_root: String = "res://assets/audio"
## Maps a sound event key to a replacement folder. An empty folder path mutes that event.
@export var event_folders: Dictionary[String, String] = {}
## Assign an AudioStream or an AudioStreamRandomizer to override an event's folder.
@export var event_streams: Dictionary[String, AudioStream] = {}

@export_group("Event mix")
@export var default_playback_loudness: float = 40.0
@export_range(1.0, 200.0, 1.0, "or_greater") var reference_loudness: float = 60.0
@export var minimum_db: float = -24.0
@export var maximum_db: float = 3.0
@export var event_maximum_db: Dictionary[String, float] = {}
@export var event_unit_size: Dictionary[String, float] = {}
@export var event_max_distance: Dictionary[String, float] = {}
@export var pitch_range: Vector2 = Vector2(0.95, 1.05)

@export_group("Room and lecture")
@export var classroom_ambiance: AudioStream
@export var classroom_ambiance_db: float = -26.0
@export var lecture_chalk: AudioStream
@export var lecture_chalk_db: float = 4.0
@export var lecture_chalk_unit_size: float = 8.0
@export var lecture_chalk_max_distance: float = 35.0
