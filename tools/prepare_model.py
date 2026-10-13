"""Cleans a Tripo GLB for the game, in background Blender.

    blender --background --factory-startup --python tools/prepare_model.py -- \
        --in raw.glb --out game/assets/models/keeper.glb --size 1.65 [--measure height]
        [--max-faces 30000] [--yaw 0] [--min-part 0.02] [--preview out_dir]

Steps: import, drop stray loose parts (generated floors, floating scraps),
optional yaw fix, scale so the chosen dimension matches --size (meters), put
the origin at the bottom center, optional decimate, apply transforms, export
GLB (+ animations/armature kept), and render front/side/top preview PNGs.
Rigged models are only scaled/re-origined; mesh edits are skipped so skinning
stays intact.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--in", dest="src", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--size", type=float, required=True)
ap.add_argument("--measure", choices=["height", "length", "width"], default="height")
ap.add_argument("--max-faces", type=int, default=0)
ap.add_argument("--yaw", type=float, default=0.0, help="degrees about up axis")
ap.add_argument("--pitch", type=float, default=0.0, help="degrees about the X axis (applied before yaw)")
ap.add_argument("--min-part", type=float, default=0.02, help="drop loose parts smaller than this fraction of the bounds")
ap.add_argument("--preview", default="")
ap.add_argument("--tex", type=int, default=2048, help="max texture size in pixels (0 = keep)")
args = ap.parse_args(argv)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=args.src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
rigged = bool(armatures) or any(o.find_armature() for o in meshes)
report = {"src": args.src, "rigged": rigged, "meshes": len(meshes)}


def world_bounds(objs):
    # Real vertex positions: bound_box can be stale right after mesh edits.
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def face_count():
    return sum(len(o.data.polygons) for o in meshes)


report["faces_before"] = face_count()

if not rigged:
    # Bake object transforms into the mesh so every later step works in world space.
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    for o in [o for o in bpy.context.scene.objects if o.type == "EMPTY"]:
        bpy.data.objects.remove(o)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Some exports are split along UV seams into triangle soup: every face its own
    # "island". Weld coincident vertices first (UVs live on loops, so they survive),
    # otherwise loose-part removal eats real surface and collapse can't simplify.
    for o in meshes:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        bm.to_mesh(o.data)
        bm.free()

    # Remove loose islands much smaller than the model (generated floor bits, specks).
    lo, hi = world_bounds(meshes)
    diag = (hi - lo).length
    removed = 0
    for o in meshes:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.verts.ensure_lookup_table()
        seen = set()
        doomed = []
        for v in bm.verts:
            if v.index in seen:
                continue
            stack, island = [v], []
            seen.add(v.index)
            while stack:
                cur = stack.pop()
                island.append(cur)
                for e in cur.link_edges:
                    w = e.other_vert(cur)
                    if w.index not in seen:
                        seen.add(w.index)
                        stack.append(w)
            xs = [p.co for p in island]
            span = (Vector((max(c.x for c in xs), max(c.y for c in xs), max(c.z for c in xs))) -
                    Vector((min(c.x for c in xs), min(c.y for c in xs), min(c.z for c in xs)))).length
            if span < diag * args.min_part:
                doomed.extend(island)
        if doomed:
            removed += len(doomed)
            bmesh.ops.delete(bm, geom=list(set(doomed)), context="VERTS")
            bm.to_mesh(o.data)
        bm.free()
    report["loose_verts_removed"] = removed

    for _ in range(4):
        if not args.max_faces or face_count() <= args.max_faces * 1.05:
            break
        ratio = args.max_faces / face_count()
        for o in meshes:
            mod = o.modifiers.new("decimate", "DECIMATE")
            mod.ratio = ratio
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier=mod.name)

roots = [o for o in bpy.context.scene.objects if o.parent is None]
for o in roots:
    o.rotation_mode = "XYZ"  # glTF import uses quaternions, which ignore rotation_euler
if args.pitch:
    for o in roots:
        o.rotation_euler.x += math.radians(args.pitch)
    bpy.context.view_layer.update()
    if not rigged:
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.object.transform_apply(rotation=True)
if args.yaw:
    for o in roots:
        o.rotation_euler.z += math.radians(args.yaw)
    bpy.context.view_layer.update()

lo, hi = world_bounds(meshes)
dims = hi - lo
measured = {"height": dims.z, "length": max(dims.x, dims.y), "width": min(dims.x, dims.y)}[args.measure]
scale = args.size / max(measured, 1e-6)
for o in roots:
    o.scale *= scale
    o.location *= scale
bpy.context.view_layer.update()
lo, hi = world_bounds(meshes)
offset = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
for o in roots:
    o.location -= offset
bpy.context.view_layer.update()
if not rigged:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Tripo surfaces are often thin single shells; after decimation a few faces
# point inward and would be culled into see-through specks. Render both sides.
for mat in bpy.data.materials:
    mat.use_backface_culling = False

# Huge Tripo textures (8K) cost lots of VRAM for no visible gain at game distance.
resized = []
if args.tex:
    for img in bpy.data.images:
        w, h = img.size
        if max(w, h) > args.tex:
            f = args.tex / max(w, h)
            img.scale(int(w * f), int(h * f))
            resized.append(f"{img.name} {w}->{int(w * f)}")
report["textures_resized"] = resized

lo, hi = world_bounds(meshes)
report.update({
    "faces_after": face_count(),
    "dims_m": [round(d, 3) for d in (hi - lo)],
    "scale_applied": round(scale, 5),
    "materials": sorted({s.material.name for o in meshes for s in o.material_slots if s.material}),
    "actions": [a.name for a in bpy.data.actions],
})

Path(args.out).parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=args.out, export_format="GLB", export_apply=not rigged,
                          export_animations=True, export_yup=True)

if args.preview:
    out_dir = Path(args.preview)
    out_dir.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    world = bpy.data.worlds.new("w")
    world.color = (0.12, 0.14, 0.18)
    scene.world = world
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    lo, hi = world_bounds(meshes)
    size = max(hi - lo) * 1.25
    cam_data.ortho_scale = size
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    center = (lo + hi) / 2
    # Blender front view looks along +Y; glTF/Godot +Z forward maps to Blender -Y.
    views = {"front": (Vector((0, -1, 0)), (90, 0, 0)), "side": (Vector((1, 0, 0)), (90, 0, 90)), "top": (Vector((0, 0, 1)), (0, 0, 0))}
    stem = Path(args.out).stem
    for name, (direction, rot) in views.items():
        cam.location = center + direction * size * 2
        cam.rotation_euler = [math.radians(r) for r in rot]
        scene.render.filepath = str(out_dir / f"{stem}_{name}.png")
        bpy.ops.render.render(write_still=True)

print("PREPARE_REPORT " + json.dumps(report))
