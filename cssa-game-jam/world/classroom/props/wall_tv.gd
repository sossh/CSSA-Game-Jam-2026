extends Node3D
## Lobby blooper TV (easter egg). Purely cosmetic and local to each peer:
## it touches no gameplay state, RPCs, noise or physics.
##
## Media is read at runtime from a plain folder (default `tv_media/` beside the
## Godot project, or beside the exported executable), so people can drop files
## in without touching code or re-importing. Images: png/jpg/jpeg/webp/bmp/tga.
## Video: Ogg Theora (.ogv) only, which is all Godot can decode. The filename
## becomes the on-screen caption.
##
## Performance: nothing runs unless the local camera is inside the lobby volume
## and looking toward the TV. Otherwise video is paused, the screen is hidden,
## `_process` is off and only a 0.3 s timer ticks. Images decode on a worker
## thread and are downscaled, so a 12 MP phone photo never causes a hitch.

const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "bmp", "tga"]
const VIDEO_EXTENSIONS := ["ogv"]
const FADE_OUT_TIME := 0.22
const FADE_IN_TIME := 0.3
const EMPTY_RETRY_SECONDS := 2.0

enum State { SHOWING, LOADING, FADE_OUT, FADE_IN }

@export var media_folder_name := "tv_media"
@export_range(2.0, 60.0, 0.5) var image_seconds := 6.0
@export_range(3.0, 120.0, 0.5) var max_video_seconds := 30.0
@export_range(256, 2048, 64) var max_image_edge := 1280
## Camera must look at least this far toward the TV (dot product) to animate it.
@export_range(-1.0, 1.0, 0.05) var facing_dot_min := 0.2
## Muted by default so a blooper never covers the game's noise cues.
@export var video_volume_db := -80.0

@onready var _display: Node3D = %Display
@onready var _screen: MeshInstance3D = %Screen
@onready var _video: VideoStreamPlayer = %Video
@onready var _caption: Label3D = %Caption
@onready var _status: Label3D = %Status
@onready var _zone_shape: CollisionShape3D = %ZoneShape

var _material: ShaderMaterial
var _folder := ""
var _files: Array[String] = []
var _current_path := ""
var _state := State.SHOWING
var _active := false
var _has_content := false
var _showing_video := false
var _remaining := 0.0
var _fade := 0.0
var _last_aspect := 0.0

var _task_id := -1
var _task_image: Image = null
var _pending_path := ""
var _pending_texture: Texture2D = null
var _pending_video: VideoStreamTheora = null


func _ready() -> void:
	_material = _screen.material_override as ShaderMaterial
	_video.volume_db = video_volume_db
	_folder = _resolve_folder()
	_display.visible = false
	set_process(false)


func _exit_tree() -> void:
	if _task_id != -1:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1


func _on_proximity_timer_timeout() -> void:
	var should_run := _camera_sees_tv()
	if should_run != _active:
		_set_active(should_run)


func _on_video_finished() -> void:
	if _showing_video:
		_remaining = 0.0


func _set_active(value: bool) -> void:
	_active = value
	_display.visible = value
	set_process(value)
	if _showing_video:
		_video.paused = not value
	if value and _state == State.SHOWING and (not _has_content or _remaining <= 0.0):
		_advance()


func _camera_sees_tv() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var local_pos := _zone_shape.global_transform.affine_inverse() * cam.global_position
	var half := (_zone_shape.shape as BoxShape3D).size * 0.5
	if absf(local_pos.x) > half.x or absf(local_pos.y) > half.y or absf(local_pos.z) > half.z:
		return false
	var to_tv := (global_position - cam.global_position).normalized()
	return (-cam.global_basis.z).dot(to_tv) > facing_dot_min


func _process(delta: float) -> void:
	match _state:
		State.SHOWING:
			if _showing_video:
				_sync_video_aspect()
			_remaining -= delta
			if _remaining <= 0.0:
				_advance()
		State.LOADING:
			if _task_id != -1 and WorkerThreadPool.is_task_completed(_task_id):
				WorkerThreadPool.wait_for_task_completion(_task_id)
				_task_id = -1
				_finish_image_load()
		State.FADE_OUT:
			_fade = minf(_fade + delta / FADE_OUT_TIME, 1.0)
			_material.set_shader_parameter("static_amount", _fade)
			if _fade >= 1.0:
				_swap_in_pending()
				_state = State.FADE_IN
		State.FADE_IN:
			_fade = maxf(_fade - delta / FADE_IN_TIME, 0.0)
			_material.set_shader_parameter("static_amount", _fade * _fade)
			if _fade <= 0.0:
				_material.set_shader_parameter("static_amount", 0.0)
				_state = State.SHOWING


# ---- Folder / playlist ----------------------------------------------------

func _resolve_folder() -> String:
	var candidates: Array[String] = [ProjectSettings.globalize_path("res://" + media_folder_name)]
	var exe_dir := OS.get_executable_path().get_base_dir()
	candidates.append(exe_dir.path_join(media_folder_name))
	# macOS .app bundle: next to the .app, and inside Contents/Resources.
	candidates.append(exe_dir.path_join("../../../" + media_folder_name).simplify_path())
	candidates.append(exe_dir.path_join("../Resources/" + media_folder_name).simplify_path())
	for path in candidates:
		if DirAccess.dir_exists_absolute(path):
			return path
	return candidates[0]


func _scan() -> void:
	var found: Array[String] = []
	for file_name in DirAccess.get_files_at(_folder):
		var ext := file_name.get_extension().to_lower()
		if ext in IMAGE_EXTENSIONS or ext in VIDEO_EXTENSIONS:
			found.append(_folder.path_join(file_name))
	found.sort()
	_files = found


func _advance() -> void:
	_scan()
	if _files.is_empty():
		_show_no_signal()
		_remaining = EMPTY_RETRY_SECONDS
		return
	var next := (_files.find(_current_path) + 1) % _files.size()
	_pending_path = _files[next]
	_current_path = _pending_path
	_remaining = 0.5  # holds the old frame if this file turns out unreadable

	if _pending_path.get_extension().to_lower() in VIDEO_EXTENSIONS:
		_pending_video = VideoStreamTheora.new()
		_pending_video.file = _pending_path
		_pending_texture = null
		_begin_fade()
	else:
		_pending_video = null
		_task_image = null
		_task_id = WorkerThreadPool.add_task(_decode_image.bind(_pending_path, max_image_edge))
		_state = State.LOADING


## Runs on a worker thread: file IO, decode and downscale only.
func _decode_image(path: String, max_edge: int) -> void:
	var img := Image.load_from_file(path)
	if img != null and not img.is_empty():
		var biggest := maxi(img.get_width(), img.get_height())
		if biggest > max_edge:
			var s := float(max_edge) / float(biggest)
			img.resize(maxi(1, int(img.get_width() * s)), maxi(1, int(img.get_height() * s)), Image.INTERPOLATE_BILINEAR)
		_task_image = img


func _finish_image_load() -> void:
	if _task_image == null:
		_state = State.SHOWING  # unreadable file: _remaining is short, so we skip it
		return
	_pending_texture = ImageTexture.create_from_image(_task_image)
	_task_image = null
	_begin_fade()


func _begin_fade() -> void:
	# Straight to the swap when nothing is on screen yet, so first load is instant.
	if _has_content:
		_fade = 0.0
		_state = State.FADE_OUT
	else:
		_fade = 1.0
		_swap_in_pending()
		_state = State.FADE_IN


func _swap_in_pending() -> void:
	var texture: Texture2D = null
	if _pending_video != null:
		_video.stream = _pending_video
		_video.play()
		_video.paused = not _active
		texture = _video.get_video_texture()
		_showing_video = texture != null
		_remaining = max_video_seconds
	else:
		_video.stop()
		_showing_video = false
		texture = _pending_texture
		_remaining = image_seconds
	_pending_video = null
	_pending_texture = null
	if texture == null:
		_remaining = 0.5
		return
	_material.set_shader_parameter("media", texture)
	_material.set_shader_parameter("has_media", 1.0)
	_set_aspect(texture.get_size())
	_caption.text = _caption_for(_current_path)
	_caption.visible = true
	_status.visible = false
	_has_content = true


func _show_no_signal() -> void:
	_video.stop()
	_showing_video = false
	_has_content = false
	_state = State.SHOWING
	_material.set_shader_parameter("has_media", 0.0)
	_material.set_shader_parameter("static_amount", 0.14)
	_caption.visible = false
	_status.visible = true


# ---- Helpers --------------------------------------------------------------

func _sync_video_aspect() -> void:
	var texture := _video.get_video_texture()
	if texture != null:
		_set_aspect(texture.get_size())


func _set_aspect(size: Vector2) -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	var aspect := size.x / size.y
	if not is_equal_approx(aspect, _last_aspect):
		_last_aspect = aspect
		_material.set_shader_parameter("media_aspect", aspect)


func _caption_for(path: String) -> String:
	var text := path.get_file().get_basename()
	var lead := RegEx.create_from_string("^[0-9\\s_\\-.]+")
	text = lead.sub(text, "")
	return text.replace("_", " ").replace("-", " ").strip_edges().to_upper()
