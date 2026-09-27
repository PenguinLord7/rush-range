extends AnimatableBody3D
class_name TargetHitbox
## A damageable collider on a target. Bullets and punches call apply_hit();
## it forwards to the parent RangeTarget with its own multiplier (e.g. the head).

@export var damage_multiplier: float = 1.0
@export var is_head: bool = false

var _target: Node = null

func _ready() -> void:
	collision_layer = Layers.TARGET
	collision_mask = 0
	# Follow the target's transform hierarchy directly (StaticBody-like). With
	# sync_to_physics on, the body would stay at its spawn transform when a
	# parent moves it, which breaks moving targets.
	sync_to_physics = false
	_target = get_parent()
	while _target != null and not (_target is RangeTarget):
		_target = _target.get_parent()
	if _target == null:
		push_warning("TargetHitbox: no RangeTarget ancestor for %s" % name)

func apply_hit(damage: float, position: Vector3, direction: Vector3) -> Dictionary:
	if _target == null:
		return {"damage": 0, "headshot": false, "killed": false}
	return _target.receive_hit(damage * damage_multiplier, is_head, position, direction)

func set_active(active: bool) -> void:
	collision_layer = Layers.TARGET if active else 0

## The owning RangeTarget, so area damage can dedupe multiple hitboxes.
func get_target() -> Node:
	return _target
