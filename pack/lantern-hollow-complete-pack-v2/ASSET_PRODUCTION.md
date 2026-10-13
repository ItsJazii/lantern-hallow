# Tripo → Blender → Godot production workflow

## Generate selectively

Use individual single-subject PNGs. Start with giant tree trunk/canopy, tea stall, four NPCs, Moonfin, and rod. Test tree + stall + one NPC in Godot early. The keeper can remain stationary, fox seated, spirits bobbing. Generate no visible player body/hands for this first-person game.

The bridge, dock, bench, stones, lantern posts, bait jar, coin, bobber, and pellet may be faster as simple Blender models. Reuse one canopy module, one moss rock, one stepping stone, one fern, one flower, and one lily with rotation/scale variation. Duplicate three quest plants with stable IDs. Reuse lanterns across scenery and ending.

Suggested starting triangle budgets (visual targets, not hard constraints): NPCs 5–15k each; hero trunk 15–30k; stall 10–25k; rod/fish 2–8k each; small props 0.3–3k; reusable foliage modules 0.5–3k. Start with 1k textures, use 2k only where visible on a hero asset. Profile the actual composition; instances and draw calls matter along with triangle counts.

## Blender inspection

1. Inspect front, side, back, and underside; remove generated floors/background scraps.
2. Fix obvious holes, flipped normals, pinched limbs, merged openings, and stretched textures.
3. Set meters, apply rotation/scale, and use sensible pivots: feet/base for NPCs/props; grip origin for rod; central body for fish.
4. Keep thin fins/ears robust. Rebuild rod guides and fishing line rather than accepting noisy floating geometry. Simplify small pellet/coin details.
5. Split material regions needed for controllable effects: lantern paper, moonleaf accent, spirit heart. Check wish lantern top/bottom openings and rebuild if closed.
6. Preserve source model; export GLB; reopen or import it in Godot before accepting the handoff. GLB scale, orientation, material slots, and textures must survive import.

Do not spend hours on perfect retopology for stationary props. Spend cleanup time on silhouettes, faces, materials, and visible defects. Avoid severe blind decimation on face/fin/ear shapes.

## Godot assembly

Wrap each imported model in a small scene. Gameplay script, stable ID, prompt, and simple collider belong to the wrapper. Swapping a mesh must not break quest links. Use StaticBody3D with simple shapes for bridge/dock/terrain and nonphysical visuals for small decorative plants. Keep interaction layers separate from ground and visual clutter.

## Elements built in the engine

Terrain/loop path/inlet and pond plane, procedural sky or simple licensed sky background, material palette, water shader and ripples, fishing line, steam, low-density fog, fireflies, lantern sway/release paths, short NPC tween idles, UI and prompts. These do not need extra Tripo images. Create simple forms directly; use the map and art direction as references.

## Production checklist

Whole silhouette intact; no accidental support mesh; correct relative scale; clean normals; matching palette; pivot suitable; simple collision; import verified; script separated; credits/source recorded. For the rod, check both ends and every line attachment. For the Moonfin, ensure fins remain readable and the gold crescent faces the catch camera.

The pack contains references only. Track actual model import/cleanup status in your project; do not confuse an image in the gallery with a completed game asset.
