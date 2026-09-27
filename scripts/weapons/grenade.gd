extends WeaponBase
class_name Grenade
## Throwable grenade. Hold the trigger to charge, release to throw. Handles its
## own trigger flow (base auto-fire is bypassed) and slowly regenerates ammo.

@export var min_throw_speed: float = 9.0
@export var max_throw_speed: float = 20.0
@export var max_charge_time: float = 0.9
@export var explosion_radius: float = 4.5
@export var regen_time: float = 6.0
@export var projectile_scene: PackedScene

var _charge: float = 0.0
var _charging: bool = false
var _regen: float = 0.0

func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_switch_blend = maxf(_switch_blend - delta * 3.5, 0.0)
	_update_reload(delta)
	_update_transform(delta)

	if _charging:
		_charge = minf(_charge + delta / maxf(max_charge_time, 0.01), 1.0)

	if current_ammo < magazine_size:
		_regen += delta
		if _regen >= regen_time:
			_regen = 0.0
			current_ammo += 1
			_emit_ammo()
			AudioManager.play_sfx("click", -14.0)
	else:
		_regen = 0.0

	if _model:
		_model.visible = current_ammo > 0

func _on_trigger_pressed() -> void:
	if current_ammo <= 0:
		AudioManager.play_sfx("dry_fire", -6.0)
		Events.notice.emit("NO GRENADES")
		return
	_charging = true
	_charge = 0.0

func _on_trigger_released() -> void:
	if not _charging:
		return
	_charging = false
	if current_ammo <= 0:
		return
	_throw()
	_charge = 0.0

func _throw() -> void:
	current_ammo -= 1
	_emit_ammo()
	GameState.register_shot()
	var origin: Vector3 = manager.camera.aim_origin()
	var dir: Vector3 = manager.camera.aim_direction()
	var speed := lerpf(min_throw_speed, max_throw_speed, _charge)
	var scene := manager.get_tree().current_scene
	if scene == null or projectile_scene == null:
		return
	var proj := projectile_scene.instantiate()
	scene.add_child(proj)
	proj.global_transform = Transform3D(Basis(), origin + dir * 0.6 - Vector3.UP * 0.12)
	proj.launch(dir * speed + Vector3.UP * (2.4 + 2.2 * _charge), damage, explosion_radius)
	AudioManager.play_sfx("grenade_throw", -3.0)

func _extra_weapon_offset() -> Vector3:
	return Vector3(0.02 * _charge, 0.0, 0.07 * _charge)

func _extra_weapon_rotation() -> Vector3:
	return Vector3(0.25 * _charge, 0.0, 0.0)
