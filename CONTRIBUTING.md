# Contributing

Thanks for your interest! The project is in pre-production, directed by Deovandski Skibinski Junior, so the best contributions right now are:

- **Issues:** bugs in the pre-production build (say which phone or browser), problems with the website, or mistakes in the docs.
- **Lore corrections:** if anything contradicts the #HusbandOutWorld series, the series wins. Open an issue.
- **Pull requests:** small, focused changes are welcome. For anything bigger (new mechanics, art, new systems), open an issue first so it fits the white paper.

## Ground rules

- Read [docs/white-paper](docs/white-paper/README.md) before proposing gameplay changes. Design decisions recorded there are settled unless the maintainer reopens them.
- Keep the game **active**: no idle progress, no timers that run while the app is closed, no gacha, no ads, no in-app purchases.
- Code is GDScript for Godot 4.7. Run the tests before opening a PR:
  `godot --headless --path game -s res://tests/test_save_manager.gd`
- Art follows the [illustrator brief](docs/art/illustrator-brief.md): sizes, palette, naming and folders.
- **Never commit secrets** (keystores, passwords, service-account files). See [SECURITY.md](SECURITY.md).
- By contributing, you agree your code is released under the MIT license and your docs and content under CC BY-NC-SA 4.0, as described in [LICENSE](LICENSE).
