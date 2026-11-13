extends Node

signal status_changed(message: String)
signal joined
signal disconnected(message: String)

const PORT := 7777
var active: bool = false
var player_name: String = "Transfer student"
var join_code: String = ""
var addresses: Array[String] = []
var command_line_used: bool = false
var closing: bool = false

func _ready() -> void:
	multiplayer.connected_to_server.connect(func(): joined.emit())
	multiplayer.connection_failed.connect(func(): disconnect_session("Could not connect. Check the LAN code and UDP port 7777."))
	multiplayer.server_disconnected.connect(func(): disconnect_session("The host left the classroom."))
	multiplayer.peer_disconnected.connect(func(id):
		if active and multiplayer.is_server(): Game.remove_player(id))

func host(display_name: String, address: String = "") -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, Game.config.maximum_players - 1, 3)
	if error != OK:
		status_changed.emit("Cannot host: " + error_string(error))
		return error
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
	joined.emit()
	return OK

func join(display_name: String, code: String) -> Error:
	var address := decode_code(code)
	if address.is_empty():
		status_changed.emit("Enter eight hex digits (C0A8-012A), or a LAN IPv4 address.")
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, PORT, 3)
	if error != OK:
		status_changed.emit(error_string(error))
		return error
	player_name = clean_name(display_name)
	join_code = encode_ip(address)
	active = true
	multiplayer.multiplayer_peer = peer
	status_changed.emit("Connecting…")
	return OK

func disconnect_session(message: String = "") -> void:
	if closing: return
	closing = true
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
