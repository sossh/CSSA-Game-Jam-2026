class_name StudentRagdoll
extends Node3D

## Six physical bodies joined with PinJoint3D. The owning player simulates;
## peers render the transmitted limb transforms. No skeleton asset required.
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
	for i in range(bodies.size()):
		var body := bodies[i]
		body.transform = rest_poses[i]
		var material: StandardMaterial3D = body.get_node("Mesh").material_override
		material.albedo_color = color.lightened(0.2) if i == 1 else color
		body.linear_velocity = impulse
		body.angular_velocity = Vector3(2, 1, -3) if simulate else Vector3.ZERO
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
