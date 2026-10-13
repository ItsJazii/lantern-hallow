# Cozy adventurer's journal UI — v4 preferred direction

Use ui/adventurer-journal-ui.png as the primary concept. ui/cozy-ui-concept.png is an earlier simpler alternative; the journal version is preferred. The lower two panels in either concept show separate UI states, not overlays to display together. Concepts are design references, not ready-to-import UI textures or screenshots of implemented controls.

The garden's timber, leaf-wrapped bait, warm lanterns, woodland creatures and twilight pond all suggest a small travel journal. Use ivory parchment notes, a moss bookmark, tiny brass accents and simple ink leaf/lantern/bobber icons. Keep the game world visible. The interface should feel personal, quiet and adventurous.

## Palette and sizing

| Token | Value | Use |
| --- | --- | --- |
| Parchment | #F4E6C8 | Opaque readable panel fill |
| Ink | #203C35 | Main text and icons |
| Moss | #465B3A | Primary button and bookmark |
| Button text | #FFF7E6 | Text on moss buttons |
| Brass | #AA7A35 | Thin outline, focus and small ornaments |
| Muted ink | #5C6856 | Supporting text |

At a 1920×1080 design viewport, start with 32 px screen margins, 20–24 px panel padding, 22 px body text, 26–28 px headings, and 48–56 px action rows. Use subtle 10–16 px rounded corners and 1–2 px borders. These are starting targets, then verify at 1280×720 and larger displays. Preserve readable spacing when scaled. Use the project's available licensed fonts: friendly readable serif for short headings and a clean sans serif for body text. Text remains real UI text.

## Screens and behavior

| State | Visible interface | Required behavior |
| --- | --- | --- |
| Exploration | Compact current-quest note top-left, coins/bait ticket top-right, tiny center dot | Show only the current quest's short actionable step |
| Near interaction | Small bottom-center paper/key chip | Show E plus specific action; hide when out of range |
| Keeper shop | Bottom dialogue panel, name, short line, Buy bait and Goodbye | Buy costs 1 coin, adds 1 bait; disabled when unaffordable; existing keyboard choices 1/2 remain |
| Fishing wait | Small calm waiting note | No new reaction or fight meter |
| Bite | A little tug! and E Reel in | Persist until action or cancellation; no timeout added |
| Reveal/release | Fish name and E Release | Preserve the existing release transaction and quest progression |
| Quest complete | Small temporary journal-stamp toast | Brief appearance; do not hide the player's view |
| Pause/settings | Same parchment panel and moss controls | Preserve the game's existing pause and settings behavior |

No added combat meters, backpack system, minimap or quest-management feature is required. Reuse existing actions and game state. Keep status meaning in text as well as color. Show a visible brass focus outline; preserve keyboard navigation and predictable focus when panels open and close. The small focus ornament in the mockup is optional polish.

## Build in Godot

Build panels, labels and buttons as native UI controls in the existing UI layer. Share a theme. StyleBoxFlat supports backgrounds, borders, rounded corners and shadows; it is sufficient for the clean first pass. Redraw small icons as simple vector shapes or use properly separated sprite assets. A subtle paper texture or custom panel edge is optional final polish. Never use the whole concept image as a UI background or Tripo input; it contains example text and several unrelated components.

Keep animation quiet: a brief fade/slide for dialogue, a small nudge on a bite, and a gentle completion toast. Do not animate every HUD element continuously. Confirm labels do not overlap the world focus, dialogue stays readable over the stall, and no duplicated prompts remain from the old UI.

Official Godot reference: [StyleBoxFlat](https://docs.godotengine.org/en/stable/classes/class_styleboxflat.html).
