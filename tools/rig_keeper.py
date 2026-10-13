"""Auto-rigs and animates the tea keeper (background Blender).

    blender --background --factory-startup --python tools/rig_keeper.py -- \
        --in models_raw/keeper_clean.glb --out game/assets/models/keeper.glb [--preview DIR]

1. Builds a Mixamo-named humanoid skeleton from joint positions measured on the
   cleaned 1.65 m mesh (A-pose, facing -Y in Blender = +Z in Godot).
2. Skins a watertight voxel proxy with Blender's bone-heat weights, then
   transfers those weights to the real mesh (robust on one-piece AI meshes).
3. Keyframes the actions the game uses: idle (loop), talk (loop), wave, happy.
"""
import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--in", dest="src", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--preview", default="")
ap.add_argument("--voxel", type=float, default=0.012)
args = ap.parse_args(argv)

FPS = 24

# Joint positions (x, z) in meters for the character's LEFT side (+X); right is
# mirrored. Depth (y) is measured from nearby vertices.
SPINE = {
    "Hips": (0.0, 0.92), "Spine": (0.0, 1.06), "Spine1": (0.0, 1.20), "Neck": (0.0, 1.33),
    "Head": (0.0, 1.41), "HeadTop": (0.0, 1.65),
}
SIDE = {
    "Shoulder": (0.035, 1.27), "Arm": (0.15, 1.25), "ForeArm": (0.255, 1.04),
    "Hand": (0.31, 0.86), "HandEnd": (0.35, 0.71),
    "UpLeg": (0.09, 0.88), "Leg": (0.12, 0.48), "Foot": (0.135, 0.09), "ToeEnd": (0.135, 0.0),
}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=args.src)
body = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
body.name = "Keeper"
verts = [body.matrix_world @ v.co for v in body.data.vertices]


def depth_at(x, z, r=0.05):
    near = [p.y for p in verts if abs(p.x - x) < r and abs(p.z - z) < r]
    return sum(near) / len(near) if near else 0.0


def refine_xz(x, z, r=0.045):
    """Centers a limb joint on the limb's local cross-section."""
    near = [p for p in verts if abs(p.x - x) < r and abs(p.z - z) < r * 0.5]
    if len(near) < 10:
        return x, z
    return sum(p.x for p in near) / len(near), z


def joint(name, side=0):
    if side == 0:
        x, z = SPINE[name]
    else:
        x, z = SIDE[name]
        x *= side
        if name in ("ForeArm", "Hand"):
            x, z = refine_xz(x, z)
    y = depth_at(x, z) if name not in ("HeadTop", "ToeEnd", "HandEnd") else depth_at(x, z, 0.08)
    if name == "ToeEnd":
        y -= 0.12
    return Vector((x, y, z))


# --- Skeleton -----------------------------------------------------------------------
arm_data = bpy.data.armatures.new("KeeperRig")
rig = bpy.data.objects.new("KeeperRig", arm_data)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
eb = arm_data.edit_bones


def bone(name, head, tail, parent=None, connect=False):
    b = eb.new(name)
    b.head, b.tail = head, tail
    if parent:
        b.parent = eb[parent]
        b.use_connect = connect
    return b


bone("Hips", joint("Hips"), joint("Spine"))
bone("Spine", joint("Spine"), joint("Spine1"), "Hips", True)
bone("Spine1", joint("Spine1"), joint("Neck"), "Spine", True)
bone("Neck", joint("Neck"), joint("Head"), "Spine1", True)
bone("Head", joint("Head"), joint("HeadTop"), "Neck", True)
for side, pre in ((1, "Left"), (-1, "Right")):
    bone(pre + "Shoulder", joint("Shoulder", side), joint("Arm", side), "Spine1")
    bone(pre + "Arm", joint("Arm", side), joint("ForeArm", side), pre + "Shoulder", True)
    bone(pre + "ForeArm", joint("ForeArm", side), joint("Hand", side), pre + "Arm", True)
    bone(pre + "Hand", joint("Hand", side), joint("HandEnd", side), pre + "ForeArm", True)
    bone(pre + "UpLeg", joint("UpLeg", side), joint("Leg", side), "Hips")
    bone(pre + "Leg", joint("Leg", side), joint("Foot", side), pre + "UpLeg", True)
    bone(pre + "Foot", joint("Foot", side), joint("ToeEnd", side), pre + "Leg", True)
# Consistent rolls so local axes behave the same on both sides.
for b in eb:
    b.align_roll(Vector((0, -1, 0)) if abs(b.vector.z) > abs(b.vector.y) else Vector((0, 0, 1)))
bpy.ops.object.mode_set(mode="OBJECT")

# --- Skinning via voxel proxy -----------------------------------------------------------
proxy = body.copy()
proxy.data = body.data.copy()
proxy.name = "WeightProxy"
bpy.context.scene.collection.objects.link(proxy)
for m in list(proxy.data.materials):
    pass
remesh = proxy.modifiers.new("remesh", "REMESH")
remesh.mode = "VOXEL"
remesh.voxel_size = args.voxel
bpy.context.view_layer.objects.active = proxy
bpy.ops.object.modifier_apply(modifier=remesh.name)
dec = proxy.modifiers.new("dec", "DECIMATE")
dec.ratio = min(1.0, 40000 / max(len(proxy.data.polygons), 1))
bpy.ops.object.modifier_apply(modifier=dec.name)
print("PROXY faces", len(proxy.data.polygons))

bpy.ops.object.select_all(action="DESELECT")
proxy.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
counts = {g.name: 0 for g in proxy.vertex_groups}
names = {g.index: g.name for g in proxy.vertex_groups}
for v in proxy.data.vertices:
    for vg in v.groups:
        if vg.weight > 0.2:
            counts[names[vg.group]] += 1
print("PROXY weights per bone", counts)

# Transfer weights onto the real mesh.
dt = body.modifiers.new("weights", "DATA_TRANSFER")
dt.object = proxy
dt.use_vert_data = True
dt.data_types_verts = {"VGROUP_WEIGHTS"}
dt.vert_mapping = "POLYINTERP_NEAREST"
dt.layers_vgroup_select_src = "ALL"
dt.layers_vgroup_select_dst = "NAME"
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.datalayout_transfer(modifier=dt.name)
bpy.ops.object.modifier_apply(modifier=dt.name)


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


# Coat panels hang close to the arms; only geometry within a sleeve's reach of
# the arm chain may follow it. The rest goes back to the torso by height.
groups = {g.name: g for g in body.vertex_groups}
moved = 0
for side in ("Left", "Right"):
    chain = [(rig.data.bones[side + n].head_local, rig.data.bones[side + n].tail_local) for n in ("Arm", "ForeArm", "Hand")]
    arm_groups = [groups[side + n] for n in ("Arm", "ForeArm", "Hand")]
    for v in body.data.vertices:
        p = body.matrix_world @ v.co
        d = min(seg_dist(p, a, b) for a, b in chain)
        keep = smoothstep(0.115, 0.075, d)
        if keep >= 0.999:
            continue
        freed = 0.0
        for g in arm_groups:
            try:
                w = g.weight(v.index)
            except RuntimeError:
                continue
            if w > 0.0:
                g.add([v.index], w * keep, "REPLACE")
                freed += w * (1.0 - keep)
        if freed > 0.0:
            torso = "Spine1" if p.z > 1.15 else ("Spine" if p.z > 1.0 else "Hips")
            groups[torso].add([v.index], freed, "ADD")
            moved += 1
print("BODY coat verts returned to torso", moved)
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
unweighted = sum(1 for v in body.data.vertices if not v.groups)
print("BODY unweighted verts", unweighted, "of", len(body.data.vertices))
bpy.data.objects.remove(proxy)

body.parent = rig
mod = body.modifiers.new("Armature", "ARMATURE")
mod.object = rig

# --- Animation ----------------------------------------------------------------------------
pose = rig.pose.bones
for pb in pose:
    pb.rotation_mode = "QUATERNION"


def local_rot(name, axis, degrees):
    """Rotation about an armature-space axis, expressed in the bone's rest frame."""
    rest = rig.data.bones[name].matrix_local.to_3x3()
    q_world = Quaternion(Vector(axis), math.radians(degrees))
    return (rest.inverted() @ q_world.to_matrix() @ rest).to_quaternion()


def compose(name, rots):
    q = Quaternion()
    for axis, deg in rots:
        q = local_rot(name, axis, deg) @ q
    return q


X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)

# A relaxed stance: arms closer to the body, elbows softly bent, hands forward.
RELAX = {
    "LeftArm": [(Y, 9), (X, -6)], "RightArm": [(Y, -9), (X, -6)],
    "LeftForeArm": [(X, -18), (Y, -4)], "RightForeArm": [(X, -18), (Y, 4)],
    "LeftHand": [(X, -6)], "RightHand": [(X, -6)],
}


def key_pose(action_name, frame, extra):
    """Keys every bone: relaxed stance plus per-bone extra rotations."""
    for pb in pose:
        rots = list(RELAX.get(pb.name, [])) + list(extra.get(pb.name, []))
        pb.rotation_quaternion = compose(pb.name, rots)
        pb.keyframe_insert("rotation_quaternion", frame=frame, group=pb.name)
        pb.location = Vector()
        if pb.name == "Hips":
            pb.location = Vector(extra.get("_hips_loc", (0, 0, 0)))
            pb.keyframe_insert("location", frame=frame, group=pb.name)


def make_action(name, length_s, sampler, loop=True, step=3):
    rig.animation_data_create()
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    frames = int(length_s * FPS)
    for f in range(0, frames + 1, step):
        t = f / frames
        key_pose(name, f, sampler(t if not loop else (t % 1.0)))
    if loop:
        key_pose(name, frames, sampler(0.0))
    action.frame_range = (0, frames)
    for fc in getattr(action, "fcurves", []):
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
    rig.animation_data.action = None
    return action


def s(t, cycles=1.0, phase=0.0):
    return math.sin((t * cycles + phase) * math.tau)


def idle(t):
    breathe = s(t, 2)
    return {
        "Spine": [(X, 1.2 * breathe)],
        "Spine1": [(X, 1.6 * breathe)],
        "Neck": [(X, -0.8 * breathe)],
        "Head": [(Z, 7 * s(t, 1, 0.1)), (X, 2.5 * s(t, 1, 0.35)), (Y, 1.5 * s(t, 1, 0.6))],
        "LeftArm": [(Y, -1.2 * breathe)], "RightArm": [(Y, 1.2 * breathe)],
        "_hips_loc": (0, 0, 0.003 * breathe),
    }


def talk(t):
    g = s(t, 2)
    return {
        "Spine1": [(Z, 3 * s(t, 1)), (X, 1.5 * s(t, 2, 0.2))],
        "Head": [(X, 5 * s(t, 3, 0.1)), (Z, 6 * s(t, 1, 0.3)), (Y, 3 * s(t, 1, 0.55))],
        "RightArm": [(X, -14 - 6 * g), (Y, 6)],
        "RightForeArm": [(X, -40 - 18 * g), (Z, 10 * s(t, 1))],
        "RightHand": [(Y, 12 * s(t, 2, 0.25))],
        "LeftArm": [(X, -8 - 4 * s(t, 1, 0.5))],
        "LeftForeArm": [(X, -28 - 12 * s(t, 1, 0.5))],
    }


def wave(t):
    up = math.sin(min(t / 0.25, 1.0) * math.pi / 2) if t < 0.8 else math.cos((t - 0.8) / 0.2 * math.pi / 2)
    w = s(t, 3) * up
    # Elbow stays fairly low and the forearm does the lifting, so the coat
    # barely moves: a friendly shop-counter wave rather than a big hail.
    return {
        "RightArm": [(Y, 62 * up), (X, -28 * up)],
        "RightForeArm": [(Y, 70 * up), (X, -30 * up), (Y, 20 * w)],
        "RightHand": [(Y, 10 * w)],
        "Head": [(Z, -6 * up), (Y, -4 * up)],
        "Spine1": [(Z, -3 * up)],
    }


def happy(t):
    b = math.sin(t * math.pi)
    return {
        "Spine1": [(X, -5 * b)],
        "Head": [(X, -8 * b), (Y, 5 * s(t, 1.5))],
        "LeftArm": [(Y, -30 * b)], "RightArm": [(Y, 30 * b)],
        "LeftForeArm": [(X, -45 * b)], "RightForeArm": [(X, -45 * b)],
        "_hips_loc": (0, 0, 0.02 * b),
    }


actions = [
    make_action("idle", 4.0, idle),
    make_action("talk", 3.0, talk),
    make_action("wave", 2.5, wave, loop=False),
    make_action("happy", 1.5, happy, loop=False),
]
# Push each action into its own NLA track so the exporter writes them all.
rig.animation_data_create()
for a in actions:
    track = rig.animation_data.nla_tracks.new()
    track.name = a.name
    strip = track.strips.new(a.name, 0, a)
    track.mute = True

Path(args.out).parent.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=args.out, export_format="GLB", export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_skins=True, export_yup=True,
                          export_force_sampling=True)
print("RIG_DONE", args.out, [a.name for a in actions])

if args.preview:
    out = Path(args.preview)
    out.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x = scene.render.resolution_y = 480
    world = bpy.data.worlds.new("w")
    world.color = (0.12, 0.14, 0.18)
    scene.world = world
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.9
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = (0.35, -4, 0.95)
    cam.rotation_euler = (math.radians(90), 0, math.radians(5))
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    for a in actions:
        rig.animation_data.action = a
        n = int(a.frame_range[1])
        for i, f in enumerate((0, n // 4, n // 2)):
            scene.frame_set(f)
            scene.render.filepath = str(out / f"{a.name}_{i}.png")
            bpy.ops.render.render(write_still=True)
