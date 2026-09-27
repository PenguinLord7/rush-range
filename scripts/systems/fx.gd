extends Node
## Code-built, pooled visual effects: muzzle flashes, bullet impacts, tracers,
## explosions, shell casings and floating damage numbers.
##
## Nothing here needs .tscn files or authored particles - everything is
## constructed from primitives so the project stays easy to inspect and the
## effects stay cheap. One-shot emitters are reused from pools.

var _root: Node3D

var _impact_pool: Array[GPUParticles3D] = []
var _muzzle_pool: Array[GPUParticles3D] = []
var _casing_pool: Array[GPUParticles3D] = []
var _explosion_pool: Array[GPUParticles3D] = []
var _tracer_pool: Array[MeshInstance3D] = []
var _light_pool: Array[OmniLight3D] = []
var _number_pool: Array[Label3D] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Node3D.new()
	_root.name = "FxRoot"
	add_child(_root)

func muzzle_flash(position: Vector3, direction: Vector3) -> void:
	var p: GPUParticles3D = _acquire(_muzzle_pool, _build_muzzle)
	p.global_position = position
	_orient(p, direction)
	p.restart()
	AudioManager.play_sfx("muzzle_extra", -40.0)  # silent if missing

func impact(position: Vector3, normal: Vector3 = Vector3.UP, color: Color = Color(1.0, 0.85, 0.45)) -> void:
	var p: GPUParticles3D = _acquire(_impact_pool, _build_impact)
	p.global_position = position + normal * 0.02
	_orient(p, normal)
	p.restart()

func eject_casing(position: Vector3, right: Vector3, up: Vector3) -> void:
	var p: GPUParticles3D = _acquire(_casing_pool, _build_casing)
	p.global_position = position
	_orient(p, (right + up * 0.6).normalized())
	p.restart()

func tracer(from: Vector3, to: Vector3) -> void:
	var node: MeshInstance3D = _acquire(_tracer_pool, _build_tracer)
	var dir := to - from
	var length := dir.length()
	if length < 0.05:
		return
	node.visible = true
	node.transform = Transform3D(_basis_y_to(dir.normalized()).scaled(Vector3(1.0, length, 1.0)),
		(from + to) * 0.5)
	var mat := node.material_override as StandardMaterial3D
	mat.albedo_color.a = 0.9
	if node.has_meta("tween"):
		var old: Tween = node.get_meta("tween")
		if old and old.is_valid():
			old.kill()
	var tween: Tween = node.create_tween()
	node.set_meta("tween", tween)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.06)
	tween.tween_callback(func():
		node.visible = false
		node.scale = Vector3.ONE)

func explosion(position: Vector3, radius: float = 4.0) -> void:
	var p: GPUParticles3D = _acquire(_explosion_pool, _build_explosion)
	p.global_position = position
	p.restart()
	var light: OmniLight3D = _acquire(_light_pool, _build_light)
	light.global_position = position + Vector3.UP * 0.5
	light.omni_range = radius * 2.5
	light.light_energy = 6.0
	var tween: Tween = light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.35)
	AudioManager.play_sfx_3d("explosion", position, 2.0)

## Silent burst used when a target is destroyed (the target plays its own cue).
func destroy_burst(position: Vector3) -> void:
	var p: GPUParticles3D = _acquire(_explosion_pool, _build_explosion)
	p.global_position = position
	p.restart()

func damage_number(position: Vector3, amount: int, headshot: bool) -> void:
	var label: Label3D = _acquire(_number_pool, _build_number)
	label.global_position = position
	label.text = str(amount) + ("!" if headshot else "")
	label.modulate = Color(1.0, 0.85, 0.2) if headshot else Color.WHITE
	label.visible = true
	var start := label.global_position
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", start + Vector3(0, 1.1, 0), 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.15)
	tween.chain().tween_callback(func():
		label.visible = false
		label.modulate.a = 1.0)

# --- Pool plumbing ---------------------------------------------------------

func _acquire(pool: Array, builder: Callable):
	for item in pool:
		if _is_idle(item):
			return item
	var node = builder.call()
	_root.add_child(node)
	pool.append(node)
	return node

func _is_idle(item) -> bool:
	if item is GPUParticles3D:
		return not item.emitting
	if item is MeshInstance3D:
		return not item.visible
	if item is OmniLight3D:
		return item.light_energy <= 0.01
	if item is Label3D:
		return not item.visible
	return false

# --- Builders --------------------------------------------------------------

func _build_muzzle() -> GPUParticles3D:
	var p := _make_particles(8, 0.06, Color(1.0, 0.85, 0.3), 2.0, 5.0, 0.10,
		Vector3.ZERO, 22.0, true)
	p.draw_pass_1 = _sphere_mesh(Color(1.0, 0.9, 0.4), 2.5)
	return p

func _build_impact() -> GPUParticles3D:
	return _make_particles(10, 0.35, Color(1.0, 0.8, 0.35), 2.5, 5.5, 0.05,
		Vector3(0, -9.0, 0), 55.0, false)

func _build_casing() -> GPUParticles3D:
	var p := _make_particles(5, 0.6, Color(0.85, 0.65, 0.2), 3.0, 5.0, 0.03,
		Vector3(0, -12.0, 0), 35.0, false)
	var box := BoxMesh.new()
	box.size = Vector3(0.012, 0.012, 0.03)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.65, 0.2)
	mat.metallic = 0.8
	box.material = mat
	p.draw_pass_1 = box
	return p

func _build_explosion() -> GPUParticles3D:
	var p := _make_particles(48, 0.85, Color(1.0, 0.55, 0.12), 5.0, 13.0, 0.28,
		Vector3(0, -10.0, 0), 180.0, true)
	return p

func _build_tracer() -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.015
	mesh.bottom_radius = 0.015
	mesh.height = 1.0
	mesh.radial_segments = 5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.95, 0.6, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.4)
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.visible = false
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _build_light() -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 0.0
	return light

func _build_number() -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.006
	label.font_size = 64
	label.outline_size = 12
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.visible = false
	return label

func _make_particles(amount: int, lifetime: float, color: Color, vmin: float,
		vmax: float, size: float, gravity: Vector3, spread: float,
		along_view: bool) -> GPUParticles3D:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, -1) if along_view else Vector3(0, 1, 0)
	mat.spread = spread
	mat.initial_velocity_min = vmin
	mat.initial_velocity_max = vmax
	mat.gravity = gravity
	mat.scale_min = size * 0.6
	mat.scale_max = size * 1.5
	mat.color = color
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.process_material = mat
	p.draw_pass_1 = _sphere_mesh(color, 2.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

func _sphere_mesh(color: Color, energy: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mesh.material = mat
	return mesh

func _orient(node: Node3D, dir: Vector3) -> void:
	var up := Vector3.UP
	if absf(dir.normalized().dot(up)) > 0.99:
		up = Vector3.RIGHT
	node.look_at(node.global_position + dir, up)

func _basis_y_to(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := Vector3.UP.cross(y)
	if x.length_squared() < 1e-6:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)
