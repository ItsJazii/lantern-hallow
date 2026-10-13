> v4 visual addition: follow OPUS_VISUAL_PASS_PROMPT.md, GRASS_PLACEMENT.md and UI_ART_DIRECTION.md for current groundcover and UI. The earlier core game plan below remains applicable.

> v3 addition: read NEW_MODEL_HANDOFF.md for the current ambient-creature and dressing expansion. It adds 14 reference assets (including firefly), two side trees and keeper supplements while preserving the four-quest core. The earlier baseline scope and schedule below do not imply that all new assets are already integrated.

# Lantern Hollow — complete Opus implementation prompt

You are my lead Godot developer and technical artist. Build Lantern Hollow, a small, beautiful, cozy first-person 3D garden adventure. I have one production day. Deliver a playable Windows prototype with a complete quest chain, relaxed pond fishing, satisfying sound, and a carefully composed visual presentation. Work through implementation and verification; do not stop at a proposal.

## 1. Read the pack and lock the scope

Read READ_ME_FIRST.md, BUILD_BRIEF.md, FISHING_DESIGN.md, ART_DIRECTION.md, ASSET_PRODUCTION.md, SOUND_PLAN.md, map/layout.json, design/game-spec.json, and manifest.json. Inspect the supplied concept images. Asset references are PNG modeling guides; they are not existing GLB files, audio, or a tested game. Inventory actual local tools and project files before claiming access to them. Use available tools directly; give me precise handoff steps for tools you cannot operate.

Use one installed stable Godot 4 version, GDScript, and the Forward+ renderer. Record the exact engine version. Target Windows desktop, keyboard and mouse, a 1080p presentation, and a measured 60 FPS goal on the development PC. Build one scene and one connected garden. Avoid adding a second engine or changing versions midway. Create a runnable project and verify an early desktop export before spending hours on decoration.

The main journey should take roughly 8–12 minutes, followed by optional fishing and free exploration. There is no combat, death, hunger, time pressure, multiplayer, crafting tree, day/night cycle, procedural world, fishing skill tree, or large inventory. Four NPCs only. A single Moonfin species is enough. Preserve time for polish and export.

## 2. The experience and visual identity

It is a blue-hour garden surrounding a teal pond. A giant golden-green tree shelters an inviting timber tea stall. Amber paper lanterns, mossy stone edges, a curved wooden bridge, violet moonleaves, cream lilies, and small pink flowers make a warm, colorful place. The mood is calm, friendly, and magical. Give the player breathing room and readable paths.

Use stylized rounded silhouettes and broad, coherent material detail. The references establish identity and palette; the map and inventory establish scope. Incidental extra fish, vessels, waterfalls, plants, or structures shown in mood concepts do not require extra systems or unique models. Do not attempt to reconstruct every tiny decorative feature.

Palette anchors: night navy #17283F, deep teal #236E78, amber #F2B65D, cream #F3E4C7, moss #66805A, lavender #A7A1DF, restrained coral #DB8F94. Treat these as starting values under the final lighting, not literal mandatory texture pixels.

Establish three attractive viewpoints: the arrival bridge looking toward the giant tree and stall; the southeast dock looking across warm pond reflections; and the tea counter with the keeper, kettle, cup, and bait jar. Validate them at player eye height in Godot. Spend the visual budget on the tree silhouette, believable light, water, and four expressive NPCs. Use foreground framing at the image edges while keeping the center and walkways clear. Do not carpet every surface with flowers or lights.

## 3. Camera, input, and comfort

Use CharacterBody3D with a capsule, a simple floor check, approximately 3 m/s walking, and a 1.6 m eye height. Start near 75 degrees FOV and tune by playing. No visible body or hands. The fishing rod appears only during fishing. No required jumping or sprinting. Keep head bob and motion blur off. Clamp vertical look, provide mouse sensitivity, capture the mouse during play, and release it in menus.

Controls: WASD movement; mouse look; E interact, advance short dialogue, cast, reel, and release; Esc pause or close a dialogue; H hide/show HUD; E stand up from a bench. Select interactions with a short camera ray, around 2.5 m, backed by sensible collision layers. Show one context-sensitive prompt. Lock movement when a dialogue, bait purchase, fishing session, or seated mode needs focus. Restore it reliably on exit.

Esc during waiting or bite fishing states opens pause with an explicit Cancel fishing option. Cancel before the catch reveal has no cost. At catch reveal, pause keeps the fish waiting for release; do not allow another interaction to discard or duplicate the pending reward. Quitting and loading resets uncommitted fishing safely.

## 4. World blockout and characters

Use Godot meters, X east, Y up, Z south. Build approximately 60 × 50 m of garden with a pond centered at [0,0] in XZ, radii about 12.5 and 9.5 m. Tea stall [-24,0]; giant tree [-23,-8]; moonleaf grove [16,-13]; dock [13,9]; bench [0,18]; arrival [-30,26]; bridge [-20,15.5]. The spawn is just outside the nominal garden. Treat map/layout.json as suggested coordinates, then tune for traversable paths and readable views. Pond ground is blocked so the player cannot fall into deep water.

Create one loop path with short spurs to the tea counter, grove, dock, and bench. Cross the inlet with the entry bridge. Use invisible boundaries supported by tree silhouettes and terrain rather than a visible rectangular wall. Simplify collisions independently of detailed rendered meshes. Test the bridge arch, dock edges, counter reach, and terrain slopes immediately.

The keeper is a friendly young adult with short indigo hair, navy cloak, ochre scarf, cream apron, and boots; remain behind the counter with a subtle idle. The moss spirit is an olive bean-like creature with two leaf ears, near the grove. The ivory fox sits beside the stall, with amber ear and tail accents. The blue spirit is a small pale-blue bell/pear shape with a curled head and gold heart, on the dock. Spirits can bob and turn using tweens; the fox can breathe and make a small happy motion. A stationary keeper is acceptable. No walking AI or complex rigs are needed for this version.

## 5. Implement the exact quest chain

Opening: the keeper greets the player and sends them to the moss spirit. Dialogue: “You found us just in time. Would you gather a little moonleaf for tonight's tea?”

Quest 1, A Little Help: speak to the moss spirit, then collect exactly three uniquely identified moonleaf targets in its grove. Each target counts once and disappears or visibly changes. Tracker shows 0/3 through 3/3. Return to the keeper to complete the quest. Moss line: “Just three leaves, please. The rest are still dreaming.”

Quest 2, Tea for a Friend: interact with the kettle after the leaf quest is complete. A short steam/pouring beat sets tea_brewed. Interact with the cup or nearby fox to serve tea once. The fox reacts warmly. The keeper awards exactly three garden coins once and unlocks the bait purchase option. Keeper line: “Our little friend looks happier already. Take these coins—there's someone waiting by the pond.” This does not award the wish lantern yet.

Quest 3, A Moonfin Wish: visit the blue spirit, which asks to see a Moonfin returned to the pond. Buy one bait from the keeper for one garden coin; the first purchase also lends the rod at no extra charge. Blue line: “Could you show me a Moonfin? Let it go again, and we'll make a wish together.” After speaking to blue, fish from the marked dock spot. First successful catch is guaranteed to be a Moonfin. Release it to complete this quest. Blue responds “There it goes! A little moon, back where it belongs.” Award the wish lantern once after this release.

Quest 4, Light the Evening: after the Moonfin quest, light two uniquely identified dock lanterns. Tracker shows 0/2 through 2/2. Interact with the blue spirit to release the wish lantern. Play a short celebration: a handful of reused wish-lantern meshes rise on scripted curves, nearby lights brighten gently, and music resolves. No extra NPC crowd. Set ending_complete once. Return to normal free exploration, bench use, bait purchasing, and repeatable fishing.

Keep quest text friendly and specific. Wrong-order interactions provide a helpful next step, never silently consume items. Tea, coins, wish lantern, lantern ignition, and ending rewards are idempotent. The active objective updates immediately and after loading a save. Use explicit stable target IDs rather than object-name guesses.

## 6. Fishing: small, relaxed, and complete

Use one controlled fishing station on the southeast dock. Show available bait and coins compactly. The bait shop is a small keeper dialogue option, “Buy bait · 1 coin,” with buy/back actions; no dedicated shop building or grid inventory. Disable buy when unaffordable. Deduct one coin and add one bait atomically. First successful purchase sets has_rod. Keep the rod loan permanent.

Implement a clear state machine: IDLE → CASTING → WAITING → BITE → REELING → CATCH_REVEAL → RELEASING → IDLE. Entry requires the rod, at least one bait, and the first blue-spirit conversation for the initial quest. Cast with E, animate the visible rod and bobber toward a fixed water anchor, then wait 4–7 seconds. Use a fine procedural line rather than simulated rope. Show slow bobber motion and light ripples. A gentle bell, clear bobber dip, and “A bite! Press E to reel” announce the bite. The bite persists until the player responds; no timing failure, mash input, tension bar, or fish escape.

E reels in with a short tween and softly rising cue. Reveal a 0.25–0.35 m Moonfin above the water with teal back, ivory belly, gold crescent, and lavender fins. Show “Moonfin! Press E to release.” E plays a small arc and splash back into the pond. Use the same fish model for every catch. Size or tint variations are stretch polish only.

Commit the transaction once when the release finishes: subtract one bait, add two garden coins, increment release_count, update the first-fish quest and wish-lantern flag if eligible, then save. Guard against repeated button presses and animation callbacks. The intentionally generous economy is three starting coins, bait cost one, release reward two; it supports unlimited calm play. Do not add fish selling or a competing reward source.

Bait is reserved logically during fishing but remains unconsumed until the committed release. Cancellation before catch reveal, leaving the game before commitment, or loading a saved game resets the transient session with no cost or reward. No autosave may contain a partly applied transaction. If a corrupted or manually edited state somehow has zero coins and zero bait after fishing unlock, offer one emergency bait from the keeper only while both remain zero. Clearly separate this recovery from normal rewards.

Give each cast exactly one pending catch token, clear it on commitment/cancel/load, and reject input outside the allowed state. Pause freezes wait timers and animation. Prevent starting a second session, purchasing bait, or triggering another dialogue during an active cast. Never leave the player movement-locked after an interruption.

## 7. Asset production and replacement workflow

Use each standalone character or asset PNG as a separate Tripo input. Do not upload a full scene concept to generate the whole map. Prioritize tree trunk, canopy module, tea stall, four NPCs, rod, and Moonfin. Simple dock, bridge, stones, jar, bobber, coin, bait pellet, and lanterns may be quicker to build directly in Blender. Keep the pellet as one reusable small object; it need not be visible during every cast.

Inspect every generated model from multiple sides. Remove background geometry, fix obvious holes and normals, apply transforms, and put sensible pivots on ground contact or animation origins. Work in meters. Rebuild thin rod guides and fragile fin geometry when necessary. Generate the fishing line in the engine. Export GLB with checked material slots and embedded or reliably linked textures. Keep source files if available. Use simple proxy colliders, not detailed trimesh collision for every leaf.

Each imported model lives inside an asset wrapper scene. Interaction IDs and scripts belong on the wrapper so a mesh swap does not break the game. Use coherent named materials for wood, brass, stone, foliage, paper, ceramic, and spirit glow. Make leaf/paper transparency intentional. The reference blue spirit is mostly opaque; add a restrained glow and only use transparency if it sorts cleanly. For the wish lantern, inspect its open top and base after reconstruction and rebuild if needed.

Terrain, sky, pond surface, steam, mist, fireflies, cast ripples, fishing line, and lantern motion are engine-built elements. Do not wait for additional generated models for them. If an asset is unavailable, use a tidy silhouette placeholder and report it honestly. The project should stay runnable throughout replacement.

## 8. Rendering and sound polish

First make the tree/stall/pond composition work with the actual camera. Use cool soft environmental light, a gentle moon key, and a few warm local lights where they visibly matter. Lantern meshes can be emissive without each owning a shadow-casting light. Preserve paper texture and avoid blown-out orange whites. Keep roughness deliberate: mellow timber, soft moss, matte cloth, ceramic highlights, warm brass, restrained reflective water.

Use a stable stylized pond shader with low-amplitude ripple normals, teal depth impression, softened shoreline, and a working reflection strategy. Reflection probes are a useful starting point. Validate any screen-space reflections in the exact material setup: they have visibility limitations and do not reflect transparent objects. Use an opaque reflective water fallback if transparency introduces sorting or missing reflections. Do not promise perfect reflections from a screenshot. Water should look attractive from both bridge and dock.

Use restrained glow, low-density fog, sparse fireflies, kettle steam, subtle foliage movement, and gentle NPC/lantern motion. Fog must not hide the four objectives. Bake static lighting only if the installed version and workflow are already working and the bake fits the schedule; otherwise finish with environmental and local lighting. Do not stack costly global illumination techniques blindly. Capture all three hero views in Godot, inspect material scale, shadows, silhouettes, and UI, and iterate before adding more clutter.

Follow SOUND_PLAN.md. Use soft felt piano/plucked-string music around 65–75 BPM, quiet breeze/crickets, spatial pond movement, wood/stone/grass footsteps, kettle simmer and pouring, ceramic clinks, friendly spirit responses, leaf chimes, and a short ending variation. Fishing needs cast whoosh, bobber plop, a recognizable gentle bite cue, reel sound, and release splash. Shop purchase uses a soft coin chime. Keep bite feedback both visible and audible.

Use Master, Music, SFX, and Ambience buses with saved volume settings. Make loops seamless, avoid clipping, prevent dialogue chirps from spamming, and maintain ambience under music. Use original or appropriately licensed audio and record credits. The pack supplies sound directions, not finished audio clips.

## 9. UI, persistence, and organization

Create a compact cream-on-navy UI with restrained gold/lavender accents, readable type, a tiny interaction dot, current objective, context prompt, and small coin/bait counts when relevant. H hides presentation HUD only; it must not hide mandatory choices in a blocking dialogue. Pause includes Resume, audio/sensitivity settings, Cancel fishing when allowed, Restart with confirmation, and Quit. Bench sitting is a short peaceful view with an obvious E-to-stand prompt. Three hidden charms are optional after core polish.

Separate player/input, interaction, quest state, fishing state, UI, audio, and save responsibilities. Suggested folders: scenes/world, scenes/player, scenes/npcs, scenes/interactables, scripts, assets/models, assets/materials, assets/audio, assets/ui, shaders, data, and docs. Use readable small scripts and signals, not one giant manager tied to node paths.

Persist committed quest flags, collected target IDs, tea state, shop/rod unlock, coins, bait, first Moonfin release, wish-lantern ownership, lit-lantern IDs, ending state, and settings to user:// with a schema version and safe defaults. Save after meaningful committed changes. Never serialize a live fishing tween as progress. Restart resets gameplay state and scene visuals while preserving user settings. Load must rebuild visuals from state without replaying reward events.

## 10. Work order and completion evidence

Use the 12–14 focused-hour schedule as a budget, not a reason to skip validation: first hour for runnable blockout and early export; next two for the four quests; next two for fishing/shop/save; next four for asset replacement and three hero views; next one or two for sound/UI/comfort; final two for playthrough, performance, fixes, and final export. Generate/import models alongside independent implementation where the available tools permit. Give concise progress updates that state what works and what remains.

If time slips, cut hidden charms, species variations, complex keeper animation, and extra decoration in that order. Keep all four quests, one-species fishing, readable controls, pause/save, coherent lighting, core sound, and a desktop build. Do not spend the final hour adding systems.

Validate a fresh start through the ending; a save/load in each quest; wrong-order interactions; repeated leaf, tea, lantern, and reward interactions; unaffordable purchases; casting with no bait; repeated E during every fishing state; paused wait/reel; cancel before reveal; quit/reload before commitment; first Moonfin guarantee; repeat fishing after ending; restart; bench exit; HUD toggle; audio settings; and bridge/dock boundaries. After tea, buy one bait and release once: coins must be 4, bait 0, rod owned, and first-fish completion true. Repeat release input must not change that balance.

Profile the target PC using the actual exported game. Provide High and Balanced settings only if useful and verified. Reduce dynamic shadow lights, unnecessary foliage density, reflection updates, and particle counts before sacrificing the main composition. State measured resolution, hardware, and performance honestly.

Deliver the Godot project, the Windows build with all required files, a short README with controls and run/export steps, asset/audio credits, three in-engine showcase screenshots, and a concise list of anything still using placeholders. Distinguish completed and tested work from visual goals. Start now by inspecting the pack and local environment, creating the runnable project, and proving the first export.
