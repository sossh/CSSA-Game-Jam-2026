class_name ClassroomItem
extends RigidBody3D

const KID_VISUAL_SCENES: Array[PackedScene] = [
	preload("res://characters/kid_visual.tscn"),
	preload("res://characters/kid_visual_2.tscn"),
	preload("res://characters/kid_visual_3.tscn"),
	preload("res://characters/kid_visual_4.tscn")
]

var entity_id: String
@export var item_id: String = "apple"
var data: ItemData
var holder: int = 0
var thrower: String = ""
@export var kid: bool = false
@export var skin_variant: int = 0
@export var kid_seated_y_offset: float = 0.32
@export var kid_seated_x_offset: float = 0
@export var kid_seated_z_offset: float = -0.15
var default_visual_pos := Vector3(0, -0.8, 0)
var dead: bool = false
var home_seat: int = -1
var seated: bool = false
var noise_at: float = 0
var return_at: float = 0
var last_impact: float = -10
var old_velocity := Vector3.ZERO
var destination := Transform3D.IDENTITY
@onready var label: Label3D = $NameLabel
@onready var visual: Node3D = $Visual

func _ready() -> void:
	data = ItemDB.get_item(item_id)
	mass = Game.config.clone_mass if kid else data.mass
	freeze = not Game.is_host() or seated
	if kid:
		var kv: Node3D = get_node_or_null("KidVisual")
		if kv:
			default_visual_pos = kv.position
		if skin_variant == 0:
			skin_variant = randi_range(1, 4)
		set_skin_variant(skin_variant)
		if has_node("CloneVisual") and $CloneVisual.has_method("set_color"):
			$CloneVisual.set_color(Color(0.62, 0.65, 0.8) if not dead else Color(0.5, 0.3, 0.4))
		_update_kid_animation()
	label.text = display_name()
	noise_at = Game.elapsed + randf_range(25, 60)
	destination = global_transform

func display_name() -> String:
	if kid: return "Expired clone" if dead else "Clone student"
	return data.display_name if data else item_id

func _physics_process(delta: float) -> void:
	if kid:
		_update_kid_animation()
	if holder != 0:
		freeze = true
		collision_layer = 0
		collision_mask = 0
		if Game.world.player_nodes.has(holder):
			global_transform = Game.world.player_nodes[holder].held_transform(kid)
		return
	collision_layer = 8 if kid else 4
	collision_mask = 15
	if not Game.is_host():
		freeze = true
		global_transform = global_transform.interpolate_with(destination, minf(1, delta * 22))
		return
	freeze = seated
	old_velocity = linear_velocity
	if global_position.y < Game.config.fall_out_height:
		Game.world.remove_item(entity_id)
		return
	if not kid or dead: return
	if not seated and Game.elapsed >= return_at and linear_velocity.length() < Game.config.clone_return_max_speed:
		var seat: int = Game.world.free_seat(home_seat)
		if seat >= 0:
			home_seat = seat
			global_position = Game.world.seat_positions[seat] + Vector3(0, 0.8, 0)
			rotation = Vector3.ZERO
			seated = true
			freeze = true

func _impact(body: Node) -> void:
	if not Game.is_host() or holder != 0 or seated: return
	var speed := old_velocity.length()
	if speed < Game.config.interactions.minimum_impact_speed or Game.elapsed - last_impact < Game.config.interactions.impact_cooldown: return
	last_impact = Game.elapsed
	# Defer changes to bodies until the physics query has completed.
	resolve_impact.call_deferred(body, speed, old_velocity)

func resolve_impact(body: Node, speed: float, hit_velocity: Vector3) -> void:
	if not is_inside_tree() or not is_instance_valid(body): return
	var tuning := Game.config.interactions
	var base_loudness := tuning.clone_impact_loudness if kid else data.impact_noise
	var speed_scale := clampf(speed / tuning.impact_speed_reference, tuning.impact_loudness_scale.x, tuning.impact_loudness_scale.y)
	var loudness := minf(tuning.impact_loudness_cap, base_loudness * speed_scale)
	var sound := "splat" if data.effect == "tomato" and not kid else "impact"
	NoiseBus.emit_noise(global_position, loudness, thrower, sound)
	if thrower != "" and speed > 4 and Game.allowed(0, entity_id + ":impact_log", 1.5):
		var hit_name := "the classroom"
		if body is StudentPlayer: hit_name = Game.actor_name(str(body.peer_id))
		elif body is ClassroomTeacher: hit_name = "the teacher"
		elif body is ClassroomItem: hit_name = body.display_name()
		Game.log_activity("%s's %s hits %s." % [Game.actor_name(thrower), display_name(), hit_name])
	if body is StudentPlayer and str(body.peer_id) != thrower:
		var impulse := hit_velocity.normalized() * minf(tuning.impact_impulse_cap, speed * tuning.impact_impulse_scale) + Vector3.UP * tuning.impact_lift
		if not kid and data.effect == "tomato":
			Game.event.rpc("splat", {"id": body.peer_id})
			Game.event.rpc("burst", {"position": global_position, "color": Color.TOMATO})
			Game.world.remove_item(entity_id)
		elif speed > tuning.ragdoll_impact_speed: Game.launch_player(body.peer_id, impulse)
	elif body is ClassroomTeacher:
		body.provoked(thrower, global_position)
	if not kid and data.effect == "tomato" and is_inside_tree() and speed > tuning.tomato_splat_speed:
		Game.event.rpc("burst", {"position": global_position, "color": Color.TOMATO})
		Game.world.remove_item(entity_id)

func pickup(id: int) -> void:
	holder = id
	seated = false
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0

func release(at: Vector3, impulse: Vector3, source: String) -> void:
	holder = 0
	seated = false
	freeze = false
	collision_layer = 8 if kid else 4
	collision_mask = 15
	global_position = at
	linear_velocity = impulse
	angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
	thrower = source
	return_at = Game.elapsed + Game.config.clone_return_delay
	last_impact = Game.elapsed

func serialize() -> Dictionary:
	return {"item": item_id, "transform": global_transform, "holder": holder, "kid": kid,
		"dead": dead, "seated": seated, "home": home_seat, "skin": skin_variant}

func receive(state: Dictionary) -> void:
	destination = state.transform
	holder = state.holder
	dead = state.dead
	seated = state.seated
	if state.has("skin") and state.skin != skin_variant:
		set_skin_variant(state.skin)
	if kid:
		_update_kid_animation()

func set_skin_variant(variant: int) -> void:
	if not kid:
		return
	skin_variant = clampi(variant, 1, 4)
	var old_kv: Node3D = get_node_or_null("KidVisual")
	if old_kv and old_kv.get_meta("skin_variant", 1) == skin_variant:
		return
	var new_scene: PackedScene = KID_VISUAL_SCENES[skin_variant - 1]
	var new_kv: Node3D = new_scene.instantiate()
	new_kv.name = "KidVisual"
	new_kv.set_meta("skin_variant", skin_variant)
	if old_kv:
		new_kv.transform = old_kv.transform
		old_kv.name = "OldKidVisual"
		old_kv.queue_free()
	add_child(new_kv)
	default_visual_pos = new_kv.position
	_update_kid_animation()

func _update_kid_animation() -> void:
	if not kid:
		return
	var kv: Node3D = get_node_or_null("KidVisual")
	if not kv:
		return
	var anim_player: AnimationPlayer = kv.get_node_or_null("AnimationPlayer")
	if not anim_player:
		return

	var target_anim: String = "idle"
	if dead:
		target_anim = "death"
	elif seated:
		target_anim = "sit"
	else:
		target_anim = "idle"

	if target_anim == "sit":
		kv.position = default_visual_pos + Vector3(kid_seated_x_offset, kid_seated_y_offset, kid_seated_z_offset)
	else:
		kv.position = default_visual_pos

	if target_anim == "death":
		if anim_player.assigned_animation != "death":
			anim_player.play("death")
	elif anim_player.current_animation != target_anim:
		if target_anim == "sit" and anim_player.has_animation("sit"):
			var sit_anim: Animation = anim_player.get_animation("sit")
			if sit_anim and sit_anim.loop_mode != Animation.LOOP_LINEAR:
				sit_anim.loop_mode = Animation.LOOP_LINEAR
		elif target_anim == "idle" and anim_player.has_animation("idle"):
			var idle_anim: Animation = anim_player.get_animation("idle")
			if idle_anim and idle_anim.loop_mode != Animation.LOOP_LINEAR:
				idle_anim.loop_mode = Animation.LOOP_LINEAR
		anim_player.play(target_anim)
