extends SceneTree
## Prints the world-space AABB size of each imported model. Diagnostic tool.

const PATHS := [
	"res://models/weapons/rifle.glb",
	"res://models/weapons/handgun.glb",
	"res://models/weapons/grenade.glb",
	"res://models/player/hand.glb",
	"res://models/environment/target_humanoid.glb",
	"res://models/environment/target_disc.glb",
	"res://models/environment/wall.glb",
	"res://models/environment/barrier.glb",
	"res://models/environment/crate.glb",
	"res://models/environment/platform.glb",
	"res://models/environment/ramp.glb",
	"res://models/environment/building.glb",
]

func _initialize() -> void:
	for path in PATHS:
		var packed = load(path)
		if packed == null:
			print(path, " LOAD FAILED")
			continue
		var inst = packed.instantiate()
		var root := Node3D.new()
		root.add_child(inst)
		var aabb := _combined_aabb(inst)
		print("%-48s size=%s min=%s max=%s" % [path, str(aabb.size), str(aabb.position), str(aabb.end)])
		root.free()
	quit()

func _combined_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for child in _meshes(node):
		var mesh_aabb: AABB = child.get_aabb()
		var xform: Transform3D = child.global_transform if child.is_inside_tree() else child.transform
		var world := xform * mesh_aabb
		if first:
			result = world
			first = false
		else:
			result = result.merge(world)
	return result

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			out.append(child)
		out.append_array(_meshes(child))
	return out
