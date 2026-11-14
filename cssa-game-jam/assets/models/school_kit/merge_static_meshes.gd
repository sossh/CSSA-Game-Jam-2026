@tool
extends EditorScenePostImport

## Import-time optimisation for the static School Kit props.
## The source models split furniture into dozens of small meshes (books, drawer
## rails, fasteners), each costing a draw call per pass. Every kit model bakes
## its look into one albedo atlas, so this script merges all meshes into a
## single MeshInstance3D named "Mesh" with one surface per albedo texture (or
## per flat colour for untextured parts). It also switches the kit's
## nearest-neighbour samplers to smooth mipmapped filtering.
## Runs only in the editor importer; there is no runtime cost.

## Nodes whose names contain one of these are not imported.
## Faded_Writing: the chalkboard's baked "CLASS 03" chalk, which fights the lesson Label3D.
const SKIP_NODES: Array[String] = ["Faded_Writing"]

func _post_import(scene: Node) -> Object:
	var groups: Dictionary = {}
	var order: Array = []
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null or _skipped(instance, scene): continue
		var xform := _transform_to(scene, instance)
		for surface in instance.mesh.get_surface_count():
			var material := instance.get_active_material(surface)
			var key := _material_key(material)
			if not groups.has(key):
				groups[key] = {"material": material, "tool": SurfaceTool.new(), "best": -1}
				order.append(key)
			var group: Dictionary = groups[key]
			# The material covering the most vertices represents the merged surface.
			var vertex_count: int = instance.mesh.surface_get_array_len(surface)
			if vertex_count > group.best:
				group.best = vertex_count
				group.material = material
			group.tool.append_from(instance.mesh, surface, xform)
	if order.is_empty(): return scene
	var merged := ArrayMesh.new()
	for key in order:
		var group: Dictionary = groups[key]
		group.tool.commit(merged)
		merged.surface_set_material(merged.get_surface_count() - 1, _smooth(group.material))
	# The props are static: drop the split meshes, empties and drawer/door animations.
	for child in scene.get_children():
		scene.remove_child(child)
		child.free()
	var result := MeshInstance3D.new()
	result.name = "Mesh"
	result.mesh = merged
	scene.add_child(result)
	result.owner = scene
	return scene

func _skipped(node: Node, root: Node) -> bool:
	var current := node
	while current != null and current != root:
		for pattern in SKIP_NODES:
			if pattern in String(current.name): return true
		current = current.get_parent()
	return false

func _transform_to(root: Node, node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current: Node = node
	while current != root and current is Node3D:
		xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform

func _material_key(material: Material) -> String:
	var base := material as BaseMaterial3D
	if base == null: return "other:%d" % (material.get_instance_id() if material else 0)
	if base.albedo_texture:
		var texture_id := base.albedo_texture.resource_path
		if texture_id == "": texture_id = str(base.albedo_texture.get_instance_id())
		return "tex:%s|%d" % [texture_id, base.transparency]
	return "flat:%s|%.2f|%.2f|%d" % [base.albedo_color.to_html(), base.metallic, base.roughness, base.transparency]

func _smooth(material: Material) -> Material:
	var base := material as BaseMaterial3D
	if base: base.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material
