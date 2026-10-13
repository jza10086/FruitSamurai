# Fruit Samurai

独立的 3D 水果切击街机原型。使用 **Godot 4.7.2** 打开 `project.godot`，等待资源导入后按 F5。中文界面，鼠标按住划动或单指滑动；每果 10 分，连续切中至少 3 个有额外连击分。漏掉 3 个水果或切中炸弹结束，Esc 暂停。主菜单可开启减弱动态效果。

水果来自 Kenney Food Kit 2.0（CC0），字体为 DejaVu 与 Noto CJK，具体文件、来源链接、许可证和修改方式均见下方资产清单及 `third_party/`。切割使用预制半体与西瓜楔块，不是任意网格实时布尔切割。

A complete single-player fruit-slicing arcade prototype for **Godot 4.7.2**, with real 3D fruit, authored cut pieces, colored juice, a luminous blade trail, original synthesized sound effects, and a full-frame dark-wood dojo presentation. An original project inspired by the fruit-slicing genre; it does not use Fruit Ninja branding, code, or proprietary assets.

## Run

1. Install Godot 4.7.2 (standard build; no .NET required).
2. Import `project.godot` and let the GLB/font/audio assets import.
3. Press **F6** in `scenes/main.tscn`, or **F5** to play the project.

The Compatibility renderer is selected. No plugins, network access, downloads, or external runtime dependencies are needed. The authored canvas is 1600 × 900 and scales to the window. Landscape 16:9 is recommended.

## Play

- Choose **开始挑战** (Start).
- Hold the left mouse button and sweep across fruit. Touch screens support one finger swiping.
- Each fruit is worth **10 points**. Slice at least **3 fruit in one continuous streak** for a bonus of **5 × fruit count**. The streak settles on release or after 0.30 seconds without a hit.
- Fruit rise from the bottom, rotate in 3D, and fall under gravity. Missing **three** fruit ends the round.
- Cutting a **black bomb with a glowing fuse** ends the round immediately. Avoiding bombs costs nothing.
- **Esc** or **暂停** pauses the round. **继续挑战** resumes and **重新开始** starts a new round from the pause menu. Losing window focus also pauses automatically.
- Enable **减弱动态效果** (Reduced Motion) from the menu for no screen shake/hit stop, stationary menu fruit and quieter effects.
- Best score and Reduced Motion are saved locally in Godot's `user://progress.cfg`.

## Implementation

- `scenes/main.tscn`: editable 3D camera, environment, board, lights, gameplay containers, menu and HUD Controls.
- `scripts/main.gd`: explicit menu/playing/paused/over states, wave spawning, score, continuous screen-space segment-vs-projected-circle collisions, mouse/touch arbitration and cleanup.
- `scripts/fruit.gd`: imported GLB setup, normalized sizing, gravity/spin and authored bomb mesh.
- `scripts/slice_effects.gd`: layered fading blade core/glow, colored juice, bomb sparks and transient combo callouts.
- `scripts/board.gdshader`: procedural wood-grain backdrop.
- `scripts/fruit_palette.gdshader`: runtime fruit-color adjustment and procedural watermelon rind stripes; original GLB and texture files are unchanged.
- `tests/`: automated model and scene regression coverage.

Fruit are actual `MeshInstance3D` models lit with warm key/cool fill lights and shadows. Slicing uses a conservative projected circular hit area rather than pixel-perfect mesh collision, and sweeps the entire input segment to avoid fast-swipe tunneling. A target can score only once. Multitouch is intentionally limited to the first active finger; emulated mouse/touch events are disabled and a touch cooldown suppresses duplicate mouse input.

### Cutting method and limitations

This prototype uses **authored cut pieces, not arbitrary runtime mesh Boolean slicing**. Apple and pear split into matching supplied halves. Lemon uses its supplied cross-section halves. Pieces rotate and separate in relation to the swipe direction. Watermelon uses the model's eight authored wedges, which scatter independently. The cut surface is therefore a prepared cross-section and may not exactly match the original fruit's orientation at impact. There are four playable fruit types, one classic endless mode, no online services, and no mobile export/signing setup.

## Asset sources and licenses

| Files | Author / source | License | Use / changes |
| --- | --- | --- | --- |
| `assets/models/apple.glb`, `apple-half.glb`, `pear.glb`, `pear-half.glb`, `lemon.glb`, `lemon-half.glb`, `watermelon.glb` | **Kenney**, [Food Kit 2.0](https://kenney.nl/assets/food-kit) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Playable 3D fruit and fragments. Original files unchanged; runtime centering, scaling, rotation, separation and palette remapping. |
| `assets/models/banana.glb`, `orange.glb`, `pineapple.glb` | Kenney, same Food Kit | CC0 1.0 | Included optional source models; not spawned by the current game. No cut halves claimed for these models. |
| `assets/models/Textures/colormap.png` | Kenney, same Food Kit | CC0 1.0 | Shared original palette texture. Preserve this relative folder path when moving GLBs. |
| `assets/Chinese.ttc` | [Noto CJK / Google](https://github.com/notofonts/noto-cjk) | SIL Open Font License 1.1 | Unmodified Chinese UI font from the existing project; notice in `third_party/Noto-LICENSE.txt`. |
| `assets/Display.ttf` | [DejaVu Fonts](https://dejavu-fonts.github.io/), DejaVu Sans | Bitstream Vera / DejaVu license | Unmodified font, renamed for a portable display-font path. Full notice in `third_party/DejaVu-LICENSE.txt`. |
| `assets/audio/*.wav` | Original procedural synthesis for this project | MIT, as project code | Slice noise sweep, harmonic combo chime, bomb rumble and missed-fruit tone; no sampled third-party recordings. |
| Board shader, bomb meshes, blade, juice and original HUD skin | Original code for this project | MIT | Generated at runtime, no third-party images. |

The original Kenney notice is in `third_party/LICENSE-Kenney.txt`. `assets/ASSET_SOURCES.md` contains detailed provenance, and `assets/ASSET_MANIFEST.json` records original sizes and SHA-256 hashes. CC0 allows commercial use and modification without attribution; credit is retained here for traceability.

## Tests

Run after the initial editor import:

```sh
godot --headless --path . --script tests/regression.gd
```

See `QA.md` for the actual tested version, scenarios, and remaining limits. GUI checks and headless checks are different: headless logic tests cannot establish rendered visual quality or actual touch hardware behavior.

## HUD comparison skins

The in-game HUD has three real CC0 asset-pack treatments plus an original paper/ink/red-seal treatment. The main menu is unchanged. Run with `-- --hud-style=wenrexa5`, `mobile`, `hypercasual`, or `original` (default). See [HUD_VARIANTS.md](HUD_VARIANTS.md) for the exact source credits, unmodified source-file manifest, graphical capture command and deterministic demonstration-state disclosure.
