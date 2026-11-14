class_name PlayerVisual
extends Node3D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var skeleton: Skeleton3D = $GeneralSkeleton

var current_color: Color = Color.WHITE
var _queued_throw: bool = false
var _is_throwing: bool = false
var _is_standing_up: bool = false
var _is_jumping: bool = false
var _materials_duplicated: bool = false
var _is_seated: bool = false

func _ready() -> void:
	_ensure_unique_materials()
	if anim_player:
		if not anim_player.animation_finished.is_connected(_on_animation_finished):
			anim_player.animation_finished.connect(_on_animation_finished)
		if anim_player.has_animation("idle"):
			anim_player.play("idle")

func _ensure_unique_materials() -> void:
	if _materials_duplicated:
		return
	_materials_duplicated = true
	for mi in find_children("*", "MeshInstance3D"):
		var mat: Material = mi.get_surface_override_material(0)
		if mat:
			mi.set_surface_override_material(0, mat.duplicate())

func set_color(new_color: Color) -> void:
	current_color = new_color
	_ensure_unique_materials()
	for mi in find_children("*", "MeshInstance3D"):
		var mat: StandardMaterial3D = mi.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			if mi.name == "head":
				mat.albedo_color = current_color.lightened(0.2)
			elif mi.name == "legs":
				mat.albedo_color = current_color.darkened(0.2)
			else:
				mat.albedo_color = current_color

func trigger_throw() -> void:
	if _is_seated or _is_standing_up:
		_queued_throw = true
		trigger_stand_up()
	else:
		if _is_throwing and anim_player.is_playing() and anim_player.current_animation == "throw":
			return
		_queued_throw = false
		_is_throwing = true
		_is_standing_up = false
		_is_jumping = false
		if anim_player and anim_player.has_animation("throw"):
			anim_player.speed_scale = 1.0
			anim_player.play("throw")

func trigger_stand_up() -> void:
	if _is_standing_up and anim_player.is_playing() and anim_player.current_animation == "stand_up":
		return
	_is_standing_up = true
	_is_throwing = false
	_is_jumping = false
	if anim_player and anim_player.has_animation("stand_up"):
		anim_player.speed_scale = 1.0
		anim_player.play("stand_up")

func trigger_jump() -> void:
	if _is_standing_up or _is_throwing or _is_seated:
		return
	if _is_jumping and anim_player.is_playing() and anim_player.current_animation == "jump":
		return
	_is_jumping = true
	if anim_player and anim_player.has_animation("jump"):
		anim_player.speed_scale = 1.0
		anim_player.play("jump")

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"stand_up":
		_is_standing_up = false
		if _queued_throw:
			_queued_throw = false
			_is_throwing = true
			if anim_player and anim_player.has_animation("throw"):
				anim_player.speed_scale = 1.0
				anim_player.play("throw")
	elif anim_name == &"throw":
		_is_throwing = false
	elif anim_name == &"jump":
		_is_jumping = false
		if anim_player:
			anim_player.speed_scale = 1.0
	elif anim_name == &"idle":
		if anim_player and anim_player.has_animation("idle"):
			anim_player.speed_scale = 1.0
			anim_player.play("idle")

func update_motion(is_on_floor: bool, velocity: Vector3, is_sprinting: bool, mode: String, delta: float) -> void:
	if not anim_player:
		return

	if mode in ["ragdoll", "dead"]:
		_queued_throw = false
		_is_throwing = false
		_is_standing_up = false
		_is_jumping = false
		_is_seated = false
		anim_player.speed_scale = 1.0
		return

	if mode == "seated":
		_is_seated = true
		if _is_standing_up:
			if anim_player.is_playing() and anim_player.current_animation == "stand_up":
				return
			_is_standing_up = false
			if _queued_throw:
				_queued_throw = false
				_is_throwing = true
				if anim_player.has_animation("throw"):
					anim_player.speed_scale = 1.0
					anim_player.play("throw")
					return
		if _is_throwing:
			if anim_player.is_playing() and anim_player.current_animation == "throw":
				return
			_is_throwing = false
		if anim_player.current_animation != "sit":
			anim_player.speed_scale = 1.0
			anim_player.play("sit")
		return

	_is_seated = false

	# If standing up animation is in progress: let it finish!
	if _is_standing_up:
		if anim_player.is_playing() and anim_player.current_animation == "stand_up":
			return
		_is_standing_up = false
		if _queued_throw:
			_queued_throw = false
			_is_throwing = true
			if anim_player.has_animation("throw"):
				anim_player.speed_scale = 1.0
				anim_player.play("throw")
				return

	# If throw animation is in progress: let it finish!
	if _is_throwing:
		if anim_player.is_playing() and anim_player.current_animation == "throw":
			return
		_is_throwing = false

	# If jump animation is in progress: let it finish!
	if _is_jumping:
		if anim_player.is_playing() and anim_player.current_animation == "jump":
			if not is_on_floor and velocity.y > 0.05:
				# Ascending: play up to 0.82 seconds and pause at apex
				if anim_player.current_animation_position >= 0.82:
					anim_player.speed_scale = 0.0
					anim_player.seek(0.82, true)
				else:
					anim_player.speed_scale = 1.0
			else:
				# Descending or landing: resume and play to completion
				if anim_player.current_animation_position < 0.82:
					anim_player.seek(0.82, true)
				anim_player.speed_scale = 1.0
			return
		_is_jumping = false
		anim_player.speed_scale = 1.0

	# If airborne and moving upwards or falling without jump active (e.g. falling off a ledge)
	if not is_on_floor:
		if velocity.y > 0.05:
			trigger_jump()
			return
		elif velocity.y < -2.5:
			trigger_jump()
			if anim_player.current_animation == "jump":
				anim_player.seek(0.82, true)
			return

	anim_player.speed_scale = 1.0

	# Grounded locomotion: walk / run / idle with hysteresis so it doesn't flicker/restart
	var h_speed: float = Vector2(velocity.x, velocity.z).length()
	var currently_moving: bool = anim_player.current_animation in ["walk", "run"]
	var is_moving: bool = h_speed > (0.15 if currently_moving else 0.3)
	if is_moving:
		if is_sprinting:
			if anim_player.current_animation != "run":
				anim_player.play("run")
		else:
			if anim_player.current_animation != "walk":
				anim_player.play("walk")
	else:
		if anim_player.current_animation != "idle" or not anim_player.is_playing():
			anim_player.play("idle")
