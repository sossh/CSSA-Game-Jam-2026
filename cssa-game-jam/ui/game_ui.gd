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
@onready var rocket_stage_1: Node2D = %RocketStage1
@onready var rocket_stage_2: Node2D = %RocketStage2
@onready var rocket_stage_3: Node2D = %RocketStage3
@onready var phase_label: Label = %PhaseLabel
@onready var prompt: Label = %Prompt
@onready var held_label: Label = %HeldLabel
@onready var banner: RichTextLabel = %Banner
@onready var stomach: ProgressBar = %Stomach
@onready var gas_bar: ProgressBar = %Gas
@onready var charge: ProgressBar = %ThrowCharge
@onready var scoreboard: RichTextLabel = %Scoreboard
@onready var debug: Label = %Debug
@onready var pause_panel: PanelContainer = %Pause
@onready var vending_panel: PanelContainer = %Vending
@onready var vending_grid_layout: VBoxContainer = %VendingGridLayout
@onready var vending_grid: GridContainer = %VendingGrid
@onready var vending_scroll: ScrollContainer = %VendingScroll
@onready var tint: ColorRect = %DamageTint
@onready var death_filter: ColorRect = %DeathFilter
@onready var wasted_container: CenterContainer = %WastedContainer
@onready var wasted_label: Label = %WastedLabel
@onready var crawl_panel: Control = %Crawl
@onready var crawl_text: Label = %CrawlText
var banner_left: float = 0
var debug_visible: bool = false
var wasted_timer: float = 0.0
var was_alive: bool = true

func _ready() -> void:
	stomach.max_value = Game.config.stomach_max
	gas_bar.max_value = Game.config.gas_capacity
	charge.max_value = Game.config.player.throw_charge_seconds
	Game.announcement.connect(show_banner)
	Game.effect.connect(on_effect)
	Net.status_changed.connect(func(message): menu_status.text = message)
	Net.lan_games_found.connect(show_lan_games)
	var lobby_status := "Same LAN • 2–%d students • Host runs the classroom" % Game.config.maximum_players
	menu_status.text = get_tree().get_meta("disconnect_message", lobby_status)
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

const VENDING_CARD := preload("res://ui/vending_entry.tscn")

var vending_machine_id := "vending"
var vending_sequence := 0
var pending_purchase := 0

func close_vending() -> void:
	pending_purchase = 0
	vending_panel.hide()
	update_mouse()

func open_vending(machine_id: String = "vending") -> void:
	vending_machine_id = machine_id
	pending_purchase = 0
	for card in vending_grid.get_children():
		vending_grid.remove_child(card)
		card.queue_free()
	var balance := int(Game.players.get(multiplayer.get_unique_id(), {}).get("money", 0))
	var stock := ItemDB.stock(machine_id)
	vending_grid.columns = clampi(stock.size(), 1, 4)
	var falcon := machine_id == ItemDB.ROCKET_VENDING
	vending_grid_layout.alignment = BoxContainer.ALIGNMENT_CENTER if falcon else BoxContainer.ALIGNMENT_BEGIN
	for data: ItemData in stock:
		var card := VENDING_CARD.instantiate() as VendingCard
		vending_grid.add_child(card)
		card.configure(data, falcon)
		card.pressed.connect(purchase_item.bind(data.id))
	vending_scroll.scroll_vertical = 0
	update_vending_affordability(balance)
	vending_panel.show()
	update_mouse()

func update_vending_affordability(balance: int) -> void:
	for card: VendingCard in vending_grid.get_children():
		card.update_affordability(balance, pending_purchase != 0)

func purchase_item(item_id: String) -> void:
	if not vending_panel.visible or pending_purchase != 0: return
	var player: Dictionary = Game.players.get(multiplayer.get_unique_id(), {})
	if player.is_empty() or not ItemDB.sells(item_id, vending_machine_id): return
	if player.money < ItemDB.get_item(item_id).price: return
	vending_sequence += 1
	pending_purchase = vending_sequence
	update_vending_affordability(player.money)
	Game.request("buy", {"item": item_id, "machine": vending_machine_id, "request_id": pending_purchase})

func connected() -> void:
	reset_wasted()
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
		if vending_panel.visible: close_vending()
		else: pause_panel.visible = not pause_panel.visible
		update_mouse()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("start_run") and not Game.ui_open: Game.request("start")
	if event.is_action_pressed("debug_hud"): debug_visible = not debug_visible

func _process(delta: float) -> void:
	banner_left -= delta
	banner.visible = banner_left > 0
	tint.color.a = maxf(0, tint.color.a - delta * Game.config.flash_fade_per_second)
	if wasted_timer > 0.0:
		wasted_timer -= delta
		if wasted_timer <= 0.0:
			wasted_container.visible = false
			if is_instance_valid(death_filter): death_filter.visible = false
		else:
			var alpha: float = clampf(wasted_timer / 1.0, 0.0, 1.0)
			wasted_container.modulate.a = alpha
			if is_instance_valid(death_filter): death_filter.modulate.a = alpha
	if crawl_panel.visible:
		crawl_text.position.y -= delta * 45
		if crawl_text.position.y < -1100: close_crawl()
	if not Net.active or not Game.players.has(multiplayer.get_unique_id()):
		if vending_panel.visible: close_vending()
		if is_instance_valid(death_filter): death_filter.visible = false
		if is_instance_valid(wasted_container): wasted_container.visible = false
		return
	var id := multiplayer.get_unique_id()
	var p: Dictionary = Game.players[id]
	var is_dead: bool = not p.alive or p.mode == "dead"
	if was_alive and is_dead:
		trigger_wasted()
	elif not was_alive and not is_dead:
		reset_wasted()
	was_alive = not is_dead
	stats.text = "%d" % p.money
	_update_rocket_stage(rocket_stage_1, Game.installed_rocket_parts.has("rocket"))
	_update_rocket_stage(rocket_stage_2, Game.installed_rocket_parts.has("rocket_second_stage"))
	_update_rocket_stage(rocket_stage_3, Game.installed_rocket_parts.has("rocket_fairing"))
	stomach.value = p.stomach
	var current_gas: float = float(p.get("gas", 0.0))
	gas_bar.value = current_gas
	var minutes := int(ceil(Game.remaining) / 60.0)
	var seconds := int(ceil(Game.remaining)) % 60
	phase_label.text = "STUDENT: %s\n%s • GRADE %d • %02d:%02d\nJOIN %s • %d classes / %d parts" % [p.name, Game.phase.to_upper(), Game.grade, minutes, seconds, Net.join_code, Game.survived, Game.rocket_parts]
	if Game.phase in ["lobby", "game_over"]:
		phase_label.text += "\n[ENTER] Host: start new run" if Game.is_host() else "\nWaiting for host"
	var player = Game.world.player_nodes.get(id)
	if is_instance_valid(player):
		prompt.text = player.interaction_text if p.alive else "SPECTATING • Space / Ctrl fly • Re-clone at the bell"
		if p.mode == "carried": prompt.text = "[SPACE] Struggle! Press %d times to escape." % Game.config.player.struggle_presses
		if p.mode == "seated":
			if player.interaction_text == "":
				prompt.text = "[E] Stand • [SPACE] Stand • [Right-click] Eat • [Left-click] Throw"
			elif player.target_id == "seat:" + str(p.seat):
				prompt.text = "[E] Stand up • [Right-click] Eat • [Left-click] Throw"
		elif p.alive and player.interaction_text == "" and Game.phase in ["break", "preparation"] and Game.remaining <= Game.config.warning_bell_seconds and Game.remaining > 0.0:
			prompt.text = "WARNING BELL! Get to your chair! [%02d]" % int(ceil(Game.remaining))
		charge.visible = player.charge >= 0
		charge.value = player.charge
		if charge.material is ShaderMaterial:
			charge.material.set_shader_parameter("progress", clampf(player.charge / maxf(0.001, charge.max_value), 0.0, 1.0))
	held_label.text = "EMPTY HAND • [Left-click] Punch • [E] Grab"
	if p.held.begins_with("player:"): held_label.text = "HOLDING YOUR FRIEND • Hold Left-click to throw • Q drop"
	elif Game.world.items.has(p.held):
		var item = Game.world.items[p.held]
		held_label.text = item.display_name() + " • [Right-click] Use / eat • Hold Left-click to throw • Q drop"
	if p.eat_until > Game.elapsed: held_label.text = "CHOMP CHOMP CHOMP…"
	scoreboard.visible = Input.is_action_pressed("scoreboard")
	if scoreboard.visible:
		scoreboard.text = "CLASS REGISTER\n"
		for other in Game.players.values():
			var safe_name := str(other.name).replace("[", "[lb]")
			scoreboard.text += "%s   [img=19x19]res://assets/ui/bitcoin.png[/img]%d   %s\n" % [safe_name, other.money, "%d stomach" % other.stomach if other.alive else "DEAD"]
	debug.visible = debug_visible
	var teacher_state_name := "Unknown"
	if Game.world.teacher.fsm and Game.world.teacher.fsm.current_state:
		teacher_state_name = Game.world.teacher.fsm.current_state.display_name
	debug.text = "FPS %d | Teacher %s | Suspicion %.1f | Items %d" % [Engine.get_frames_per_second(), teacher_state_name, Game.world.teacher.suspicion, Game.world.items.size()]
	if vending_panel.visible:
		update_vending_affordability(p.money)
		if not p.alive or Game.phase not in ["lobby", "preparation", "break"]: close_vending()

func trigger_wasted() -> void:
	wasted_timer = 1.6
	if is_instance_valid(wasted_container):
		wasted_container.visible = true
		wasted_container.modulate.a = 1.0
	if is_instance_valid(death_filter):
		death_filter.visible = true
		death_filter.modulate.a = 1.0

func reset_wasted() -> void:
	wasted_timer = 0.0
	if is_instance_valid(wasted_container):
		wasted_container.visible = false
	if is_instance_valid(death_filter):
		death_filter.visible = false

func _update_rocket_stage(stage: Node2D, installed: bool) -> void:
	var fill := stage.get_node("Fill") as Polygon2D
	var outline := stage.get_node("Outline") as Line2D
	fill.color = Color(0.18, 0.95, 1.0, 0.85) if installed else Color(0.01, 0.05, 0.1, 0.25)
	outline.default_color = Color(0.78, 1.0, 1.0, 1.0) if installed else Color(0.18, 0.92, 1.0, 0.45)

func show_banner(text: String) -> void:
	var formatted := text.replace("[", "[lb]").replace("\u20bf", "[img=16x16]res://assets/ui/bitcoin.png[/img]")
	banner.text = "[right]%s[/right]" % formatted
	banner_left = Game.config.banner_seconds

func on_effect(kind: String, data: Dictionary) -> void:
	if kind == "vending_result" and pending_purchase != 0 and data.id == multiplayer.get_unique_id() and data.request_id == pending_purchase:
		if data.purchased:
			close_vending()
		else:
			pending_purchase = 0
			update_vending_affordability(data.balance)
	if kind == "vending" and data.id == multiplayer.get_unique_id(): open_vending(data.get("machine", "vending"))
	if kind == "killed" and data.id == multiplayer.get_unique_id(): trigger_wasted()
	if kind in ["hurt", "splat"] and data.id == multiplayer.get_unique_id():
		tint.color.a = Game.config.splat_flash_alpha if kind == "splat" else Game.config.hurt_flash_alpha
