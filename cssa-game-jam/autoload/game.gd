extends Node

signal announcement(text: String)
signal state_changed
signal effect(kind: String, data: Dictionary)
signal activity_added(line: String)

const SNAPSHOT_INTERVAL := 0.0667
const SNAPSHOT_CHUNK_BYTES := 1000

var activity_history: PackedStringArray = []

var config: GameConfig = preload("res://config/game_config.tres")
var world: Node3D
var players: Dictionary = {}
var phase: String = "menu"
var remaining: float = 0.0
var grade: int = 1
var survived: int = 0
var rocket_parts: int = 0
var ui_open: bool = true
var elapsed: float = 0.0
var sync_time: float = 0.0
var epoch: int = 0
var cooldowns: Dictionary = {}
var snapshot_sequence: int = 0
var receiving_sequence: int = -1
var received_chunks: Dictionary = {}
var next_npc_noise_at: float = 0.0

func is_host() -> bool:
	return Net.active and multiplayer.is_server()

func reset() -> void:
	activity_history.clear()
	players.clear()
	phase = "menu"
	remaining = 0
	grade = 1
	survived = 0
	rocket_parts = 0
	cooldowns.clear()
	next_npc_noise_at = 0.0
	epoch = 0
	receiving_sequence = -1
	received_chunks.clear()
	ui_open = true

func _physics_process(delta: float) -> void:
	if not is_host() or not is_instance_valid(world): return
	elapsed += delta
	if phase in ["preparation", "class", "break"]:
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0:
			match phase:
				"preparation": start_class()
				"class": start_break()
				"break": start_preparation()
	for id in players.keys():
		var p: Dictionary = players[id]
		if not p.alive: continue
		if phase == "class":
			p.stomach = maxf(0, p.stomach - config.hunger_per_second * delta * (1.0 + (grade - 1) * config.hunger_per_grade))
			if p.stomach <= 0:
				kill(id, "starved during alien calculus")
				continue
			if p.stomach < config.growl_stomach_threshold and elapsed >= p.growl_at:
				p.growl_at = elapsed + randf_range(config.growl_interval.x, config.growl_interval.y)
				NoiseBus.emit_noise(p.position, config.growl_loudness, str(id), "stomach_growl")
		if p.mode == "ragdoll" and elapsed >= p.recover_at:
			p.mode = "walk"
			p.limbs = []
		if p.eat_until > 0 and elapsed >= p.eat_until:
			finish_eating(id)
		if p.get("gas", 0.0) >= config.gas_capacity and allowed(id, "auto_gas", config.auto_gas_cooldown):
			relieve_gas(id)
		if p.burp_at > 0 and elapsed >= p.burp_at:
			p.burp_at = 0.0
			NoiseBus.emit_noise(p.position, config.burp_loudness, str(id), "burp")
		if p.pop_until > elapsed and allowed(id, "pop", config.interactions.pop_rocks_interval):
			NoiseBus.emit_noise(p.position, config.interactions.pop_rocks_loudness, str(id), "pop_rocks")
		if p.position.y < config.fall_out_height:
			kill(id, "fell out of the curriculum")
	if is_host() and phase == "class" and next_npc_noise_at > 0.0 and elapsed >= next_npc_noise_at:
		next_npc_noise_at = elapsed + randf_range(config.npc_noise_interval.x, config.npc_noise_interval.y)
		trigger_npc_noise()
	sync_time += delta
	if sync_time >= SNAPSHOT_INTERVAL:
		sync_time = 0
		broadcast_snapshot()

func make_snapshot() -> Dictionary:
	return {"epoch": epoch, "players": players, "phase": phase, "remaining": remaining,
		"grade": grade, "survived": survived, "rocket_parts": rocket_parts, "elapsed": elapsed,
		"world": world.serialize()}

func broadcast_snapshot() -> void:
	# Full snapshots repair lost updates and make late joins simple. Compress and
	# split below the ENet MTU; never send a giant unreliable fragmented packet.
	var packed := var_to_bytes(make_snapshot()).compress(FileAccess.COMPRESSION_DEFLATE)
	snapshot_sequence += 1
	var count := ceili(float(packed.size()) / SNAPSHOT_CHUNK_BYTES)
	for index in range(count):
		snapshot_chunk.rpc(snapshot_sequence, index, count, packed.slice(index * SNAPSHOT_CHUNK_BYTES, (index + 1) * SNAPSHOT_CHUNK_BYTES))

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func snapshot_chunk(sequence: int, index: int, count: int, chunk: PackedByteArray) -> void:
	if sequence < receiving_sequence or count < 1 or count > 256 or index < 0 or index >= count: return
	if sequence > receiving_sequence:
		receiving_sequence = sequence
		received_chunks.clear()
	received_chunks[index] = chunk
	if received_chunks.size() != count: return
	var packed := PackedByteArray()
	for i in range(count): packed.append_array(received_chunks[i])
	var decoded = bytes_to_var(packed.decompress_dynamic(2 * 1024 * 1024, FileAccess.COMPRESSION_DEFLATE))
	if decoded is Dictionary: apply_snapshot(decoded)
	received_chunks.clear()

@rpc("authority", "call_remote", "reliable", 0)
func initial_state(data: Dictionary) -> void:
	apply_snapshot(data)
	activity_history = data.get("activity", PackedStringArray())
	activity_added.emit("")

func apply_snapshot(data: Dictionary) -> void:
	if not Net.active or not is_instance_valid(world): return
	if int(data.epoch) < epoch: return
	epoch = data.epoch
	players = data.players
	phase = data.phase
	remaining = data.remaining
	grade = data.grade
	survived = data.survived
	rocket_parts = data.rocket_parts
	elapsed = data.elapsed
	world.reconcile(data.world)
	state_changed.emit()

@rpc("any_peer", "call_remote", "reliable", 0)
func register(display_name: String) -> void:
	if not is_host(): return
	var id := multiplayer.get_remote_sender_id()
	if id == 0: id = 1
	if players.has(id) or players.size() >= config.maximum_players: return
	if phase == "menu": phase = "lobby"
	var alive := phase != "class"
	players[id] = {"name": Net.clean_name(display_name), "stomach": config.stomach_max,
		"money": config.starting_bitcoin, "food": 0.0, "alive": alive,
		"position": world.chute_position(players.size()), "yaw": 0.0, "pitch": 0.0,
		"mode": "walk" if alive else "dead", "seat": -1, "held": "", "carrier": 0,
		"eat_until": 0.0, "violation_until": 0.0, "speed_until": 0.0, "recover_at": 0.0,
		"burp_at": 0.0, "growl_at": elapsed + 15, "pop_until": 0.0, "gas": 0.0,
		"epoch": 0, "limbs": [], "launch": Vector3.ZERO}
	world.ensure_players()
	if id != 1:
		var initial := make_snapshot()
		initial["activity"] = activity_history
		initial_state.rpc_id(id, initial)
	event.rpc("banner", {"text": "%s fell down the transfer chute." % players[id].name})
	event.rpc("sound", {"position": players[id].position, "key": "chute", "loudness": 60.0})
	print("PLAYER_JOINED ", id, " ", players[id].name)

func remove_player(id: int) -> void:
	if not players.has(id): return
	world.release_hand(id)
	for other in players:
		if players[other].carrier == id: launch_player(other, Vector3.UP * 2)
	players.erase(id)
	world.ensure_players()
	check_wipe()

@rpc("any_peer", "call_remote", "reliable", 0)
func leave_server() -> void:
	if is_host(): remove_player(multiplayer.get_remote_sender_id())

func request(action_name: String, data: Dictionary = {}) -> void:
	if not Net.active: return
	if is_host(): handle_action(1, action_name, data)
	else: action.rpc_id(1, action_name, data)

@rpc("any_peer", "call_remote", "reliable", 0)
func action(action_name: String, data: Dictionary) -> void:
	if is_host(): handle_action(multiplayer.get_remote_sender_id(), action_name, data)

func handle_action(id: int, action_name: String, data: Dictionary) -> void:
	if not players.has(id): return
	if action_name == "start" and id == 1 and phase in ["lobby", "game_over"]:
		start_run()
		return
	var p: Dictionary = players[id]
	if not p.alive or phase == "game_over": return
	if action_name == "wiggle" and p.mode == "carried" and allowed(id, "wiggle", config.player.struggle_interval_seconds):
		p.recover_at += 1
		if p.recover_at >= config.player.struggle_presses:
			if players.has(p.carrier): players[p.carrier].held = ""
			launch_player(id, Vector3.UP * config.player.struggle_impulse)
		return
	if p.mode in ["carried", "ragdoll"]: return
	match action_name:
		"interact":
			if allowed(id, "interact", config.interactions.interact_cooldown): world.interact(id, str(data.get("target", "")))
		"throw", "drop":
			if p.eat_until <= elapsed and allowed(id, "throw", config.interactions.throw_cooldown):
				world.release_hand(id, clampf(float(data.get("charge", 0.0)), 0, 1) if action_name == "throw" else -1.0)
		"use":
			if p.eat_until <= elapsed and allowed(id, "use", config.interactions.use_cooldown): world.use_held(id)
		"punch":
			if p.held == "" and allowed(id, "punch", config.interactions.punch_cooldown): world.punch(id)
		"stand":
			if p.mode == "seated":
				p.position = world.seat_positions[p.seat] + Vector3(0.95, 0, 0)
				p.mode = "walk"
				p.seat = -1
				p.epoch += 1
		"fart":
			if allowed(id, "fart", config.interactions.fart_cooldown): relieve_gas(id)
		"step":
			if p.mode == "walk" and allowed(id, "step", config.interactions.step_cooldown):
				var step_pos: Vector3 = data.get("position", p.position)
				NoiseBus.emit_noise(step_pos, config.player.sprint_step_loudness if data.get("sprint", false) else config.player.walk_step_loudness, str(id), "footstep")
		"buy":
			if allowed(id, "buy", config.interactions.buy_cooldown): world.buy(id, str(data.get("item", "")), str(data.get("machine", "vending")))

func allowed(id: int, key: String, interval: float) -> bool:
	var token := str(id) + ":" + key
	if elapsed < float(cooldowns.get(token, 0.0)): return false
	cooldowns[token] = elapsed + interval
	return true

@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func pose(position: Vector3, yaw: float, pitch: float, limbs: Array, pose_epoch: int) -> void:
	if is_host(): accept_pose(multiplayer.get_remote_sender_id(), position, yaw, pitch, limbs, pose_epoch)

func accept_pose(id: int, position: Vector3, yaw: float, pitch: float, limbs: Array, pose_epoch: int) -> void:
	if not players.has(id) or not position.is_finite() or not is_finite(yaw) or not is_finite(pitch): return
	var p: Dictionary = players[id]
	if p.epoch != pose_epoch: return
	if p.mode in ["walk", "ragdoll", "dead"]: p.position = position
	p.yaw = yaw
	var pitch_limit := config.player.pitch_limit_radians + 0.05
	p.pitch = clampf(pitch, -pitch_limit, pitch_limit)
	if p.mode in ["ragdoll", "dead"] and limbs.size() == 6: p.limbs = limbs

func start_run() -> void:
	epoch += 1
	grade = 1
	survived = 0
	rocket_parts = 0
	world.clear_items()
	world.teacher.drugs = 0
	for id in players:
		players[id].money = config.starting_bitcoin
		respawn(id)
	start_preparation()

func start_preparation() -> void:
	phase = "preparation"
	remaining = config.preparation_seconds
	world.prepare_class()
	for id in players: players[id].food = 0.0
	event.rpc("banner", {"text": "GRADE %d • Drug the coffee. Find food. Take a seat." % grade})
	print("PHASE preparation grade=", grade)

func start_class() -> void:
	phase = "class"
	remaining = config.class_seconds
	next_npc_noise_at = elapsed + randf_range(config.npc_first_noise_delay.x, config.npc_first_noise_delay.y)
	world.teacher.start_class()
	event.rpc("sound", {"position": world.bell_origin.global_position, "key": "bell", "loudness": config.bell_volume})
	event.rpc("banner", {"text": "CLASS STARTED • Sit down. Eat quietly. Blame your friends."})
	for id in players:
		if players[id].alive and players[id].position.z > 8.0:
			kill(id, "was absent at roll call")
	print("PHASE class")

func start_break() -> void:
	if phase == "game_over": return
	survived += 1
	phase = "break"
	remaining = config.break_seconds
	next_npc_noise_at = 0.0
	world.teacher.leave()
	world.teacher.drugs = 0
	for id in players:
		var p: Dictionary = players[id]
		p.money += config.attendance_allowance + int(p.food * config.bitcoin_per_food)
		if not p.alive:
			p.money -= config.cloning_fee
			respawn(id)
	grade += 1
	event.rpc("sound", {"position": world.bell_origin.global_position, "key": "bell", "loudness": config.bell_volume})
	event.rpc("banner", {"text": "RECESS • Allowances paid. Clones cost ₿%d. Vending is open!" % config.cloning_fee})
	print("PHASE break survived=", survived)

func respawn(id: int) -> void:
	world.release_hand(id)
	var p: Dictionary = players[id]
	p.alive = true
	p.stomach = config.stomach_max
	p.mode = "walk"
	p.position = world.chute_position(players.keys().find(id))
	p.seat = -1
	p.carrier = 0
	p.eat_until = 0.0
	p.burp_at = 0.0
	p.pop_until = 0.0
	p.speed_until = 0.0
	p.violation_until = 0.0
	p.gas = 0.0
	p.limbs = []
	p.epoch += 1
	event.rpc("sound", {"position": p.position, "key": "clone", "loudness": config.clone_volume})

func damage(id: int, amount: float, reason: String, impulse: Vector3 = Vector3.ZERO) -> void:
	if not players.has(id) or not players[id].alive: return
	players[id].stomach = maxf(0, players[id].stomach - amount)
	event.rpc("hurt", {"id": id})
	if players[id].stomach <= 0: kill(id, reason, impulse)
	elif impulse.length() > 0 and reason != "was expelled by shotgun": launch_player(id, impulse)

func kill(id: int, reason: String, impulse: Vector3 = Vector3.ZERO) -> void:
	if not players[id].alive: return
	var p: Dictionary = players[id]
	world.release_hand(id)
	if p.carrier and players.has(p.carrier): players[p.carrier].held = ""
	p.alive = false
	p.mode = "dead"
	p.seat = -1
	p.carrier = 0
	p.eat_until = 0.0
	p.launch = impulse
	p.epoch += 1
	world.spawn_corpse(id, impulse)
	event.rpc("banner", {"text": "%s %s." % [p.name, reason]})
	check_wipe()

func check_wipe() -> void:
	if not phase in ["class", "preparation"]: return
	for p in players.values():
		if p.alive: return
	phase = "game_over"
	world.teacher.leave()
	event.rpc("banner", {"text": "CLASS DISMISSED FOREVER • %d classes • %d rocket parts" % [survived, rocket_parts]})
	print("PHASE game_over")

func launch_player(id: int, impulse: Vector3) -> void:
	if not players.has(id) or not players[id].alive: return
	world.release_hand(id)
	var p: Dictionary = players[id]
	if p.carrier and players.has(p.carrier): players[p.carrier].held = ""
	p.carrier = 0
	p.seat = -1
	p.mode = "ragdoll"
	p.launch = impulse
	p.recover_at = elapsed + config.player.ragdoll_seconds
	p.eat_until = 0.0
	p.limbs = []
	p.epoch += 1

func finish_eating(id: int) -> void:
	var p: Dictionary = players[id]
	p.eat_until = 0.0
	var item = world.items.get(p.held)
	if not is_instance_valid(item): return
	var data: ItemData = item.data
	p.stomach = minf(config.stomach_max, p.stomach + data.food)
	if phase == "class": p.food += data.food
	if data.effect == "speed": p.speed_until = elapsed + config.player.energy_boost_seconds
	if data.effect == "pop_rocks": p.pop_until = elapsed + config.interactions.pop_rocks_seconds
	if data.sound == "can_open" or data.effect == "speed":
		NoiseBus.emit_noise(p.position, config.interactions.can_crush_loudness, str(id), "crush_can")
	p.gas = clampf(float(p.get("gas", 0.0)) + data.food, 0.0, config.gas_capacity)
	p.held = ""
	world.remove_item(item.entity_id)
	log_activity("%s finished %s (+%d stomach)." % [p.name, data.display_name, int(data.food)])

func relieve_gas(id: int) -> void:
	if not players.has(id): return
	var p: Dictionary = players[id]
	if not p.alive: return
	var kind: String = "fart" if randf() < 0.5 else "burp"
	var loudness: float = config.burp_loudness if kind == "burp" else config.fart_loudness
	p.gas = maxf(0.0, float(p.get("gas", 0.0)) - randf_range(config.gas_relief.x, config.gas_relief.y))
	NoiseBus.emit_noise(p.position, loudness, str(id), kind)

func trigger_npc_noise() -> void:
	if not is_instance_valid(world): return
	var seated_kids: Array = []
	for item in world.items.values():
		if item.kid and not item.dead and item.seated:
			seated_kids.append(item)
	if seated_kids.is_empty(): return
	var kid = seated_kids.pick_random()
	var sound: String = ["chew", "crunch", "sneeze", "fart"].pick_random()
	NoiseBus.emit_noise(kid.global_position, randf_range(config.npc_noise_loudness.x, config.npc_noise_loudness.y), kid.entity_id, sound)

func actor_name(source: String) -> String:
	if source.is_valid_int() and players.has(int(source)): return players[int(source)].name
	if is_instance_valid(world) and world.items.has(source): return world.items[source].display_name()
	return "Something" if source.is_empty() else "A student"

func log_activity(text: String) -> void:
	if is_host(): event.rpc("activity", {"text": text, "time": elapsed})

func append_activity(text: String, time: float) -> void:
	var line := "[%02d:%02d] %s" % [int(time) / 60, int(time) % 60, text]
	activity_history.append(line)
	while activity_history.size() > config.activity_limit: activity_history.remove_at(0)
	activity_added.emit(line)

@rpc("authority", "call_local", "reliable", 0)
func event(kind: String, data: Dictionary) -> void:
	match kind:
		"banner":
			announcement.emit(str(data.text))
			append_activity(str(data.text), float(data.get("time", elapsed)))
		"activity": append_activity(str(data.text), float(data.get("time", elapsed)))
		"sound": Sfx.play_at(str(data.key), data.position, float(data.get("loudness", Sfx.config.default_playback_loudness)))
	effect.emit(kind, data)
