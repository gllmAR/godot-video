extends Control
## Test chamber for Godot Video (GAV) addon
## Allows browsing and playing test videos to validate hardware acceleration

@onready var file_tree: Tree = $VBoxContainer/HSplitContainer/FilePanel/FileTree
@onready var aspect_container: AspectRatioContainer = $VBoxContainer/HSplitContainer/VideoPanel/AspectContainer
@onready var video_player: VideoStreamPlayer = $VBoxContainer/HSplitContainer/VideoPanel/AspectContainer/VideoPlayer
@onready var info_label: RichTextLabel = $VBoxContainer/HSplitContainer/VideoPanel/InfoPanel/InfoLabel
@onready var controls_panel: HBoxContainer = $VBoxContainer/ControlsPanel
@onready var play_button: Button = $VBoxContainer/ControlsPanel/PlayButton
@onready var pause_button: Button = $VBoxContainer/ControlsPanel/PauseButton
@onready var stop_button: Button = $VBoxContainer/ControlsPanel/StopButton
@onready var progress_slider: HSlider = $VBoxContainer/ControlsPanel/ProgressSlider
@onready var time_label: Label = $VBoxContainer/ControlsPanel/TimeLabel
@onready var hw_accel_check: CheckButton = $VBoxContainer/TopPanel/HWAccelCheck
@onready var loop_check: CheckButton = $VBoxContainer/TopPanel/LoopCheck
@onready var status_label: Label = $VBoxContainer/TopPanel/StatusLabel

const TEST_MEDIA_DIR = "res://test_media"
const DEMO_MEDIA_DIR = "res://"

enum PlaybackState {
	STOPPED,     # No video loaded or playback stopped
	PLAYING,     # Video is actively playing
	PAUSED       # Video is paused
}

var current_file: String = ""
var test_media_files: Array[Dictionary] = []
var is_seeking: bool = false
var playback_state: PlaybackState = PlaybackState.STOPPED

func _ready() -> void:
	setup_ui()
	scan_test_media()
	populate_file_tree()
	connect_signals()
	
	# Check if GAV plugin is loaded
	if Engine.has_singleton("GAV"):
		status_label.text = "✓ GAV Plugin Loaded"
		status_label.modulate = Color.GREEN
	else:
		status_label.text = "✗ GAV Plugin Not Found"
		status_label.modulate = Color.RED

func setup_ui() -> void:
	# Setup file tree
	file_tree.hide_root = true
	file_tree.columns = 2
	file_tree.set_column_title(0, "File")
	file_tree.set_column_title(1, "Info")
	file_tree.set_column_expand(0, true)
	file_tree.set_column_expand(1, true)
	
	# Setup video player
	video_player.loop = false
	
	# Setup controls and tooltips
	progress_slider.editable = false
	progress_slider.step = 0.01  # Smooth seeking with small steps
	progress_slider.scrollable = false  # Prevent accidental scroll wheel seeks
	play_button.tooltip_text = "Play/Pause/Resume (Space)"
	pause_button.visible = false  # Hidden - play button handles pause
	stop_button.tooltip_text = "Stop (Esc)"
	progress_slider.tooltip_text = "Seek through video (←/→ for ±5s)"
	loop_check.tooltip_text = "Loop playback (Shift+L)"
	
	update_controls_state()

func scan_test_media() -> void:
	test_media_files.clear()
	
	# Scan test_media directory
	print("[TestChamber] Checking for test_media at: ", TEST_MEDIA_DIR)
	if DirAccess.dir_exists_absolute(TEST_MEDIA_DIR):
		print("[TestChamber] Found test_media directory, scanning...")
		_scan_directory(TEST_MEDIA_DIR, "test_media")
	else:
		print("[TestChamber] test_media directory not found")
	
	# Scan demo directory for existing media
	print("[TestChamber] Scanning demo directory: ", DEMO_MEDIA_DIR)
	_scan_directory(DEMO_MEDIA_DIR, "demo", [".mp4", ".mov", ".webm", ".mkv"])
	
	print("[TestChamber] Total files found: ", test_media_files.size())
	test_media_files.sort_custom(func(a, b): return a.path < b.path)

func _scan_directory(dir_path: String, category: String, extensions: Array[String] = []) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		print("[TestChamber] Failed to open directory: ", dir_path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = dir_path.path_join(file_name)
		
		if dir.current_is_dir():
			if file_name != "." and file_name != ".." and file_name != ".godot" and file_name != "addons":
				_scan_directory(full_path, category + "/" + file_name, extensions)
		else:
			var ext = file_name.get_extension().to_lower()
			# Skip .uid files and .import files
			if file_name.ends_with(".uid") or file_name.ends_with(".import"):
				file_name = dir.get_next()
				continue
			if ext in ["mp4", "mov", "webm", "mkv", "ogg", "avi"] or (extensions.is_empty() or "." + ext in extensions):
				print("[TestChamber] Found video: ", full_path)
				test_media_files.append({
					"path": full_path,
					"name": file_name,
					"category": category,
					"extension": ext
				})
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func populate_file_tree() -> void:
	file_tree.clear()
	var root = file_tree.create_item()
	
	# Group by category
	var categories: Dictionary = {}
	for file_info in test_media_files:
		var cat = file_info.category
		if cat not in categories:
			categories[cat] = []
		categories[cat].append(file_info)
	
	# Create tree structure
	for category in categories.keys():
		var cat_item = file_tree.create_item(root)
		cat_item.set_text(0, category)
		cat_item.set_selectable(0, false)
		
		for file_info in categories[category]:
			var file_item = file_tree.create_item(cat_item)
			file_item.set_text(0, file_info.name)
			file_item.set_text(1, _get_file_info_text(file_info))
			file_item.set_metadata(0, file_info)

func _get_file_info_text(file_info: Dictionary) -> String:
	var name: String = file_info.name
	var info_parts: Array[String] = []
	
	# Parse info from filename
	if "h264" in name or "x264" in name:
		info_parts.append("H.264")
	elif "hevc" in name or "h265" in name or "x265" in name:
		info_parts.append("HEVC")
	elif "vp9" in name:
		info_parts.append("VP9")
	elif "av1" in name:
		info_parts.append("AV1")
	elif "prores" in name:
		info_parts.append("ProRes")
	
	# Resolution
	if "480p" in name:
		info_parts.append("480p")
	elif "720p" in name:
		info_parts.append("720p")
	elif "1080p" in name:
		info_parts.append("1080p")
	elif "1440p" in name:
		info_parts.append("1440p")
	elif "4k" in name or "2160" in name:
		info_parts.append("4K")
	elif "8k" in name or "4320" in name:
		info_parts.append("8K")
	
	# Pixel format
	if "10bit" in name or "main10" in name:
		info_parts.append("10-bit")
	
	# Framerate
	if "60fps" in name or "fps_60" in name:
		info_parts.append("60fps")
	elif "120fps" in name or "fps_120" in name:
		info_parts.append("120fps")
	
	return " • ".join(info_parts) if not info_parts.is_empty() else file_info.extension.to_upper()

func connect_signals() -> void:
	file_tree.item_activated.connect(_on_file_tree_item_activated)
	play_button.pressed.connect(_on_play_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	progress_slider.value_changed.connect(_on_progress_value_changed)
	progress_slider.drag_started.connect(_on_progress_drag_started)
	progress_slider.drag_ended.connect(_on_progress_drag_ended)
	hw_accel_check.toggled.connect(_on_hw_accel_toggled)
	loop_check.toggled.connect(_on_loop_toggled)

func _input(event: InputEvent) -> void:
	# Keyboard shortcuts for playback control
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				# Space bar: play/pause/resume toggle
				_on_play_pressed()
				accept_event()
			KEY_ESCAPE:
				# ESC stops playback
				if playback_state != PlaybackState.STOPPED:
					_on_stop_pressed()
				accept_event()
			KEY_LEFT:
				# Left arrow: seek backward 5 seconds
				if video_player.stream != null and playback_state != PlaybackState.STOPPED:
					var current_pos = video_player.stream_position
					var new_pos = max(0.0, current_pos - 5.0)
					video_player.stream_position = new_pos
					progress_slider.value = new_pos
					accept_event()
			KEY_RIGHT:
				# Right arrow: seek forward 5 seconds
				if video_player.stream != null and playback_state != PlaybackState.STOPPED:
					var current_pos = video_player.stream_position
					var length = video_player.get_stream_length()
					var new_pos = min(length, current_pos + 5.0)
					video_player.stream_position = new_pos
					progress_slider.value = new_pos
					accept_event()
			KEY_L:
				# L key toggles loop
				if event.shift_pressed:
					loop_check.button_pressed = not loop_check.button_pressed
					_on_loop_toggled(loop_check.button_pressed)
					accept_event()

func _on_file_tree_item_activated() -> void:
	var selected = file_tree.get_selected()
	if selected == null:
		return
	
	var file_info = selected.get_metadata(0)
	if file_info == null:
		return
	
	load_and_play_video(file_info.path)

func load_and_play_video(path: String) -> void:
	# Stop any existing playback
	if playback_state != PlaybackState.STOPPED:
		stop_video()
	
	current_file = path
	
	var stream = load(path) as GAVStream
	if stream == null:
		update_info("❌ Failed to load: " + path.get_file())
		playback_state = PlaybackState.STOPPED
		update_controls_state()
		return
	
	video_player.stream = stream
	
	# Set loop on the stream so it's passed to playback
	stream.loop = loop_check.button_pressed
	video_player.loop = loop_check.button_pressed
	
	# Set aspect ratio based on video dimensions
	var texture = video_player.get_video_texture()
	if texture:
		var size = texture.get_size()
		if size.y > 0:
			aspect_container.ratio = size.x / size.y
	
	# Connect finished signal
	if not stream.finished.is_connected(_on_video_finished):
		stream.finished.connect(_on_video_finished)
	
	# Start playback
	video_player.paused = false
	video_player.play()
	playback_state = PlaybackState.PLAYING
	
	update_info("▶ Playing: " + path.get_file())
	update_controls_state()

func stop_video() -> void:
	if video_player.stream != null:
		video_player.stop()
		# Don't clear the stream - keep it loaded so we can replay
		# video_player.stream = null
	playback_state = PlaybackState.STOPPED
	progress_slider.value = 0
	time_label.text = "0:00 / 0:00"
	update_controls_state()

func _on_video_finished() -> void:
	# This signal is emitted when loop is disabled and video reaches the end
	print("Video finished signal received")
	# Video has ended, update state
	if not video_player.loop:
		playback_state = PlaybackState.STOPPED
		update_controls_state()
		update_info("✓ Playback finished")

func _on_play_pressed() -> void:
	if playback_state == PlaybackState.STOPPED:
		# Start new playback or replay
		if current_file.is_empty():
			return
		load_and_play_video(current_file)
	elif playback_state == PlaybackState.PAUSED:
		# Resume from pause
		video_player.paused = false
		playback_state = PlaybackState.PLAYING
		update_info("▶ Resumed")
		update_controls_state()
	elif playback_state == PlaybackState.PLAYING:
		# Pause the video
		video_player.paused = true
		playback_state = PlaybackState.PAUSED
		update_info("⏸ Paused")
		update_controls_state()

func _on_pause_pressed() -> void:
	# This button is now hidden, but keep the handler for compatibility
	if playback_state == PlaybackState.PLAYING:
		video_player.paused = true
		playback_state = PlaybackState.PAUSED
		update_info("⏸ Paused")
		update_controls_state()
	elif playback_state == PlaybackState.PAUSED:
		video_player.paused = false
		playback_state = PlaybackState.PLAYING
		update_info("▶ Resumed")
		update_controls_state()

func _on_stop_pressed() -> void:
	stop_video()
	update_info("⏹ Stopped")

func _on_progress_drag_started() -> void:
	is_seeking = true

func _on_progress_drag_ended(_value_changed: bool) -> void:
	is_seeking = false
	# Apply the final seek position when drag ends
	if video_player.stream != null and playback_state != PlaybackState.STOPPED:
		video_player.stream_position = progress_slider.value

func _on_progress_value_changed(value: float) -> void:
	# During drag, show preview position in time label
	if is_seeking and video_player.stream != null:
		var length = video_player.get_stream_length()
		if length > 0:
			time_label.text = "%s / %s (Seeking)" % [
				_format_time(value),
				_format_time(length)
			]
	# If not dragging but slider was clicked, seek immediately
	elif not is_seeking and video_player.stream != null and playback_state != PlaybackState.STOPPED:
		# Check if this is a user click (not from _process update)
		var current_pos = video_player.stream_position
		if abs(value - current_pos) > 0.5:  # Threshold to distinguish user input from _process updates
			video_player.stream_position = value

func _on_hw_accel_toggled(enabled: bool) -> void:
	# Note: Hardware acceleration preference would need to be set before loading
	# For now, this is informational
	update_info("ℹ Hardware acceleration: " + ("Enabled" if enabled else "Disabled"))

func _on_loop_toggled(enabled: bool) -> void:
	video_player.loop = enabled
	# Update the stream's loop property if video is loaded
	if video_player.stream:
		video_player.stream.loop = enabled
	update_info(("🔁 Loop: Enabled" if enabled else "➡ Loop: Disabled"))

func update_controls_state() -> void:
	var has_stream = video_player.stream != null
	
	# Play/Pause button changes based on state
	play_button.disabled = not has_stream
	if playback_state == PlaybackState.PLAYING:
		play_button.text = "⏸ Pause"
	elif playback_state == PlaybackState.PAUSED:
		play_button.text = "▶ Resume"
	else:  # STOPPED
		play_button.text = "▶ Play"
	
	# Hide the separate pause button - play button handles it
	pause_button.visible = false
	
	# Stop button: enabled when playing or paused
	stop_button.disabled = playback_state == PlaybackState.STOPPED
	
	# Slider: editable when we have a stream and not stopped
	progress_slider.editable = has_stream and playback_state != PlaybackState.STOPPED

func update_info(message: String) -> void:
	var info_text = "[b]" + message + "[/b]\n\n"
	
	if video_player.stream != null:
		info_text += "[b]File:[/b] " + current_file.get_file() + "\n"
		info_text += "[b]Path:[/b] " + current_file + "\n\n"
		
		# Get video info from GAV if available
		if Engine.has_singleton("GAV"):
			info_text += "[color=green]Hardware Acceleration: Available[/color]\n"
			info_text += "[color=gray]Note: Actual HW usage depends on codec support[/color]\n"
	
	info_label.text = info_text

func _process(_delta: float) -> void:
	# Only update progress slider when not seeking
	if not is_seeking and video_player.stream != null:
		var pos = video_player.stream_position
		var length = video_player.get_stream_length()
		
		if length > 0:
			progress_slider.max_value = length
			# Only update slider value if we're not actively seeking
			progress_slider.value = pos
			
			# Update time label based on state
			if playback_state == PlaybackState.PLAYING:
				time_label.text = "%s / %s" % [
					_format_time(pos),
					_format_time(length)
				]
			elif playback_state == PlaybackState.PAUSED:
				time_label.text = "%s / %s (Paused)" % [
					_format_time(pos),
					_format_time(length)
				]

func _format_time(seconds: float) -> String:
	var mins = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%d:%02d" % [mins, secs]
