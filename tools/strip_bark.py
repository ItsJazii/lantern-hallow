"""Removes the brown bark faces from a foliage model, keeping only leaves.
Each face's colour is sampled from the base-colour texture at its UV centre;
faces that read as brown/orange (red clearly above green, low saturation of
green) are deleted. Usage:
  blender -b -P strip_bark.py -- in.glb out.glb
"""
import sys

import bmesh
import bpy

a = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0])
for o in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
    mat = o.active_material
    img = None
    for n in mat.node_tree.nodes:
        if n.type == "TEX_IMAGE":
            for l in n.outputs[0].links:
                if l.to_socket.name == "Base Color":
                    img = n.image
    w, h = img.size
    px = img.pixels[:]
    bm = bmesh.new()
    bm.from_mesh(o.data)
    uv = bm.loops.layers.uv.active
    dead = []
    for f in bm.faces:
        cu = sum(l[uv].uv.x for l in f.loops) / len(f.loops)
        cv = sum(l[uv].uv.y for l in f.loops) / len(f.loops)
        x = min(w - 1, max(0, int((cu % 1.0) * w)))
        y = min(h - 1, max(0, int((cv % 1.0) * h)))
        i = (y * w + x) * 4
        r, g, b = px[i], px[i + 1], px[i + 2]
        if r > g * 1.05:  # bark: redder than green
            dead.append(f)
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    bm.to_mesh(o.data)
    print("STRIP", o.name, "removed", len(dead), "of", len(dead) + len(bm.faces))
    bm.free()
bpy.ops.export_scene.gltf(filepath=a[1], export_format="GLB")
