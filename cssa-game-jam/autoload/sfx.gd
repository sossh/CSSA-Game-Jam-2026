extends Node

## Human-recorded/licensed files only. Missing audio is intentionally silent.
## Add assets/audio/<event>/<variation>.ogg or .wav; no code change needed.
var cache: Dictionary = {}
const SOUND_SCENE := preload("res://effects/positional_sound.tscn")

func play_at(key: String, position: Vector3, loudness: float = 40.0) -> void:
	if not cache.has(key):
		var streams: Array[AudioStream] = []
		var folder := "res://assets/audio/" + key
		if DirAccess.dir_exists_absolute(folder):
			for filename in ResourceLoader.list_directory(folder):
				if filename.get_extension() in ["wav", "ogg", "mp3"]:
					var stream = load(folder.path_join(filename))
					if stream is AudioStream: streams.append(stream)
		cache[key] = streams
	var options: Array = cache[key]
	if options.is_empty(): return
	var speaker: AudioStreamPlayer3D = SOUND_SCENE.instantiate()
	speaker.stream = options.pick_random()
	speaker.volume_db = clampf(linear_to_db(maxf(loudness, 1.0) / 60.0), -24.0, 2.0)
	speaker.pitch_scale = randf_range(0.94, 1.06)
	add_child(speaker)
	speaker.global_position = position
	speaker.play()
