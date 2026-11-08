# 02 — Design direction

Recorded November 8, 2026 from Deovandski. Items marked **decided** are settled; the rest are proposals to refine.

## Core pillar: active play

- The loop is about **catching fish**, not collecting. Some fish should be truly hard to catch, as in Stardew Valley.
- No gacha, idle or collection-driven progression.

## References

- **Stardew Valley — closest to the idea.** The loop centers on the catch, and some fish are hard to land. We also borrow its **bait and tackle system** and their effects.
- **Clash of Critters — rejected as a model.** Too gacha, and actual play isn't varied enough; its loop centers on collecting.
- **osu! and Project Diva (rhythm games) — inspiration for the fight input and the forgiveness settings.** Mechanics only, never names or assets.

## The fight box (decided)

- The fight happens in a **2D box that works like a trackpad**. It replaces Stardew's single bar; vertical, horizontal and diagonal sliders become path shapes inside the box.
- The player fights the fish by **sliding finger(s) across the box**, combined with tap and release, flicks, holds and other gestures, in the style of osu!.

### Fingers and hands (decided)

- **Start of the game: one finger, one hand.**
- **Progression goes up to at most 2 fingers**, sized so the **index and middle finger of one hand** can move independently. The box stays small enough for that.
- Two hands are allowed, especially on **tablets, which are supported**, but never required.

### Two-pad layout (decided)

- **Interactive pad** at the bottom of the screen, where the fingers go.
- **Shadow pad** above it that mirrors the targets, paths and finger positions, so the player watches the shadow while their fingers cover the real pad.
- Fish, line tension and progress also sit in the upper area.
- Open: how much the real pad shows (the pre-production touch test uses minimal visuals on the real pad, full visuals plus ghost finger dots on the shadow).

### Forgiveness and accessibility (decided)

- Timing-forgiveness settings like osu! and Project Diva, plus latency calibration.
- **Design intent: players beat hard fish with bait and tackle, not settings.** The settings exist for accessibility.
- Warning shown when the forgiveness settings are changed (Deovandski's wording): "Use this for accessibility, not to cheese the game! Otherwise you only have yourself to blame when you're bored"

### Mechanic vocabulary (proposal)

| Mechanic | Input | Fishing meaning |
| --- | --- | --- |
| Trace | Keep a finger on a moving marker along a path | Following the fish as it swims |
| Tap / release | Tap a target in its timing window, or lift on cue | Setting the hook; easing line tension |
| Flick | Fast swipe in a shown direction | Yanking against a sudden run |
| Hold / brace | Press and hold; release at the right moment | Bracing against a big pull |
| Spin | Circle a finger around a center point | Reeling in |
| Two-finger | Index + middle: two traces, or hold + trace | Hard and legendary fish only |

### Lore fish as pattern twists (proposal)

- **Sanbi:** decoy targets (fake lips and tails) that cost progress if tapped.
- **Ptaina:** ultrasonic stun briefly freezes the box.
- **Fihi:** shock pulses; fingers must be lifted during a shock.
- **Stardew behaviors (mixed, dart, smooth, sinker, floater)** map to path styles.

## Bait and tackle (direction decided; item list proposed)

With no seasons and no day/night cycle, **bait and region become the main levers for which fish bite**, and **tackle becomes the main lever for difficulty**. Stardew's items, translated to the fight box (verify Stardew details against the [Stardew Valley Wiki](https://stardewvalleywiki.com/Fishing) before final balancing):

| Stardew item | Stardew effect | Fight-box version |
| --- | --- | --- |
| Bait | Fish bite faster | Shorter wait for a bite |
| Wild Bait | Chance of catching two fish | Chance of a double catch |
| Magnet | More treasure | More treasure chests during fights |
| Magic Bait | Ignores season, time and weather | Attracts any fish in the region |
| Targeted Bait | Attracts one specific fish | Attracts one species (journal completion, quests) |
| Challenge Bait | More fish, lost with each mistake | Bonus fish for a perfect fight; each miss removes one |
| Cork Bobber | Bigger catch bar | Larger targets, wider path tolerance |
| Trap Bobber | Progress drains slower when the fish escapes | Progress drains slower when off-path |
| Lead Bobber | Bar doesn't bounce | Paths don't recoil or snap back |
| Barbed Hook | Bar clings to the fish | Marker pulls gently toward your finger |
| Spinner / Dressed Spinner | Faster bites | Faster bites |
| Treasure Hunter | Treasure easier to grab | Treasure targets bigger or linger longer |
| Curiosity Lure | Rare fish more likely | Rare fish more likely |
| Sonar Bobber | Shows the hooked fish | Previews the next pattern or the species |
| Quality Bobber | Better fish quality | Better fish quality |

Lore gear on top: for example an insulated line that blocks Fihi shocks, or ear-plugs that cancel Ptaina stuns.

## Difficulty ladder (proposal)

Common fish: one finger, slow traces and a few taps → mid-tier: flicks and holds, faster paths → legendaries: two-finger (index + middle) sections, orientation changes and lore twists. The tackle loadout is the intended counter to each step.

## Constraints

- **Touch latency varies by phone:** forgiving windows, calibration, and judging mostly on staying on the path rather than frame-exact timing.
- **Box size:** small enough for index-and-middle spacing; start around 160 x 160 base pixels and confirm in playtests, including tablets.
- **Tablets:** supported. The layout scales to wider screens, and the pad's physical size stays finger-sized rather than growing with the screen.
- **Engine:** Godot reports each finger separately (touch index on screen-touch and screen-drag events). The pre-production touch test already tracks two fingers on web and Android.
