class_name DisplayTeacherShoot
extends Node3D

const SHOT_SCENE := preload("res://effects/shot.tscn")
const BURST_SCENE := preload("res://effects/impact_burst.tscn")
const AIM_DURATION := 1.48
const TOTAL_DURATION := 2.73

enum ShootStage { IDLE, AIMING, SHOT, RECOVERING }
var current_state: ShootStage = ShootStage.IDLE

@export_group("Demonstration Settings")
@export var is_sitting: bool = true
@export var auto_loop: bool = false
@export var slow_motion: bool = false
@export var camera_index: int = 0

# Node References
@onready var teacher_visual: TeacherVisual = %TeacherVisual
@onready var player_visual: PlayerVisual = %PlayerVisual
@onready var student_origin: Node3D = %StudentOrigin
@onready var laser: MeshInstance3D = %AimLaser
@onready var muzzle_flash_light: OmniLight3D = %MuzzleFlashLight
@onready var shotgun_audio: AudioStreamPlayer = %ShotgunAudio
@onready var pump_audio: AudioStreamPlayer = %PumpAudio
@onready var effects_container: Node3D = %EffectsContainer

# Cameras
@onready var cinematic_camera: Camera3D = %CinematicCamera
@onready var teacher_camera: Camera3D = %TeacherCamera
@onready var student_camera: Camera3D = %StudentCamera
@onready var side_camera: Camera3D = %SideCamera
var cameras: Array[Camera3D] = []
var camera_names: Array[String] = [
	"1: Cinematic (3/4)",
	"2: Teacher Over-Shoulder",
	"3: Student POV",
	"4: Side Profile"
]
var camera_base_transforms: Dictionary = {}

# UI References
@onready var status_label: Label = %StatusLabel
@onready var camera_label: Label = %CameraLabel
@onready var shoot_button: Button = %ShootButton
@onready var resetButton: Button = %ResetButton
@onready var cam_button: Button = %CamButton
@onready var pose_button: Button = %PoseButton
@onready var speed_button: Button = %SpeedButton
@onready var auto_button: Button = %AutoButton

# Simulation state
var student_initial_pos := Vector3(0.0, 0.0, 1.8)
var student_pos := Vector3.ZERO
var student_velocity := Vector3.ZERO
var student_rot_x: float = 0.0
var is_flying: bool = false
var aim_timer: float = 0.0
var pumped_sound: bool = false
var recovery_timer: float = 0.0
var shake_amount: float = 0.0

func _ready() -> void:
	cameras = [cinematic_camera, teacher_camera, student_camera, side_camera]
	for cam in cameras:
		if cam:
			camera_base_transforms[cam] = cam.transform
	
	_connect_ui()
	_apply_camera(camera_index)
	_update_ui_buttons()
	reset_scene()

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _connect_ui() -> void:
	if shoot_button: shoot_button.pressed.connect(start_sequence)
	if resetButton: resetButton.pressed.connect(reset_scene)
	if cam_button: cam_button.pressed.connect(cycle_camera)
	if pose_button: pose_button.pressed.connect(toggle_pose)
	if speed_button: speed_button.pressed.connect(toggle_slowmo)
	if auto_button: auto_button.pressed.connect(toggle_auto)

func _update_ui_buttons() -> void:
	if camera_label:
		camera_label.text = "Camera: " + camera_names[camera_index]
	if pose_button:
		pose_button.text = "Pose: [Sitting]" if is_sitting else "Pose: [Standing]"
	if speed_button:
		speed_button.text = "Speed: [0.25x]" if slow_motion else "Speed: [1.0x]"
	if auto_button:
		auto_button.text = "Auto-Loop: [ON]" if auto_loop else "Auto-Loop: [OFF]"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
		if current_state == ShootStage.IDLE:
			start_sequence()
		else:
			reset_scene()
			start_sequence()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				reset_scene()
			KEY_C:
				cycle_camera()
			KEY_P:
				toggle_pose()
			KEY_T:
				toggle_slowmo()
			KEY_A:
				toggle_auto()
			KEY_1:
				_apply_camera(0)
			KEY_2:
				_apply_camera(1)
			KEY_3:
				_apply_camera(2)
			KEY_4:
				_apply_camera(3)

func start_sequence() -> void:
	if current_state == ShootStage.AIMING or current_state == ShootStage.SHOT:
		return
	
	current_state = ShootStage.AIMING
	aim_timer = 0.0
	pumped_sound = false
	recovery_timer = 0.0
	laser.visible = true
	_set_status("AIMING — Teacher aims shotgun at student...")

	# Trigger teacher shoot animation
	if teacher_visual and teacher_visual.animation_player:
		teacher_visual.set_gun_visible(true)
		teacher_visual.animation_player.play("shoot-animation")
		teacher_visual.animation_player.seek(0.0, true)

func _physics_process(delta: float) -> void:
	# Camera shake decay
	if shake_amount > 0.001:
		shake_amount = lerpf(shake_amount, 0.0, delta * 8.0)
		var current_cam = cameras[camera_index]
		if current_cam and camera_base_transforms.has(current_cam):
			var base_tr: Transform3D = camera_base_transforms[current_cam]
			var shake_offset := Vector3(
				randf_range(-shake_amount, shake_amount),
				randf_range(-shake_amount, shake_amount),
				randf_range(-shake_amount, shake_amount) * 0.5
			)
			current_cam.transform.origin = base_tr.origin + shake_offset
	else:
		var current_cam = cameras[camera_index]
		if current_cam and camera_base_transforms.has(current_cam):
			current_cam.transform = camera_base_transforms[current_cam]

	# Aiming state
	if current_state == ShootStage.AIMING:
		aim_timer += delta
		_update_laser()

		# Shotgun pump sound
		if aim_timer >= 0.28 and not pumped_sound:
			pumped_sound = true
			if pump_audio: pump_audio.play()

		# Teacher fires at 1.48s (peak of animation)
		if aim_timer >= AIM_DURATION:
			execute_shot()

	# Flight / knockback physics
	if is_flying:
		student_velocity.y -= 19.6 * delta
		student_pos += student_velocity * delta
		student_origin.global_position = student_pos

		# Rotate player backward onto their back
		student_rot_x = lerp_angle(student_rot_x, -PI * 0.5, delta * 9.0)
		if player_visual:
			player_visual.rotation.x = student_rot_x

		# Floor impact
		if student_pos.y <= 0.0:
			student_pos.y = 0.0
			student_origin.global_position = student_pos
			student_velocity.x = move_toward(student_velocity.x, 0.0, delta * 18.0)
			student_velocity.z = move_toward(student_velocity.z, 0.0, delta * 14.0)
			
			if absf(student_velocity.y) > 1.0:
				_spawn_burst(student_pos + Vector3(0, 0.2, 0), Vector3.UP)
			student_velocity.y = 0.0

			if student_velocity.length_squared() < 0.04:
				is_flying = false
				current_state = ShootStage.RECOVERING
				_set_status("EXPELLED — Student knocked flat by 12-gauge blast!")

	# Recovery / Auto-loop timer
	if current_state == ShootStage.RECOVERING:
		recovery_timer += delta
		if auto_loop and recovery_timer >= 2.2:
			reset_scene()
			start_sequence()

func _update_laser() -> void:
	if not laser.visible:
		return
	
	var muzzle_pos := _get_shotgun_muzzle()
	var chest_target := student_origin.global_position + Vector3(0, 0.75 if is_sitting else 0.95, 0)
	var dist := muzzle_pos.distance_to(chest_target)
	
	laser.global_position = (muzzle_pos + chest_target) * 0.5
	if dist > 0.05:
		laser.look_at(chest_target, Vector3.UP)
		laser.scale.z = dist

func _get_shotgun_muzzle() -> Vector3:
	if teacher_visual and teacher_visual.shotgun:
		# Approximate barrel tip offset in world space
		var gun := teacher_visual.shotgun
		return gun.global_position - gun.global_basis.z * 0.85 + gun.global_basis.y * 0.05
	return Vector3(0.13, 1.45, -3.0)

func execute_shot() -> void:
	current_state = ShootStage.SHOT
	laser.visible = false
	shake_amount = 0.25

	# Audio
	if shotgun_audio: shotgun_audio.play()

	# Muzzle flash light
	if muzzle_flash_light:
		muzzle_flash_light.visible = true
		var t := create_tween()
		t.tween_property(muzzle_flash_light, "light_energy", 0.0, 0.12).from(6.0)
		t.tween_callback(func(): muzzle_flash_light.visible = false)

	# Effects
	var muzzle_pos := _get_shotgun_muzzle()
	var chest_target := student_origin.global_position + Vector3(0, 0.85, 0)
	var shoot_dir := (chest_target - muzzle_pos).normalized()
	
	_spawn_shot(muzzle_pos, shoot_dir)
	_spawn_burst(chest_target, -shoot_dir)

	# Knockback student
	is_flying = true
	student_velocity = shoot_dir * 8.5 + Vector3.UP * 3.4
	_set_status("BANG! — Direct hit on student!")

func _spawn_shot(at: Vector3, dir: Vector3) -> void:
	if not SHOT_SCENE: return
	var flash: Node3D = SHOT_SCENE.instantiate()
	effects_container.add_child(flash)
	flash.global_position = at
	if dir.length_squared() > 0.01:
		var norm_dir := dir.normalized()
		var up := Vector3.UP if absf(norm_dir.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
		flash.look_at(at + norm_dir, up)

func _spawn_burst(at: Vector3, dir: Vector3) -> void:
	if not BURST_SCENE: return
	var burst: Node3D = BURST_SCENE.instantiate()
	effects_container.add_child(burst)
	burst.global_position = at
	if dir.length_squared() > 0.01:
		var norm_dir := dir.normalized()
		var up := Vector3.UP if absf(norm_dir.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
		burst.look_at(at + norm_dir, up)

func reset_scene() -> void:
	current_state = ShootStage.IDLE
	is_flying = false
	aim_timer = 0.0
	recovery_timer = 0.0
	pumped_sound = false
	shake_amount = 0.0
	laser.visible = false
	if muzzle_flash_light: muzzle_flash_light.visible = false

	# Clear temporary effects
	for child in effects_container.get_children():
		child.queue_free()

	# Reset teacher
	if teacher_visual and teacher_visual.animation_player:
		teacher_visual.animation_player.play("idle")
		teacher_visual.set_gun_visible(true)

	# Reset student
	student_pos = student_initial_pos
	student_velocity = Vector3.ZERO
	student_rot_x = 0.0
	student_origin.global_position = student_pos

	if player_visual:
		player_visual.rotation.x = 0.0
		if is_sitting:
			player_visual.position = Vector3(0.0, 0.32, -0.15)
			if player_visual.anim_player:
				player_visual.anim_player.play("sit")
		else:
			player_visual.position = Vector3.ZERO
			if player_visual.anim_player:
				player_visual.anim_player.play("idle")

	_set_status("READY — Press Shoot (Space / Enter) to fire!")
	_update_ui_buttons()

func cycle_camera() -> void:
	_apply_camera((camera_index + 1) % cameras.size())

func _apply_camera(idx: int) -> void:
	camera_index = idx
	for i in range(cameras.size()):
		if cameras[i]:
			cameras[i].current = (i == camera_index)
	_update_ui_buttons()

func toggle_pose() -> void:
	is_sitting = not is_sitting
	reset_scene()

func toggle_slowmo() -> void:
	slow_motion = not slow_motion
	Engine.time_scale = 0.25 if slow_motion else 1.0
	_update_ui_buttons()

func toggle_auto() -> void:
	auto_loop = not auto_loop
	_update_ui_buttons()

func _set_status(msg: String) -> void:
	if status_label:
		status_label.text = msg
