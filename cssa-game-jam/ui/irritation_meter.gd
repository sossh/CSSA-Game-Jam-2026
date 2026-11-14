extends Control
## Teacher irritation-o-meter. Read-only view of the replicated irritation state on
## ClassroomTeacher; it never writes gameplay state. It only does work while class is
## running, and only touches text, shader and tween state when a value actually changes.

const TIERS: Array[Dictionary] = [
	{"at": 0.0, "name": "VIBING", "face": "(^_^)", "color": Color(0.35, 1.0, 0.72), "quip": "Teacher is enjoying the silence."},
	{"at": 0.15, "name": "MILDLY PEEVED", "face": "(-_-)", "color": Color(0.82, 1.0, 0.35), "quip": "A pen click. Somebody is pushing it."},
	{"at": 0.35, "name": "SIGHING AUDIBLY", "face": "(-_-;)", "color": Color(1.0, 0.86, 0.3), "quip": "Eyebrow raised. Clipboard noted."},
	{"at": 0.55, "name": "MARKER SQUEAK SOON", "face": ">:(", "color": Color(1.0, 0.58, 0.18), "quip": "The marker squeak is coming."},
	{"at": 0.75, "name": "COFFEE LEVEL CRISIS", "face": ">:O!", "color": Color(1.0, 0.32, 0.2), "quip": "Coffee is NOT going to fix this."},
	{"at": 0.92, "name": "NUCLEAR PTA MEETING", "face": "#@*!%", "color": Color(1.0, 0.3, 0.85), "quip": "Meltdown. Hide the snacks."},
]
const IDLE_ALPHA := 0.6

@onready var shaker: Control = %Shaker
@onready var frame: Panel = %Frame
@onready var face_panel: Panel = %FacePanel
@onready var face: Label = %Face
@onready var percent: Label = %Percent
@onready var tier_label: Label = %Tier
@onready var bar: ColorRect = %Bar
@onready var reason: Label = %Reason
@onready var din_bar: ProgressBar = %DinBar
@onready var steam_left: CPUParticles2D = %SteamLeft
@onready var steam_right: CPUParticles2D = %SteamRight

var shown: float = 0.0
var din_shown: float = 0.0
var kick: float = 0.0
var primed := false
var shaking := false
var popup_active := false
var last_seq: int = 0
var last_tier: int = -1
var last_percent: int = -1
var pop_tween: Tween
var reason_tween: Tween
var bar_material: ShaderMaterial

func _ready() -> void:
	modulate.a = 0.0
	bar_material = bar.material as ShaderMaterial
	_set_tier(0, false)

func _find_teacher() -> ClassroomTeacher:
	if not Net.active or not is_instance_valid(Game.world): return null
	return Game.world.get("teacher") as ClassroomTeacher

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	var teacher := _find_teacher()
	var wanted := 1.0 if teacher != null and Game.phase == "class" else 0.0
	if modulate.a != wanted:
		modulate.a = move_toward(modulate.a, wanted, delta * 3.0)
	if wanted == 0.0:
		if primed: _go_idle()
		return
	if not (Game.is_host() or teacher.snapshot_seen): return
	var maximum: float = Game.config.teacher.irritation_maximum
	var target := clampf(teacher.irritation / maximum, 0.0, 1.0)
	if not primed:
		# A late joiner or new class: adopt the current state silently, no stale popup.
		primed = true
		shown = target
		din_shown = teacher.din_fraction()
		last_seq = teacher.irritation_seq
		_apply_level()
		_apply_din()
	elif teacher.irritation_seq != last_seq:
		last_seq = teacher.irritation_seq
		_on_spike(teacher)
	var diff := target - shown
	if absf(diff) > 0.0004:
		shown += diff * (1.0 - exp(-delta * (10.0 if diff > 0.0 else 4.0)))
		_apply_level()
	var din_diff := teacher.din_fraction() - din_shown
	if absf(din_diff) > 0.004:
		din_shown += din_diff * (1.0 - exp(-delta * 6.0))
		_apply_din()
	_shake(delta)

func _go_idle() -> void:
	primed = false
	steam_left.emitting = false
	steam_right.emitting = false
	if shaking:
		shaking = false
		shaker.position = Vector2.ZERO
		shaker.rotation = 0.0
	kick = 0.0
	last_tier = -1

func _apply_level() -> void:
	bar_material.set_shader_parameter("level", shown)
	var percent_now := int(round(shown * 100.0))
	if percent_now != last_percent:
		last_percent = percent_now
		percent.text = "%d%%" % percent_now
	var tier := 0
	for i in TIERS.size():
		if shown >= float(TIERS[i].at): tier = i
	if tier != last_tier: _set_tier(tier, tier > last_tier and last_tier >= 0)

func _apply_din() -> void:
	din_bar.value = din_shown

func _set_tier(tier: int, rising: bool) -> void:
	var data := TIERS[tier]
	var color: Color = data.color
	last_tier = tier
	tier_label.text = data.name
	tier_label.add_theme_color_override("font_color", color)
	percent.add_theme_color_override("font_color", color)
	face.text = data.face
	face.add_theme_color_override("font_color", color)
	frame.self_modulate = Color.WHITE.lerp(color, 0.55)
	face_panel.self_modulate = Color.WHITE.lerp(color, 0.6)
	steam_left.emitting = tier >= 4
	steam_right.emitting = tier >= 4
	if not popup_active:
		reason.text = data.quip
		reason.modulate.a = IDLE_ALPHA
	if rising:
		_pop(face_panel, 1.35)
		var teacher := _find_teacher()
		if teacher != null and tier >= 3:
			Sfx.play_at("teacher_meltdown" if tier >= 5 else "teacher_irritated", teacher.global_position, 40.0)

func _on_spike(teacher: ClassroomTeacher) -> void:
	var code := teacher.irritation_reason
	var text: String = ClassroomTeacher.IRRITATION_REASONS[code] if code >= 0 and code < ClassroomTeacher.IRRITATION_REASONS.size() else ""
	var gain := teacher.irritation_gain
	if gain > 0:
		kick = clampf(0.4 + gain / 40.0, 0.4, 1.0)
		_pop(face_panel, 1.0 + kick * 0.4)
		_show_reason("+%d  %s" % [gain, text], TIERS[last_tier].color)
	elif text != "":
		_show_reason(text, Color(0.5, 1.0, 0.75))

func _show_reason(text: String, color: Color) -> void:
	popup_active = true
	reason.text = text
	reason.add_theme_color_override("font_color", color)
	reason.modulate.a = 1.0
	_pop(reason, 1.2)
	if reason_tween: reason_tween.kill()
	reason_tween = create_tween()
	reason_tween.tween_interval(1.8)
	reason_tween.tween_property(reason, "modulate:a", 0.0, 0.5)
	reason_tween.tween_callback(_end_popup)

func _end_popup() -> void:
	popup_active = false
	reason.text = TIERS[last_tier].quip
	reason.add_theme_color_override("font_color", TIERS[last_tier].color)
	reason.modulate.a = IDLE_ALPHA

func _pop(node: Control, from_scale: float) -> void:
	node.scale = Vector2.ONE * from_scale
	if pop_tween and pop_tween.is_valid() and node == face_panel: pop_tween.kill()
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if node == face_panel: pop_tween = tween

func _shake(delta: float) -> void:
	var heat := clampf((shown - 0.55) / 0.45, 0.0, 1.0)
	var amplitude := heat * 3.5 + kick * 6.0
	if kick > 0.0:
		kick = move_toward(kick, 0.0, delta * 2.5)
		bar_material.set_shader_parameter("flash", kick)
	if amplitude > 0.05:
		shaking = true
		shaker.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amplitude
		shaker.rotation = randf_range(-1.0, 1.0) * amplitude * 0.004
	elif shaking:
		shaking = false
		shaker.position = Vector2.ZERO
		shaker.rotation = 0.0
