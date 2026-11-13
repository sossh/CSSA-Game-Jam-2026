class_name Greybox
extends RefCounted

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.85
	return result

static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, solid: bool = true) -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	parent.add_child(root)
	root.position = at
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	root.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		collision.shape = box_shape
		root.add_child(collision)
	return root

static func label(parent: Node3D, text: String, at: Vector3, size: int = 32) -> Label3D:
	var result := Label3D.new()
	result.text = text
	result.position = at
	result.font_size = size
	result.outline_size = 5
	parent.add_child(result)
	return result

static func mannequin(parent: Node3D, color: Color) -> Node3D:
	var visual := Node3D.new()
	parent.add_child(visual)
	box(visual, Vector3(0, 1.0, 0), Vector3(0.48, 0.65, 0.28), color, false)
	box(visual, Vector3(0, 1.56, 0), Vector3(0.36, 0.38, 0.34), color.lightened(0.25), false)
	for x in [-1.0, 1.0]:
		box(visual, Vector3(x * 0.17, 0.35, 0), Vector3(0.21, 0.65, 0.25), color.darkened(0.25), false)
		box(visual, Vector3(x * 0.37, 1.0, 0), Vector3(0.18, 0.65, 0.22), color, false)
		box(visual, Vector3(x * 0.08, 1.6, -0.18), Vector3(0.06, 0.06, 0.02), Color.BLACK, false)
	return visual
