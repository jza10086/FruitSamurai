# HUD comparison — 2026-10-13

Four **real runtime skins** for the same game. The main menu, 3D models, cut pieces, blade, spawning, collision and scoring rules remain unchanged. Combo callouts now use the bundled Chinese font and concise “3 连斩 / +15” text.

| Command-line style | Direction | Actual third-party PNG use |
| --- | --- | --- |
| `wenrexa5` | Gold/coral casual-game frame | Wenrexa UI Casual Free #5: counter frame, blank pause button, heart and missed-fruit icon |
| `mobile` | Compact cyan mobile UI | Wenrexa UI Casual Game Interface: counter panel, pause, heart and missed-fruit icon |
| `hypercasual` | Bright blue counter + yellow best-score badge | MadFireOn Hyper Casual UI: counters, pause background/icon, trophy, heart and crossed mark |
| `original` | Warm paper, ink numerals, gilt edge and vermilion seal | Original vector drawing; no third-party UI image |

All three downloaded UI sets are **CC0 1.0** on their authors’ official pages. Only selected PNGs are included; no paid PSD assets are used. Source PNG bytes are unchanged, with display scaling/nine-slicing and optional tint at runtime. Original archive-relative paths and SHA-256 hashes are in `assets/ui/MANIFEST.json`; source links/license verification are in `third_party/ui/ASSET-SOURCES-AND-LICENSES.md`.

## Play a skin

```sh
godot --path . -- --hud-style=wenrexa5
# Also: mobile, hypercasual, original. Default and invalid-name fallback: original.
```

No skin selector, debug badge or key prompt appears in the in-game HUD. The existing menu and pause menu are unchanged. Only the pause button consumes mouse/touch input. Counter artwork and lives markers permit swipes through them.

## Reproducible comparison scene

```sh
godot --path . --resolution 1920x1080 -- --hud-style=original --hud-preview --hud-capture=/absolute/path/original.png
```

Use a graphical renderer, not `--headless`, to capture. The optional capture flag creates a native 1920×1080 Godot viewport (even if the desktop window is smaller), then saves it as a PNG after a completed frame; it does not composite or generate a screenshot externally. Leave off `--hud-preview` for normal gameplay.

The comparison is an explicitly **preset, frozen demonstration state**, not a claimed recorded game result: score 245, best 980, one missed fruit, four intact fruits, a split lemon, blade, juice and a 3-fruit/+15 combo. Every style shares the same seeded scene and camera. It reuses the real game scene, GLB fruit, authored split pieces, effects and HUD. This allows fair visual comparison without random timing differences. The preview does not write its preset score to disk. It is a frozen visual fixture, not a playable mode; restart without the preview flag to play.

## Test

```sh
./tests/run_regression.sh /path/to/Godot_v4.7.2-stable_linux.x86_64
godot --headless --path . --script tests/hud_regression.gd
```

Use an isolated writable `HOME` and XDG directories when testing to keep player saves untouched. See `QA.md` for tested results and limitations.
