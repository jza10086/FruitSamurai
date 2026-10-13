# Fruit Samurai QA

Tested 2026-10-12 with Godot 4.7.2 stable (`ed1daf0bf`), Linux headless.

## Result

**69 regression checks passed, 0 failures.** Asset import, regression run, and a separate 120-frame main-scene smoke run exited successfully with no warnings or errors on the final run.

## Reproduce

From any directory:

```sh
./tests/run_regression.sh /path/to/Godot_v4.7.2-stable_linux.x86_64
```

The runner uses a temporary isolated user home and XDG directories. It imports assets, runs `tests/regression.gd`, and launches the main scene for 120 frames. Saved test scores do not alter the player's real save file.

## Verified

- Initial menu, Play, Pause, Continue, New Round, game-over replay, Escape toggling, and focus-loss pause.
- Swept segment-circle collision: fast diagonal crossings, misses, tangent and zero-length cases; a projected fruit is actually cut by a long diagonal swipe.
- One fruit scores once even if crossed and explicitly cut repeatedly before its queued deletion.
- Ten points per fruit, three-fruit +15 bonus, one-time combo settlement, and held strokes cannot chain separated waves indefinitely.
- Authored apple halves and eight watermelon wedges spawn correctly.
- Bomb ends the round without awarding fruit points; no score after game over; missed bomb does not cost a life; three missed fruit end the round.
- Pause freezes fruit, fragments, spawn timer, elapsed time, and effect processing. Resume clamps a large simulation delta to 0.033 seconds.
- Restart removes round entities, counters, effects, and resets gameplay while retaining best score.
- Touch UI pauses/resumes/restarts without beginning a slicing gesture; second finger cannot steal a stroke; mouse events during touch and the post-touch cooldown are ignored; mouse works afterward.
- Mouse release over UI ends the stroke before GUI consumption and pays the combo once. Motion without the left button settles a stale stroke without cutting; ordinary hover cannot slice, while held-left motion still cuts.
- Reduced-motion mode disables hit stop and lowers particle count; reduced-motion preference and best score persist.
- Ten model imports, four sound imports, display font, and Chinese font including a CJK glyph are valid resources.
- Play, New Round, Reduced Motion and Pause controls fit transformed physical bounds at both 1600×900 and 1280×720.

## Scope and limitations

These are engine-driven scene/model/input-handler tests, not screenshot-based visual approval or a real-device touchscreen test. Layout checks verify transformed control bounds, not every possible display aspect ratio or localized text appearance. Audible sound quality is not assessed in headless mode. GUI button signals and touch handlers are exercised directly; desktop mouse routing and actual device event delivery should also be checked during a graphical playtest.

## Graphical playtest

An independent desktop/cloud GUI playtest additionally verified real mouse-drag hits and score increases; visible apple/lemon halves and eight watermelon wedges; colored juice and the blade trail; three-miss game over; repeated Escape pause/resume; and pause-menu restart cleanup. The final palette was visually reviewed after fixing over-bright lighting, a too-strong wood pattern, and hard color-mask seams. Fruit now read as red apple, green pear, yellow lemon and striped green watermelon. The prototype remains stylized low-poly.

Combo and bomb rules are covered by automated scene tests; they are not claimed as independently completed physical-input GUI cases. Real touchscreen hardware, exported mobile builds, and audible sound quality were not tested.

## HUD variant update — 2026-10-13

Godot 4.7.2: **69 original regression checks and 685 added HUD checks passed, 0 failures**. `tests/hud_regression.gd` verifies all four skins at 1600×900, 1280×720 and 1920×1080, nine-digit score fitting, all 0–3 miss states with real source textures, repeated skin replacement without orphaned decorations, control bounds, and only-Pause input interception. Events are routed through the actual viewport to verify mouse/touch pause, resume and restart; decorative textures allow swipes through.

The full runner now imports, runs both suites, then smoke-tests the main scene and all four deterministic preview variants. The fixture cannot save its preset score to player progress. Screenshot fixtures are disclosed in `HUD_VARIANTS.md` and do not represent measured player performance. Headless input simulation does not replace actual touchscreen hardware testing.

### HUD graphical review

An independent cloud-desktop playtest verified the original skin with real mouse slicing (0 → 10), three-miss game over, pause/continue and Escape. All four skins were visually reviewed in native 1920×1080 Godot viewport captures with the same deterministic fixture. Visual review led to a smaller original paper scorecard, separated best-score line, stronger combo hierarchy, improved mobile number/caption spacing and corrected HyperCasual trophy layering. The other three skins share the tested gameplay and received automated viewport mouse/touch routing checks; they are not claimed as separately physically played. Actual touchscreen hardware remains untested.
