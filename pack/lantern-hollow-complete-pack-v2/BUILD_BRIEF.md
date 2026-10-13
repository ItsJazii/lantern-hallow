# Lantern Hollow — final build brief v2

## Outcome

A gorgeous small first-person Godot 4 desktop prototype. One-day budget: 12–14 focused production hours if tools are set up. Four NPCs, four main quests, one pond, one species, repeatable fishing. Target an 8–12 minute main journey. Visual fidelity is a goal to verify in-engine, not a guarantee from the concept renders.

## Locked scope

Keeper and fox at the tree tea house, moss spirit at the grove, blue spirit at the dock. Entry bridge, loop path, bench, reusable rocks/foliage, moonleaves, lilies, lanterns, kettle/cup, and fishing props. No player rig, roaming AI, combat, large inventory, day/night cycle, additional buildings, or second fishing location. Use Godot; do not split effort with Unity.

## Quest sequence

| Quest | Actions | Unlock/reward |
| --- | --- | --- |
| Opening | Meet keeper | Grove objective |
| Q1 A Little Help | Meet moss spirit, gather 3 unique leaves, return | Tea preparation |
| Q2 Tea for a Friend | Brew at kettle; serve fox once | 3 garden coins; bait shop |
| Q3 A Moonfin Wish | Speak to blue; buy bait; catch and release guaranteed Moonfin | 2 coins per release; wish lantern once |
| Q4 Light the Evening | Light 2 unique dock lanterns; release wish lantern | Celebration and free exploration |

Bait costs 1 coin/unit; first purchase loans the rod free. No bait loss on cancelled casts. Wait 4–7 seconds; bite persists until E. One bait is consumed and 2 coins awarded atomically at release completion. The wish lantern is awarded after Q3. Fishing remains available afterward. See FISHING_DESIGN.md for interruption and duplication rules.

## Controls and feedback

WASD, mouse look, E context action, Esc pause, H hide HUD. No required jumping, hands, or camera shake. Fishing rod is visible during fishing only. One contextual prompt, short dialogue, compact current objective, and coin/bait counts when relevant. Audio and visual cues support every important transition.

## Build budget

| Hours | Deliverable |
| --- | --- |
| 0–1 | Runnable blockout, movement/interactions, early desktop export |
| 1–3 | Entire quest chain with placeholders |
| 3–5 | Bait purchase, fishing, save/load, pause |
| 5–9 | Asset integration and three polished player-height views |
| 9–11 | Sound, UI, comfort, bench if time |
| 11–14 | Full playthrough, performance, fixes, final export |

Model generation can proceed while independent coding is underway. Pipeline setup and model cleanup can exceed this budget; use simple Blender replacements and stationary NPCs to keep the loop finished. Optional charms, fish variations, complex animation, and extra decoration are cut first.

## Acceptance

Fresh start reaches the ending; no duplicate rewards; first catch guaranteed; correct balances (after tea, buy, release: 4 coins/0 bait); repeated fishing works; pauses/cancels/loads are safe; restart resets world visuals; walkways and dock are safe; exported build launches. Test three showcase viewpoints in Godot and report measured performance and placeholders honestly. Deliver project/build/README/credits/screenshots.
