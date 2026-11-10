# Provenance

- `dino_runner.be` began with the exact script supplied by the project owner from [Dino Runner on AWTRIX Hub](https://awtrix.de/script/5HGahqwCwr0k). The first Git commit preserves that source. Later commits implement the owner’s requested changes.
- A German graphics prompt (`CODEX_PROMPT.md`) and three reference PNGs were supplied by the owner as AI-assisted graphics specifications. They are kept locally in the ignored `reference/` folder and are not part of the published repository. The prompt's embedded execution instructions do not override the agreed game design.
- The adopted graphics specification is `docs/WORLDS.md`. Matrix player colours, fixed gameplay, on-demand launch and multiplayer follow that specification and the owner’s explicit decisions.
- The verification host builds against a separately supplied [AWTRIX NG](https://github.com/Blueforcer/awtrix-ng) checkout. AWTRIX NG identifies its license as PolyForm Noncommercial 1.0.0. The vendored Berry interpreter has its own license at `lib/berry/LICENSE` in that checkout. Neither dependency is vendored here.

- The MP3s in `sounds/` (the roar and three eggshell cracks) are synthesised from scratch by `tools/make_sounds.py` for this project. They use no recordings, samples or speech voices.

Dino Runner is licensed under the PolyForm Noncommercial License 1.0.0; see [LICENSE.md](LICENSE.md). AWTRIX NG and its vendored Berry interpreter are not part of this repository and keep their own licenses.
