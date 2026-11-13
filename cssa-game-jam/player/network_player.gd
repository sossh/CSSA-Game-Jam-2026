class_name StudentPlayer
extends CharacterBody3D

var peer_id: int
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var visual: StudentVisual = $Visual
@onready var name_label: Label3D = $NameLabel
@onready var ragdoll: StudentRagdoll = $Ragdoll
var color: Color
var local: bool = false
var applied_epoch: int = -1
var last_mode: String = ""
var pitch: float = 0.0
var send_timer: float = 0.0
var step_timer: float = 0.0
var charge: float = -1.0
var target_id: String = ""
var interaction_text: String = ""

func _ready() -> void:
	local = peer_id == multiplayer.get_unique_id()
	color = Color.from_hsv(fmod(peer_id * 0.173, 1.0), 0.55, 0.95)
	visual.set_color(color)
	visual.visible = not local
	camera.current = local
	name_label.text = str(Game.players[peer_id].name)
	name_label.visible = not local
	global_position = Game.players[peer_id].position

func _unhandled_input(event: InputEvent) -> void:
	if not local or Game.ui_open or not Game.players.has(peer_id): return
	var p: Dictionary = Game.players[peer_id]
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * 0.002
		pitch = clampf(pitch - event.relative.y * 0.002, -1.45, 1.45)
	if event.is_action_pressed("interact") and target_id != "": Game.request("interact", {"target": target_id})
	if event.is_action_pressed("use_item"): Game.request("use")
	if event.is_action_pressed("drop_item"): Game.request("drop")
	if event.is_action_pressed("fart"): Game.request("fart")
	if event.is_action_pressed("jump"):
		if p.mode == "seated": Game.request("stand")
		if p.mode == "carried": Game.request("wiggle")
	if event.is_action_pressed("throw_item"):
		if p.held == "": Game.request("punch")
		else: charge = 0
	if event.is_action_released("throw_item") and charge >= 0:
		Game.request("throw", {"charge": minf(charge, 1.0)})
		charge = -1

func _physics_process(delta: float) -> void:
	if not Game.players.has(peer_id): return
	var p: Dictionary = Game.players[peer_id]
	var mode: String = p.mode
	if applied_epoch != p.epoch:
		applied_epoch = p.epoch
		global_position = p.position
		velocity = Vector3.ZERO
		ragdoll.deactivate()
	if mode == "ragdoll" and not ragdoll.active:
		ragdoll.activate(color, p.position, p.yaw, local, p.launch)
	if mode != "ragdoll" and ragdoll.active:
		if local:
			global_position = ragdoll.bodies[0].global_position
			global_position.y = maxf(0.2, global_position.y)
		ragdoll.deactivate()
	visual.visible = not local and mode not in ["dead", "ragdoll"]
	name_label.visible = not local and mode != "dead"
	collision_layer = 0 if mode == "dead" else 2
	if mode == "carried" and Game.world.player_nodes.has(p.carrier):
		var carrier = Game.world.player_nodes[p.carrier]
		global_position = carrier.carry_position() - Vector3(0, 0.9, 0)
		if Game.is_host(): p.position = global_position
		visual.rotation.z = PI / 2
	elif mode == "seated":
		global_position = p.position
		visual.rotation.z = 0
	elif mode == "ragdoll":
		if local: global_position = ragdoll.bodies[0].global_position - Vector3(0, 0.9, 0)
		else:
			ragdoll.follow(p.limbs, delta)
			global_position = p.position
	elif local:
		visual.rotation.z = 0
		var input := Vector2.ZERO if Game.ui_open else Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var forward_basis := camera.global_basis if mode == "dead" else global_basis
		var direction := forward_basis * Vector3(input.x, 0, input.y)
		var speed := 4.0
		if Input.is_action_pressed("sprint"): speed = 6.5
		if p.speed_until > Game.elapsed: speed *= 1.8
		if mode == "dead":
			if not Game.ui_open: direction.y += float(Input.is_action_pressed("jump")) - float(Input.is_action_pressed("crouch"))
			global_position += direction * 8 * delta
		else:
			velocity.x = move_toward(velocity.x, direction.x * speed, 30 * delta)
			velocity.z = move_toward(velocity.z, direction.z * speed, 30 * delta)
			if not is_on_floor(): velocity.y -= 15 * delta
			if not Game.ui_open and Input.is_action_just_pressed("jump") and is_on_floor(): velocity.y = 5.0
			move_and_slide()
			step_timer -= delta
			if input.length() > 0.1 and is_on_floor() and step_timer <= 0:
				step_timer = 0.32 if speed > 4 else 0.5
				Game.request("step", {"sprint": speed > 4})
	else:
		global_position = global_position.lerp(p.position, minf(1, delta * 18))
	if not local:
		rotation.y = lerp_angle(rotation.y, p.yaw, minf(1, delta * 20))
		pitch = lerpf(pitch, p.pitch, minf(1, delta * 20))
	head.rotation.x = pitch
	head.position.y = 1.15 if mode == "seated" else 1.55
	if local:
		if charge >= 0: charge += delta
		if Game.ui_open: charge = -1
		find_target()
		send_timer += delta
		if send_timer >= 0.033:
			send_timer = 0
			var limbs: Array = ragdoll.poses() if ragdoll.active else []
			if Game.is_host(): Game.accept_pose(peer_id, global_position, rotation.y, pitch, limbs, applied_epoch)
			else: Game.pose.rpc_id(1, global_position, rotation.y, pitch, limbs, applied_epoch)
	last_mode = mode

func find_target() -> void:
	target_id = ""
	interaction_text = ""
	if Game.ui_open: return
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * 3.2, 31, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return
	var object = hit.collider
	if object is Interactable:
		target_id = object.interaction_id
		interaction_text = object.focus()
	elif object is ClassroomItem and object.holder == 0:
		target_id = object.entity_id
		interaction_text = "[E] Grab " + object.display_name()
	elif object is StudentPlayer and Game.players[object.peer_id].alive:
		target_id = "player:" + str(object.peer_id)
		interaction_text = "[E] Grab " + Game.players[object.peer_id].name

func carry_position() -> Vector3:
	return head.global_position - head.global_basis.z * 1.15 - Vector3(0, 0.45, 0)

func held_transform(big: bool = false) -> Transform3D:
	var transform_out := head.global_transform
	if big:
		transform_out.origin = carry_position()
		transform_out.basis = global_basis.rotated(global_basis.z, PI / 2)
		return transform_out

	var p: Dictionary = Game.players.get(peer_id, {})
	var eat_until: float = float(p.get("eat_until", 0.0))
	if eat_until > Game.elapsed:
		var time_left: float = eat_until - Game.elapsed
		var time_in: float = 1.5 - time_left
		var blend: float = clampf(time_in / 0.12, 0.0, 1.0) * clampf(time_left / 0.12, 0.0, 1.0)

		# Minecraft-style eating chomp & bobbing:
		var t := time_in * 24.0
		var chomp := absf(sin(t))
		var shake := sin(t * 1.5) * 0.012

		# Move from bottom-right (0.35, -0.3, -0.85) to center in front of mouth (0.08, -0.15, -0.48)
		var base_offset := Vector3(0.35, -0.3, -0.85)
		var eat_offset := Vector3(
			0.08 + shake,
			-0.15 - chomp * 0.035,
			-0.48 + chomp * 0.04
		)
		var final_offset: Vector3 = base_offset.lerp(eat_offset, blend)
		transform_out.origin = head.global_position + head.global_basis * final_offset

		# Tilt towards mouth with biting angle
		var tilt_x := deg_to_rad(-22.0 + chomp * 12.0) * blend
		var tilt_y := deg_to_rad(-20.0) * blend
		var tilt_z := deg_to_rad(12.0 + sin(t * 1.2) * 5.0) * blend
		transform_out.basis = transform_out.basis.rotated(head.global_basis.x, tilt_x)
		transform_out.basis = transform_out.basis.rotated(head.global_basis.y, tilt_y)
		transform_out.basis = transform_out.basis.rotated(head.global_basis.z, tilt_z)
		return transform_out

	transform_out.origin += head.global_basis * Vector3(0.35, -0.3, -0.85)
	return transform_out
