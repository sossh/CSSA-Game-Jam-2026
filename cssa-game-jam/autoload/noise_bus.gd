extends Node

signal noise_made(position: Vector3, loudness: float, source: String, kind: String)

func emit_noise(position: Vector3, loudness: float, source: String = "", kind: String = "impact") -> void:
	if not Game.is_host(): return
	noise_made.emit(position, loudness, source, kind)
	Game.event.rpc("sound", {"position": position, "key": kind, "loudness": loudness})
