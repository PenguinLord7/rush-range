extends Node3D
## Game scene controller: spawns the player, wires the pause menu and handles
## ESC / restart.

@onready var arena: Node3D = $Arena
@onready var player: Player = $Player
@onready var pause_menu: Control = $PauseMenu

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameState.reset_run()
	AudioManager.stop_music()
	get_tree().paused = false
	if player and arena:
		player.global_position = arena.spawn_point + Vector3(0, 0.3, 0)
	if pause_menu:
		pause_menu.resume_pressed.connect(_resume)
		pause_menu.restart_pressed.connect(_restart)
		pause_menu.menu_pressed.connect(_to_menu)

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event.is_action_pressed("pause"):
		_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart"):
		_restart()

func _pause() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if pause_menu:
		pause_menu.open()

func _resume() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if pause_menu:
		pause_menu.close()

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
