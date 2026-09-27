extends RigidBody3D
class_name GrenadeProjectile
## Physics grenade: bounces off surfaces, blinks, then explodes after its fuse,
## damaging every target within the blast radius with distance falloff.

@export var fuse_time: float = 2.2

var damage: float = 60.0
var blast_radius: float = 4.5
var _fuse: float = 2.2
var _exploded: bool = false
var _blink: float = 0.0

func _ready() -> void:
	collision_layer = Layers.PROJECTILE
	collision_mask = Layers.WORLD | Layers.TARGET | Layers.PLAYER
	_fuse = fuse_time
	_blink = fuse_time

func launch(velocity: Vector3, dmg: float, radius: float) -> void:
	linear_velocity = velocity
	damage = dmg
	blast_radius = radius

func _physics_process(delta: float) -> void:
	_fuse -= delta
	# Blink faster as the fuse runs out.
	_blink += delta
	var rate := lerpf(0.35, 0.08, 1.0 - clampf(_fuse / maxf(fuse_time, 0.01), 0.0, 1.0))
	if fmod(_blink, rate) < delta:
		var light := get_node_or_null("Blink")
		if light is OmniLight3D:
			light.light_energy = 3.0
			get_tree().create_timer(rate * 0.5).timeout.connect(func():
				if is_instance_valid(light):
					light.light_energy = 0.0)
	if _fuse <= 0.0 and not _exploded:
		_explode()

func _explode() -> void:
	_exploded = true
	Fx.explosion(global_position, blast_radius)
	_damage_area()
	_shake_player()
	queue_free()

func _damage_area() -> void:
	var space := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = blast_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = Transform3D(Basis(), global_position)
	params.collision_mask = Layers.TARGET
	var hits := space.intersect_shape(params, 32)
	var seen := {}
	for h in hits:
		var collider: Object = h.get("collider")
		if collider == null or not collider.has_method("apply_hit"):
			continue
		# A target has body + head hitboxes; damage each target only once.
		var key: Object = collider
		if collider.has_method("get_target"):
			key = collider.get_target()
		if key == null or seen.has(key):
			continue
		seen[key] = true
		var target_pos: Vector3 = collider.global_position
		var to_target := target_pos - global_position
		var dist := to_target.length()
		var falloff := clampf(1.0 - dist / maxf(blast_radius, 0.01), 0.25, 1.0)
		var dir := to_target.normalized() if dist > 0.01 else Vector3.UP
		# Blast damage ignores headshot multipliers (call the target directly).
		var result: Dictionary
		if collider.has_method("get_target") and collider.get_target() != null:
			result = collider.get_target().receive_hit(damage * falloff, false, target_pos, dir)
		else:
			result = collider.apply_hit(damage * falloff, target_pos, dir)
		Events.damage_dealt.emit(target_pos, int(result.get("damage", damage * falloff)), false)
		Events.hit_confirmed.emit(bool(result.get("killed", false)), false)

func _shake_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player.has_method("get_camera"):
		var cam: Camera3D = player.get_camera()
		var dist: float = cam.global_position.distance_to(global_position)
		var strength := clampf(1.0 - dist / (blast_radius * 3.0), 0.0, 1.0)
		if strength > 0.0:
			cam.add_shake(strength * 1.5)
			player.apply_blast(dir_to_player(cam), strength)

func dir_to_player(cam: Camera3D) -> Vector3:
	var d := cam.global_position - global_position
	return d.normalized()
