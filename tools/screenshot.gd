extends Node
## Screenshot harness. Boots the menu and the game, then saves PNGs to
## res://screenshots for visual verification. Run on a real display:
##
##   godot --path . res://tools/screenshot.tscn

const OUT_DIR := "res://screenshots"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await _scene_shots()
	get_tree().quit()

func _scene_shots() -> void:
	var menu = load("res://scenes/main/main_menu.tscn").instantiate()
	add_child(menu)
	await _settle(8)
	await _capture("menu.png")
	menu.queue_free()
	await _settle(3)

	var game = load("res://scenes/main/game.tscn").instantiate()
	add_child(game)
	await _settle(20)
	await _capture("game_spawn.png")

	var player = game.get_node("Player")
	var manager = player.get_weapon_holder()

	# Bird's-eye overview of the arena.
	var bird := Camera3D.new()
	game.add_child(bird)
	bird.global_position = Vector3(0, 55, -30)
	bird.rotation_degrees = Vector3(-72, 0, 0)
	bird.far = 4000.0
	bird.current = true
	await _settle(8)
	await _capture("arena_birdseye.png")
	player.get_camera().current = true
	bird.queue_free()
	await _settle(3)

	manager.switch_to(1, true)
	await _settle(6)
	await _capture("game_handgun.png")
	await _capture_zoom("zoom_handgun.png")

	manager.switch_to(2, true)
	await _settle(6)
	await _capture("game_fist.png")
	await _capture_zoom("zoom_fist.png")

	manager.switch_to(3, true)
	await _settle(6)
	await _capture("game_grenade.png")
	await _capture_zoom("zoom_grenade.png")

	manager.switch_to(0, true)
	await _settle(6)
	await _capture_zoom("zoom_rifle.png")
	Settings.fov = 80.0
	await _settle(4)
	player.rotation.y = deg_to_rad(-55.0)
	await _settle(6)
	await _capture("game_movement_area.png")

	player.rotation.y = deg_to_rad(55.0)
	await _settle(6)
	await _capture("game_moving_targets.png")

	player.rotation.y = 0.0
	await _settle(4)
	await _capture("game_range.png")

func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame

func _capture_zoom(name: String) -> void:
	Settings.fov = 50.0
	await _settle(5)
	await _capture(name)
	Settings.fov = 80.0
	await _settle(3)

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OUT_DIR.path_join(name)
	var err := image.save_png(path)
	if err != OK:
		printerr("screenshot: failed to save %s (%d)" % [path, err])
	else:
		print("screenshot: saved ", path)
