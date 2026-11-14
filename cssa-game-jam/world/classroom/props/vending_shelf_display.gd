extends Node3D

const SLOT_SIZE := Vector3(0.19, 0.27, 0.32)

func _ready() -> void:
	for slot: Marker3D in get_children():
		var item_id: String = slot.get_meta("item_id")
		var item: ClassroomItem = ItemDB.get_item(item_id).scene.instantiate()
		var visual := item.get_node("Visual") as Node3D
		item.remove_child(visual)
		item.free()
		slot.add_child(visual)

		var bounds := AABB()
		var has_mesh := false
		for node in visual.find_children("*", "MeshInstance3D", true, false) + [visual]:
			if not node is MeshInstance3D or node.mesh == null or not node.is_visible_in_tree():
				continue
			var mesh_bounds: AABB = slot.global_transform.affine_inverse() * node.global_transform * node.get_aabb()
			bounds = bounds.merge(mesh_bounds) if has_mesh else mesh_bounds
			has_mesh = true
		if not has_mesh:
			continue
		var fit := SLOT_SIZE / bounds.size.max(Vector3.ONE * 0.001)
		var factor := minf(fit.x, minf(fit.y, fit.z))
		visual.scale *= factor
		visual.position = visual.position * factor - Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
