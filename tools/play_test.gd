extends Node
## Headless gameplay test: boots the real game scene, simulates input, and
## checks movement modes + every weapon. Run:
##
##   godot --headless --path . res://tools/play_test.tscn --quit-after 3000

var _checks: int = 0
var _failures: int = 0

func _ready() -> void:
	var game = load("res://scenes/main/game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var player = game.get_node("Player")
	var manager = player.get_weapon_holder()
	await _wait(0.2)

	await _test_movement(player)
	await _test_double_jump(player, manager)
	await _test_ads_recoil(player, manager)
	await _test_fist(player, manager)
	await _test_grenade(manager)
	_test_settings()
	await _test_menu()

	_finish()

func _test_movement(player) -> void:
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	await _wait(0.5)
	Input.action_release("move_forward")
	_check(player.global_position.distance_to(start) > 0.5,
		"WASD moves the player (%.2f m)" % player.global_position.distance_to(start))

	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _wait(0.5)
	_check(player.is_sprinting(), "sprint state activates")
	Input.action_press("crouch")
	await _wait(0.15)
	_check(player.is_sliding(), "crouch while sprinting slides")
	Input.action_release("crouch")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _wait(0.8)

	# Ensure grounded before jumping.
	for i in 30:
		if player.is_on_floor():
			break
		await get_tree().physics_frame
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	await get_tree().physics_frame
	_check(player.velocity.y > 1.0, "jump gives upward velocity (%.1f)" % player.velocity.y)
	# Air control: moving while airborne should build horizontal speed.
	Input.action_press("move_forward")
	await _wait(0.25)
	var air_speed := Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_release("move_forward")
	_check(air_speed > 1.5, "can move in the air after jumping (%.1f m/s)" % air_speed)
	await _wait(0.8)

func _test_double_jump(player, manager) -> void:
	# Without the Fist, a mid-air jump must be ignored.
	manager.switch_to(0, true)
	await _ensure_grounded(player)
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	await _wait(0.12)
	var vy_rifle: float = player.velocity.y
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	await get_tree().physics_frame
	_check(player.velocity.y <= vy_rifle + 0.5,
		"no air jump without fist (vy %.1f -> %.1f)" % [vy_rifle, player.velocity.y])
	await _wait(1.0)

	# With the Fist equipped, the second jump fires.
	manager.switch_to(2, true)
	await _ensure_grounded(player)
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	await _wait(0.15)
	var vy_fist: float = player.velocity.y
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	await get_tree().physics_frame
	_check(player.velocity.y > vy_fist + 0.5,
		"fist grants double jump (vy %.1f -> %.1f)" % [vy_fist, player.velocity.y])
	await _wait(1.0)
	manager.switch_to(0, true)

func _ensure_grounded(player) -> void:
	for i in 180:
		if player.is_on_floor():
			return
		await get_tree().physics_frame

func _test_ads_recoil(player, manager) -> void:
	manager.switch_to(0, true)
	await _wait(0.1)
	var cam: Camera3D = player.get_camera()
	var weapon: WeaponBase = manager.current_weapon()

	weapon.current_ammo = 30
	weapon._ads_blend = 0.0
	var before_hip: float = cam.recoil_amount()
	weapon._shoot()
	var hip: float = cam.recoil_amount() - before_hip

	weapon.current_ammo = 30
	weapon._ads_blend = 1.0
	var before_ads: float = cam.recoil_amount()
	weapon._shoot()
	var ads: float = cam.recoil_amount() - before_ads

	_check(hip > 0.0001, "hip fire kicks the camera (%.4f)" % hip)
	_check(ads < hip * 0.2, "no camera kick while aiming (hip %.4f, ads %.4f)" % [hip, ads])
	weapon._ads_blend = 0.0

func _test_fist(player, manager) -> void:
	manager.switch_to(2, true)
	var target = load("res://scenes/targets/target_humanoid.tscn").instantiate()
	add_child(target)
	target.global_position = player.global_position - player.transform.basis.z * 1.2
	target.global_position.y = 0.0
	await _wait(0.1)
	var before: float = target.health
	manager.current_weapon().begin_trigger()
	await _wait(0.1)
	manager.current_weapon().end_trigger()
	_check(target.health < before, "fist punch damages a nearby target (%.0f -> %.0f)" % [before, target.health])
	target.queue_free()

func _test_grenade(manager) -> void:
	manager.switch_to(3, true)
	var target = load("res://scenes/targets/target_humanoid.tscn").instantiate()
	add_child(target)
	target.global_position = Vector3(0, 0, -4)
	await _wait(0.1)
	var before: float = target.health

	var proj = load("res://scenes/weapons/grenade_projectile.tscn").instantiate()
	add_child(proj)
	proj.global_position = Vector3(0, 1.0, -1.0)
	proj.launch(Vector3(0, 0, -3.0), 200.0, 5.0)
	await _wait(2.6)
	_check(target.health < before or target.destroyed,
		"grenade explosion damages a target (%.0f -> %.0f)" % [before, target.health])
	target.queue_free()

func _test_settings() -> void:
	Settings.set_value("fov", 95.0)
	_check(is_equal_approx(Settings.fov, 95.0), "settings update")
	Settings.set_value("master_volume", 0.42)
	Settings.load_settings()
	_check(is_equal_approx(Settings.master_volume, 0.42), "settings persist to disk")
	Settings.set_value("screen_shake", false)
	Settings.load_settings()
	_check(Settings.screen_shake == false, "screen shake setting persists")
	Settings.reset_defaults()

func _test_menu() -> void:
	var menu = load("res://scenes/main/main_menu.tscn").instantiate()
	add_child(menu)
	await _wait(0.1)
	_check(menu.get_child_count() > 0, "main menu builds its UI")
	menu.queue_free()
	await _wait(0.1)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  PASS: ", label)
	else:
		_failures += 1
		printerr("  FAIL: ", label)

func _finish() -> void:
	print("play_test: %d/%d checks passed." % [_checks - _failures, _checks])
	if _failures > 0:
		printerr("play_test: FAILED (%d)" % _failures)
		get_tree().quit(1)
	else:
		print("play_test: OK")
		get_tree().quit(0)
