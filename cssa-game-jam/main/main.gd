extends Node

func _ready() -> void:
	Net.joined.connect(connected)
	Net.disconnected.connect(disconnected)
	call_deferred("command_line")

func connected() -> void:
	if Game.is_host(): Game.register(Net.player_name)
	else: Game.register.rpc_id(1, Net.player_name)
	$UI.connected()

func disconnected(message: String) -> void:
	Game.reset()
	if "--network-test" in OS.get_cmdline_user_args():
		get_tree().quit()
		return
	# A fresh scene also clears every replicated entity and local ragdoll.
	get_tree().set_meta("disconnect_message", message)
	get_tree().reload_current_scene.call_deferred()

func command_line() -> void:
	if Net.command_line_used: return
	Net.command_line_used = true
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--port="): Net.port = int(arg.trim_prefix("--port="))
		if arg.begins_with("--prep="): Game.config.preparation_seconds = float(arg.trim_prefix("--prep="))
		if arg.begins_with("--class="): Game.config.class_seconds = float(arg.trim_prefix("--class="))
		if arg.begins_with("--break="): Game.config.break_seconds = float(arg.trim_prefix("--break="))
		if arg.begins_with("--quit-after="):
			get_tree().create_timer(float(arg.trim_prefix("--quit-after="))).timeout.connect(get_tree().quit)
	if "--host" in args: Net.host("Host", "127.0.0.1" if "--loopback" in args else "")
	for arg in args:
		if arg.begins_with("--join="): Net.join("LAN student", arg.trim_prefix("--join="))
	if "--autostart" in args:
		get_tree().create_timer(2).timeout.connect(func(): Game.request("start"))
	if "--smoke" in args:
		var smoke = load("res://tests/smoke_runner.tscn").instantiate()
		add_child(smoke)
	if "--network-test" in args:
		var test = load("res://tests/network_runner.tscn").instantiate()
		add_child(test)
