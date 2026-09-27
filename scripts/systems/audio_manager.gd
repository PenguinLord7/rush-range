extends Node
## Central audio service.
##
## - Creates the Music/Effects audio buses on startup (no bus layout resource
##   required).
## - Lazily scans res://audio for .wav/.ogg files and loads them by base name.
## - Reuses small pools of players so rapid fire doesn't allocate every shot.

const SOUND_DIRS: Array[String] = [
	"res://audio/weapons",
	"res://audio/player",
	"res://audio/environment",
	"res://audio/ui",
]

var _streams: Dictionary = {}
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_2d: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_load_streams()
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)

func _ensure_buses() -> void:
	for bus_name in ["Music", "Effects"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
			AudioServer.set_bus_volume_db(idx, linear_to_db(1.0))

func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)

func has_sound(name: String) -> bool:
	return _streams.has(name)

func play_sfx(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _streams.get(name)
	if stream == null:
		return
	var player := _free_2d()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

func play_sfx_3d(name: String, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _streams.get(name)
	if stream == null:
		return
	var player := _free_3d()
	player.global_position = position
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

func play_music(name: String, volume_db: float = -6.0) -> void:
	var stream: AudioStream = _streams.get(name)
	if stream == null:
		return
	_music.stream = stream
	_music.volume_db = volume_db
	_music.play()

func stop_music() -> void:
	_music.stop()

func _free_2d() -> AudioStreamPlayer:
	for p in _pool_2d:
		if not p.playing:
			return p
	var p := AudioStreamPlayer.new()
	p.bus = "Effects"
	add_child(p)
	_pool_2d.append(p)
	return p

func _free_3d() -> AudioStreamPlayer3D:
	for p in _pool_3d:
		if not p.playing:
			return p
	var p := AudioStreamPlayer3D.new()
	p.bus = "Effects"
	p.max_distance = 60.0
	p.unit_size = 8.0
	add_child(p)
	_pool_3d.append(p)
	return p

func _load_streams() -> void:
	for dir in SOUND_DIRS:
		_scan_dir(dir)

func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if dir.current_is_dir():
			if not file.begins_with("."):
				_scan_dir(path.path_join(file))
		elif file.ends_with(".wav") or file.ends_with(".ogg") or file.ends_with(".mp3"):
			var res_path := path.path_join(file)
			var stream := ResourceLoader.load(res_path)
			if stream is AudioStream:
				_streams[file.get_basename()] = stream
		file = dir.get_next()
	dir.list_dir_end()
