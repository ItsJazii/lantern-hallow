"""Renders a model with full PBR materials under game-like lighting (EEVEE):
warm lantern key, cool moon rim, dim blue-hour ambience.

    blender --background --factory-startup --python tools/render_beauty.py -- --in model.glb --out shot.png
"""
import argparse
import math
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--in", dest="src", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--yaw", type=float, default=-30.0, help="camera angle around the model, degrees")
args = ap.parse_args(argv)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=args.src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
pts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
center = (lo + hi) / 2
size = max(hi - lo)

scene = bpy.context.scene
for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        continue
scene.render.resolution_x = scene.render.resolution_y = 900
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"

world = bpy.data.worlds.new("night")
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs[0].default_value = (0.03, 0.05, 0.09, 1)
bg.inputs[1].default_value = 0.6
scene.world = world


def light(kind, energy, color, loc, size_m=0.5):
    data = bpy.data.lights.new(kind, kind)
    data.energy = energy
    data.color = color
    if kind == "AREA":
        data.size = size_m
    obj = bpy.data.objects.new(kind, data)
    obj.location = center + Vector(loc) * size
    scene.collection.objects.link(obj)
    direction = center - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return obj


light("AREA", 60 * size * size, (1.0, 0.72, 0.42), (-1.2, -1.6, 0.9), size)  # lantern key
light("AREA", 18 * size * size, (0.55, 0.68, 1.0), (1.6, 1.4, 1.4), size)    # moon rim
light("AREA", 6 * size * size, (0.45, 0.55, 0.8), (1.5, -1.2, 0.2), size)    # soft blue fill

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.lens = 70
scene.collection.objects.link(cam)
scene.camera = cam
a = math.radians(args.yaw)
cam.location = center + Vector((math.sin(a), -math.cos(a), 0.18)) * size * 3.2
cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.render.filepath = args.out
bpy.ops.render.render(write_still=True)
print("BEAUTY_DONE", args.out)
