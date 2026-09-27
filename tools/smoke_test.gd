extends Node
## Headless smoke test. Run with:
##
##   godot --headless --path . res://tools/smoke_test.tscn --quit-after 600
##
## Exits with code 0 when all checks pass, 1 otherwise. Safe to run in CI.

var _failures: int = 0
var _checks: int = 0

func _ready() -> void:
	_build_world()
	var player = load("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	player.global_position = Vector3(0, 0.2, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_check(player != null, "player instantiates")
	_check(player.is_in_group("player"), "player is in group 'player'")
	_check(player.get_camera() != null, "player has camera")

	var manager = player.get_weapon_holder()
	_check(manager != null, "player has weapon manager")
	if manager == null:
		_finish()
		return
	_check(manager.weapons.size() == 4, "four weapons spawned (got %d)" % manager.weapons.size())

	# Names / slots in order.
	var expected := ["ASSAULT RIFLE", "HANDGUN", "FIST", "GRENADE"]
	for i in expected.size():
		if i < manager.weapons.size():
			_check(manager.weapons[i].display_name == expected[i],
				"weapon %d is %s" % [i + 1, expected[i]])

	# Weapon switching.
	manager.switch_to(1, true)
	_check(manager.current_index == 1, "switch to handgun")
	manager.switch_to(3, true)
	_check(manager.current_weapon().kind == WeaponBase.Kind.GRENADE, "grenade kind")

	# Ammo + reload on the rifle.
	var rifle: WeaponBase = manager.weapons[0]
	manager.switch_to(0, true)
	_check(rifle.current_ammo == 30, "rifle starts with 30 (got %d)" % rifle.current_ammo)
	rifle.current_ammo = 10
	rifle.request_reload()
	_check(rifle.reloading, "rifle begins reloading")
	rifle._reload_left = 0.001
	await get_tree().create_timer(0.1).timeout
	_check(rifle.current_ammo == 30, "rifle reloaded to 30 (got %d)" % rifle.current_ammo)
	_check(rifle.reserve == 100, "rifle reserve 100 after reload (got %d)" % rifle.reserve)

	# Firing consumes ammo (raycast into empty space is fine).
	rifle.current_ammo = 30
	var before := rifle.current_ammo
	rifle._cooldown = 0.0
	rifle.begin_trigger()
	await get_tree().process_frame
	await get_tree().process_frame
	rifle.end_trigger()
	_check(rifle.current_ammo == before - 1, "firing consumed one round (got %d)" % rifle.current_ammo)

	# Targets: damage, destroy, score, respawn.
	GameState.reset_run()
	var target = load("res://scenes/targets/target_humanoid.tscn").instantiate()
	add_child(target)
	target.global_position = Vector3(0, 0, -5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hp0: float = target.health
	rifle.current_ammo = 30
	rifle._cooldown = 0.0
	rifle.spread_base_deg = 0.0
	rifle.spread_move_deg = 0.0
	rifle.begin_trigger()
	await get_tree().process_frame
	await get_tree().process_frame
	rifle.end_trigger()
	_check(target.health < hp0, "rifle damaged target (%.0f -> %.0f)" % [hp0, target.health])

	var score_before: int = GameState.score
	var result: Dictionary = target.receive_hit(9999.0, true, target.global_position, Vector3.FORWARD)
	_check(bool(result.get("killed", false)) and target.destroyed, "lethal hit destroys target")
	_check(GameState.score > score_before, "destroying a target awards score")
	await get_tree().create_timer(target.respawn_delay + 0.3).timeout
	_check(not target.destroyed and is_equal_approx(target.health, target.max_health),
		"target respawns with full health")

	_finish()

func _build_world() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, -0.5, 0)
	add_child(body)

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  PASS: ", label)
	else:
		_failures += 1
		printerr("  FAIL: ", label)

func _finish() -> void:
	print("smoke_test: %d/%d checks passed." % [_checks - _failures, _checks])
	if _failures > 0:
		printerr("smoke_test: FAILED (%d)" % _failures)
		get_tree().quit(1)
	else:
		print("smoke_test: OK")
		get_tree().quit(0)
