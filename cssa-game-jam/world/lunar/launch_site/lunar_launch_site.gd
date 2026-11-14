extends Node3D

@export var earth: Node3D
@export var turn_climb := 77.0
@export var approach_distance := 195.0
@export var earth_flyby_distance := 85.0

@onready var stage_models: Array[Node3D] = [$Falcon9/Booster, $Falcon9/UpperStage, $Falcon9/Fairing]
@onready var stage_colliders: Array[CollisionShape3D] = [
	$Falcon9/RocketBody/BoosterCollision,
	$Falcon9/RocketBody/UpperStageCollision,
	$Falcon9/RocketBody/FairingCollision,
]
@onready var status_label: Label3D = $LaunchConsole/Status
@onready var console: Interactable = $LaunchConsole/Interact
@onready var flight: AnimationPlayer = $Flight
@onready var ignition: AudioStreamPlayer3D = $IgnitionAudio
@onready var launch_camera: Camera3D = $LaunchCamera
@onready var launch_listener: AudioListener3D = $LaunchCamera/AudioListener3D
@onready var rocket: Node3D = $Falcon9
@onready var pad_position := rocket.position
@onready var tower_clearance: Marker3D = $TowerClearance

var displayed_parts := PackedStringArray()
var displayed_launch := -1.0
var flight_duration := 0.0
# The animation advances from 0–1 during the vertical climb and 1–2 on the Earth approach.
@export_storage var flight_progress := 0.0:
	set(value):
		flight_progress = value
		if is_node_ready(): update_flight_pose()

func _ready() -> void:
	flight_duration = flight.get_animation(&"launch").length

func _process(_delta: float) -> void:
	if displayed_launch >= 0.0:
		update_launch_camera(minf(flight.current_animation_position, flight_duration) if flight.is_playing() else flight_duration)

func update_launch_camera(playhead: float) -> void:
	var rocket_center := rocket.to_global(Vector3.UP * 31.0)
	var pad := to_global(pad_position)
	var pullback := smoothstep(0.0, 3.6, playhead)
	var wide_position := pad + Vector3(25, 12, 24).lerp(Vector3(54, 41, 50), pullback)
	wide_position.y += (rocket_center.y - pad.y - 14.0) * 0.8
	var camera_position := wide_position
	var aim := rocket_center.lerp(pad + Vector3.UP * 7.0, 0.25 * (1.0 - pullback))
	if is_instance_valid(earth):
		var flight_view := smoothstep(4.2, 7.5, playhead)
		var toward_earth := rocket_center.direction_to(earth.global_position)
		var side := toward_earth.cross(Vector3.UP).normalized()
		var chase_position := rocket_center - toward_earth * 56.0 + side * 23.0 + Vector3.UP * 13.0
		camera_position = camera_position.lerp(chase_position, flight_view)
		aim = aim.lerp(rocket_center.lerp(earth.global_position, 0.22), flight_view)
	launch_camera.global_position = camera_position
	launch_camera.look_at(aim)
	launch_camera.fov = lerpf(63.0, 48.0, smoothstep(4.2, 7.5, playhead))

func update_flight_pose() -> void:
	var clearance := tower_clearance.position
	if flight_progress <= 1.0 or not is_instance_valid(earth):
		rocket.position = pad_position.lerp(clearance, minf(flight_progress, 1.0))
		rocket.quaternion = Quaternion.IDENTITY
		rocket.scale = Vector3.ONE
		return

	var approach := flight_progress - 1.0
	var destination := to_local(earth.global_position.move_toward(to_global(clearance), earth_flyby_distance))
	var climb_step := Vector3.UP * turn_climb
	var turn_start := clearance + climb_step
	var turn_end := turn_start + climb_step * 0.5
	var approach_control := destination.move_toward(Vector3(clearance.x, destination.y, clearance.z), approach_distance)
	# Keep the first two control points vertical so the curve starts without a sudden change in pitch.
	var climb_curve := clearance.bezier_interpolate(turn_start, turn_end, approach_control, approach)
	var approach_curve := turn_start.bezier_interpolate(turn_end, approach_control, destination, approach)
	rocket.position = climb_curve.lerp(approach_curve, approach)
	var heading := climb_step.bezier_interpolate(turn_end - turn_start, approach_control - turn_end,
		destination - approach_control, approach)
	rocket.quaternion = Quaternion(Vector3.UP, heading.normalized())
	rocket.scale = Vector3.ONE * lerpf(1.0, 0.48, smoothstep(0.48, 1.0, approach))

func apply_assembly(parts: PackedStringArray, started_at: float, elapsed: float) -> void:
	if parts == displayed_parts and started_at == displayed_launch: return
	displayed_parts = parts.duplicate()
	var launched := started_at >= 0.0
	for index in range(ItemDB.FALCON_STOCK.size()):
		var installed := parts.has(ItemDB.FALCON_STOCK[index])
		stage_models[index].visible = installed
		stage_colliders[index].set_deferred("disabled", not installed or launched)

	if started_at != displayed_launch:
		displayed_launch = started_at
		if launched:
			flight.play(&"launch")
			# Peers that join during or after flight go directly to the current pose.
			var playhead := clampf(elapsed - started_at, 0.0, flight.current_animation_length)
			flight.seek(playhead, true)
			update_launch_camera(playhead)
			launch_camera.make_current()
			launch_listener.make_current()
			if DisplayServer.get_name() != "headless" and playhead < ignition.stream.get_length():
				ignition.play(playhead)
		else:
			launch_camera.clear_current(false)
			launch_listener.clear_current()
			ignition.stop()
			flight.play(&"RESET")
			flight.advance(0.0)
			flight.stop(true)

	if launched:
		console.prompt = "Falcon 9 launched"
		status_label.text = "FALCON 9\nLAUNCH CONFIRMED"
	elif parts.size() == ItemDB.FALCON_STOCK.size():
		console.prompt = "Launch Falcon 9 (empty hand)"
		status_label.text = "FALCON 9\nREADY FOR LAUNCH"
	else:
		console.prompt = "Install held rocket part"
		status_label.text = "FALCON 9 ASSEMBLY\n%d / %d INSTALLED" % [parts.size(), ItemDB.FALCON_STOCK.size()]
