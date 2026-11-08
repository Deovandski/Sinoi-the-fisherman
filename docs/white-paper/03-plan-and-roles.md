# 03 — Plan and roles

Recorded November 8, 2026 from Deovandski's plan.

## Timeline

- **Now:** Deovandski finishes #HusbandOutWorld Vol 4 and other queued work. Meanwhile he gathers docs and writes this white paper.
- **Q1 2027:** production starts.
- The repository, website, build pipeline and save system are set up ahead of time (pre-production build).

## Roles

| Who | Role |
| --- | --- |
| Deovandski Skibinski Junior | Technical architect and director. Directs several Claude agents that build the game, so specs must be strong and explicit. |
| Claude agents | Build the game from the white paper and specs: code, data, tooling, prototype assets. |
| Illustrator | Has agreed to join and is learning pixel art and Aseprite from the [illustrator brief](../art/illustrator-brief.md). Draws the final art over the placeholder templates. |
| Friends | Playtesters, and the natural candidates for Google Play's closed test. |

## Art pipeline

1. AI-generated **placeholder** assets for the prototype, iterated as the game evolves.
2. Placeholders are handed to the illustrator as templates.
3. She draws the final art over them.

Placeholders must already follow the brief's final specs (canvas sizes, anchor points, animation tags, file names, folders) so final art drops in with no code changes. Mark placeholders clearly (a folder or a manifest) so none ship by accident.

## Playtesting

- The illustrator gets a **dedicated test phone** paid for by Deovandski and kept in developer mode, instead of her main phone: developer mode and USB debugging weaken a phone's security.
- Friends playtest too. If they join through the Google Play closed-testing link (not a sideloaded APK), their testing also counts toward the Play requirement for new personal accounts: 12 testers opted in for 14 continuous days.
- The website's browser version lets anyone try builds without installing anything.

## Open source

The project is open source: code under MIT, docs and original content under CC BY-NC-SA 4.0 (see [LICENSE](../../LICENSE)). Secrets (signing keys, store credentials) never enter the repository.
