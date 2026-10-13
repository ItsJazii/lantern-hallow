"""Deletes the faces of a model that lie entirely below a fraction of its height
(e.g. the soil block under a grass patch, which ends up buried anyway), then
re-exports it. Usage:
  blender -b -P cut_below.py -- in.glb out.glb 0.35
"""
import sys
import bmesh
import bpy

a = sys.argv[sys.argv.index("--") + 1:]
src, dst, frac = a[0], a[1], float(a[2])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
    mw = o.matrix_world
    bm = bmesh.new()
    bm.from_mesh(o.data)
    zs = [(mw @ v.co).z for v in bm.verts]
    cut = min(zs) + (max(zs) - min(zs)) * frac
    dead = [f for f in bm.faces if max((mw @ v.co).z for v in f.verts) < cut]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    bm.to_mesh(o.data)
    bm.free()
    print("CUT", o.name, "removed", len(dead), "faces below", round(cut, 4))
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB")
