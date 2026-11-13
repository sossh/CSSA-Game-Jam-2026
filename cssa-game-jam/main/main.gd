extends Node

func _ready() -> void:
	install_inputs()
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

func install_inputs() -> void:
	var keys := {"interact": KEY_E, "drop_item": KEY_Q, "fart": KEY_F,
		"sprint": KEY_SHIFT, "crouch": KEY_CTRL, "start_run": KEY_ENTER,
		"scoreboard": KEY_TAB, "debug_hud": KEY_F3}
	for action_name in keys:
		if not InputMap.has_action(action_name): InputMap.add_action(action_name)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action_name]
		InputMap.action_add_event(action_name, event)
	for action_name in ["throw_item", "use_item"]:
		if not InputMap.has_action(action_name): InputMap.add_action(action_name)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT if action_name == "throw_item" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action_name, event)

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
