# Save format

Saves are plain JSON, so players can back them up, move them between the browser and Android, and read them. `game/scripts/autoload/save_manager.gd` owns the format.

## Where saves live

| Platform | Automatic save | Export | Import |
| --- | --- | --- | --- |
| Browser | `user://save.json` (browser IndexedDB for this site) | Downloads `sinoi-save-YYYYMMDD-HHMMSS.json` | File picker |
| Android | `user://save.json` (private app storage) | System file picker; clipboard if that fails | System file picker, or *Paste save* |
| Desktop (editor) | `user://save.json` | Native file dialog | Native file dialog, or paste |

## Format policy until 1.0

Decided by Deovandski, 2026-11-22:

- **Until alpha:** the save format can keep changing without worries. Still bump `VERSION` and add a simple `_migrate()` step (it's cheap and keeps testers' saves loading), but don't hold back a change to protect old pre-alpha saves.
- **Heading from alpha into beta:** prepare to **lock the save format for 1.0**: review every key, remove placeholders, write the final version of this page, and test migrations from every alpha version.
- **From 1.0 on:** the format is locked; changes must be additive and always migrate.

## Version 3 (current)

```json
{
  "format": "sinoi-save",
  "version": 3,
  "game_version": "0.0.1",
  "created_at": "2026-11-08T13:00:00",
  "updated_at": "2026-11-08T13:05:12",
  "pearls": 12,
  "catches": [
    { "fish": "magatum", "pearls": 5, "caught_at": "2026-11-08T13:04:50" }
  ],
  "settings": {
    "timing_forgiveness": 0,
    "left_handed": false
  },
  "playtest": {
    "fight_modes": {
      "hold_hop": {
        "difficulty": 7,
        "levels": {
          "5": { "feel": 2, "catches": 4, "escapes": 0, "catch_seconds": 38.0, "good": 20.5, "judged": 24.0 },
          "7": { "feel": 3, "catches": 2, "escapes": 1, "catch_seconds": 21.5, "good": 8.0, "judged": 10.0 }
        }
      }
    }
  }
}
```

| Key | Type | Meaning |
| --- | --- | --- |
| `format` | string | Always `sinoi-save`. Anything else is rejected. |
| `version` | int | Save format version. Newer than the game's = rejected; older = migrated. |
| `game_version` | string | Game version that last wrote the save (informational). |
| `created_at`, `updated_at` | string | UTC timestamps, ISO 8601 without zone. |
| `pearls` | int | Money, in pearls (the base coin of Vraki). |
| `catches` | array | Placeholder catch log: fish id, pearls earned, time. |
| `settings.timing_forgiveness` | int | Accessibility timing window (0 = default). |
| `settings.left_handed` | bool | Mirror the fight box. |
| `playtest.fight_modes` | object | Pre-production fight-box playtests, keyed by mode id (`game/data/fight_modes.json`). Only modes that were played or rated appear. |
| `playtest.fight_modes.<id>.difficulty` | int | The mode's difficulty slider level, 0 (easy) to 10 (hard); 5 is the middle. |
| `playtest.fight_modes.<id>.levels` | object | Results per difficulty level, keyed by the level as a string (`"0"` to `"10"`). |
| `….levels.<level>.feel` | int | The tester's "How hard?" rating, 1–5 (0 = not rated). |
| `….levels.<level>.catches`, `.escapes` | int | Fish caught and fish that got away at that level. |
| `….levels.<level>.catch_seconds` | float | Total seconds spent on caught fish (average = this ÷ catches). |
| `….levels.<level>.good`, `.judged` | float | Accuracy totals: accuracy = good ÷ judged. |

## Version history

| Version | Change |
| --- | --- |
| 1 | First format: pearls, catch log, settings. |
| 2 | Adds `playtest.fight_modes` (fight-box ratings and results). Version 1 saves get an empty `playtest` section. |
| 3 | Fight-box results are split by difficulty level (`difficulty` + `levels`). Version 2 results move to level 5, the middle (they were played at the fixed tuning). |

## Import rules

- Must parse as a JSON object, under 1 MB, with `format` = `sinoi-save` and a `version` from 1 to the current version (3).
- Missing keys are filled with defaults. Values of the wrong type fall back to the default. Unknown keys are kept, so newer fields survive a round trip through an older build of the same version.
- A rejected import leaves the current save untouched.

## Changing the format

1. Bump `VERSION` in `save_manager.gd`.
2. Add a step to `_migrate()` that upgrades the previous version.
3. Update `default_data()`, this page (including the version history) and `tests/test_save_manager.gd`.
4. Follow the format policy above: free to change until alpha, locked from 1.0.
