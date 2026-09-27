extends WeaponBase
class_name AssaultRifle
## Automatic rifle with a recoil pattern that climbs while the trigger is held,
## rewarding short controlled bursts.

var _sustain: float = 0.0

func _process(delta: float) -> void:
	_sustain = maxf(_sustain - delta * 2.2, 0.0)
	super._process(delta)

func _shoot() -> void:
	super._shoot()
	_sustain = minf(_sustain + 0.55, 3.0)

func recoil_multiplier() -> float:
	return 1.0 + _sustain * 0.16
