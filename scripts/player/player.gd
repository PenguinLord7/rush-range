extends CharacterBody3D
## First-person player controller.
##
## Movement is a small explicit state machine so each mode (walk / sprint /
## crouch / slide / air) is easy to read and tune. The camera is a sibling
## script (player_camera.gd) that owns look, bob, FOV and recoil; this script
## only moves the body and reports what state it is in.

class_name Player

enum State { WALK, SPRINT, CROUCH, SLIDE, AIR }

@export_group("Speeds")
@export var walk_speed: float = 6.0
@export var sprint_speed: float = 9.5
@export var crouch_speed: float = 3.2

@export_group("Slide")
@export var slide_speed: float = 12.5
@export var slide_end_speed: float = 5.0
@export var slide_duration: float = 0.65
@export var slide_cooldown: float = 0.45
@export var slide_friction: float = 9.0
@export var slide_steer: float = 2.0

@export_group("Jump / gravity")
@export var jump_velocity: float = 5.8
@export var gravity: float = 26.0
## Extra mid-air jumps granted while the Fist is equipped.
@export var fist_air_jumps: int = 1

@export_group("Acceleration")
@export var ground_accel: float = 55.0
@export var ground_friction: float = 45.0
@export var air_accel: float = 12.0

@export_group("Body")
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.2
@export var stand_eye: float = 1.62
@export var crouch_eye: float = 1.0
@export var slide_eye: float = 0.72
@export var body_lerp_speed: float = 12.0

@onready var _collision: CollisionShape3D = $Collision
@onready var _camera: Camera3D = $Camera
@onready var _ceiling: RayCast3D = $CeilingCheck
@onready var _weapons: Node3D = $Camera/WeaponHolder

var state: State = State.WALK
var current_speed: float = 0.0
var _slide_timer: float = 0.0
var _slide_cd: float = 0.0
var _current_height: float = 1.8
var _current_eye: float = 1.62
var _step_distance: float = 0.0
var _air_jumps_used: int = 0
var _was_on_floor: bool = true
var _input_dir: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("player")
	_current_height = stand_height
	_current_eye = stand_eye
	_collision.shape = _collision.shape.duplicate()
	_camera.set_body(self)
	_camera.set_eye_height(_current_eye)
	if _weapons and _weapons.has_method("setup"):
		_weapons.setup(self, _camera)

func _physics_process(delta: float) -> void:
	_slide_cd = maxf(_slide_cd - delta, 0.0)
	if is_on_floor():
		_air_jumps_used = 0
	_input_dir = _read_input_dir()
	_update_state(delta)
	_apply_movement(delta)
	_update_body_shape(delta)

	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_camera.on_landed(absf(velocity.y) + current_speed * 0.15)
	_was_on_floor = on_floor

	current_speed = Vector2(velocity.x, velocity.z).length()
	_update_footsteps(delta, on_floor)
	_camera.set_movement_state(state, current_speed)
	move_and_slide()

func _update_footsteps(delta: float, on_floor: bool) -> void:
	if not on_floor or state == State.SLIDE or _input_dir == Vector3.ZERO or current_speed < 1.0:
		_step_distance = 0.0
		return
	_step_distance += current_speed * delta
	var interval := 2.6 if state == State.SPRINT else 2.0
	if state == State.CROUCH:
		interval = 1.6
	if _step_distance >= interval:
		_step_distance = 0.0
		var volume := -18.0 if state == State.CROUCH else -12.0
		AudioManager.play_sfx("footstep_%d" % (1 + randi() % 4), volume, randf_range(0.92, 1.08))

func _read_input_dir() -> Vector3:
	var raw := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(raw.x, 0.0, raw.y))
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.001 else Vector3.ZERO

func _update_state(delta: float) -> void:
	var on_floor := is_on_floor()

	if not on_floor:
		state = State.AIR
		_slide_timer = 0.0
		return

	if state == State.SLIDE:
		_slide_timer -= delta
		if _slide_timer <= 0.0 or current_speed < slide_end_speed:
			_end_slide()
		return

	# Start a slide: must be moving fast and be grounded with crouch pressed.
	var wants_slide := Input.is_action_just_pressed("crouch") \
		and _slide_cd <= 0.0 and current_speed > 5.5 and _input_dir != Vector3.ZERO
	if wants_slide:
		_start_slide()
		return

	if Input.is_action_pressed("crouch"):
		state = State.CROUCH
	elif Input.is_action_pressed("sprint") and _input_dir != Vector3.ZERO:
		state = State.SPRINT
	else:
		state = State.WALK

func _apply_movement(delta: float) -> void:
	if state == State.SLIDE:
		# Keep momentum, slowly bleed speed, allow a little steering.
		var horiz := Vector3(velocity.x, 0.0, velocity.z)
		horiz = horiz.move_toward(Vector3.ZERO, slide_friction * delta)
		velocity.x = horiz.x
		velocity.z = horiz.z
		if _input_dir != Vector3.ZERO:
			var side := _input_dir.cross(Vector3.UP) * slide_steer
			velocity.x += side.x * delta
			velocity.z += side.z * delta
	else:
		var target_speed := walk_speed
		match state:
			State.SPRINT:
				target_speed = sprint_speed
			State.CROUCH:
				target_speed = crouch_speed
			State.AIR:
				target_speed = clampf(current_speed, 0.0, sprint_speed)
		var desired := _input_dir * target_speed
		var accel := ground_accel if is_on_floor() else air_accel
		var horiz := Vector3(velocity.x, 0.0, velocity.z)
		if _input_dir == Vector3.ZERO and is_on_floor():
			horiz = horiz.move_toward(Vector3.ZERO, ground_friction * delta)
		else:
			horiz = horiz.move_toward(desired, accel * delta)
		velocity.x = horiz.x
		velocity.z = horiz.z

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			_do_jump(false)
		elif _can_air_jump():
			_air_jumps_used += 1
			_do_jump(true)

func _do_jump(is_air_jump: bool) -> void:
	velocity.y = jump_velocity * (0.95 if is_air_jump else 1.0)
	AudioManager.play_sfx("jump", -6.0, 1.18 if is_air_jump else 1.0)
	if is_air_jump:
		_camera.add_shake(0.12)

## Air jumps are only available while the Fist is the active weapon.
func _can_air_jump() -> bool:
	return _air_jumps_used < _max_air_jumps()

func _max_air_jumps() -> int:
	if _weapons == null or not _weapons.has_method("current_kind"):
		return 0
	return fist_air_jumps if _weapons.current_kind() == 1 else 0

func _start_slide() -> void:
	state = State.SLIDE
	_slide_timer = slide_duration
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	var dir := horiz.normalized() if horiz.length() > 0.1 else -transform.basis.z
	var speed := maxf(horiz.length(), slide_speed)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	AudioManager.play_sfx("slide", -8.0)

func _end_slide() -> void:
	_slide_cd = slide_cooldown
	if Input.is_action_pressed("crouch"):
		state = State.CROUCH
	else:
		state = State.WALK

func _update_body_shape(delta: float) -> void:
	var target_height := stand_height
	var target_eye := stand_eye
	match state:
		State.CROUCH:
			target_height = crouch_height
			target_eye = crouch_eye
		State.SLIDE:
			target_height = crouch_height
			target_eye = slide_eye
		_:
			# Only stand back up if there is headroom.
			if _current_height < stand_height - 0.01 and _ceiling.is_colliding():
				target_height = crouch_height
				target_eye = crouch_eye

	_current_height = lerpf(_current_height, target_height, minf(body_lerp_speed * delta, 1.0))
	var capsule := _collision.shape as CapsuleShape3D
	if capsule:
		capsule.height = _current_height
		_collision.position.y = _current_height * 0.5
	_current_eye = lerpf(_current_eye, target_eye, minf(body_lerp_speed * delta, 1.0))
	_camera.set_eye_height(_current_eye)

func get_camera() -> Camera3D:
	return _camera

func is_sprinting() -> bool:
	return state == State.SPRINT

func is_crouching() -> bool:
	return state == State.CROUCH

func is_sliding() -> bool:
	return state == State.SLIDE

func is_airborne() -> bool:
	return state == State.AIR

## Higher = less accurate. Used by weapons to scale spread with movement.
func movement_accuracy_penalty() -> float:
	match state:
		State.WALK:
			return 0.35
		State.SPRINT:
			return 1.0
		State.CROUCH:
			return -0.2
		State.SLIDE:
			return 1.4
		State.AIR:
			return 1.6
	return 0.35

func get_weapon_holder() -> Node3D:
	return _weapons

## Knockback from grenade blasts.
func apply_blast(direction: Vector3, strength: float) -> void:
	velocity += direction * strength * 7.0 + Vector3.UP * strength * 3.5
