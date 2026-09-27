extends Camera3D
## First-person camera: mouse look, recoil, head bob, landing dip, FOV.
##
## The player body owns horizontal yaw (so movement follows the look direction)
## and calls set_eye_height() for crouch/slide. This script owns the final
## camera transform: pitch, recoil, bob and shake all stack here.

@export var look_enabled: bool = true

@export_group("Recoil recovery")
@export var recoil_recovery: float = 12.0
@export var recoil_return_fraction: float = 1.0

var _player: CharacterBody3D
var _pitch: float = 0.0
var _eye_height: float = 1.62

# Recoil offsets (radians), recovered over time.
var _recoil_pitch: float = 0.0
var _recoil_yaw: float = 0.0

# Head bob.
var _bob_time: float = 0.0
var _bob_amount: float = 0.0
var _bob_target: float = 0.0

# Landing dip and explosion shake.
var _land_offset: float = 0.0
var _shake: float = 0.0

# FOV / ADS.
var _base_fov: float = 80.0
var _current_fov: float = 80.0
var _ads: bool = false
var _ads_fov: float = 55.0
var _sprinting: bool = false

func _ready() -> void:
	_base_fov = Settings.fov
	_current_fov = _base_fov
	fov = _current_fov
	top_level = false

func set_body(body: CharacterBody3D) -> void:
	_player = body

func set_eye_height(height: float) -> void:
	_eye_height = height

func _unhandled_input(event: InputEvent) -> void:
	if not look_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var sens: float = Settings.mouse_sensitivity
		var dy: float = event.relative.y * (1.0 if not Settings.invert_y else -1.0)
		_pitch -= dy * sens
		_pitch = clampf(_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
		if _player:
			_player.rotate_y(-event.relative.x * sens)

func _process(delta: float) -> void:
	# Recover recoil toward zero; the fraction lets some recoil "stick" for feel.
	_recoil_pitch = move_toward(_recoil_pitch, 0.0, recoil_recovery * delta)
	_recoil_yaw = move_toward(_recoil_yaw, 0.0, recoil_recovery * delta)
	_land_offset = lerpf(_land_offset, 0.0, minf(9.0 * delta, 1.0))
	_shake = maxf(_shake - delta * 2.5, 0.0)

	_update_bob(delta)
	_update_fov(delta)

	var roll := 0.0
	if _player:
		var local_vel := _player.global_transform.basis.inverse() * _player.velocity
		roll = deg_to_rad(-local_vel.x * 0.9)

	var shake_off := Vector3.ZERO
	if _shake > 0.001:
		shake_off = Vector3(
			randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake * 0.02

	rotation.x = _pitch + _recoil_pitch + _land_offset * 0.35 + shake_off.y
	rotation.y = _recoil_yaw + shake_off.x
	rotation.z = roll

	var bob_x := sin(_bob_time) * _bob_amount * 0.6
	var bob_y := absf(sin(_bob_time * 2.0)) * _bob_amount
	position = Vector3(bob_x, _eye_height + bob_y - _land_offset, 0.0)

func _update_bob(delta: float) -> void:
	var sprinting := _sprinting
	var target: float
	if _player and _player.is_airborne():
		target = 0.0
	elif _player and _player.is_crouching():
		target = 0.012
	else:
		target = 0.05 if sprinting else 0.028
	_bob_target = target
	_bob_amount = lerpf(_bob_amount, _bob_target, minf(8.0 * delta, 1.0))
	var speed := 0.0
	if _player:
		speed = Vector2(_player.velocity.x, _player.velocity.z).length()
	_bob_time += delta * (speed * (1.9 if sprinting else 1.4))
	if _bob_time > TAU * 1000.0:
		_bob_time = fmod(_bob_time, TAU)

func _update_fov(delta: float) -> void:
	_base_fov = Settings.fov
	var target := _base_fov
	if _ads:
		target = _ads_fov
	elif _sprinting:
		target = _base_fov + 6.0
	_current_fov = lerpf(_current_fov, target, minf(10.0 * delta, 1.0))
	fov = _current_fov

func set_movement_state(state: int, speed: float) -> void:
	_sprinting = state == 1  # Player.State.SPRINT
	if state == 3:  # SLIDE
		_sprinting = true

## Called by weapons. Amounts are in radians.
func add_recoil(pitch: float, yaw: float) -> void:
	_recoil_pitch += pitch
	_recoil_yaw += yaw

func set_ads(active: bool, ads_fov: float = 55.0) -> void:
	_ads = active
	_ads_fov = ads_fov

func on_landed(strength: float) -> void:
	_land_offset += clampf(strength * 0.008, 0.01, 0.12)
	AudioManager.play_sfx("land", -8.0 + randf() * 1.5)

func add_shake(amount: float) -> void:
	if not Settings.screen_shake:
		return
	_shake = maxf(_shake, amount)

func get_pitch() -> float:
	return _pitch + _recoil_pitch

## World-space aim ray from the camera (used for hitscan).
func aim_origin() -> Vector3:
	return global_position

func aim_direction() -> Vector3:
	return -global_transform.basis.z.normalized()
