extends Node3D

@export var earth: Node3D
@export var turn_climb := 77.0
@export var approach_distance := 195.0

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
@onready var rocket: Node3D = $Falcon9
@onready var pad_position := rocket.position
@onready var tower_clearance: Marker3D = $TowerClearance

var displayed_parts := PackedStringArray()
var displayed_launch := -1.0
# The animation advances from 0–1 during the vertical climb and 1–2 on the Earth approach.
@export_storage var flight_progress := 0.0:
	set(value):
		flight_progress = value
		if is_node_ready(): update_flight_pose()

func update_flight_pose() -> void:
	var clearance := tower_clearance.position
	if flight_progress <= 1.0 or not is_instance_valid(earth):
		rocket.position = pad_position.lerp(clearance, minf(flight_progress, 1.0))
		rocket.quaternion = Quaternion.IDENTITY
		rocket.scale = Vector3.ONE
		return

	var approach := flight_progress - 1.0
	var destination := to_local(earth.global_position)
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
	rocket.scale = Vector3.ONE * lerpf(1.0, 0.15, smoothstep(0.54, 0.95, approach))

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
			if DisplayServer.get_name() != "headless" and playhead < ignition.stream.get_length():
				ignition.play(playhead)
		else:
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
