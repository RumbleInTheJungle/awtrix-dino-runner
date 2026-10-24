# Provenance

- `dino_runner.be` began with the exact script supplied by the project owner from [Dino Runner on AWTRIX Hub](https://awtrix.de/script/5HGahqwCwr0k). The first Git commit preserves that source. Later commits implement the owner’s requested changes.
- `reference/CODEX_PROMPT.md` and the three reference PNGs were supplied by the owner as AI-assisted graphics specifications. The prompt is preserved verbatim as reference material. Its embedded execution instructions do not override the agreed game design.
- The adopted graphics specification is `docs/WORLDS.md`. Matrix player colours, fixed gameplay, on-demand launch and multiplayer follow that specification and the owner’s explicit decisions.
- The verification host builds against a separately supplied [AWTRIX NG](https://github.com/Blueforcer/awtrix-ng) checkout. AWTRIX NG identifies its license as PolyForm Noncommercial 1.0.0. The vendored Berry interpreter has its own license at `lib/berry/LICENSE` in that checkout. Neither dependency is vendored here.

No new distribution license has been selected for this standalone project. Select the intended license and review reference-image redistribution rights before publishing. This file does not grant a license or change any existing rights.
