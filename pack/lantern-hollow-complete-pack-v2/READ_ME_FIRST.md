# Lantern Hollow — complete reference pack v2, with fishing

Start by opening **index.html** after unzipping the folder. It is an offline gallery with every reference, the labeled map, and links to the production documents. Read the complete **MASTER_PROMPT.md**, then give it and this folder to your coding agent.

## What's included

- Four individual NPC references: keeper, moss spirit, ivory fox, blue spirit.
- Twenty-four individual asset references: eighteen garden/tea assets plus six fishing assets.
- Nine scene concepts plus one original character lineup.
- Revised fishing map in PNG and editable SVG, suggested coordinates, machine-readable game specification, art direction, asset workflow, fishing rules, sound plan, schedule, and full Opus prompt.
- Original image-generation prompts and an inventory with image dimensions and checksums.

The new fishing references are one rod, bobber, Moonfin, bait jar, garden coin, and bait pellet. Upload **one standalone subject PNG at a time** to Tripo. Scene concepts are visual targets, not whole-map reconstruction inputs. Check the rear and sides of generated meshes; image-to-3D does not guarantee production-ready geometry.

This is a design and image-reference package. It does not contain generated GLB models, a playable Godot project, or finished audio. Those are produced using the included workflow and master prompt.

## Final game

Godot 4, Forward+, Windows desktop, first person, no visible player hands/body. One 60 × 50 m suggested garden with a giant tree, tea stall, pond, grove, bridge, dock, and bench. Four NPCs, four main quests, one fish species. Main journey target: 8–12 minutes; repeatable fishing afterward.

**Gather 3 moonleaves → brew and serve fox tea → receive 3 coins → buy bait from the keeper → speak with blue spirit and catch/release a Moonfin → receive wish lantern → light 2 dock lanterns → lantern celebration.** The blue-spirit conversation and bait purchase may occur in either order after tea; both are required before the first cast.

Bait costs 1 coin. The first purchase lends the rod free. Each completed fish release consumes 1 bait and rewards 2 coins. Bite waits for the player; no timed failure. First catch is guaranteed Moonfin. The wish lantern is awarded after the first fish release, not after tea.

## Read the map

North is up; tea house west, grove northeast, fishing/lantern dock southeast, bench south, arrival southwest. One loop path connects the destinations. Q1 marks gathering, Q2 tea, and Q3/Q4 share the dock. Charms A/B/C are optional stretch content. Suggested coordinates are in map/layout.json; adjust after collision and camera playtests.

The vector map defines topology and scope. Concept images define mood, color, and composition. Incidental extra fish, vessels, waterfalls, and decorative details in images are optional; the inventory and build brief control production scope.

## Production order

1. Runnable blockout and early Windows export.
2. Four quests with clean placeholders.
3. Shop, fishing, committed-state saving.
4. Replace the important meshes and polish three main views.
5. Sound/UI/comfort, playthrough, performance, final export.

Use ASSET_PRODUCTION.md for the Tripo → Blender → Godot handoff. Terrain, sky, water, fishing line, steam, mist, ripples, and light effects are built in the engine. Keep all required gameplay before adding optional charms.
