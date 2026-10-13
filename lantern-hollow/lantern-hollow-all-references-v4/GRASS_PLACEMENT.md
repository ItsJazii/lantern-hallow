# Grass and garden color — v4 current direction

Use concepts/colorful-groundcover.png as the placement and mood target. It is an AI art-direction concept based on your screenshot, not a screenshot of an implemented grass system. The current direction replaces the earlier tall, spiky, uniformly dark grass pass.

## Generate these models in Tripo

| Reference | Proposed export name | Final height | Use |
| --- | --- | --- | --- |
| grass/grass_short.png | grass_short.glb | 0.08–0.12 m | Main soft meadow groundcover |
| grass/grass_tall.png | grass_tall.glb | 0.25–0.35 m | Optional sparse accents at roots and rocks |

One PNG per Tripo generation. Keep roots together, preserve gaps between curved blades and remove any generated ground disk. In Blender, apply scale, position the origin at the root, inspect normals and simplify the mesh before export. These are proposed additional names, not entries from Opus's original model list. Scale the imported GLB to the listed real-world height; image framing does not establish units.

Generate the short tuft first. Most of the visual improvement comes from placement and scale. The same mesh can have several tinted materials or instance colors; separate sage, lime and gold model generations are unnecessary. Use the existing plants/03-pink-flower.png model for recolored small flower groups. If Tripo creates dense fused blades, Opus can construct a simple curved-blade tuft directly using this image as the shape reference.

## Color groups

| Area | Groundcover | Flower accents |
| --- | --- | --- |
| Paths and lantern posts | Sage/moss with small fresh lime patches; muted straw-gold in warm light | Cream; a few blush flowers |
| Pond banks | Cool sage with occasional soft teal-green | Small lavender groups near selected dry banks |
| Tea stall | Familiar warm green and modest gold | Blush and cream clusters |
| Shaded roots/grove | Deep moss and cool sage | Very sparse |

Keep at least roughly 85 percent of vegetation green. Put colors in blended local patches with a few neighbors sharing a hue. Avoid assigning fully random rainbow colors per tuft. Palette values in design/grass-pass.json are starting art targets; lighting changes their apparent color.

## Placement and rendering handoff

- Short grass dominates; tall grass is a sparse accent. Vary yaw, height and spacing modestly. Keep open mossy ground gaps and soft patch edges.
- Keep the entire walkable path, pond water, bridge, dock and stall floor clear. Preserve quest plants and animal visibility. Add vegetation only on supported terrain, with roots touching the sampled surface; do not scatter at a single flat height.
- Ground texture should have gentle moss/earth variation so gaps do not expose a uniformly flat green surface. Match ground and root colors. No grass collisions are needed.
- Use GPU-instanced repetitions through MultiMesh, split into local chunks rather than one garden-wide group. MultiMesh shares visibility bounds; separating groups helps avoid rendering far-away grass unnecessarily. Start with a few hundred triangles per cleaned tuft as a budget suggestion, then profile the actual game. Inspect multi-surface imports instead of assuming one draw call for a whole complex GLB.
- Gentle shared wind should mainly move tips and keep roots planted. Reduce coverage with distance; concentrate effort around the arrival path, stall and fishing dock.
- Add a little soft ambient fill so sage and flowers remain legible at twilight. Preserve blue distance and amber lantern pools. If tuning Environment ambient color/energy, ensure sky contribution is below 1; otherwise those settings have no effect. Judge the actual camera views, not isolated material previews.

## Check in the actual game

Compare before/after from arrival, stall and dock. Walk every path; inspect grass from player-eye height and near the ground for floating roots, spikes, repeated rows and oversized tufts. Check frame time before/after, then reduce density or mesh cost where needed. This pack does not verify runtime performance or import quality.

Official Godot references: [MultiMesh](https://docs.godotengine.org/en/stable/classes/class_multimesh.html), [Environment](https://docs.godotengine.org/en/stable/classes/class_environment.html).
