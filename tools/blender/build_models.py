"""
build_models.py

Programmatically builds all original low-poly 3D models for the Godot 4 game
and exports each as its own .glb (GLB) file.

Run headless:
    blender --background --factory-startup --python /home/penguin/godot/tools/blender/build_models.py

Coordinate convention
---------------------
Blender is Z-up / -Y forward. Godot (and glTF after export) is Y-up with
forward = -Z.  The exporter maps a Blender point (bx, by, bz) to the glTF point
(bx, bz, -by).  This script therefore lets you author everything in *Godot*
coordinates and converts on the fly:

        g2b(x, y, z) -> (x, -z, y)

So a muzzle placed at Godot z = -0.55 ends up at Blender y = +0.55, which the
exporter turns back into glTF/Godot z = -0.55 (forward).  Up (+Y Godot) becomes
Blender +Z, right (+X) stays +X.

Everything is authored in meters.
"""

import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix

# --------------------------------------------------------------------------- #
# Paths
# --------------------------------------------------------------------------- #

MODELS_ROOT = "/home/penguin/godot/models"

# --------------------------------------------------------------------------- #
# Coordinate helpers
# --------------------------------------------------------------------------- #

_RX90 = Matrix.Rotation(math.radians(90.0), 3, "X")


def g2b(x, y, z):
    """Godot coordinate -> Blender coordinate."""
    return (x, -z, y)


def _godot_rot_to_blender(rot):
    """Convert a Godot-space XYZ euler (radians) to a Blender-space euler."""
    if rot == (0.0, 0.0, 0.0):
        return (0.0, 0.0, 0.0)
    rg = Euler(rot, "XYZ").to_matrix()
    rb = _RX90 @ rg @ _RX90.transposed()
    return tuple(rb.to_euler())


# --------------------------------------------------------------------------- #
# Scene helpers
# --------------------------------------------------------------------------- #


def reset_scene():
    """Remove every object and datablock so each model starts clean."""
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)
    for curve in list(bpy.data.curves):
        bpy.data.curves.remove(curve)


def make_material(name, color, roughness=0.6, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
    mat.diffuse_color = (color[0], color[1], color[2], 1.0)
    return mat


def _select_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def _apply_transforms(obj):
    _select_only(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def _finish(obj, material, flat=True):
    if material is not None:
        obj.data.materials.append(material)
    if flat:
        for poly in obj.data.polygons:
            poly.use_smooth = False
    return obj


# --------------------------------------------------------------------------- #
# Primitive helpers (all positions/sizes are in Godot coordinates)
# --------------------------------------------------------------------------- #


def add_box(name, center, size, material, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=g2b(*center))
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_euler = _godot_rot_to_blender(rot)
    # Blender axes: x = Godot x, y = Godot z, z = Godot y
    obj.scale = (size[0], size[2], size[1])
    _apply_transforms(obj)
    return _finish(obj, material)


def add_cylinder(name, center, radius, depth, material, axis="Z", verts=12):
    """Cylinder with its axis along the requested *Godot* axis."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts, radius=radius, depth=depth, location=g2b(*center)
    )
    obj = bpy.context.active_object
    obj.name = name
    if axis == "Z":  # Godot forward  -> Blender +Y
        obj.rotation_euler = (math.radians(-90.0), 0.0, 0.0)
    elif axis == "X":  # Godot right    -> Blender +X
        obj.rotation_euler = (0.0, math.radians(90.0), 0.0)
    # axis == "Y" (up) -> default Blender +Z, no rotation
    _apply_transforms(obj)
    return _finish(obj, material)


def add_cone(name, center, radius1, radius2, depth, material, axis="Y", verts=12):
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts,
        radius1=radius1,
        radius2=radius2,
        depth=depth,
        location=g2b(*center),
    )
    obj = bpy.context.active_object
    obj.name = name
    if axis == "Z":
        obj.rotation_euler = (math.radians(-90.0), 0.0, 0.0)
    elif axis == "X":
        obj.rotation_euler = (0.0, math.radians(90.0), 0.0)
    _apply_transforms(obj)
    return _finish(obj, material)


def add_ico_sphere(name, center, radius, material, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=subdivisions, radius=radius, location=g2b(*center)
    )
    obj = bpy.context.active_object
    obj.name = name
    _apply_transforms(obj)
    return _finish(obj, material)


def add_torus(
    name,
    center,
    major_radius,
    minor_radius,
    material,
    rot=(0.0, 0.0, 0.0),
    major_segments=16,
    minor_segments=6,
):
    bpy.ops.mesh.primitive_torus_add(
        location=g2b(*center),
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=major_segments,
        minor_segments=minor_segments,
    )
    obj = bpy.context.active_object
    obj.name = name
    if rot != (0.0, 0.0, 0.0):
        obj.rotation_euler = _godot_rot_to_blender(rot)
        _apply_transforms(obj)
    return _finish(obj, material)


def add_wedge(name, material):
    """Solid ramp wedge: 2 m wide (X), 2 m long (Z), 1 m rise toward -Z."""
    verts = [
        (-1.0, 0.0, 1.0),   # A low  left
        (1.0, 0.0, 1.0),    # B low  right
        (-1.0, 1.0, -1.0),  # C high left
        (1.0, 1.0, -1.0),   # D high right
        (-1.0, 0.0, -1.0),  # E high left  bottom
        (1.0, 0.0, -1.0),   # F high right bottom
    ]
    faces = [
        (0, 1, 5, 4),  # bottom
        (0, 2, 3, 1),  # sloped top surface
        (4, 5, 3, 2),  # vertical back
        (0, 4, 2),     # left triangle
        (1, 3, 5),     # right triangle
    ]
    bverts = [g2b(*v) for v in verts]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(bverts, [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return _finish(obj, material)


# --------------------------------------------------------------------------- #
# Export
# --------------------------------------------------------------------------- #


def export_glb(relative_path):
    path = os.path.join(MODELS_ROOT, relative_path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    try:
        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format="GLB",
            use_selection=False,
            export_apply=True,
            export_yup=True,
        )
    except TypeError:
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB")
    return path


def report_bounds(label, expected_negative_z=True):
    """Print the model bounds expressed back in Godot coordinates."""
    lo = [1e9, 1e9, 1e9]
    hi = [-1e9, -1e9, -1e9]
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            wx, wy, wz = obj.matrix_world @ Matrix.Translation(corner).to_translation()
            # Blender -> Godot: (bx, bz, -by)
            gx, gy, gz = wx, wz, -wy
            lo[0], lo[1], lo[2] = min(lo[0], gx), min(lo[1], gy), min(lo[2], gz)
            hi[0], hi[1], hi[2] = max(hi[0], gx), max(hi[1], gy), max(hi[2], gz)
    print(
        "  bounds (Godot m) x[{:.3f},{:.3f}] y[{:.3f},{:.3f}] z[{:.3f},{:.3f}]".format(
            lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]
        )
    )


# --------------------------------------------------------------------------- #
# Shared palette
# --------------------------------------------------------------------------- #

GUNMETAL = (0.16, 0.17, 0.20)
DARK = (0.07, 0.07, 0.08)
ORANGE = (0.85, 0.35, 0.12)
BLUE = (0.35, 0.55, 0.95)
OLIVE = (0.25, 0.40, 0.20)
OLIVE_DARK = (0.16, 0.26, 0.13)
YELLOW = (0.90, 0.78, 0.15)
SKIN = (0.80, 0.60, 0.48)
WHITE = (0.95, 0.95, 0.95)
RED = (0.85, 0.15, 0.15)


# --------------------------------------------------------------------------- #
# Model builders
# --------------------------------------------------------------------------- #


def build_rifle():
    metal = make_material("RifleMetal", GUNMETAL, roughness=0.45, metallic=0.6)
    accent = make_material("RifleAccent", ORANGE, roughness=0.55)
    grip = make_material("RifleGrip", DARK, roughness=0.8)

    # Receiver body (pistol grip sits at the origin mount point)
    add_box("Receiver", (0.0, 0.075, -0.02), (0.055, 0.06, 0.34), metal)
    # Barrel (points toward -Z)
    add_cylinder("Barrel", (0.0, 0.085, -0.32), 0.013, 0.40, metal, axis="Z")
    # Muzzle brake
    add_cylinder("MuzzleBrake", (0.0, 0.085, -0.545), 0.019, 0.065, metal,
                 axis="Z", verts=8)
    # Handguard (accent)
    add_box("Handguard", (0.0, 0.075, -0.245), (0.05, 0.055, 0.20), accent)
    # Gas block + front sight
    add_box("GasBlock", (0.0, 0.108, -0.35), (0.022, 0.03, 0.03), metal)
    add_box("FrontSight", (0.0, 0.138, -0.35), (0.008, 0.03, 0.008), metal)
    # Top rail + rear sight
    add_box("TopRail", (0.0, 0.111, -0.06), (0.03, 0.012, 0.22), metal)
    add_box("RearSight", (0.0, 0.128, 0.04), (0.03, 0.02, 0.02), metal)
    # Pistol grip at the origin (mount point), leaning back
    add_box("PistolGrip", (0.0, 0.0, 0.0), (0.04, 0.11, 0.05), grip,
            rot=(math.radians(-20.0), 0.0, 0.0))
    # Trigger guard + trigger, just forward of the grip
    add_box("TriggerGuardBottom", (0.0, -0.005, -0.055), (0.02, 0.008, 0.07), grip)
    add_box("TriggerGuardFront", (0.0, 0.02, -0.088), (0.02, 0.055, 0.008), grip)
    add_box("Trigger", (0.0, 0.015, -0.055), (0.012, 0.045, 0.008), grip)
    # Curved detachable magazine in front of the trigger
    add_box("MagazineTop", (0.0, -0.008, -0.135), (0.034, 0.10, 0.055), metal,
            rot=(math.radians(12.0), 0.0, 0.0))
    add_box("MagazineBottom", (0.0, -0.10, -0.16), (0.034, 0.10, 0.05), metal,
            rot=(math.radians(30.0), 0.0, 0.0))
    # Stock (accent) with connector
    add_box("StockTube", (0.0, 0.075, 0.135), (0.038, 0.045, 0.08), metal)
    add_box("Stock", (0.0, 0.055, 0.235), (0.045, 0.075, 0.13), accent)


def build_handgun():
    metal = make_material("PistolMetal", GUNMETAL, roughness=0.4, metallic=0.6)
    accent = make_material("PistolAccent", BLUE, roughness=0.55)

    # Slide
    add_box("Slide", (0.0, 0.06, -0.015), (0.03, 0.035, 0.20), metal)
    # Frame
    add_box("Frame", (0.0, 0.028, 0.0), (0.028, 0.028, 0.13), metal)
    # Barrel tip
    add_cylinder("Barrel", (0.0, 0.058, -0.118), 0.009, 0.03, metal, axis="Z", verts=10)
    # Grip (accent, angled)
    add_box("Grip", (0.0, -0.03, 0.055), (0.032, 0.10, 0.055), accent,
            rot=(math.radians(-22.0), 0.0, 0.0))
    # Trigger guard + trigger
    add_box("TriggerGuardBottom", (0.0, -0.028, 0.0), (0.018, 0.008, 0.06), metal)
    add_box("TriggerGuardFront", (0.0, -0.012, -0.03), (0.018, 0.032, 0.008), metal)
    add_box("Trigger", (0.0, -0.012, 0.0), (0.01, 0.025, 0.008), accent)
    # Sights
    add_box("FrontSight", (0.0, 0.083, -0.095), (0.006, 0.012, 0.012), metal)
    add_box("RearSight", (0.0, 0.083, 0.075), (0.022, 0.012, 0.012), metal)


def build_hand():
    """Cartoony fist made of exactly two rectangular prisms (mitt + wrist)."""
    skin = make_material("HandSkin", SKIN, roughness=0.85)
    cuff = make_material("HandCuff", (0.28, 0.30, 0.34), roughness=0.9)

    # Big mitt block pointing forward along -Z (origin at the wrist joint).
    add_box("FistBlock", (0.0, 0.0, -0.055), (0.11, 0.10, 0.11), skin)
    # Wrist / forearm block behind it.
    add_box("WristBlock", (0.0, 0.0, 0.055), (0.085, 0.085, 0.10), cuff)


def build_grip_hand():
    """Simple blocky hand for gripping weapons (origin at wrist, forward -Z)."""
    skin = make_material("GripSkin", SKIN, roughness=0.85)
    cuff = make_material("GripCuff", (0.28, 0.30, 0.34), roughness=0.9)

    # Wrist / forearm stub.
    add_box("Wrist", (0.0, 0.0, 0.05), (0.072, 0.072, 0.09), cuff)
    # Palm.
    add_box("Palm", (0.0, 0.0, -0.02), (0.075, 0.085, 0.08), skin)
    # Fingers wrapping forward and down around a grip.
    add_box("Fingers", (0.0, -0.02, -0.065), (0.072, 0.055, 0.05), skin)
    for i in range(3):
        x = -0.024 + i * 0.024
        add_box("FingerRidge%d" % (i + 1), (x, -0.045, -0.07),
                (0.018, 0.03, 0.045), skin)
    # Thumb folded across the top.
    add_box("Thumb", (0.034, 0.022, -0.04), (0.026, 0.03, 0.05), skin,
            rot=(0.0, 0.0, math.radians(-10.0)))


def build_grenade():
    body = make_material("GrenadeBody", OLIVE, roughness=0.8)
    ridge = make_material("GrenadeRidge", OLIVE_DARK, roughness=0.8)
    cap = make_material("GrenadeCap", (0.12, 0.12, 0.12), roughness=0.5, metallic=0.4)
    lever = make_material("GrenadeLever", YELLOW, roughness=0.5)

    add_ico_sphere("Body", (0.0, 0.0, 0.0), 0.05, body, subdivisions=2)
    # Horizontal segmentation rings
    add_torus("RidgeTop", (0.0, 0.02, 0.0), 0.048, 0.004, ridge, major_segments=12,
              minor_segments=4)
    add_torus("RidgeMid", (0.0, 0.0, 0.0), 0.05, 0.004, ridge, major_segments=12,
              minor_segments=4)
    add_torus("RidgeBottom", (0.0, -0.02, 0.0), 0.048, 0.004, ridge,
              major_segments=12, minor_segments=4)
    # Vertical segmentation ribs
    for i in range(8):
        phi = i * math.pi / 4.0
        x = 0.048 * math.sin(phi)
        z = 0.048 * math.cos(phi)
        add_box("Rib%d" % (i + 1), (x, 0.0, z), (0.006, 0.072, 0.006), ridge,
                rot=(0.0, phi, 0.0))
    # Top cap, fuse and safety lever / pin ring
    add_cylinder("Neck", (0.0, 0.062, 0.0), 0.014, 0.026, cap, axis="Y", verts=10)
    add_cylinder("Cap", (0.0, 0.08, 0.0), 0.02, 0.022, cap, axis="Y", verts=10)
    add_box("SafetyLever", (0.028, 0.045, 0.0), (0.01, 0.075, 0.024), lever,
            rot=(0.0, 0.0, math.radians(6.0)))
    add_torus("PinRing", (0.032, 0.085, 0.0), 0.015, 0.0035, lever,
              rot=(math.radians(90.0), 0.0, 0.0), major_segments=12, minor_segments=5)


def build_target_humanoid():
    board_mat = make_material("TBoard", WHITE, roughness=0.9)
    red = make_material("TSilhouette", RED, roughness=0.9)
    stand = make_material("TStand", (0.30, 0.30, 0.33), roughness=0.7, metallic=0.3)

    add_box("Board", (0.0, 0.9, 0.0), (0.6, 1.8, 0.08), board_mat)
    # Humanoid silhouette on the +Z face.  Each layer sits at a slightly
    # different depth so no two coplanar faces overlap (avoids z-fighting).
    add_box("Torso", (0.0, 1.12, 0.046), (0.34, 0.58, 0.014), red)
    add_box("Hips", (0.0, 0.80, 0.047), (0.30, 0.16, 0.014), red)
    add_cylinder("Head", (0.0, 1.56, 0.048), 0.105, 0.014, red, axis="Z", verts=16)
    for sx, tag in ((-1.0, "L"), (1.0, "R")):
        add_box("Shoulder" + tag, (sx * 0.205, 1.31, 0.049),
                (0.12, 0.14, 0.014), red)
        add_box("Arm" + tag, (sx * 0.255, 1.06, 0.050),
                (0.10, 0.44, 0.014), red)
        add_box("Leg" + tag, (sx * 0.10, 0.47, 0.050),
                (0.12, 0.62, 0.014), red)
    # A-frame base
    for sx in (-0.24, 0.24):
        side = "L" if sx < 0 else "R"
        add_box("LegFront" + side, (sx, 0.475, 0.175), (0.04, 1.0, 0.04), stand,
                rot=(math.radians(-20.0), 0.0, 0.0))
        add_box("LegBack" + side, (sx, 0.475, -0.175), (0.04, 1.0, 0.04), stand,
                rot=(math.radians(20.0), 0.0, 0.0))
    add_box("CrossBar", (0.0, 0.12, 0.0), (0.52, 0.05, 0.05), stand)
    add_box("CenterPost", (0.0, 0.45, -0.09), (0.06, 0.9, 0.06), stand)


def build_target_disc():
    post = make_material("DiscPost", (0.30, 0.30, 0.33), roughness=0.7, metallic=0.3)
    white = make_material("DiscWhite", WHITE, roughness=0.9)
    red = make_material("DiscRed", RED, roughness=0.9)
    blue = make_material("DiscBlue", (0.15, 0.25, 0.70), roughness=0.9)

    add_cylinder("Post", (0.0, 0.525, 0.0), 0.03, 1.05, post, axis="Y", verts=12)
    # Concentric discs, each facing +Z
    add_cylinder("PlateWhite", (0.0, 1.10, 0.0), 0.30, 0.05, white, axis="Z", verts=24)
    add_cylinder("RingRed", (0.0, 1.10, 0.031), 0.22, 0.012, red, axis="Z", verts=24)
    add_cylinder("RingWhite", (0.0, 1.10, 0.038), 0.15, 0.012, white, axis="Z", verts=24)
    add_cylinder("RingBlue", (0.0, 1.10, 0.045), 0.08, 0.012, blue, axis="Z", verts=24)
    add_cylinder("Bullseye", (0.0, 1.10, 0.052), 0.026, 0.012, red, axis="Z", verts=16)


def build_wall():
    body = make_material("WallBody", (0.72, 0.76, 0.80), roughness=0.95)
    trim = make_material("WallTrim", (0.20, 0.55, 0.60), roughness=0.7)
    base = make_material("WallBase", (0.42, 0.46, 0.50), roughness=0.9)

    add_box("WallPanel", (0.0, 1.45, 0.0), (4.0, 2.9, 0.30), body)
    add_box("TopTrim", (0.0, 2.93, 0.0), (4.04, 0.14, 0.34), trim)
    add_box("BaseTrim", (0.0, 0.07, 0.0), (4.04, 0.12, 0.34), base)


def build_barrier():
    body = make_material("BarrierBody", (0.90, 0.90, 0.90), roughness=0.85)
    stripe = make_material("BarrierStripe", (0.90, 0.40, 0.10), roughness=0.7)
    foot = make_material("BarrierFoot", (0.25, 0.25, 0.27), roughness=0.8)

    add_box("BarrierBody", (0.0, 0.5, 0.0), (2.0, 1.0, 0.40), body)
    add_box("TopCap", (0.0, 1.0, 0.0), (2.04, 0.06, 0.44), stripe)
    add_box("Foot", (0.0, 0.04, 0.0), (2.0, 0.08, 0.50), foot)
    # Stripes on both faces
    for z, tag in ((0.205, "F"), (-0.205, "B")):
        for i, y in enumerate((0.20, 0.50, 0.80)):
            add_box("Stripe%s%d" % (tag, i + 1), (0.0, y, z), (2.0, 0.15, 0.02), stripe)


def build_crate():
    body = make_material("CrateBody", (0.72, 0.52, 0.30), roughness=0.9)
    frame = make_material("CrateFrame", (0.35, 0.22, 0.12), roughness=0.85)

    add_box("CrateBody", (0.0, 0.5, 0.0), (1.0, 1.0, 1.0), body)
    for x in (-0.46, 0.46):
        for z in (-0.46, 0.46):
            tag = ("L" if x < 0 else "R") + ("F" if z > 0 else "B")
            add_box("CornerPost" + tag, (x, 0.5, z), (0.11, 0.98, 0.11), frame)
    for y in (0.045, 0.955):
        tag = "B" if y < 0.5 else "T"
        for z in (-0.455, 0.455):
            add_box("RailX" + tag + ("F" if z > 0 else "B"), (0.0, y, z),
                    (0.90, 0.08, 0.11), frame)
        for x in (-0.455, 0.455):
            add_box("RailZ" + tag + ("L" if x < 0 else "R"), (x, y, 0.0),
                    (0.11, 0.08, 0.90), frame)


def build_platform():
    body = make_material("PlatformBody", (0.55, 0.55, 0.58), roughness=0.9)
    edge = make_material("PlatformEdge", (0.85, 0.60, 0.10), roughness=0.7)

    add_box("PlatformSlab", (0.0, 0.15, 0.0), (3.0, 0.30, 3.0), body)
    # Colored border frame around the top edge (leaves the deck gray)
    for z in (-1.47, 1.47):
        add_box("EdgeTrimX" + ("B" if z < 0 else "F"), (0.0, 0.315, z),
                (3.06, 0.07, 0.12), edge)
    for x in (-1.47, 1.47):
        add_box("EdgeTrimZ" + ("L" if x < 0 else "R"), (x, 0.31, 0.0),
                (0.12, 0.06, 3.06), edge)


def build_building():
    wall = make_material("BuildingWall", (0.90, 0.88, 0.82), roughness=0.95)
    roof = make_material("BuildingRoof", (0.13, 0.50, 0.50), roughness=0.8)
    floor = make_material("BuildingFloor", (0.45, 0.45, 0.48), roughness=0.95)
    door = make_material("BuildingDoor", (0.20, 0.22, 0.25), roughness=0.8)

    add_box("Floor", (0.0, 0.05, 0.0), (5.6, 0.1, 5.6), floor)
    add_box("WallBack", (0.0, 2.5, -2.9), (5.6, 5.0, 0.2), wall)
    add_box("WallLeft", (-2.9, 2.5, 0.0), (0.2, 5.0, 6.0), wall)
    add_box("WallRight", (2.9, 2.5, 0.0), (0.2, 5.0, 6.0), wall)
    # Front (+Z) wall split around a 1.4 x 2.2 m doorway
    add_box("WallFrontLeft", (-1.75, 2.5, 2.9), (2.1, 5.0, 0.2), wall)
    add_box("WallFrontRight", (1.75, 2.5, 2.9), (2.1, 5.0, 0.2), wall)
    add_box("WallFrontLintel", (0.0, 3.6, 2.9), (1.4, 2.8, 0.2), wall)
    # Recessed doorway
    add_box("DoorRecess", (0.0, 1.09, 2.80), (1.38, 2.18, 0.06), door)
    # Roof slab
    add_box("Roof", (0.0, 5.15, 0.0), (6.4, 0.3, 6.4), roof)


def build_ramp():
    body = make_material("RampBody", (0.50, 0.50, 0.52), roughness=0.9)
    edge = make_material("RampEdge", (0.85, 0.60, 0.10), roughness=0.7)

    add_wedge("Ramp", body)
    # Colored lip capping the high edge
    add_box("HighLip", (0.0, 1.02, -0.94), (2.04, 0.16, 0.10), edge)
    # Colored grip strips lying on the sloped surface (rise 1 over run 2)
    slope = math.atan2(1.0, 2.0)
    for i in range(3):
        z = 0.6 - 0.6 * i
        y = (1.0 - z) / 2.0
        add_box("GripStrip%d" % (i + 1), (0.0, y + 0.025, z), (2.0, 0.02, 0.10),
                edge, rot=(slope, 0.0, 0.0))


# --------------------------------------------------------------------------- #
# Registry + driver
# --------------------------------------------------------------------------- #

MODELS = [
    ("weapons/rifle.glb", build_rifle),
    ("weapons/handgun.glb", build_handgun),
    ("player/hand.glb", build_hand),
    ("player/hand_grip.glb", build_grip_hand),
    ("weapons/grenade.glb", build_grenade),
    ("environment/target_humanoid.glb", build_target_humanoid),
    ("environment/target_disc.glb", build_target_disc),
    ("environment/wall.glb", build_wall),
    ("environment/barrier.glb", build_barrier),
    ("environment/crate.glb", build_crate),
    ("environment/platform.glb", build_platform),
    ("environment/building.glb", build_building),
    ("environment/ramp.glb", build_ramp),
]


def main():
    outputs = []
    for relative_path, builder in MODELS:
        print("\n=== %s ===" % relative_path)
        reset_scene()
        builder()
        report_bounds(relative_path)
        path = export_glb(relative_path)
        outputs.append(path)

    print("\n================ SUMMARY ================")
    all_ok = True
    for path in outputs:
        exists = os.path.isfile(path)
        size = os.path.getsize(path) if exists else 0
        ok = exists and size > 2048
        all_ok = all_ok and ok
        print("{}  {:>8,} bytes  {}".format(
            "OK " if ok else "BAD", size, path))
    print("=========================================")
    print("All models OK" if all_ok else "SOME MODELS FAILED")


if __name__ == "__main__":
    main()
