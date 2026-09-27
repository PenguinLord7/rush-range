extends Node3D
class_name TargetMover
## Attached to a target's Pivot. Moves the model + hitboxes relative to their
## placed position. One script covers every moving target type.

enum Mode { NONE, HORIZONTAL, VERTICAL, POPUP }

@export var mode: Mode = Mode.NONE
@export var distance: float = 3.0
@export var speed: float = 1.2
@export var phase: float = 0.0
@export var randomize_phase: bool = true
@export var popup_up_time: float = 1.6
@export var popup_down_time: float = 1.1

var _base: Vector3
var _t: float = 0.0
var _popup_t: float = 0.0
var _up: bool = true

func _ready() -> void:
	_base = position
	_t = phase + (randf() * TAU if randomize_phase else 0.0)
	_popup_t = popup_up_time

func _process(delta: float) -> void:
	match mode:
		Mode.NONE:
			pass
		Mode.HORIZONTAL:
			_t += delta * speed
			position = _base + Vector3(sin(_t) * distance, 0.0, 0.0)
		Mode.VERTICAL:
			_t += delta * speed
			var f := sin(_t) * 0.5 + 0.5
			position = _base + Vector3(0.0, f * distance, 0.0)
		Mode.POPUP:
			_popup_t -= delta
			var target_y := _base.y + (distance if _up else 0.0)
			position.y = lerpf(position.y, target_y, minf(7.0 * delta, 1.0))
			if _popup_t <= 0.0:
				_up = not _up
				_popup_t = popup_up_time if _up else popup_down_time
	if _t > TAU * 1000.0:
		_t = fmod(_t, TAU)
