extends Node

## Human-recorded/licensed files only. Missing audio is intentionally silent.
const SOUND_SCENE := preload("res://effects/positional_sound.tscn")

var config: AudioConfig = preload("res://config/audio_config.tres")
var cache: Dictionary[String, Array] = {}

func _ready() -> void:
	# Load every event folder up front. Doing it on first play made the first throw,
	# impact, punch or shotgun blast hitch while the files were listed and read.
	if DisplayServer.get_name() != "headless": warm_cache.call_deferred()

func warm_cache() -> void:
	var keys: Array[String] = []
	for entry in ResourceLoader.list_directory(config.event_root):
		if entry.ends_with("/"): keys.append(entry.trim_suffix("/"))
	for key in config.event_folders.keys():
		if key not in keys: keys.append(key)
	for key in keys: stream_for_event(key)

func stream_for_event(key: String) -> AudioStream:
	if config.event_streams.has(key):
		return config.event_streams[key]
	if not cache.has(key):
		var streams: Array[AudioStream] = []
		var folder := config.event_folders.get(key, config.event_root.path_join(key)) as String
		if not folder.is_empty():
			for filename in ResourceLoader.list_directory(folder):
				if filename.get_extension().to_lower() in ["wav", "ogg", "mp3"]:
					var stream := ResourceLoader.load(folder.path_join(filename)) as AudioStream
					if stream != null: streams.append(stream)
		cache[key] = streams
	var options: Array = cache[key]
	return options.pick_random() if not options.is_empty() else null

func play_at(key: String, position: Vector3, loudness: float) -> void:
	if DisplayServer.get_name() == "headless": return
	var stream := stream_for_event(key)
	if stream == null: return
	var speaker: AudioStreamPlayer3D = SOUND_SCENE.instantiate()
	speaker.stream = stream
	var max_db: float = config.event_maximum_db.get(key, config.maximum_db)
	var volume_db := linear_to_db(maxf(loudness, 1.0) / config.reference_loudness)
	speaker.volume_db = clampf(volume_db, config.minimum_db, max_db)
	speaker.unit_size = config.event_unit_size.get(key, speaker.unit_size)
	speaker.max_distance = config.event_max_distance.get(key, speaker.max_distance)
	speaker.pitch_scale = randf_range(config.pitch_range.x, config.pitch_range.y)
	add_child(speaker)
	speaker.global_position = position
	speaker.play()
