extends Node3D
class_name WeaponBase
## Shared logic for all weapons: timers, ammo, reloading, movement-coupled
## spread, recoil, muzzle effects and the procedural first-person animation
## (sway / bob / kick / ADS / reload / equip).
##
## Subclasses set exported stats in their .tscn and override behavior such as
## _fire() (melee/grenade) or the fire mode. The WeaponManager owns switching.

enum Kind { HITSCAN, MELEE, GRENADE }

@export_group("Identity")
@export var display_name: String = "Weapon"
@export var slot: int = 1
@export var kind: Kind = Kind.HITSCAN
@export var icon: Texture2D

@export_group("Damage")
@export var damage: float = 20.0
@export var headshot_multiplier: float = 2.0
@export var range_m: float = 120.0

@export_group("Fire")
@export var automatic: bool = true
@export var rpm: float = 650.0
@export var magazine_size: int = 30
@export var reserve_ammo: int = 120
@export var infinite_reserve: bool = false
@export var reload_time: float = 1.9
@export var fire_sound: String = "rifle_shot"
@export var hit_scan: bool = true

@export_group("Accuracy (degrees)")
@export var spread_base_deg: float = 0.7
@export var spread_move_deg: float = 2.2
@export var spread_ads_deg: float = 0.12
@export var spread_max_deg: float = 7.0

@export_group("Recoil")
@export var recoil_pitch_deg: float = 0.55
@export var recoil_yaw_deg: float = 0.30
@export var recoil_kick: float = 0.05
@export var kick_recovery: float = 4.0

@export_group("Aim")
@export var can_ads: bool = true
@export var ads_fov: float = 55.0
@export var ads_speed: float = 13.0
@export var can_fire_while_sprinting: bool = false

@export_group("Mount")
@export var mount_position: Vector3 = Vector3(0.30, -0.24, -0.55)
@export var mount_rotation: Vector3 = Vector3.ZERO
@export var ads_position: Vector3 = Vector3(0.0, -0.16, -0.40)
@export var ads_rotation: Vector3 = Vector3.ZERO

@export_group("Animation")
@export var sway_amount: float = 0.006
@export var bob_amount: Vector2 = Vector2(0.012, 0.010)
@export var bob_frequency: float = 1.6

# Runtime state (managed here, read by the manager/HUD).
var current_ammo: int = 0
var reserve: int = 0
var reloading: bool = false
var manager: Node = null

var _cooldown: float = 0.0
var _reload_left: float = 0.0
var _trigger_held: bool = false
var _fire_requested: bool = false
var _ads_active: bool = false
var _ads_blend: float = 0.0
var _sprint_lower: float = 0.0
var _kick: float = 0.0
var _switch_blend: float = 0.0
var _reload_blend: float = 0.0
var _bob_time: float = 0.0
var _model: Node3D
var _muzzle: Node3D
var _eject: Node3D

func _ready() -> void:
	current_ammo = magazine_size
	reserve = reserve_ammo
	_model = get_node_or_null("Model")
	_muzzle = get_node_or_null("Muzzle")
	_eject = get_node_or_null("EjectPoint")
	set_process(false)

# --- Manager API -----------------------------------------------------------

func equip() -> void:
	set_process(true)
	visible = true
	_trigger_held = false
	_fire_requested = false
	_ads_blend = 0.0
	_switch_blend = 1.0
	_emit_ammo()

func unequip() -> void:
	set_process(false)
	visible = false
	_trigger_held = false
	_ads_active = false
	reloading = false

func begin_trigger() -> void:
	_trigger_held = true
	_fire_requested = true
	_on_trigger_pressed()

func end_trigger() -> void:
	_trigger_held = false
	_on_trigger_released()

func set_ads(active: bool) -> void:
	_ads_active = active
	if manager and manager.has_method("on_ads_changed"):
		manager.on_ads_changed(active and can_ads)

func set_sprinting(value: bool) -> void:
	# Lower the weapon while sprinting; blend handled in _update_transform.
	_sprint_lower = 1.0 if value else 0.0

func request_reload() -> void:
	if reloading or kind == Kind.MELEE or kind == Kind.GRENADE:
		return
	if current_ammo >= magazine_size:
		return
	if not infinite_reserve and reserve <= 0:
		Events.out_of_ammo.emit()
		Events.notice.emit("NO AMMO")
		return
	reloading = true
	_reload_left = reload_time
	Events.reload_started.emit(reload_time)
	AudioManager.play_sfx("reload", -4.0)
	_emit_ammo()

func can_reload() -> bool:
	return not reloading and current_ammo < magazine_size \
		and (infinite_reserve or reserve > 0)

## Whether the trigger can currently produce a shot.
func can_fire() -> bool:
	if reloading or _cooldown > 0.0:
		return false
	if manager and manager.player:
		var p = manager.player
		if p.is_sprinting() and not can_fire_while_sprinting:
			return false
		if p.is_sliding() and not can_fire_while_sprinting:
			return false
	return true

# --- Frame loop ------------------------------------------------------------

func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_switch_blend = maxf(_switch_blend - delta * 3.5, 0.0)
	_update_reload(delta)
	_update_transform(delta)

	if reloading:
		return
	if _fire_requested and not automatic:
		_fire_requested = false
		_try_fire()
	elif _trigger_held and automatic:
		_try_fire()

func _update_reload(delta: float) -> void:
	if not reloading:
		_reload_blend = move_toward(_reload_blend, 0.0, 3.0 * delta)
		return
	_reload_left -= delta
	_reload_blend = 1.0
	if _reload_left <= 0.0:
		_finish_reload()

func _finish_reload() -> void:
	var needed := magazine_size - current_ammo
	if infinite_reserve:
		current_ammo = magazine_size
	else:
		var take := mini(needed, reserve)
		current_ammo += take
		reserve -= take
	reloading = false
	_reload_blend = 0.0
	Events.reload_finished.emit()
	_emit_ammo()

func _try_fire() -> void:
	if not can_fire():
		return
	if current_ammo <= 0:
		AudioManager.play_sfx("dry_fire", -6.0)
		if can_reload():
			request_reload()
		return

	_cooldown = 60.0 / maxf(rpm, 1.0)
	_shoot()

func _shoot() -> void:
	current_ammo -= 1
	_emit_ammo()
	GameState.register_shot()
	Events.weapon_fired.emit()

	var origin: Vector3 = manager.camera.aim_origin()
	var dir: Vector3 = manager.camera.aim_direction()
	if kind == Kind.HITSCAN:
		_muzzle_effects(dir)
	_fire(origin, dir)

	# Recoil + weapon kick (arcade: fully recoverable, player can fight it).
	# Only firearms recoil; the fist and grenade do not push the camera.
	# While aiming the camera stays still: recoil is shown by the weapon kick.
	if kind == Kind.HITSCAN and (recoil_pitch_deg > 0.0 or recoil_yaw_deg > 0.0):
		var mult := recoil_multiplier() * (1.0 - _ads_blend)
		if mult > 0.0:
			var pitch := deg_to_rad(recoil_pitch_deg) * mult * randf_range(0.85, 1.15)
			var yaw := deg_to_rad(recoil_yaw_deg) * mult * randf_range(-1.0, 1.0)
			manager.camera.add_recoil(pitch, yaw)
		_kick = recoil_kick

	if current_ammo == 0 and can_reload():
		request_reload()

## Default hitscan behavior. Override for melee / grenade.
func _fire(origin: Vector3, dir: Vector3) -> void:
	var spread_dir := spread_direction(dir)
	var end := origin + spread_dir * range_m
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, end, Layers.SHOOTABLE)
	var hit := space.intersect_ray(query)
	var impact := end
	if not hit.is_empty():
		impact = hit.position
		_handle_impact(hit, impact, spread_dir)
	Fx.tracer(_muzzle_position(), impact)

func _handle_impact(hit: Dictionary, impact: Vector3, dir: Vector3) -> void:
	var collider: Object = hit.get("collider")
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	if collider and collider.has_method("apply_hit"):
		var result: Dictionary = collider.apply_hit(damage, impact, dir)
		var dealt: int = int(result.get("damage", damage))
		var head: bool = bool(result.get("headshot", false))
		var killed: bool = bool(result.get("killed", false))
		GameState.register_hit()
		Events.damage_dealt.emit(impact, dealt, head)
		Events.hit_confirmed.emit(killed, head)
		Fx.impact(impact, normal, Color(1.0, 0.4, 0.3))
	else:
		Fx.impact(impact, normal)
		AudioManager.play_sfx_3d("impact", impact, -8.0)

func _on_trigger_released() -> void:
	pass

## Hook for the grenade: hold to charge, release to throw.
func _on_trigger_pressed() -> void:
	pass

## Scales recoil; the rifle climbs while sustained firing.
func recoil_multiplier() -> float:
	return 1.0

## Extra procedural offsets, overridden by the grenade (charge wind-up).
func _extra_weapon_offset() -> Vector3:
	return Vector3.ZERO

func _extra_weapon_rotation() -> Vector3:
	return Vector3.ZERO

func sync_hud() -> void:
	_emit_ammo()

## 0..1 how far into ADS the weapon is (used by the HUD crosshair).
func ads_amount() -> float:
	return _ads_blend

# --- Helpers ---------------------------------------------------------------

func spread_direction(dir: Vector3) -> Vector3:
	var spread := spread_base_deg
	if manager and manager.player:
		spread += manager.player.movement_accuracy_penalty() * spread_move_deg
	spread = clampf(spread, spread_ads_deg, spread_max_deg)
	if _ads_blend > 0.0:
		spread = lerpf(spread, spread_ads_deg, _ads_blend)
	if spread <= 0.001:
		return dir
	var basis := Basis.looking_at(dir, Vector3.UP)
	var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if offset.length() > 1.0:
		offset = offset.normalized()
	offset *= tan(deg_to_rad(spread))
	return (dir + basis.x * offset.x + basis.y * offset.y).normalized()

func _muzzle_position() -> Vector3:
	if _muzzle:
		return _muzzle.global_position
	return global_position

func _muzzle_effects(dir: Vector3) -> void:
	var pos := _muzzle_position()
	Fx.muzzle_flash(pos, dir)
	AudioManager.play_sfx_3d(fire_sound, pos, -3.0, randf_range(0.95, 1.06))
	if _eject:
		Fx.eject_casing(_eject.global_position, _muzzle.global_transform.basis.x, Vector3.UP)

func _emit_ammo() -> void:
	Events.ammo_changed.emit(current_ammo, -1 if infinite_reserve else reserve, reloading)

func ammo_text() -> String:
	if kind == Kind.MELEE:
		return "∞"
	if kind == Kind.GRENADE:
		return str(current_ammo)
	return "%d / %d" % [current_ammo, reserve]

func _update_transform(delta: float) -> void:
	var ads_target := 1.0 if (_ads_active and can_ads) else 0.0
	_ads_blend = move_toward(_ads_blend, ads_target, ads_speed * delta)

	var pos := mount_position.lerp(ads_position, _ads_blend)
	var rot := mount_rotation.lerp(ads_rotation, _ads_blend)

	# Strafe sway + walk bob.
	var local_vel := Vector3.ZERO
	if manager and manager.player:
		local_vel = manager.player.global_transform.basis.inverse() * manager.player.velocity
	var local_speed := Vector2(local_vel.x, local_vel.z).length()
	_bob_time += delta * local_speed * bob_frequency
	var bob := Vector3(sin(_bob_time) * bob_amount.x, absf(sin(_bob_time * 2.0)) * bob_amount.y, 0.0)
	var sway := Vector3(-local_vel.x * sway_amount, 0.0, local_vel.z * sway_amount * 0.4)
	sway = sway.limit_length(0.03)
	pos += bob + sway

	# Sprint lower.
	pos.y -= 0.09 * _sprint_lower
	rot.x += 0.28 * _sprint_lower

	# Recoil kick.
	_kick = move_toward(_kick, 0.0, kick_recovery * delta)
	pos.z += _kick
	rot.x -= _kick * 1.6

	pos += _extra_weapon_offset()
	rot += _extra_weapon_rotation()

	# Reload dip and equip raise.
	pos.y -= 0.10 * _reload_blend
	rot.x += 0.45 * _reload_blend
	pos.y -= 0.32 * _switch_blend
	rot.x += 1.0 * _switch_blend

	transform = Transform3D(Basis.from_euler(rot), pos)
