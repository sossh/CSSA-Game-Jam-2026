extends Node3D

var color: Color = Color(1, 0.75, 0.1)

func _ready() -> void:
	for particle: MeshInstance3D in get_children():
		var material: StandardMaterial3D = particle.material_override
		material.albedo_color = color
		var tween := create_tween().set_parallel(true)
		tween.tween_property(particle, "position", Vector3(randf_range(-1, 1), randf_range(0, 1.4), randf_range(-1, 1)), 0.4)
		tween.tween_property(particle, "scale", Vector3.ZERO, 0.4)
	get_tree().create_timer(0.45).timeout.connect(queue_free)
