# Fishing design — A Moonfin Wish

## Small economy

Start with 0 coins/0 bait/no rod. Fox tea completion awards 3 coins once and unlocks the keeper's bait option. Buy one bait for 1 coin. First purchase also lends the rod permanently. Blue-spirit conversation starts the fish objective. Both conversation and purchase can occur in either order; both are required for first cast.

The only fish species is Moonfin. It has a teal back, ivory belly, gold crescent marking, and lavender fins. First quest catch is guaranteed; later catches reuse the same mesh. Catch-and-release earns 2 coins. There is no selling or skill progression. This intentionally forgiving loop gains 1 coin net per purchased bait and completed release.

| Step | Coins | Bait | State |
| --- | --- | --- | --- |
| Fresh start | 0 | 0 | No rod |
| Serve tea | 3 | 0 | Shop unlocked |
| Buy first bait | 2 | 1 | Rod loaned |
| Complete release | 4 | 0 | First-fish quest complete; wish lantern owned |
| Buy and release again | 5 | 0 | Repeatable fishing |

## Interaction state machine

IDLE → CASTING → WAITING (4–7 seconds) → BITE (waits indefinitely) → REELING → CATCH_REVEAL → RELEASING → IDLE.

E starts a cast, reels at bite, and confirms release at reveal. Initial cast requires first blue conversation, rod, bait, and station proximity. Hide player hands/body; a wood/brass rod enters the lower-right view. Its line is procedural and attached to a fixed cast anchor. Bobber is coral/cream for contrast. Use a plop, small ripples, gentle dip/bell, brief reel, fish reveal, then a short release arc/splash. No countdown, tension meter, fish escape, or rapid tapping.

## Atomic commit and interruptions

- Reserve one bait logically at session entry; do not deduct it yet.
- On release completion, consume 1 bait, award 2 coins, increment release_count, apply eligible first-fish/wish-lantern progress once, then save the complete transaction.
- Give each session a single pending token. Guard callbacks and repeated E. All relevant persistent values change together.
- Esc pauses timers/tweens. Offer Cancel fishing before CATCH_REVEAL; cancellation returns IDLE with no cost/reward. At reveal/release, pause retains the pending fish and only resume or quit may interrupt.
- Quit/load discards all uncommitted fishing. Saved bait and coins remain unchanged. Restore movement and clear rod/bobber/line/UI/transient tokens.
- Purchasing, new dialogue, and a second cast are unavailable during an active session.
- First completed Moonfin release after the blue conversation grants wish lantern once and unlocks two dock-lighting targets. Q4 ending does not stop future fishing.
- Optional recovery: if fishing is unlocked and both coins and bait are zero, keeper offers 1 free bait only while that exact condition is true.

The pack describes the logic; it has not been executed in Godot. Verify interruption behavior in the implementation.

## Asset handoff

fishing/01-fishing-rod.png: 1.7 m, wood/brass, cream grip; line engine-generated.
fishing/02-bobber.png: roughly 8 cm, coral/ivory/navy, brass eyelet.
fishing/03-moonfin.png: 25–35 cm, one species, thick readable fins.
fishing/04-bait-jar.png: 22 cm, ceramic with wooden lid, on existing stall.
fishing/05-garden-coin.png: 3.5 cm, embossed leaf; can drive UI icon direction.
fishing/06-bait-pellet.png: 1.2 cm, seed dough; optional close-up/shop dressing, no simulation.

One fish reference represents the species; it is not a fifth NPC. Three additional fishing concepts show dock play, release, and the keeper purchase view.
