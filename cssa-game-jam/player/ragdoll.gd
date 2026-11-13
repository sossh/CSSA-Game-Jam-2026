class_name StudentRagdoll
extends Node3D

## Six physical bodies joined with PinJoint3D. The owning player simulates;
## peers render the transmitted limb transforms. No skeleton asset required.
var bodies: Array[RigidBody3D] = []
var simulating: bool = false

func build(color: Color, origin: Vector3, yaw: float, simulate: bool, impulse: Vector3) -> void:
	simulating = simulate
	var sizes := [Vector3(0.46, 0.6, 0.28), Vector3(0.34, 0.36, 0.32),
		Vector3(0.18, 0.6, 0.2), Vector3(0.18, 0.6, 0.2), Vector3(0.2, 0.65, 0.23), Vector3(0.2, 0.65, 0.23)]
	var offsets := [Vector3(0, 1.05, 0), Vector3(0, 1.57, 0), Vector3(-0.36, 1.02, 0),
		Vector3(0.36, 1.02, 0), Vector3(-0.15, 0.36, 0), Vector3(0.15, 0.36, 0)]
	var basis := Basis(Vector3.UP, yaw)
	for i in range(6):
		var body := RigidBody3D.new()
		body.name = "Limb%d" % i
		body.collision_layer = 0
		body.collision_mask = 1
		body.mass = 4.0 if i == 0 else 1.0
		body.freeze = not simulate
		body.continuous_cd = true
		body.angular_damp = 0.6
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = sizes[i]
		collider.shape = shape
		body.add_child(collider)
		Greybox.box(body, Vector3.ZERO, sizes[i], color.lightened(0.2) if i == 1 else color, false)
		add_child(body)
		body.global_transform = Transform3D(basis, origin + basis * offsets[i])
		body.linear_velocity = impulse
		body.angular_velocity = Vector3(2, 1, -3) if simulate else Vector3.ZERO
		bodies.append(body)
	var anchors := [Vector3(0, 1.38, 0), Vector3(-0.28, 1.25, 0), Vector3(0.28, 1.25, 0), Vector3(-0.15, 0.72, 0), Vector3(0.15, 0.72, 0)]
	for i in range(1, 6):
		var joint := PinJoint3D.new()
		add_child(joint)
		joint.global_position = origin + basis * anchors[i - 1]
		joint.node_a = joint.get_path_to(bodies[0])
		joint.node_b = joint.get_path_to(bodies[i])

func poses() -> Array:
	var result: Array = []
	for body in bodies: result.append(body.global_transform)
	return result

func follow(poses_data: Array, delta: float) -> void:
	if poses_data.size() != bodies.size(): return
	for i in range(bodies.size()):
		if poses_data[i] is Transform3D:
			bodies[i].global_transform = bodies[i].global_transform.interpolate_with(poses_data[i], minf(1, delta * 20))
