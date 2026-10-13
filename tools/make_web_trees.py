"""Blender: lighter copies of the forest trees for the browser build.

Decimates each tree to about TARGET triangles (UVs kept, so the game reuses the
original tree's textures) and exports it without images as <name>_web.glb.

    blender --background --factory-startup --python tools/make_web_trees.py
"""
import pathlib

import bpy

ROOT = pathlib.Path(__file__).resolve().parent.parent
MODELS = ROOT / "game" / "assets" / "models"
TARGET = 3000

for name in ["forest_tree_a", "forest_tree_b"]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(MODELS / f"{name}.glb"))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    before = 0
    for o in meshes:
        tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
        before += tris
        mod = o.modifiers.new("decimate", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = min(1.0, TARGET / max(tris, 1))
        mod.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    after = sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons)
    bpy.ops.export_scene.gltf(filepath=str(MODELS / f"{name}_web.glb"), export_format="GLB",
                              export_image_format="NONE", export_yup=True)
    print(f"WEB_TREE {name}: {before} -> {after} triangles")
