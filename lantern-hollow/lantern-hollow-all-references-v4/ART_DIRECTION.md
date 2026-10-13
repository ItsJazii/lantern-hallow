> v4 visual addition: follow OPUS_VISUAL_PASS_PROMPT.md, GRASS_PLACEMENT.md and UI_ART_DIRECTION.md for current groundcover and UI. The earlier core game plan below remains applicable.

> v3 addition: read NEW_MODEL_HANDOFF.md for the current ambient-creature and dressing expansion. It adds 14 reference assets (including firefly), two side trees and keeper supplements while preserving the four-quest core. The earlier baseline scope and schedule below do not imply that all new assets are already integrated.

# Art direction and quality gates

## Visual promise

A premium stylized twilight garden: inviting amber light surrounded by cool blue atmosphere, readable rounded characters, jewel-like teal water, and small rose/lavender accents. Attractive composition matters more than object count. Original tea-house concepts and the new fishing scenes define the shared visual language.

## Three hero views

1. Arrival bridge: tree silhouette and tea counter as the focal point, pond visible, a clear path ahead. Branches/foliage frame edges; keep the center open.
2. Fishing dock: warm reflections across cool water; rod lower right; blue spirit to the side; no UI covering the bobber. Camera respects actual pond size. Mood concept fish schools are optional; one Moonfin mesh is sufficient.
3. Keeper counter: expressive face, coherent wood/brass/ceramic materials, kettle/cup/bait jar, three visual coins if desired. Brief readable purchase UI. Extra tiny counter items in concepts are optional.

## Cohesion rules

Night navy #17283F; teal #236E78; amber #F2B65D; cream #F3E4C7; moss #66805A; lavender #A7A1DF; restrained coral #DB8F94. Tune values under final lighting. Broad bark/stone detail; bevels visible at player scale; reasonable roughness; consistent material/texture scale. Avoid photoreal assets mixed with toy-like characters.

Keep paper highlights below white clipping; let brass differ from matte wood; let flower accents punctuate green banks. Cluster repeated foliage in intentional groups with gaps. Cover seams using a few roots/rocks, not endless clutter. Use only a few shadow-casting local lights; most lanterns are emission plus appropriately placed light sources.

## Gates before more decoration

- Gate A: graybox path traversal works; bridge/dock/shoreline/counter distances feel right at 1.6 m eye height.
- Gate B: one tree/stall/pond view looks coherent in Godot with final palette and approximate lighting.
- Gate C: all four NPCs match silhouettes, relative scale, and materials; no floating feet, broken normals, or stray background meshes.
- Gate D: dock water and bobber remain readable at gameplay resolution; no obvious reflection/transparency sorting failure.
- Gate E: three in-engine screenshots remain attractive with HUD hidden, and all objectives remain easy to find with HUD on.

Use restrained glow, low-density mist, a handful of fireflies, gentle water/plant motion, and short character animations. Keep DOF subtle in screenshots and off or negligible in regular play. Avoid motion blur and forced camera shake. Finish visual consistency before increasing detail.

## Rendering notes

Use Forward+ and verify exact installed Godot APIs. Reflection probes are a practical starting point; SSR only reflects visible screen content and opaque objects. Transparency must be validated rather than assumed. An opaque stylized reflective pond is a valid fallback. Static light baking is optional if setup and budget permit. Emissive paper alone is not a substitute for scene lighting.

Official technical references checked for this pack:
- https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html
- https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/reflection_probes.html
- https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html
- https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_lightmap_gi.html

Concept renders are an aesthetic target. Inspect and tune the actual exported game; no performance or visual parity is claimed by this reference package.
