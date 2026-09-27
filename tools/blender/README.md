# Model generation (Blender → glTF)

All low-poly game models are generated procedurally by `build_models.py` using
Blender in headless mode. There are no hand-authored `.blend` files: the script
is the single source of truth, and it is re-runnable and idempotent (the scene,
meshes and materials are cleared between every model, and output files are
overwritten).

## Regenerate every model

```bash
blender --background --factory-startup --python /home/penguin/godot/tools/blender/build_models.py
```

The script prints per-model bounding boxes (in Godot coordinates) and a final
summary with every output path and file size. Every model must end up larger
than 2 KB; run `ls -la /home/penguin/godot/models/*/` to confirm on disk.

## Outputs

| File | Description |
| --- | --- |
| `models/weapons/rifle.glb` | Stylized assault rifle, grip at origin, muzzle toward -Z |
| `models/weapons/handgun.glb` | Stylized semi-auto pistol, grip at origin |
| `models/player/hand.glb` | First-person right fist + short forearm, origin at wrist |
| `models/weapons/grenade.glb` | Frag grenade with segmented body, lever and pin ring |
| `models/environment/target_humanoid.glb` | Humanoid silhouette board on an A-frame |
| `models/environment/target_disc.glb` | Circular bullseye on a post |
| `models/environment/wall.glb` | 4 × 3 × 0.3 m modular wall panel |
| `models/environment/barrier.glb` | 2 × 1 × 0.4 m low cover barrier |
| `models/environment/crate.glb` | 1 m cargo crate with edge trim |
| `models/environment/platform.glb` | 3 × 0.3 × 3 m raised platform |
| `models/environment/building.glb` | 6 × 5 × 6 m block building with recessed door |
| `models/environment/ramp.glb` | 2 m wide wedge ramp rising 1 m |

## Conventions

- **Coordinate system:** authored in Godot coordinates (`+X` right, `+Y` up,
  forward `-Z`). The helper `g2b()` converts to Blender (Z-up) and the glTF
  exporter converts back to Y-up, so the exported axes match Godot exactly.
- **Origin:** each model's origin is its natural mount point (grip for weapons,
  base centre at `y = 0` for environment pieces) in meters.
- **Style:** flat-shaded, low-poly primitives (boxes, cylinders, cones, icospheres)
  with Principled BSDF materials using flat base colours and no textures.
- **Materials** are exported by default with `export_scene.gltf(..., export_format="GLB")`.

## Editing

Each model lives in its own `build_*` function and is registered in the `MODELS`
list at the bottom of the script. Add a function, append it to `MODELS`, and
re-run the command above.
