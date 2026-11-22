# 06 — Fish fights (sections)

Recorded November 22, 2026 from Deovandski's brief in [issue #16](https://github.com/Deovandski/Sinoi-the-fisherman/issues/16). **Status: prototype to playtest.** The fish and their numbers are placeholders; the structure (sections, a mode and a difficulty range each) is Deovandski's direction.

## The brief

- Replace the title screen's **Cast (placeholder)** with a screen, like the fight-box test, for testing every fish.
- Pick the fish from a **drop-down** of every fish in the game. **No difficulty slider**: difficulty is set per fish.
- Every fish has a **section bar** that fills in. Some fish have one section, others several. **Each section is a fight-box mode with a difficulty range.**
- On the fight-box test, swap the carousel for the same kind of drop-down and remove the "How hard?" boxes (the slider does that job).

## How a fish fight works

- The meter has one segment per section. The first segment starts a quarter full (`rules.start`); the others start empty.
- Each section plays one fight-box mode ([chapter 04](04-fight-box-modes.md)). Filling the current segment moves on to the next section, which switches mode with a banner ("Section 2/3: Reel Spin").
- Filling the last segment **catches** the fish. If the current segment empties, the fish **gets away**, and the fight starts again from the first section.
- **Difficulty follows the fish's curve** (decided by Deovandski, 2026-11-22). Each fish sets `curve`:
  - `climb`: difficulty rises from the low end of the section's range to the high end as the segment fills, so the fish fights harder as it tires. Deovandski: it makes sense from a UX perspective.
  - `bell`: difficulty rises to the high end halfway through the segment and eases back to the low end, for fish that burn out (Magatum for now).
- **A strong section carries over** (decided by Deovandski, 2026-11-22). Finishing a section hands the next one a head start of up to `carry_max` (25% of the segment), scaled by the accuracy of the section just finished: nothing at or below `carry_threshold` (50%), the full head start at 100%. The banner says so ("Strong finish! Head start +20%"). Why: it rewards a good section right away (a hit of dopamine), and makes catch streaks easier to keep while chasing harder fish.
- **Streak:** catches in a row, kept across fish (so a streak can be carried to a harder fish) and reset by an escape. The stats row shows it, the catch banner shows the best, and it's saved.
- A catch adds the fish and a random reward from its pearl range to the save (what the old Cast button did), so the title screen's Pearls and Catches keep counting.

## The data

Every fish is in [`game/data/fish.json`](../../game/data/fish.json), easiest first:

```json
{
  "id": "magatum",
  "name": "Magatum",
  "based_on": "tuna (Japanese maguro + Portuguese atum)",
  "pearls": [3, 8],
  "curve": "bell",
  "description": "Fast and strong, but it burns out: ...",
  "sections": [
    {"mode": "flick_hookset", "difficulty": [0.3, 0.5]},
    {"mode": "reel_spin", "difficulty": [0.4, 0.6]},
    {"mode": "tap_tempo", "difficulty": [0.4, 0.6]}
  ]
}
```

- `mode` is a mode id from `fight_modes.json`; `difficulty` is `[from, to]` on the 0 (easy) to 1 (hard) scale, the same scale as the fight-box test's slider (shown there as 0–10).
- `curve` is `climb` (default) or `bell`.
- The top-level `rules` apply to every fish: `{"start": 0.25, "carry_max": 0.25, "carry_threshold": 0.5}`.
- The mode's `[easy, hard]` tuning pairs are blended at the section's current difficulty, so tuning a mode once tunes it for every fish.

## The fish so far

All four existed before as the Cast button's placeholder catches. Their sections are a first pass, themed on the real fish they're named after.

| Fish | Based on | Sections (difficulty 0–10) | Curve | Pearls |
| --- | --- | --- | --- | --- |
| Karkoi | carp (Karpfen + koi) | Slide Guide 1–3 | climb | 2–5 |
| Bagnazu | catfish (bagre + namazu) | Reel Spin 2–4, Slide Guide 3–5 | climb | 2–6 |
| Magatum | tuna (maguro + atum) | Hookset 3–5, Reel Spin 4–6, Tap Tempo 4–6 | bell | 3–8 |
| Sanbi (canon) | #HusbandOutWorld | Hookset 5–7 (decoys), Hold Hop 5–7, Lost Ref 6–8 | climb | 10–25 |

The "based on" pairs for Karkoi and Bagnazu are Claude's reading of the existing names under the two-language rule; Magatum's is the example in CLAUDE.md. Sanbi's fight is a placeholder until the lore is checked.

## The fish test screen

![The fish test in the web build: the title screen's new Fish test button, the fish drop-down, Bagnazu's intro card (two sections), and Bagnazu's first section (Reel Spin) with the two-segment meter between the boxes.](img/2026-11-22-fish-test.png)

- **Title screen → Fish test: fight a fish.** A drop-down at the top lists every fish with its section count; under it, Back, the stats for that fish (won, lost, the streak, current difficulty) and **Copy**.
- The intro card shows the fish's description, its sections and their difficulty ranges, its curve and its pearl range.
- Copy puts a results table on the clipboard:

```
Sinoi the Fisherman fish test, build 0.0.1, Android, screen 1080x2400, motion sensor yes
streak: 2 now, best 5
fish | sections | caught | lost | avg catch s | accuracy %
Magatum | Hookset 3-5, Reel Spin 4-6, Tap Tempo 4-6 (bell) | 1 | 3 | 41.2 | 57
```

- Results per fish and the streak are saved (`playtest.fish` and `playtest.streak`, save format v5, see [SAVE_FORMAT.md](../SAVE_FORMAT.md)). **Reset save** clears them.

## Code

- `scripts/fight/fight_stage.gd` — the fight box shared by both test screens: pads, segmented meter, cue, intro card, banners, touch routing, sensor, sounds.
- `scripts/fight/fish_fight.gd` — sections, segment fills, difficulty curves, carry-over, catch and escape.
- `scripts/fight/fish_catalog.gd` — reads `fish.json`.
- `scripts/fish_test.gd` + `scenes/fish_test.tscn` — the screen.
- `tests/test_fish_fights.gd` — data checks, section flow, climb and bell curves, carry-over, escape, and every fish's sections running.

## Answered (2026-11-22)

- **Difficulty inside a section:** climbing is right; some fish follow a bell curve instead, set per fish.
- **Meter between sections:** a strong finish carries over, to reward good play and make streaks easier to keep while chasing harder fish.
- **Drop-downs instead of carousels:** they take less screen, which is kept free for the tooling and debugging that playtests will add.

## Open questions

- **Escape:** emptying any section loses the fish and restarts from section one. With carry-over in place, should later sections also be more forgiving?
- **Streak rewards:** the streak is tracked and shown; does it earn anything (bonus pearls, rarer fish)?
- Fish beyond these four (canon Fihi, Ptaina, True Sanbi King, and new two-language fish) wait for the region and fish lists.
