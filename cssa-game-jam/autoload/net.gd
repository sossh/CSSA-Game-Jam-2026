extends Node

signal status_changed(message: String)
signal joined
signal disconnected(message: String)
signal lan_games_found(games: Dictionary)

const DISCOVERY_REQUEST := "cosmic-detention/find/1"
const DISCOVERY_RESPONSE := "cosmic-detention/host/1:"

var config: NetworkConfig = preload("res://config/network_config.tres")
var port: int = config.game_port
var active: bool = false
var player_name: String = "Transfer student"
var join_code: String = ""
var addresses: Array[String] = []
var command_line_used: bool = false
var closing: bool = false
var discovery_listener: PacketPeerUDP
var discovery_scan: PacketPeerUDP
var discovery_deadline: int
var next_discovery_probe: int
var discovered_games: Dictionary = {}

func _ready() -> void:
	multiplayer.connected_to_server.connect(func(): joined.emit())
	multiplayer.connection_failed.connect(func(): disconnect_session("Could not connect. Check the LAN code and UDP port %d." % port))
	multiplayer.server_disconnected.connect(func(): disconnect_session("The host left the classroom."))
	multiplayer.peer_disconnected.connect(func(id):
		if active and multiplayer.is_server(): Game.remove_player(id))

func host(display_name: String, address: String = "") -> Error:
	if active or closing: return ERR_BUSY
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, Game.config.maximum_players - 1, 3)
	if error != OK:
		status_changed.emit("Cannot host: " + error_string(error))
		return error
	stop_lan_scan()
	multiplayer.multiplayer_peer = peer
	active = true
	player_name = clean_name(display_name)
	addresses.clear()
	for ip in IP.get_local_addresses():
		if ip.is_valid_ip_address() and not ":" in ip and not ip.begins_with("127."):
			addresses.append(ip)
	var chosen := address
	if chosen.is_empty():
		chosen = addresses[0] if not addresses.is_empty() else "127.0.0.1"
	join_code = encode_ip(chosen)
	# Sessions on a custom gameplay port are joined directly, including integration tests.
	if port == config.game_port:
		discovery_listener = PacketPeerUDP.new()
		if discovery_listener.bind(config.discovery_port, "0.0.0.0") != OK:
			discovery_listener = null
			push_warning("Could not start LAN discovery. Direct joins are still available.")
	joined.emit()
	return OK

func join(display_name: String, code: String) -> Error:
	if active or closing: return ERR_BUSY
	var address := decode_code(code)
	if address.is_empty():
		status_changed.emit("Enter eight hex digits (C0A8-012A), or a LAN IPv4 address.")
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port, 3)
	if error != OK:
		status_changed.emit(error_string(error))
		return error
	stop_lan_scan()
	player_name = clean_name(display_name)
	join_code = encode_ip(address)
	active = true
	multiplayer.multiplayer_peer = peer
	status_changed.emit("Connecting…")
	return OK

func find_lan_games() -> void:
	if active or closing or discovery_scan != null: return
	if port != config.game_port:
		status_changed.emit("Enter the host's Wi-Fi IP or join code to join on a custom port.")
		return
	var socket := PacketPeerUDP.new()
	if socket.bind(0, "0.0.0.0") != OK:
		status_changed.emit("Could not start LAN search. Enter the host's Wi-Fi IP or join code.")
		return
	socket.set_broadcast_enabled(true)
	socket.set_dest_address("255.255.255.255", config.discovery_port)
	discovery_scan = socket
	discovered_games.clear()
	next_discovery_probe = Time.get_ticks_msec()
	discovery_deadline = next_discovery_probe + config.discovery_duration_ms
	status_changed.emit("Looking for classrooms on your local network…")

func _process(_delta: float) -> void:
	if discovery_listener != null:
		respond_to_discovery()
	if discovery_scan != null:
		poll_lan_scan()

func respond_to_discovery() -> void:
	for _packet in range(mini(discovery_listener.get_available_packet_count(), 32)):
		if discovery_listener.get_packet() != DISCOVERY_REQUEST.to_utf8_buffer(): continue
		var address := discovery_listener.get_packet_ip()
		var port := discovery_listener.get_packet_port()
		if discovery_listener.set_dest_address(address, port) == OK:
			discovery_listener.put_packet((DISCOVERY_RESPONSE + player_name).to_utf8_buffer())

func poll_lan_scan() -> void:
	for _packet in range(mini(discovery_scan.get_available_packet_count(), 32)):
		var packet := discovery_scan.get_packet()
		if discovery_scan.get_packet_port() != config.discovery_port or packet.size() > 128: continue
		var response := packet.get_string_from_utf8()
		if not response.begins_with(DISCOVERY_RESPONSE): continue
		# Use the sender's address instead of an address chosen on the host.
		discovered_games[discovery_scan.get_packet_ip()] = clean_name(response.trim_prefix(DISCOVERY_RESPONSE))
	var now := Time.get_ticks_msec()
	if now >= discovery_deadline:
		stop_lan_scan()
		lan_games_found.emit(discovered_games)
	elif now >= next_discovery_probe:
		discovery_scan.put_packet(DISCOVERY_REQUEST.to_utf8_buffer())
		next_discovery_probe = now + config.discovery_retry_ms

func stop_lan_scan() -> void:
	if discovery_scan == null: return
	discovery_scan.close()
	discovery_scan = null

func disconnect_session(message: String = "") -> void:
	if closing: return
	closing = true
	stop_lan_scan()
	if discovery_listener != null:
		discovery_listener.close()
		discovery_listener = null
	if active and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and not multiplayer.is_server():
		Game.leave_server.rpc_id(1)
		await get_tree().create_timer(0.15).timeout
	active = false
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	closing = false
	disconnected.emit(message)

static func clean_name(value: String) -> String:
	var result := value.strip_edges().replace("\n", " ").left(20)
	return "Transfer student" if result.is_empty() else result

static func encode_ip(ip: String) -> String:
	var pieces := ip.split(".")
	if pieces.size() != 4: return ""
	var result := ""
	for piece in pieces: result += "%02X" % int(piece)
	return result.left(4) + "-" + result.right(4)

static func decode_code(value: String) -> String:
	var text := value.strip_edges()
	if text == "localhost": return "127.0.0.1"
	if text.is_valid_ip_address() and not ":" in text: return text
	text = text.replace("-", "").replace(" ", "")
	if text.length() != 8: return ""
	for character in text.to_upper():
		if not character in "0123456789ABCDEF": return ""
	var parts := PackedStringArray()
	for i in range(4): parts.append(str(text.substr(i * 2, 2).hex_to_int()))
	return ".".join(parts)
