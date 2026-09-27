extends WeaponBase
class_name Fist
## Melee "weapon". A short sphere-cast in front of the camera damages the first
## target in range. Alternating left/right hooks drive the punch animation.

@export var punch_reach: float = 0.85
@export var punch_radius: float = 0.45

var _punch: float = 0.0
var _alternate: bool = false

func _process(delta: float) -> void:
	_punch = move_toward(_punch, 0.0, delta * 5.0)
	super._process(delta)

func _fire(origin: Vector3, dir: Vector3) -> void:
	_alternate = not _alternate
	var space := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = punch_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = Transform3D(Basis(), origin + dir * punch_reach)
	params.collision_mask = Layers.SHOOTABLE
	var hits := space.intersect_shape(params, 8)
	var connected := false
	for h in hits:
		var collider: Object = h.get("collider")
		if collider and collider.has_method("apply_hit"):
			var result: Dictionary = collider.apply_hit(damage, collider.global_position, dir)
			var head: bool = bool(result.get("headshot", false))
			var killed: bool = bool(result.get("killed", false))
			GameState.register_hit()
			Events.damage_dealt.emit(collider.global_position, int(result.get("damage", damage)), head)
			Events.hit_confirmed.emit(killed, head)
			connected = true
			break
	var pos := origin + dir * punch_reach
	AudioManager.play_sfx_3d("punch", pos, -3.0 if connected else -8.0)
	if connected:
		Fx.impact(pos, dir, Color(1.0, 0.4, 0.3))

func _extra_weapon_offset() -> Vector3:
	var side := 0.05 if _alternate else -0.05
	return Vector3(side * _punch, -0.03 * _punch, -0.20 * _punch)

func _extra_weapon_rotation() -> Vector3:
	var side := -0.45 if _alternate else 0.45
	return Vector3(-0.5 * _punch, side * _punch, 0.0)
