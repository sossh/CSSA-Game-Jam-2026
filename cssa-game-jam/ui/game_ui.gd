extends CanvasLayer

const CRAWL := "EPISODE I\nA NEW CURRICULUM\n\nIt is a period of intergalactic confusion. Having raided Earth, curious extraterrestrials have become obsessed with human culture, snacks, and questionable television broadcasts.\n\nTheir researchers cloned one human specimen. Fresh subjects now tumble down a cold metal chute into an orbiting academy. You are its latest transfer student.\n\nThe syllabus is simple: attend class, or be vaporized. Eat to survive. Spend your allowance. Build a starship, one suspicious purchase at a time.\n\nAnd whatever you do…\n\nDO NOT DISTURB THE TEACHER."
var root: Control
var menu: PanelContainer
var menu_status: Label
var name_field: LineEdit
var code_field: LineEdit
var address_field: LineEdit
var hud: Control
var stats: Label
var phase_label: Label
var prompt: Label
var held_label: Label
var banner: Label
var banner_left: float = 0
var stomach: ProgressBar
var charge: ProgressBar
var scoreboard: Label
var debug: Label
var pause_panel: PanelContainer
var vending_panel: PanelContainer
var vending_rows: VBoxContainer
var keypad: LineEdit
var vending_status: Label
var tint: ColorRect
var crawl_panel: Control
var crawl_text: Label
var crawl_y: float = 650
var debug_visible: bool = false
var crosshair: Label
var crawl_skip: Button

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 20
	root.theme = theme
	build_menu()
	build_hud()
	build_pause()
	build_vending()
	build_crawl()
	Game.announcement.connect(show_banner)
	Game.effect.connect(on_effect)
	Net.status_changed.connect(func(message): menu_status.text = message)
	menu_status.text = get_tree().get_meta("disconnect_message", "Same LAN • 2–6 students • Host runs the classroom")
	get_tree().remove_meta("disconnect_message")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func label(parent: Node, text: String, size: int = 20) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	parent.add_child(node)
	return node

func button(parent: Node, text: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 42
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func centered_panel(size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -size.x / 2
	panel.offset_right = size.x / 2
	panel.offset_top = -size.y / 2
	panel.offset_bottom = size.y / 2
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.09, 0.96)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	style.border_color = Color(0.3, 0.7, 0.8)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func build_menu() -> void:
	menu = centered_panel(Vector2(630, 570))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	menu.add_child(box)
	label(box, "COSMIC DETENTION", 42).modulate = Color(0.5, 0.95, 1)
	label(box, "Eat. Survive. Frame your friends.", 23)
	name_field = LineEdit.new()
	name_field.placeholder_text = "Student name"
	name_field.max_length = 20
	box.add_child(name_field)
	address_field = LineEdit.new()
	address_field.placeholder_text = "Host LAN IPv4 (optional; auto-detected otherwise)"
	box.add_child(address_field)
	button(box, "HOST CLASSROOM", func():
		var address := address_field.text.strip_edges()
		if address != "" and (not address.is_valid_ip_address() or ":" in address):
			menu_status.text = "Host address must be IPv4."
			return
		Net.host(name_field.text, address))
	var row := HBoxContainer.new()
	box.add_child(row)
	code_field = LineEdit.new()
	code_field.placeholder_text = "Join code, e.g. C0A8-012A"
	code_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(code_field)
	button(row, "JOIN", func(): Net.join(name_field.text, code_field.text))
	code_field.text_submitted.connect(func(_text): Net.join(name_field.text, code_field.text))
	menu_status = label(box, "", 16)
	menu_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(box, "WASD move • Mouse look • E grab / sit / interact\nLMB hold + release: throw • LMB empty: punch\nRMB eat / use • Q drop • Space jump / stand / escape\nShift sprint • G fart • Tab scoreboard • Esc menu", 17)
	button(box, "QUIT", get_tree().quit)

func build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	hud.visible = false
	stats = label(hud, "", 24)
	stats.position = Vector2(24, 18)
	stomach = ProgressBar.new()
	stomach.position = Vector2(24, 85)
	stomach.size = Vector2(270, 24)
	stomach.max_value = Game.config.stomach_max
	hud.add_child(stomach)
	phase_label = label(hud, "", 22)
	phase_label.size.x = 430
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	crosshair = label(hud, "+", 26)
	prompt = label(hud, "", 21)
	prompt.size.x = 660
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	held_label = label(hud, "", 20)
	charge = ProgressBar.new()
	charge.size = Vector2(300, 16)
	charge.max_value = 1
	charge.show_percentage = false
	hud.add_child(charge)
	banner = label(hud, "", 25)
	banner.size.x = 1040
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scoreboard = label(hud, "", 24)
	scoreboard.position = Vector2(32, 190)
	debug = label(hud, "", 16)
	debug.position = Vector2(24, 125)
	tint = ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(1, 0.05, 0, 0)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tint)

func build_pause() -> void:
	pause_panel = centered_panel(Vector2(480, 260))
	var box := VBoxContainer.new()
	pause_panel.add_child(box)
	label(box, "CLASS IS STILL RUNNING", 28)
	button(box, "RESUME", func(): pause_panel.hide(); update_mouse())
	button(box, "COPY JOIN CODE", func(): DisplayServer.clipboard_set(Net.join_code))
	button(box, "QUIT TO MAIN MENU", func(): Net.disconnect_session())
	pause_panel.hide()

func build_vending() -> void:
	vending_panel = centered_panel(Vector2(780, 640))
	var box := VBoxContainer.new()
	vending_panel.add_child(box)
	label(box, "COSMIC CRUNCH • KEYPAD", 30)
	vending_status = label(box, "Purchases drop into the tray. One hand. No inventory.", 17)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 390
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	vending_rows = VBoxContainer.new()
	vending_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vending_rows)
	keypad = LineEdit.new()
	keypad.placeholder_text = "Enter item code (e.g. A01), then Enter"
	box.add_child(keypad)
	keypad.text_submitted.connect(buy_code)
	button(box, "DISPENSE", func(): buy_code(keypad.text))
	button(box, "CLOSE [Esc]", func(): vending_panel.hide(); update_mouse())
	vending_panel.hide()

func open_vending() -> void:
	for child in vending_rows.get_children(): child.queue_free()
	var stock := ItemDB.stock()
	for i in range(stock.size()):
		var data: ItemData = stock[i]
		var locked := data.minimum_grade > Game.grade
		var text := "A%02d • ₿%d • %s" % [i + 1, data.price, data.display_name]
		if locked: text += " [GRADE %d]" % data.minimum_grade
		var entry := button(vending_rows, text, func(): Game.request("buy", {"item": data.id}))
		entry.disabled = locked
		entry.tooltip_text = data.description
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

func build_crawl() -> void:
	crawl_panel = Control.new()
	crawl_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(crawl_panel)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.005, 0.01, 0.025)
	crawl_panel.add_child(background)
	crawl_text = label(crawl_panel, CRAWL, 31)
	crawl_text.position = Vector2(270, 650)
	crawl_text.size.x = 740
	crawl_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	crawl_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crawl_text.modulate = Color(1, 0.85, 0.2)
	crawl_skip = button(crawl_panel, "SKIP INTRO [Space / Esc]", close_crawl)
	crawl_panel.hide()

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
	var viewport_size := root.size
	phase_label.position = Vector2(viewport_size.x - 470, 18)
	crosshair.position = viewport_size * 0.5 - Vector2(8, 16)
	prompt.position = viewport_size * 0.5 + Vector2(-330, 45)
	held_label.position = Vector2(24, viewport_size.y - 90)
	charge.position = Vector2(viewport_size.x * 0.5 - 150, viewport_size.y - 40)
	banner.size.x = minf(1040, viewport_size.x - 40)
	banner.position = Vector2((viewport_size.x - banner.size.x) * 0.5, 150)
	crawl_text.position.x = (viewport_size.x - crawl_text.size.x) * 0.5
	crawl_skip.position = Vector2((viewport_size.x - crawl_skip.size.x) * 0.5, viewport_size.y - 60)
	banner_left -= delta
	banner.visible = banner_left > 0
	tint.color.a = maxf(0, tint.color.a - delta * 0.25)
	if crawl_panel.visible:
		crawl_y -= delta * 45
		crawl_text.position.y = crawl_y
		if crawl_y < -1100: close_crawl()
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
	debug.text = "FPS %d | Teacher %s | Suspicion %.1f | Items %d" % [Engine.get_frames_per_second(), ClassroomTeacher.NAMES[Game.world.teacher.state], Game.world.teacher.suspicion, Game.world.items.size()]
	if vending_panel.visible:
		vending_status.text = "Balance: ₿%d • Grade %d • Purchases fall into the tray" % [p.money, Game.grade]
		if not p.alive or Game.phase == "class": vending_panel.hide(); update_mouse()

func show_banner(text: String) -> void:
	banner.text = text
	banner_left = 5

func on_effect(kind: String, data: Dictionary) -> void:
	if kind == "vending" and data.id == multiplayer.get_unique_id(): open_vending()
	if kind in ["hurt", "splat"] and data.id == multiplayer.get_unique_id():
		tint.color.a = 0.65 if kind == "splat" else 0.35
