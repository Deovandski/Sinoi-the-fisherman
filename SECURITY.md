# Security

If you find a security problem in the game, this repository or the website, please open an [issue](https://github.com/Deovandski/Sinoi-the-fisherman/issues), or for anything sensitive use GitHub's [private vulnerability reporting](https://github.com/Deovandski/Sinoi-the-fisherman/security/advisories/new).

## Secrets never go in this repository

This is a public, open-source repository. Never commit:

- Android signing keystores (`*.keystore`, `*.jks`) or their passwords;
- Godot's `export_credentials.cfg` (it lives in `game/.godot/`, which is ignored);
- Google Play or Google Cloud service-account JSON files, API keys, `.env` files.

The `.gitignore` blocks the common file names, but it can't catch everything: check `git status` before every commit. Release signing happens on the maintainer's own machine (see [docs/BUILDING.md](docs/BUILDING.md)); CI only builds debug APKs with a throwaway key.

If a secret is ever committed, treat it as leaked: rotate it first, then remove it from history.

Copyright (c) 2026, Deovandski Skibinski Junior.
