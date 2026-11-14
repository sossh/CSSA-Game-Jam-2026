class_name StudentRagdoll
extends Node3D

## Six physical bodies joined with PinJoint3D. The owning player simulates;
## peers render the transmitted limb transforms. No skeleton asset required.
const GRAVITY_LAYER := 32
# Torso takes the hit first while the head and limbs lag behind.
const IMPACT_RESPONSE := [1.15, 0.85, 0.65, 0.75, 0.45, 0.55]
const LIMB_SPIN := [
	Vector3(1.8, 0.3, 0.5),
	Vector3(-1.0, 0.5, -0.4),
	Vector3(-3.5, 1.0, -3.0),
	Vector3(-2.5, -0.8, 3.5),
	Vector3(2.8, -0.4, -0.8),
	Vector3(-1.8, 0.6, 1.0),
]

var bodies: Array[RigidBody3D] = []
var simulating: bool = false
var active: bool = false
var rest_poses: Array[Transform3D] = []

func _ready() -> void:
	for body: RigidBody3D in $Bodies.get_children():
		bodies.append(body)
		rest_poses.append(body.transform)
	deactivate()

func activate(color: Color, origin: Vector3, yaw: float, simulate: bool, impulse: Vector3) -> void:
	simulating = simulate
	active = true
	show()
	global_transform = Transform3D(Basis(Vector3.UP, yaw), origin)
	var impact_strength := clampf(impulse.length() / 10.0, 0.0, 1.5)
	for i in range(bodies.size()):
		var body := bodies[i]
		body.transform = rest_poses[i]
		var material: StandardMaterial3D = body.get_node("Mesh").material_override
		material.albedo_color = color.lightened(0.2) if i == 1 else color
		body.linear_velocity = impulse * IMPACT_RESPONSE[i] if simulate else Vector3.ZERO
		body.angular_velocity = global_basis * LIMB_SPIN[i] * impact_strength if simulate else Vector3.ZERO
		body.sleeping = false
		body.collision_layer = GRAVITY_LAYER if simulate else 0
		body.collision_mask = 1 if simulate else 0
		body.freeze = not simulate
	# Reset each joint's rest attachment after repositioning the pooled bodies.
	for joint: PinJoint3D in $Joints.get_children():
		var path_a := joint.node_a
		joint.node_a = NodePath()
		joint.node_a = path_a

func deactivate() -> void:
	active = false
	hide()
	for body in bodies:
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO

func poses() -> Array:
	var result: Array = []
	for body in bodies: result.append(body.global_transform)
	return result

func follow(poses_data: Array, delta: float) -> void:
	if poses_data.size() != bodies.size(): return
	for i in range(bodies.size()):
		if poses_data[i] is Transform3D:
			bodies[i].global_transform = bodies[i].global_transform.interpolate_with(poses_data[i], minf(1, delta * 20))
