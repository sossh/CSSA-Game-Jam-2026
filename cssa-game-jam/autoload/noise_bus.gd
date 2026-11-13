extends Node

signal noise_made(position: Vector3, loudness: float, source: String, kind: String)

func emit_noise(position: Vector3, loudness: float, source: String = "", kind: String = "impact") -> void:
	if not Game.is_host(): return
	noise_made.emit(position, loudness, source, kind)
	var facing := Vector3.FORWARD
	var seated := false
	if source.is_valid_int() and Game.players.has(int(source)):
		var player: Dictionary = Game.players[int(source)]
		facing = -(Basis(Vector3.UP, player.yaw) * Basis(Vector3.RIGHT, player.pitch)).z
		seated = player.mode == "seated"
	# Origin/direction travel with the event, so a late pose packet cannot place
	# a burp at the wrong student's mouth. Presentation never emits more noise.
	Game.event.rpc("sound", {"position": position, "key": kind, "loudness": loudness,
		"source": source, "direction": facing, "seated": seated})
	if kind in ["burp", "fart", "sneeze"]:
		var verb: String = {"burp": "burps with confidence", "fart": "releases a forbidden atmosphere", "sneeze": "sneezes away their cover"}[kind]
		Game.log_activity("%s %s." % [Game.actor_name(source), verb])
