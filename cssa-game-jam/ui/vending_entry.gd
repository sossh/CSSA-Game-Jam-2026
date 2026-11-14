class_name VendingCard
extends Button

@onready var preview: SubViewport = $Thumbnail/Preview
@onready var camera: Camera3D = $Thumbnail/Preview/Camera
@onready var thumbnail: SubViewportContainer = $Thumbnail
@onready var footer: VBoxContainer = $Footer
@onready var name_label: Label = $Footer/NameLabel
@onready var bitcoin_icon: TextureRect = $Footer/PriceRow/BitcoinIcon
@onready var price_label: Label = $Footer/PriceRow/PriceLabel

var item_id: String
var price: int

func configure(data: ItemData, tall: bool) -> void:
	if tall:
		custom_minimum_size.y = 344.0
		thumbnail.offset_bottom = 268.0
		footer.offset_top = 272.0
		name_label.add_theme_font_size_override("font_size", 20)
		price_label.add_theme_font_size_override("font_size", 20)
		bitcoin_icon.custom_minimum_size = Vector2(20, 20)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style := get_theme_stylebox(state).duplicate() as StyleBox
			style.content_margin_top = 270.0
			add_theme_stylebox_override(state, style)
	item_id = data.id
	price = data.price
	text = ""
	name_label.text = data.display_name
	price_label.text = "%d" % price
	if DisplayServer.get_name() == "headless": return
	var item := data.scene.instantiate()
	var model := item.get_node("Visual") as Node3D
	item.remove_child(model)
	item.free()
	preview.add_child(model)
	var bounds := AABB()
	var has_mesh := false
	for node in model.find_children("*", "MeshInstance3D", true, false) + [model]:
		if not node is MeshInstance3D or node.mesh == null or not node.is_visible_in_tree(): continue
		var mesh_bounds: AABB = node.global_transform * node.get_aabb()
		bounds = bounds.merge(mesh_bounds) if has_mesh else mesh_bounds
		has_mesh = true
	if not has_mesh: return
	var center := bounds.get_center()
	var direction := Vector3(1.2, 0.8, 2).normalized()
	var diameter := bounds.size.length()
	camera.position = center + direction * maxf(diameter * 2.0, 0.5)
	camera.look_at(center)
	camera.size = maxf(diameter * 1.12, 0.1)
	preview.render_target_update_mode = SubViewport.UPDATE_ONCE

func update_affordability(balance: int, purchase_pending: bool) -> void:
	disabled = purchase_pending or balance < price
	thumbnail.modulate = Color(0.52, 0.54, 0.58, 0.62) if balance < price else Color.WHITE
	footer.modulate = Color(0.62, 0.65, 0.7, 0.85) if disabled else Color.WHITE
	mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
