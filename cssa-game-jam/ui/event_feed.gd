extends PanelContainer

@onready var content: VBoxContainer = $Content
@onready var entries: RichTextLabel = $Content/Entries
@onready var toggle_tip: Label = $ToggleTip

const BITCOIN_TAG := "[img=13x13]res://assets/ui/bitcoin.png[/img]"

var _expanded := true
var _expanded_offsets := Vector4.ZERO

func _ready() -> void:
	_expanded_offsets = Vector4(offset_left, offset_top, offset_right, offset_bottom)
	refresh("")
	Game.activity_added.connect(refresh)

func refresh(_line: String) -> void:
	# Escape '[' so player names cannot inject rich-text tags, then replace ₿ with icon.
	var lines := PackedStringArray()
	for line in Game.activity_history:
		lines.append(line.replace("[", "[lb]").replace("\u20bf", BITCOIN_TAG))
	entries.text = "\n".join(lines)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		_toggle_feed()
		get_viewport().set_input_as_handled()

func _toggle_feed() -> void:
	_expanded = not _expanded
	content.visible = _expanded
	self_modulate.a = 1.0 if _expanded else 0.0
	toggle_tip.text = "[H] Hide" if _expanded else "[H] Event Feed"
	if _expanded:
		offset_left = _expanded_offsets.x
		offset_top = _expanded_offsets.y
		offset_right = _expanded_offsets.z
		offset_bottom = _expanded_offsets.w
	else:
		var min_size := get_combined_minimum_size()
		offset_left = _expanded_offsets.z - min_size.x
		offset_top = _expanded_offsets.w - min_size.y
		offset_right = _expanded_offsets.z
		offset_bottom = _expanded_offsets.w
