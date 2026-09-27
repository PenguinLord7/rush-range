extends Node3D
## Builds the shooting range at runtime from simple data. Keeping the layout in
## code makes it easy to retune: change a row in the tables below or move an
## Area function. Uses the original Blender modules for visuals and adds
## matching box colliders for reliable physics.

const WALL := "res://models/environment/wall.glb"
const BARRIER := "res://models/environment/barrier.glb"
const CRATE := "res://models/environment/crate.glb"
const PLATFORM := "res://models/environment/platform.glb"
const RAMP := "res://models/environment/ramp.glb"
const BUILDING := "res://models/environment/building.glb"
const TARGET_HUMANOID := "res://scenes/targets/target_humanoid.tscn"
const TARGET_DISC := "res://scenes/targets/target_disc.tscn"

const FLOOR_COLOR := Color(0.52, 0.6, 0.68)
const WALL_COLOR := Color(0.87, 0.88, 0.92)
const ACCENT_A := Color(1.0, 0.5, 0.15)
const ACCENT_B := Color(0.18, 0.78, 0.74)
const ACCENT_C := Color(0.62, 0.36, 0.9)
const ACCENT_D := Color(0.95, 0.8, 0.2)

var spawn_point: Vector3 = Vector3(0, 0.2, 6)

func _ready() -> void:
	_add_environment()
	_add_ground()
	_add_boundaries()
	_area_basic_range()
	_area_movement_course()
	_area_moving_targets()
	_area_reaction_test()
	_area_grenade_pit()

# --- Environment -----------------------------------------------------------

func _add_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.5, 0.85)
	sky_mat.sky_horizon_color = Color(0.75, 0.85, 0.95)
	sky_mat.ground_bottom_color = Color(0.35, 0.4, 0.45)
	sky_mat.ground_horizon_color = Color(0.7, 0.75, 0.8)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -40, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)

# --- Building blocks -------------------------------------------------------

func _static_box(size: Vector3, position: Vector3, color: Color,
		rotation_degrees_y: float = 0.0, parent: Node = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.position = position
	body.rotation_degrees.y = rotation_degrees_y
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = _material(color)
	mesh.mesh = box_mesh
	body.add_child(mesh)
	(parent if parent else self).add_child(body)
	return body

## Places a Blender module with a matching box collider.
func _prop(path: String, position: Vector3, collider_size: Vector3,
		collider_offset: Vector3 = Vector3.ZERO, rotation_degrees_y: float = 0.0,
		scale: float = 1.0) -> Node3D:
	var wrapper := Node3D.new()
	wrapper.position = position
	wrapper.rotation_degrees.y = rotation_degrees_y
	wrapper.scale = Vector3.ONE * scale
	add_child(wrapper)

	var model := (load(path) as PackedScene).instantiate()
	wrapper.add_child(model)

	if collider_size != Vector3.ZERO:
		var body := StaticBody3D.new()
		body.collision_layer = Layers.WORLD
		body.collision_mask = 0
		body.position = collider_offset
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = collider_size
		shape.shape = box
		body.add_child(shape)
		wrapper.add_child(body)
	return wrapper

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat

## A sloped ramp (rotated box) so the player can actually walk up it.
## ascend_neg_z: false if the ramp rises toward +Z.
func _slope(center: Vector3, width: float, run: float, rise: float,
		ascend_neg_z: bool, color: Color) -> void:
	var angle := atan2(rise, run)
	var length := sqrt(run * run + rise * rise)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.position = center
	body.rotation.x = angle if ascend_neg_z else -angle
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.2, length)
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(width, 0.2, length)
	box_mesh.material = _material(color)
	mesh.mesh = box_mesh
	body.add_child(mesh)
	add_child(body)

# --- Targets ---------------------------------------------------------------

func _spawn_target(scene_path: String, position: Vector3, health: float,
		score: int, mover_mode: int = 0, distance: float = 0.0,
		speed: float = 1.0, respawn_delay: float = 2.5) -> RangeTarget:
	var target: RangeTarget = (load(scene_path) as PackedScene).instantiate()
	target.max_health = health
	target.score_value = score
	target.respawn_delay = respawn_delay
	target.position = position
	if mover_mode != 0:
		var pivot := target.get_node("Pivot") as TargetMover
		pivot.mode = mover_mode
		pivot.distance = distance
		pivot.speed = speed
	add_child(target)
	return target

# --- Areas -----------------------------------------------------------------

func _add_ground() -> void:
	_static_box(Vector3(48, 1, 90), Vector3(0, -0.5, -32), FLOOR_COLOR)
	# Start booth / firing line accent.
	_static_box(Vector3(20, 0.15, 3), Vector3(0, 0.02, 4), ACCENT_A)

func _add_boundaries() -> void:
	var h := 4.0
	_static_box(Vector3(0.5, h, 90), Vector3(-24, h * 0.5, -32), WALL_COLOR)
	_static_box(Vector3(0.5, h, 90), Vector3(24, h * 0.5, -32), WALL_COLOR)
	_static_box(Vector3(48.5, h, 0.5), Vector3(0, h * 0.5, 13), WALL_COLOR)
	_static_box(Vector3(48.5, h, 0.5), Vector3(0, h * 0.5, -77), WALL_COLOR)

## Area 1: fixed paper targets at 10 m, 25 m and 50 m.
func _area_basic_range() -> void:
	_prop(WALL, Vector3(-7, 0, 0), Vector3(4, 3, 0.3), Vector3(0, 1.5, 0), 0.0)
	_prop(WALL, Vector3(7, 0, 0), Vector3(4, 3, 0.3), Vector3(0, 1.5, 0), 0.0)
	for x in [-4.0, 0.0, 4.0]:
		_spawn_target(TARGET_HUMANOID, Vector3(x, 0, -10), 100, 100)
		_spawn_target(TARGET_HUMANOID, Vector3(x, 0, -25), 100, 150)
	for x in [-2.5, 2.5]:
		_spawn_target(TARGET_DISC, Vector3(x, 0, -50), 60, 250)

## Area 2: movement course (left) - platforms, ramp, cover.
func _area_movement_course() -> void:
	# Low platforms to jump onto.
	_static_box(Vector3(3, 0.4, 3), Vector3(-14, 0.2, -21), ACCENT_B)
	_static_box(Vector3(3, 0.4, 3), Vector3(-18, 0.6, -25), ACCENT_C)
	# Ramp up to a raised lane.
	_slope(Vector3(-14, 0.5, -25.5), 3.0, 3.0, 1.0, true, ACCENT_B)
	_static_box(Vector3(3, 0.3, 4), Vector3(-14, 1.15, -30), ACCENT_B)
	# Cover and climbable crates.
	_prop(CRATE, Vector3(-8, 0, -33), Vector3(1, 1, 1), Vector3(0, 0.5, 0))
	_prop(CRATE, Vector3(-8, 1, -33), Vector3(1, 1, 1), Vector3(0, 0.5, 0))
	_prop(BARRIER, Vector3(-12, 0, -35), Vector3(2, 1, 0.4), Vector3(0, 0.5, 0))
	_prop(BARRIER, Vector3(-17, 0, -38), Vector3(2, 1, 0.4), Vector3(0, 0.5, 0), 90.0)
	# Decorative ramp module (visual only; the slope above is the walkable one).
	_prop(RAMP, Vector3(-21, 0, -31), Vector3.ZERO, Vector3.ZERO, 0.0)

## Area 3: moving targets (right).
func _area_moving_targets() -> void:
	_prop(WALL, Vector3(13, 0, -14), Vector3(4, 3, 0.3), Vector3(0, 1.5, 0), 90.0)
	_spawn_target(TARGET_HUMANOID, Vector3(13, 0, -22), 100, 200, TargetMover.Mode.HORIZONTAL, 4.0, 1.3)
	_spawn_target(TARGET_HUMANOID, Vector3(13, 0, -30), 100, 250, TargetMover.Mode.HORIZONTAL, 5.0, 2.0)
	_spawn_target(TARGET_DISC, Vector3(18, 0, -26), 60, 300, TargetMover.Mode.VERTICAL, 1.2, 1.6)

## Area 4: reaction test - pop-up targets that appear at random.
func _area_reaction_test() -> void:
	var xs := [-6.0, -3.0, 0.0, 3.0, 6.0]
	for x in xs:
		_spawn_target(TARGET_DISC, Vector3(x, 0, -60), 50, 300,
			TargetMover.Mode.POPUP, 1.6, 1.0, 1.5)

## Area 5: grenade pit - walls hide grouped targets so the blast is useful.
func _area_grenade_pit() -> void:
	# Enclosing side walls with an opening, and a back cluster.
	_prop(WALL, Vector3(-6, 0, -70), Vector3(4, 3, 0.3), Vector3(0, 1.5, 0), 0.0)
	_prop(WALL, Vector3(0, 0, -73), Vector3(4, 3, 0.3), Vector3(0, 1.5, 0), 90.0)
	_prop(BARRIER, Vector3(4, 0, -68), Vector3(2, 1, 0.4), Vector3(0, 0.5, 0), 90.0)
	_prop(BUILDING, Vector3(-14, 0, -68), Vector3(6.4, 5.3, 6.4), Vector3(0, 2.6, 0))
	# Grouped targets behind cover.
	_spawn_target(TARGET_HUMANOID, Vector3(-2, 0, -71), 120, 300)
	_spawn_target(TARGET_HUMANOID, Vector3(0, 0, -71), 120, 300)
	_spawn_target(TARGET_HUMANOID, Vector3(2, 0, -71), 120, 300)
	_spawn_target(TARGET_DISC, Vector3(8, 0, -72), 60, 350)
