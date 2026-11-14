# GodotPartyDefault · 水果武士

从正式大厅选择「GodotPartyDefault · 小游戏轮换」，在 minigames 池启用本包。支持 1–8 人，可由一人创建房间单独挑战；单人开局时，池中其他已选小游戏也须支持单人。默认 90 秒，房主可设 15–300 秒。不要直接 F6 正式入口 game.tscn；入口需要框架注入 PartyAPI。

按住鼠标左键划过水果；每果 10 分，同一笔连续切中至少 3 个有连击奖励。切中炸弹或漏掉三个水果结束个人挑战。各玩家独立操作，房主汇总分数，按分数降序排名，同分并列。所有人结束或房主时限到达后统一结算。暂停菜单和窗口失焦不会暂停网络回合，不能在一局中重新开始。

本地设置可修改切割绑定、减弱动态效果。公共三维画质复用原版协议。观战者看到场景及实时分数榜，不能提交分数；当前不转播其他玩家的逐帧刀光。结束后的个人画面冻结，仍可查看分数榜。

`game.gd` 负责正式回合、网络成绩与停止清理，`scripts/main.gd` 负责本地切割模拟。固定装饰在 `scenes/decor.tscn`，四种可编辑皮肤在 `scenes/hud/`；默认 original，可在 `scenes/main.tscn` 中替换 HUD 子场景并保持 hud 导出引用。皮肤脚本只更新分数、漏果状态与文字，不重建布局。切片、抛出水果和刀光仍按对局动态生成。

`audio/` 保存四个 Cue 和固定八声音池，复用协议 PartyGameAudio，保留原音效、-7 dB 基础音量及切果随机音高。最终音量叠加协议作用域音量，没有独立静音设置；停止、取消和结算均停止声音，离开作用域时关闭音频。进度或排名发送失败会停止本局并报告框架，不自动重试。

F6 预览使用 `scenes/main.tscn`：鼠标左键切割，Esc 暂停/继续；读取同一中文 Translation，仅修改本次预览状态，不保存偏好或提交成绩。正式模式使用 PartyInput 和框架菜单。截图与演示分数注入只在主项目 `tmp/test/fruit_samurai/`，正式脚本不处理 `--hud-capture`。

仅支持 standard 普通排名局；不实现 resource 额度或道具效果。分数由本地模拟产生，房主校验真实发送身份、类型、有限数、范围、递增序号及重复终态；不是严格防作弊模式。

移植自项目提供的 temp_game/FruitSamurai，保留 Kenney 水果、切割碎片、音效和原创 HUD。来源及许可证见 assets/ASSET_SOURCES.md、third_party/ 和项目 doc/assets/project_credits.md。原型的其他 HUD 素材随来源记录保留，正式版本使用 original 皮肤。

按住切割键划过水果，连续切中可获得连击奖励。避开炸弹，各自挑战，按最终切果分数排名。

## 包内开发文档

未带 `res://` 的源码路径以本包根目录为基准。

- [Third-party assets](gp_fruit_samurai_assets_asset_sources.md)
- [M07 水果武士　A/B　依赖 G01、G03](gp_fruit_samurai_development.md)
