extends Node3D
class_name WeaponManager
## Owns the four weapon instances, weapon switching and all trigger/reload/ADS
## input. Weapons pull camera + player state from here.

const WEAPON_SCENES: Array[PackedScene] = [
	preload("res://scenes/weapons/rifle.tscn"),
	preload("res://scenes/weapons/handgun.tscn"),
	preload("res://scenes/weapons/fist.tscn"),
	preload("res://scenes/weapons/grenade.tscn"),
]

var player: CharacterBody3D = null
var camera: Camera3D = null
var weapons: Array[WeaponBase] = []
var current_index: int = 0

func setup(owner_player: CharacterBody3D, owner_camera: Camera3D) -> void:
	player = owner_player
	camera = owner_camera
	_spawn_weapons()

func _spawn_weapons() -> void:
	for scene in WEAPON_SCENES:
		if scene == null:
			continue
		var weapon: WeaponBase = scene.instantiate()
		weapon.manager = self
		weapon.visible = false
		add_child(weapon)
		weapons.append(weapon)
	if not weapons.is_empty():
		switch_to(0, true)

func _process(_delta: float) -> void:
	if player == null or weapons.is_empty():
		return
	var weapon := weapons[current_index]
	weapon.set_sprinting(player.is_sprinting() or player.is_sliding())

	# Trigger (press + release so semi-auto and grenade charging both work).
	if Input.is_action_just_pressed("fire"):
		weapon.begin_trigger()
	if Input.is_action_just_released("fire"):
		weapon.end_trigger()

	if Input.is_action_just_pressed("reload"):
		weapon.request_reload()

	weapon.set_ads(Input.is_action_pressed("aim"))

	# Slot keys.
	for i in weapons.size():
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
			switch_to(i)
	# Mouse wheel cycles.
	if Input.is_action_just_pressed("weapon_next"):
		switch_to((current_index + 1) % weapons.size())
	if Input.is_action_just_pressed("weapon_prev"):
		switch_to((current_index - 1 + weapons.size()) % weapons.size())

func switch_to(index: int, instant: bool = false) -> void:
	if weapons.is_empty():
		return
	index = clampi(index, 0, weapons.size() - 1)
	if index == current_index and not instant:
		return
	weapons[current_index].unequip()
	current_index = index
	var weapon := weapons[index]
	weapon.equip()
	camera.set_ads(false, weapon.ads_fov)
	Events.weapon_equipped.emit(weapon.slot, {
		"name": weapon.display_name,
		"icon": weapon.icon,
		"kind": weapon.kind,
		"slot": weapon.slot,
	})
	weapon.sync_hud()
	if not instant:
		AudioManager.play_sfx("click", -10.0)

func on_ads_changed(active: bool) -> void:
	if camera == null or weapons.is_empty():
		return
	camera.set_ads(active, weapons[current_index].ads_fov)

func current_weapon() -> WeaponBase:
	if weapons.is_empty():
		return null
	return weapons[current_index]

## WeaponBase.Kind of the active weapon (-1 if none). Used by e.g. the player to
## grant the Fist its double jump.
func current_kind() -> int:
	var weapon := current_weapon()
	return weapon.kind if weapon != null else -1
