extends WeaponBase
class_name Handgun
## Precise semi-automatic sidearm. Accurate when shots are paced; the first
## shot after a pause is tighter, spam-firing opens the recoil up.

var _since_last: float = 99.0

func _process(delta: float) -> void:
	_since_last += delta
	super._process(delta)

func _shoot() -> void:
	super._shoot()
	_since_last = 0.0

func recoil_multiplier() -> float:
	return 1.0 if _since_last > 0.30 else 1.5
