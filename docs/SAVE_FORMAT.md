# Save format

Saves are plain JSON, so players can back them up, move them between the browser and Android, and read them. `game/scripts/autoload/save_manager.gd` owns the format.

## Where saves live

| Platform | Automatic save | Export | Import |
| --- | --- | --- | --- |
| Browser | `user://save.json` (browser IndexedDB for this site) | Downloads `sinoi-save-YYYYMMDD-HHMMSS.json` | File picker |
| Android | `user://save.json` (private app storage) | System file picker; clipboard if that fails | System file picker, or *Paste save* |
| Desktop (editor) | `user://save.json` | Native file dialog | Native file dialog, or paste |

## Version 1

```json
{
  "format": "sinoi-save",
  "version": 1,
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

## Import rules

- Must parse as a JSON object, under 1 MB, with `format` = `sinoi-save` and a `version` from 1 to the current version.
- Missing keys are filled with defaults. Values of the wrong type fall back to the default. Unknown keys are kept, so newer fields survive a round trip through an older build of the same version.
- A rejected import leaves the current save untouched.

## Changing the format

1. Bump `VERSION` in `save_manager.gd`.
2. Add a step to `_migrate()` that upgrades the previous version.
3. Update `default_data()`, this page and `tests/test_save_manager.gd`.
