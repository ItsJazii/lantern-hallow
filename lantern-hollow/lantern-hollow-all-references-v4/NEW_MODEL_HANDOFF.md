> v4 adds proposed grass_short.glb and optional grass_tall.glb; see GRASS_PLACEMENT.md. The exact earlier lively-model names below remain unchanged.

# New model handoff — 14 references, including firefly

These are PNG modeling references. Create textured 3D models in Tripo, inspect them, and export GLB. No GLB, animation rig, audio clip, or playable build is supplied by this ZIP.

1. Open index.html and choose a reference from the New creatures or New garden/stall props sections.
2. Upload the corresponding individual PNG in Tripo image-to-3D.
3. Inspect the complete model, especially fins, feet, ears, wing edges, jar openings, and thin stems.
4. Export GLB using the exact name in the table.
5. Place it in `D:\tripo mini game\models_raw\src\` as Opus requested, not directly in the game folder.
6. Let Opus import, scale, place, rig and animate the asset.

| Priority | Reference | Export as | Suggested size | Placement |
| --- | --- | --- | --- | --- |
| 1 | [Amber firefly](lively/creatures/firefly.png) | `firefly.glb` | 0.015–0.025 m actual length; slightly larger near-camera version if needed | Close-up visitors around shrubs and lanterns; distant glows stay effects |
| 1 | [Lily-hat frog](lively/creatures/frog.png) | `frog.glb` | 0.18–0.25 m tall | Lily pads and bank |
| 1 | [Glowing mushroom cluster](lively/garden/glow_mushrooms.png) | `glow_mushrooms.glb` | 0.30–0.45 m cluster height | Grove and tree roots |
| 1 | [Tea herb jars](lively/stall/herb_jars.png) | `herb_jars.glb` | 0.18–0.28 m container heights | Keeper shelves |
| 1 | [Coral koi](lively/creatures/koi.png) | `koi.glb` | 0.35–0.45 m long | Pond; swims with Moonfins |
| 1 | [Four potion bottles](lively/stall/potion_bottles.png) | `potion_bottles.glb` | 0.15–0.30 m bottle heights | Keeper shelves |
| 1 | [Moon rabbit](lively/creatures/rabbit.png) | `rabbit.glb` | 0.35–0.45 m seated; ears included | Grassy clearings |
| 1 | [Pond reeds](lively/garden/reeds.png) | `reeds.glb` | 0.8–1.2 m tall | Pond and stream banks |
| 2 | [Duckling](lively/creatures/duck.png) | `duck.glb` | 0.18–0.25 m body length | Pond; reuse for duckling family |
| 2 | [Hanging herb bundle](lively/stall/herb_bundle.png) | `herb_bundle.glb` | 0.35–0.45 m long | Hangs under stall roof |
| 2 | [Lantern owl](lively/creatures/owl.png) | `owl.glb` | 0.30–0.40 m tall | Giant tree perch |
| 2 | [Stone garden lantern](lively/garden/stone_lantern.png) | `stone_lantern.glb` | 0.8–1.0 m tall | Selected pond shore spots |
| 3 | [Barrel and tea crates](lively/stall/barrel_crates.png) | `barrel_crates.glb` | 0.8–1.0 m assembly height | Beside tea stall |
| 3 | [Moon moth](lively/creatures/moth.png) | `moth.glb` | 0.10–0.15 m wingspan | Lantern surroundings |

## Work first

Priority 1: koi, frog, rabbit, reeds, glow mushrooms, potion bottles, herb jars; firefly added at your request. Priority 2: owl, duck, stone lantern, herb bundle. Priority 3: moth, barrel/crates. Start with the props and creatures that will be visible in the three main camera views.

## Grouped assets

Potion bottles, herb jars, mushroom cluster and barrel/crates are deliberately single compact assemblies, matching Opus’s requested filenames. Use the whole image as one modeling input. If parts need independent animation or movement, separate them later in Blender rather than generating a whole shelf scene.

## Fireflies

`firefly.glb` is the proposed filename for the new firefly asset; it was added after Opus’s uploaded list. It is a closed-wing resting insect reference for a few near-camera visitors, with a distinct amber tail. Distant firefly glows can stay lightweight engine effects. Opus can add a subtle tail pulse, slow motion and optional wing geometry afterward. Do not enlarge every distant glow into a detailed insect or attach a dynamic light to every insect.

## Tree and keeper supplements

The two side-tree references and both keeper face/full-body references are in supplemental/. Use keeper-front-full-body.png for generating the whole character; the portrait helps preserve the face. Confirm existing model filenames with Opus for these supplemental assets rather than renaming an already integrated model blindly.

## Original references still required by Opus

Moonfin: fishing/03-moonfin.png → moonfin.glb. Rod: fishing/01-fishing-rod.png → fishing_rod.glb. Bobber: fishing/02-bobber.png → bobber.glb. Dock: environment/04-lantern-dock.png → dock.glb. All are included.

## Glass, glow and animation

Reconstructed bottles may arrive as solid shapes with baked highlights. Tune glass/liquid materials after import. Mushroom spots and the firefly tail should have controllable emissive material regions if possible. These reference images do not establish actual runtime transparency, glow or deformation quality. For the animal meshes, inspect body/limb separation before relying on a rig.

## Keep the current game focused

These creatures are ambient life, not additional quest NPCs. Keep the existing four quests and four speaking NPCs. Koi swimming in the pond do not add a new fishing species or change the first Moonfin guarantee. Use short calm reactions and a few reused instances; keep paths and the fishing bobber readable. The original one-day build schedule is tight; integrate priority-one assets first.
