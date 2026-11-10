# Verification

## Reproduce

From this repository on macOS or Linux, with Python 3, a C compiler and a local AWTRIX NG checkout:

```sh
python3 tools/build_host.py ../awtrix-ng
python3 -m unittest discover -s tests -v
python3 tools/render_previews.py --frames 600
```

The host compiles the checkout’s actual Berry interpreter with its existing configuration and precompiled objects. Device input, timers, rotation, audio and persistence are controlled mocks. Drawing primitives are native, clipped raster operations; the game’s Berry rendering code chooses every pixel. No firmware files are copied into this project.

## Results on 2026-11-09

All 20 Python test groups pass. The session suite inside them passes 113 Berry assertions. Checks cover:

- Fixed rules, on-demand metadata, no idle takeover, quiet default logs and optional debug messages.
- Clock controls, shared and separate controllers, neutral input gates, held countdown buttons and direction edges.
- Identical multiplayer obstacle seeds, second-turn handover, target display, reversed rematch order and completed-run score collection.
- Controller disappearance and slot changes, explicit confirmation, pause and quit cleanup, and a restarted countdown when a controller is lost before a run begins.
- Pausing a run and restarting a countdown when the game is hidden, with held clock buttons cleared.
- Initials, the results fanfare only for a new number one, stable score ties, the five-record cutoff, persistence reconstruction, reset, fresh-score migration and invalid stored rows.
- Matrix selection migration, installer backups, device-reported compile errors and fresh installation.
- Script sound upload only when the clock lacks the file or holds a different checksum, and a small shipped MP3.
- The egg countdown: a fresh world behind it, one crack per beat, the roar at the start, the same course afterwards and a run unaffected by the hatching overlay.
- A minimum LED level for far, mid, near and soil colours in every world except Matrix, with far ≤ mid ≤ near and decoration below hazard brightness by day and night.
- All ten worlds, day/night variants, P1/P2 colours, green Matrix dinos, renderer isolation from obstacle RNG, and exact paused-frame equality.
- Reduced ambient-effect work after sustained slow draws, no reaction to isolated spikes, step-by-step recovery and no adjustment while paused.

A 2,400-tick physics comparison matches the original script configured for 30 px/s, 5%, 500 pixels and 100% obstacle randomness. Obstacle generation and the first collision also match. The dino drawing block is unchanged byte for byte.

A 1,000-frame Matrix test checks that retained VM memory does not grow by more than 4 KiB after garbage collection. A separate 600-frame-per-world profile records these peak draw instruction counts:

| World | Peak Berry instructions per draw |
|---|---:|
| Grassland | 5,791 |
| Desert | 5,673 |
| Jungle | 6,076 |
| Neon City | 7,620 |
| Snow / Ice | 6,032 |
| Volcano | 6,528 |
| Moon Base | 5,927 |
| Storm Night | 6,674 |
| Crystal Caverns | 6,652 |
| Matrix | 7,841 |

VM heap after garbage collection was 107,935 bytes in each profile. Host mean draw times were about 0.11–0.14 ms. These values include the test environment’s Berry objects but exclude firmware and graphics-driver memory. They are not TC002 timing or memory measurements.

The machine-readable results are in [profile.json](../../previews/profile.json). Each world has a native 52×16 PNG and a 12× nearest-neighbour enlargement. The contact sheet arranges worlds in numeric order, two per row. Source/specification changes can change these measurements. The 2026-11-09 renderer optimisation was compared against the previous renderer over 7,080 frames covering all worlds, day/night, auto-mode transitions, haze, effect densities and budgets, Matrix brightness, parallax settings, HUD and menus; every frame was byte-identical. Removing the demo mode, the haze setting and the Matrix rain brightness setting (now fixed at its former 40% default) left those frames byte-identical again, with haze off. The later signature details for each world intentionally change the frames; they were reviewed on a TC002 at reduced brightness.

## Hardware checks still required

No TC002 was connected during implementation. Complete this playtest before distributing a release:

1. Install under the existing script name and check device-menu launch, absence from automatic rotation and return to normal clock apps on exit.
2. Check short/held jumps and ducking at 30 px/s and after several speed increases. Confirm the clock’s long-Select exit remains comfortable alongside the 400 ms high-jump threshold.
3. Play a match using shared controls, two Bluetooth controllers, two phones and a mixed arrangement. Disconnect a controller during a run and during the countdown; confirm the intended player can resume.
4. Inspect every world’s contrast on actual LEDs, including daylight/night changes, Matrix rain, both player colours and HUD text. Check scrolling joins during motion.
5. Check audio, winner feedback and the one-time audio failure fallback. Observe script errors, memory and input latency during a longer session.
6. Save initials, leave the game, wait at least five seconds for the device store to flush, then reboot and check the records. Verify reset and the old-Matrix upgrade path.

The game lowers its ambient-effect budget when draws exceeding 20 ms are sustained (more than about one in five). Isolated slow draws are ignored, and a long run of fast draws restores the budget step by step. It keeps gameplay timing unchanged. This fallback is tested with controlled timing; its usefulness on actual TC002 hardware remains to be measured.
