extends Node3D
class_name RangeTarget
## A practice target. Tracks health, flashes on hit, awards score and (optionally)
## respawns. Hit direction and head/body is decided by its TargetHitbox children.

enum Move { NONE, HORIZONTAL, VERTICAL, POPUP }

@export var max_health: float = 100.0
@export var score_value: int = 100
@export var respawn_delay: float = 2.5
@export var respawns: bool = true

var health: float = 100.0
var destroyed: bool = false

@onready var pivot: Node3D = $Pivot

var _flash_mat: StandardMaterial3D
var _respawn_left: float = 0.0

func _ready() -> void:
	add_to_group("target")
	health = max_health
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.albedo_color = Color(1, 1, 1, 0.85)
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.emission_enabled = true
	_flash_mat.emission = Color(1, 1, 1)

func _process(delta: float) -> void:
	if destroyed and respawns:
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			_respawn()

func receive_hit(amount: float, is_head: bool, position: Vector3, _direction: Vector3) -> Dictionary:
	if destroyed:
		return {"damage": 0, "headshot": is_head, "killed": false}
	var dealt := int(round(amount))
	health -= amount
	_flash()
	_punch()
	Fx.damage_number(position, dealt, is_head)
	AudioManager.play_sfx_3d("target_hit", position, -6.0)
	var killed := health <= 0.0
	if killed:
		_destroy()
	return {"damage": dealt, "headshot": is_head, "killed": killed}

func _flash() -> void:
	_set_overlay(_flash_mat)
	get_tree().create_timer(0.07).timeout.connect(func(): _set_overlay(null))

func _set_overlay(material: Material) -> void:
	if not is_instance_valid(pivot):
		return
	for mesh in _meshes(pivot):
		mesh.material_overlay = material

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			found.append(child)
		found.append_array(_meshes(child))
	return found

func _punch() -> void:
	if not is_instance_valid(pivot):
		return
	var tween := pivot.create_tween()
	tween.tween_property(pivot, "scale", Vector3.ONE * 1.08, 0.05)
	tween.tween_property(pivot, "scale", Vector3.ONE, 0.08)

func _destroy() -> void:
	destroyed = true
	GameState.register_destroyed()
	GameState.add_score(score_value)
	AudioManager.play_sfx_3d("target_destroy", global_position, -3.0)
	Events.target_destroyed.emit(global_position)
	Fx.destroy_burst(global_position + Vector3.UP * 1.0)
	_set_hitboxes_active(false)
	if is_instance_valid(pivot):
		pivot.visible = false
	if respawns:
		_respawn_left = respawn_delay

func _respawn() -> void:
	destroyed = false
	health = max_health
	if is_instance_valid(pivot):
		pivot.visible = true
		pivot.scale = Vector3.ONE
	_set_hitboxes_active(true)

func _set_hitboxes_active(active: bool) -> void:
	for hitbox in _hitboxes(pivot):
		hitbox.set_active(active)

func _hitboxes(node: Node) -> Array[TargetHitbox]:
	var found: Array[TargetHitbox] = []
	for child in node.get_children():
		if child is TargetHitbox:
			found.append(child)
		found.append_array(_hitboxes(child))
	return found
