extends PanelContainer

@onready var entries: RichTextLabel = $Content/Entries

func _ready() -> void:
	entries.text = "\n".join(Game.activity_history)
	Game.activity_added.connect(refresh)

func refresh(_line: String) -> void:
	# Bounded history and plain text: player names cannot inject rich-text tags.
	entries.text = "\n".join(Game.activity_history)
