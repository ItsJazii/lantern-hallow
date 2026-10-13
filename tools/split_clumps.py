"""Splits a multi-clump plant model into single clumps. Clump centers come from
k-means on the vertices near the ground; every face goes to the clump whose
center is nearest its own center (in plan). Each clump is re-centered on its
base and exported as <out_prefix>_<n>.glb, biggest first.

  blender -b -P split_clumps.py -- in.glb out_prefix k
"""
import random
import sys

import bmesh
import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
src, prefix, k = a[0], a[1], int(a[2])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
mesh = obj.data
zs = [v.co.z for v in mesh.vertices]
zmin, zmax = min(zs), max(zs)
base = [Vector((v.co.x, v.co.y)) for v in mesh.vertices if v.co.z < zmin + (zmax - zmin) * 0.15]
random.seed(3)
centers = random.sample(base, k)
for _ in range(40):
    groups = [[] for _ in range(k)]
    for p in base:
        groups[min(range(k), key=lambda i: (p - centers[i]).length_squared)].append(p)
    centers = [sum(g, Vector((0, 0))) / len(g) if g else centers[i] for i, g in enumerate(groups)]
print("CENTERS", [tuple(round(c, 3) for c in cc) for cc in centers])

results = []
for i in range(k):
    bpy.ops.object.select_all(action="DESELECT")
    dup = obj.copy()
    dup.data = obj.data.copy()
    bpy.context.collection.objects.link(dup)
    bm = bmesh.new()
    bm.from_mesh(dup.data)
    dead = []
    for f in bm.faces:
        c = f.calc_center_median()
        p = Vector((c.x, c.y))
        if min(range(k), key=lambda j: (p - centers[j]).length_squared) != i:
            dead.append(f)
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    bm.to_mesh(dup.data)
    n = len(bm.faces)
    bm.free()
    # Origin at the clump's base center.
    cx, cy = centers[i]
    for v in dup.data.vertices:
        v.co.x -= cx
        v.co.y -= cy
    results.append((n, dup))
obj.hide_set(True)
results.sort(key=lambda r: -r[0])
for idx, (n, dup) in enumerate(results, 1):
    bpy.ops.object.select_all(action="DESELECT")
    dup.select_set(True)
    bpy.context.view_layer.objects.active = dup
    out = "%s_%d.glb" % (prefix, idx)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True)
    print("CLUMP", out, n, "faces")
