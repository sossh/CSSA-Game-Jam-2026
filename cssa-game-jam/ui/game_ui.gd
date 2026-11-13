extends CanvasLayer

@onready var menu: PanelContainer = %Menu
@onready var menu_status: Label = %MenuStatus
@onready var name_field: LineEdit = %NameField
@onready var code_field: LineEdit = %CodeField
@onready var address_field: LineEdit = %AddressField
@onready var lan_games: OptionButton = %LANGames
@onready var join_lan_button: Button = %JoinLAN
@onready var hud: Control = %HUD
@onready var stats: Label = %Stats
@onready var phase_label: Label = %PhaseLabel
@onready var prompt: Label = %Prompt
@onready var held_label: Label = %HeldLabel
@onready var banner: Label = %Banner
@onready var stomach: ProgressBar = %Stomach
@onready var charge: ProgressBar = %ThrowCharge
@onready var scoreboard: Label = %Scoreboard
@onready var debug: Label = %Debug
@onready var pause_panel: PanelContainer = %Pause
@onready var vending_panel: PanelContainer = %Vending
@onready var vending_rows: VBoxContainer = %VendingRows
@onready var keypad: LineEdit = %Keypad
@onready var vending_status: Label = %VendingStatus
@onready var tint: ColorRect = %DamageTint
@onready var crawl_panel: Control = %Crawl
@onready var crawl_text: Label = %CrawlText
var banner_left: float = 0
var debug_visible: bool = false

func _ready() -> void:
	stomach.max_value = Game.config.stomach_max
	Game.announcement.connect(show_banner)
	Game.effect.connect(on_effect)
	Net.status_changed.connect(func(message): menu_status.text = message)
	Net.lan_games_found.connect(show_lan_games)
	menu_status.text = get_tree().get_meta("disconnect_message", "Same LAN • 2–6 students • Host runs the classroom")
	get_tree().remove_meta("disconnect_message")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func host_pressed() -> void:
	var address := address_field.text.strip_edges()
	if address != "" and (not address.is_valid_ip_address() or ":" in address):
		menu_status.text = "Host address must be IPv4."
		return
	Net.host(name_field.text, address)

func join_pressed(_text: String = "") -> void:
	Net.join(name_field.text, code_field.text)

func find_lan_pressed() -> void:
	Net.find_lan_games()

func join_lan_pressed() -> void:
	if lan_games.selected >= 0:
		Net.join(name_field.text, lan_games.get_item_metadata(lan_games.selected))

func show_lan_games(games: Dictionary) -> void:
	lan_games.clear()
	for address in games:
		lan_games.add_item("%s (%s)" % [games[address], address])
		lan_games.set_item_metadata(lan_games.item_count - 1, address)
	var found := not games.is_empty()
	lan_games.visible = found
	join_lan_button.visible = found
	if found:
		lan_games.select(0)
		menu_status.text = "Choose a classroom and select Join LAN Game."
	else:
		menu_status.text = "No classrooms found. Check that the host is running, or enter their Wi-Fi IP."

func quit_pressed() -> void:
	get_tree().quit()

func resume_pressed() -> void:
	pause_panel.hide()
	update_mouse()

func copy_code_pressed() -> void:
	DisplayServer.clipboard_set(Net.join_code)

func quit_to_menu_pressed() -> void:
	Net.disconnect_session()

func close_vending() -> void:
	vending_panel.hide()
	update_mouse()

func dispense_pressed() -> void:
	buy_code(keypad.text)

func open_vending() -> void:
	var stock := ItemDB.stock()
	for entry in vending_rows.get_children():
		var index := stock.find(ItemDB.get_item(entry.item_id))
		entry.refresh(index + 1)
		vending_rows.move_child(entry, index)
	vending_panel.show()
	update_mouse()
	keypad.grab_focus()

func buy_code(code: String) -> void:
	var value := code.strip_edges().to_upper().trim_prefix("A")
	if not value.is_valid_int():
		vending_status.text = "Use a code such as A01."
		return
	var index := int(value) - 1
	var stock := ItemDB.stock()
	if index < 0 or index >= stock.size():
		vending_status.text = "Unknown item code."
		return
	Game.request("buy", {"item": stock[index].id})
	keypad.clear()

func connected() -> void:
	menu.hide()
	hud.show()
	if DisplayServer.get_name() != "headless" and not "--skip-intro" in OS.get_cmdline_user_args():
		crawl_panel.show()
	update_mouse()

func close_crawl() -> void:
	crawl_panel.hide()
	update_mouse()

func update_mouse() -> void:
	Game.ui_open = menu.visible or pause_panel.visible or vending_panel.visible or crawl_panel.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Game.ui_open else Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if crawl_panel.visible and (event.is_action_pressed("jump") or event.is_action_pressed("ui_cancel")):
		close_crawl()
		get_viewport().set_input_as_handled()
		return
	if not Net.active: return
	if event.is_action_pressed("ui_cancel"):
		if vending_panel.visible: vending_panel.hide()
		else: pause_panel.visible = not pause_panel.visible
		update_mouse()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("start_run") and not Game.ui_open: Game.request("start")
	if event.is_action_pressed("debug_hud"): debug_visible = not debug_visible

func _process(delta: float) -> void:
	banner_left -= delta
	banner.visible = banner_left > 0
	tint.color.a = maxf(0, tint.color.a - delta * 0.25)
	if crawl_panel.visible:
		crawl_text.position.y -= delta * 45
		if crawl_text.position.y < -1100: close_crawl()
	if not Net.active or not Game.players.has(multiplayer.get_unique_id()): return
	var id := multiplayer.get_unique_id()
	var p: Dictionary = Game.players[id]
	stats.text = "₿%d   •   STOMACH / HEALTH\n%s" % [p.money, p.name]
	stomach.value = p.stomach
	var minutes := int(ceil(Game.remaining)) / 60
	var seconds := int(ceil(Game.remaining)) % 60
	phase_label.text = "%s • GRADE %d • %02d:%02d\nJOIN %s • %d classes / %d parts" % [Game.phase.to_upper(), Game.grade, minutes, seconds, Net.join_code, Game.survived, Game.rocket_parts]
	if Game.phase in ["lobby", "game_over"]:
		phase_label.text += "\n[ENTER] Host: start new run" if Game.is_host() else "\nWaiting for host"
	var player = Game.world.player_nodes.get(id)
	if is_instance_valid(player):
		prompt.text = player.interaction_text if p.alive else "SPECTATING • Space / Ctrl fly • Re-clone at the bell"
		if p.mode == "carried": prompt.text = "[SPACE] Struggle! Three presses to escape."
		if p.mode == "seated" and player.interaction_text == "": prompt.text = "[SPACE] Stand • [RMB] Eat • [LMB] Throw"
		charge.visible = player.charge >= 0
		charge.value = player.charge
	held_label.text = "EMPTY HAND • [LMB] Punch • [E] Grab"
	if p.held.begins_with("player:"): held_label.text = "HOLDING YOUR FRIEND • Hold LMB to throw • Q drop"
	elif Game.world.items.has(p.held):
		var item = Game.world.items[p.held]
		held_label.text = item.display_name() + " • [RMB] Use / eat • Hold LMB to throw • Q drop"
	if p.eat_until > Game.elapsed: held_label.text = "CHOMP CHOMP CHOMP…"
	scoreboard.visible = Input.is_action_pressed("scoreboard")
	if scoreboard.visible:
		scoreboard.text = "CLASS REGISTER\n"
		for other in Game.players.values(): scoreboard.text += "%s   ₿%d   %s\n" % [other.name, other.money, "%d stomach" % other.stomach if other.alive else "DEAD"]
	debug.visible = debug_visible
	var teacher_state_name := "Unknown"
	if Game.world.teacher.fsm and Game.world.teacher.fsm.current_state:
		teacher_state_name = Game.world.teacher.fsm.current_state.display_name
	debug.text = "FPS %d | Teacher %s | Suspicion %.1f | Items %d" % [Engine.get_frames_per_second(), teacher_state_name, Game.world.teacher.suspicion, Game.world.items.size()]
	if vending_panel.visible:
		vending_status.text = "Balance: ₿%d • Grade %d • Purchases fall into the tray" % [p.money, Game.grade]
		if not p.alive or Game.phase == "class": close_vending()

func show_banner(text: String) -> void:
	banner.text = text
	banner_left = 5

func on_effect(kind: String, data: Dictionary) -> void:
	if kind == "vending" and data.id == multiplayer.get_unique_id(): open_vending()
	if kind in ["hurt", "splat"] and data.id == multiplayer.get_unique_id():
		tint.color.a = 0.65 if kind == "splat" else 0.35
