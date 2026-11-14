class_name StudentPlayer
extends CharacterBody3D

var peer_id: int
var default_gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var audio_listener: AudioListener3D = $Head/Camera/AudioListener3D
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
var base_fov: float = 82.0
var bob_phase: float = 0.0
var bob_amount: float = 0.0
var strafe_roll: float = 0.0
var fov_boost: float = 0.0
var land_offset: float = 0.0
var land_velocity: float = 0.0
var kick_pitch: float = 0.0
var kick_velocity: float = 0.0
var fall_speed: float = 0.0
var was_on_floor: bool = true

func _ready() -> void:
	floor_snap_length = Game.config.player.floor_snap_length
	local = peer_id == multiplayer.get_unique_id()
	color = Color.from_hsv(fmod(peer_id * 0.173, 1.0), 0.55, 0.95)
	visual.set_color(color)
	visual.visible = not local
	camera.current = local
	base_fov = camera.fov
	if has_node("Head/Camera/ToonScreenPass"):
		$Head/Camera/ToonScreenPass.visible = local
	if local:
		audio_listener.make_current()
	name_label.text = str(Game.players[peer_id].name)
	name_label.visible = not local
	global_position = Game.players[peer_id].position

func _unhandled_input(event: InputEvent) -> void:
	if not local or Game.ui_open or not Game.players.has(peer_id): return
	var p: Dictionary = Game.players[peer_id]
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * Game.config.player.mouse_sensitivity
		var look := Game.config.player
		pitch = clampf(pitch - event.relative.y * look.mouse_sensitivity, -look.pitch_limit_radians, look.pitch_limit_radians)
	if event.is_action_pressed("interact"):
		if p.mode == "seated" and (target_id == "" or target_id == "seat:" + str(p.seat)):
			Game.request("stand")
		elif target_id != "":
			Game.request("interact", {"target": target_id})
	if event.is_action_pressed("use_item"): Game.request("use")
	if event.is_action_pressed("drop_item"): Game.request("drop")
	if event.is_action_pressed("fart"):
		if float(p.get("gas", 0.0)) > 0.0:
			Game.request("fart")
	if event.is_action_pressed("jump"):
		if p.mode == "seated": Game.request("stand")
		if p.mode == "carried": Game.request("wiggle")
	if event.is_action_pressed("throw_item"):
		if p.held == "": Game.request("punch")
		else: charge = 0
	if event.is_action_released("throw_item") and charge >= 0:
		Game.request("throw", {"charge": minf(charge / Game.config.player.throw_charge_seconds, 1.0)})
		charge = -1

func _physics_process(delta: float) -> void:
	if not Game.players.has(peer_id): return
	var p: Dictionary = Game.players[peer_id]
	var mode: String = p.mode
	if applied_epoch != p.epoch:
		applied_epoch = p.epoch
		global_position = p.position
		velocity = Vector3.ZERO
		if mode not in ["ragdoll", "dead"]:
			ragdoll.deactivate()
	if (mode == "ragdoll" or (mode == "dead" and p.launch.length() > 0)) and not ragdoll.active:
		ragdoll.activate(color, p.position, p.yaw, local, p.launch)
	if mode not in ["ragdoll", "dead"] and ragdoll.active:
		if local:
			global_position = ragdoll.bodies[0].global_position
			if ragdoll.bodies[0].get_gravity().length() >= default_gravity:
				global_position.y = maxf(0.2, global_position.y)
		ragdoll.deactivate()
	var my_id: int = multiplayer.get_unique_id()
	var local_is_dead: bool = Game.players.has(my_id) and Game.players[my_id].mode == "dead"
	var is_other_ghost: bool = not local and mode == "dead" and local_is_dead
	visual.visible = not local and (mode not in ["dead", "ragdoll"] or is_other_ghost)
	name_label.visible = not local and (mode != "dead" or is_other_ghost)
	if is_other_ghost:
		visual.set_color(Color(0.65, 0.85, 1.0))
		name_label.text = "👻 " + p.name
		name_label.modulate = Color(0.7, 0.9, 1.0, 0.85)
	elif not local and mode != "dead":
		visual.set_color(color)
		name_label.text = p.name
		name_label.modulate = Color.WHITE
	collision_layer = 0 if mode == "dead" else 2
	if mode == "carried" and Game.world.player_nodes.has(p.carrier):
		var carrier = Game.world.player_nodes[p.carrier]
		global_position = carrier.carry_position() - Vector3(0, 0.9, 0)
		if Game.is_host(): p.position = global_position
		visual.rotation = Vector3.ZERO
	elif mode == "seated":
		global_position = p.position
		visual.rotation = Vector3.ZERO
	elif mode == "ragdoll" and ragdoll.active:
		if local:
			global_position = ragdoll.bodies[0].global_position - Vector3(0, 0.9, 0)
		else:
			ragdoll.follow(p.limbs, delta)
			global_position = p.position
	elif not local and mode == "dead" and ragdoll.active:
		ragdoll.follow(p.limbs, delta)
		global_position = p.position
	elif local:
		visual.rotation = Vector3.ZERO
		var input := Vector2.ZERO if Game.ui_open else Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var forward_basis := camera.global_basis if mode == "dead" else global_basis
		var direction := forward_basis * Vector3(input.x, 0, input.y)
		var movement := Game.config.player
		var speed := movement.sprint_speed if Input.is_action_pressed("sprint") else movement.walk_speed
		if p.speed_until > Game.elapsed: speed *= movement.energy_speed_multiplier
		if mode == "dead":
			if not Game.ui_open: direction.y += float(Input.is_action_pressed("jump")) - float(Input.is_action_pressed("crouch"))
			global_position += direction * movement.spectate_speed * delta
		else:
			var gravity_ratio := get_gravity().length() / default_gravity
			var on_moon := gravity_ratio < 1.0
			var acceleration := movement.acceleration
			if on_moon:
				acceleration = movement.lunar_braking if input.is_zero_approx() else movement.lunar_acceleration
			velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
			velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
			var grounded := is_on_floor()
			var has_movement := input.length_squared() > 0.01
			step_timer -= delta
			var hop := false
			if not grounded:
				velocity.y -= movement.gravity * gravity_ratio * delta
			elif not Game.ui_open and Input.is_action_just_pressed("jump"):
				velocity.y = movement.lunar_jump_speed if on_moon else movement.jump_speed
			elif on_moon and has_movement and step_timer <= 0:
				velocity.y = movement.lunar_step_hop_speed
				hop = true
			move_and_slide()
			if has_movement and (hop or is_on_floor()) and step_timer <= 0:
				step_timer = movement.sprint_step_seconds if speed > movement.walk_speed else movement.walk_step_seconds
				Game.request("step", {"sprint": speed > movement.walk_speed, "position": global_position})
	else:
		visual.rotation = Vector3.ZERO
		global_position = global_position.lerp(p.position, minf(1, delta * 18))
	if not local:
		rotation.y = lerp_angle(rotation.y, p.yaw, minf(1, delta * 20))
		pitch = lerpf(pitch, p.pitch, minf(1, delta * 20))
	head.rotation.x = pitch
	head.position.y = 1.40 if mode == "seated" else 1.55
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

func update_camera_feel(delta: float, mode: String) -> void:
	# Purely cosmetic offsets on the Camera node (child of Head). Head, pitch and
	# replicated poses are untouched, so aim and networking are unaffected.
	var cfg := Game.config.player
	var walking: bool = cfg.camera_feel_enabled and mode not in ["ragdoll", "dead", "seated", "carried"]
	var on_floor := is_on_floor()
	var horizontal := Vector2(velocity.x, velocity.z).length()
	var intensity: float = cfg.camera_feel_intensity
	var smooth := 1.0 - exp(-cfg.camera_feel_smoothing * delta)
	var moving: bool = walking and on_floor and horizontal > 0.3
	# 0..1 for walk, up to ~1.6 at sprint speed
	var speed_ratio: float = clampf(horizontal / cfg.walk_speed, 0.0, 1.8) if moving else 0.0
	bob_amount = lerpf(bob_amount, speed_ratio, smooth)
	if moving:
		bob_phase = fmod(bob_phase + horizontal * cfg.bob_cycles_per_meter * TAU * delta, TAU * 1000.0)
	# Landing impact and jump kick via light damped springs
	if walking:
		if on_floor and not was_on_floor and fall_speed > 2.0:
			land_velocity -= clampf(fall_speed, 0.0, 14.0) * cfg.landing_dip * 4.0
			kick_velocity += clampf(fall_speed, 0.0, 14.0) * 3.0
		if was_on_floor and not on_floor and velocity.y > 1.0:
			kick_velocity -= cfg.jump_kick_degrees * 14.0
	fall_speed = maxf(0.0, -velocity.y) if not on_floor else 0.0
	was_on_floor = on_floor
	land_velocity += (-170.0 * land_offset - 18.0 * land_velocity) * delta
	land_offset += land_velocity * delta
	kick_velocity += (-170.0 * kick_pitch - 18.0 * kick_velocity) * delta
	kick_pitch += kick_velocity * delta
	var strafe_input := 0.0
	if walking and not Game.ui_open:
		strafe_input = Input.get_axis("move_left", "move_right")
	strafe_roll = lerpf(strafe_roll, strafe_input * clampf(bob_amount, 0.0, 1.5), smooth)
	var sprinting: bool = walking and on_floor and horizontal > cfg.walk_speed * 1.2
	fov_boost = lerpf(fov_boost, cfg.sprint_fov_boost if sprinting else 0.0, 1.0 - exp(-6.0 * delta))
	# Two bob cycles per step pair: vertical at 2x lateral frequency
	var vertical := -absf(sin(bob_phase * 0.5)) * cfg.bob_vertical * bob_amount
	var sway := sin(bob_phase * 0.5) * cfg.bob_horizontal * bob_amount
	var roll := sin(bob_phase * 0.5) * deg_to_rad(cfg.bob_roll_degrees) * bob_amount - strafe_roll * deg_to_rad(cfg.strafe_roll_degrees)
	camera.position = Vector3(sway, vertical + land_offset, 0.0) * intensity
	camera.rotation = Vector3(deg_to_rad(kick_pitch), 0.0, roll * intensity)
	camera.fov = base_fov + fov_boost

func find_target() -> void:
	target_id = ""
	interaction_text = ""
	if Game.ui_open or not Game.players.has(peer_id): return
	var p: Dictionary = Game.players[peer_id]
	var exclude: Array[RID] = [get_rid()]
	if p.mode == "seated" and is_instance_valid(Game.world) and Game.world.interactions.has("seat:" + str(p.seat)):
		exclude.append(Game.world.interactions["seat:" + str(p.seat)].get_rid())
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * Game.config.player.aim_reach, 31, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		if p.mode == "seated": interaction_text = "[E] Stand up"
		return
	var object = hit.collider
	if object is Interactable:
		target_id = object.interaction_id
		if p.mode == "seated" and target_id == "seat:" + str(p.seat):
			interaction_text = "[E] Stand up"
		else:
			interaction_text = object.focus()
	elif object is ClassroomItem and object.holder == 0:
		target_id = object.entity_id
		interaction_text = "[E] Grab " + object.display_name()
	elif object is StudentPlayer and Game.players[object.peer_id].alive:
		target_id = "player:" + str(object.peer_id)
		interaction_text = "[E] Grab " + Game.players[object.peer_id].name
	elif p.mode == "seated":
		interaction_text = "[E] Stand up"

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
		var time_in: float = Game.config.interactions.eat_seconds - time_left
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
