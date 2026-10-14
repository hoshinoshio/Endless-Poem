# 靠近交互按键与 Godot 信号弹窗验收

交付日期：2026-10-11；实机运行日志及截图于2026-10-10生成。工程保持在 `C:\Users\hoshi\Endless Poem\endless-poem`，Godot 4.7.2，正常入口 `scenes/main.tscn`。

## 本轮实现

1. 正常地图的教程不再显示 A/D、Space、按E等常驻按键说明，保留简短的场景问题文字。移除了装置、调查点、暮笙旁分散绘制的旧操作文案。
2. 统一显示一个银白 E 按键标识，只针对180世界像素范围内最近且满足条件的对象。装置的引导阶段、落地、平台高度与水平位置限制同时约束提示和真正的交互。暮笙的提示跟随实际NPC位置。
3. 按键事件调用 `ExplorationWorld.interact()`，重新检查当前位置与可用性后发出原生 Godot `interaction_requested(event_id: String)` 信号。会话控制器通过 `.connect(_interact)` 接收信号并打开对应的原生 Control 交互界面，不依靠上一次缓存的提示授权交互。
4. 停摆装置先打开界面，点击“校准并修复”才调用原有原子存档接口；成功后显示完成界面并保留停止时间、快进时间、倒退时间三张卡。返回或Esc不执行修复；重访已修复装置不再提供修复按钮，不重复赠卡。
5. 原有调查、暮笙证词继续打开相应界面。新规则下原先按键无反馈的补给、休整和表盘位置改为观察界面，不开启旧卡牌商店或新增战斗规则。
6. 弹窗打开时暂停地图、清空待执行跳跃与移动、关闭卡库并取消已选能力，隐藏地图E标识和教程。连续E、按键重复事件及空格不会穿透界面触发修复；返回/Esc恢复探索，已完成的教程保持隐藏。

界面沿用已采用的A银白细线及半透明暗底。依照Game Studio界面流程检查场景遮挡、提示层级和弹窗输入边界，实际实现使用Godot，不切换浏览器引擎。本轮未新增图片素材，也未调用ComfyUI生成。

## 实际验证

| 检查 | 结果 | 日志 |
|---|---|---|
| 新交互会话检查 | 22项通过 | `verification/proximity_interaction_session_stdout.log` |
| 新GPU键鼠操作与截图检查 | 31项通过 | `verification/proximity_interaction_gpu_stdout.log` |
| 原有世界/教程平台/时间目标检查 | 26项通过 | `verification/proximity_world_regression_stdout.log` |
| 原有会话与原子授予检查 | 24项通过 | `verification/authority_session_after_dialog_stdout.log` |
| 原有引导检查，未修改 | 1项旧提示文案断言失败 | `verification/proximity_onboarding_unchanged_stderr.log` |

前四组Godot退出码均为0，stderr为空。GPU测试使用独立存档、实际键盘事件与鼠标点击；角色先放置到指定位置，再通过90帧实际模拟落地。这是交互流程和画面验收，不声称本次重新徒步走完整张地图。

截图：

- [远处无交互按键](verification/proximity_01_far.png)
- [靠近装置后显示E](verification/proximity_02_near.png)
- [按E打开装置界面](verification/proximity_03_device_panel.png)
- [修复并返回探索](verification/proximity_04_repaired_continue.png)
- [按E打开暮笙证词](verification/proximity_05_npc_panel.png)

## 旧测试保护与已知不一致

本轮开始前冻结了 `tests/` 下109个文件，基线为 `verification/proximity_tests_before_2026-10-10.json`。新增了两份独立测试，未调整既有断言：

- `tests/proximity_interaction_session_acceptance.gd`
- `tests/proximity_interaction_render.gd`

`tests/onboarding_acceptance.gd` 的旧断言同时要求教程恢复到步骤2、提示必须是 `E  调查灯台`。当前恢复步骤仍为2，但地图按键文案已按用户要求移除，因而该断言失败；原测试和失败日志保留。

`tests/authority_entry_render.gd` 与 `tests/authority_playthrough_render.gd` 仍假定按 E 立即修复并赠卡，与当前“先打开界面，再确认修复”流程不同。本轮未重跑这两份旧GPU流程，不将其历史通过结果算作本轮验证。

最终独立核对确认109/109个冻结文件的SHA-256与字节长度均一致；新增的两份测试另外列出。详见 `proximity_interaction_audit_2026-10-11.md` 和 `verification/proximity_tests_after_2026-10-11.json`。

## 文件与执行分工

| 子任务 | 实际执行模型 | 修改/产出范围 |
|---|---|---|
| 接近条件、单一E标识、移除地图按键文案 | 主代理 | `exploration_world.gd`、`map_ambient.gd`、两份教程脚本 |
| 信号后的交互界面、确认修复、防重复与返回 | `gpt-6.1-sol` | `exploration_session.gd`、新增会话测试 |
| 实际Godot键鼠验证、截图 | `gpt-6.1-sol` | 新增GPU测试和验证产物 |
| 冻结测试、提示来源和接口独立审查 | `gpt-6-luna` | 新增审查记录与哈希报告 |
| 集成、原有检查运行、画面复核与说明更新 | 主代理 | README及本报告 |

子代理通过工具显式指定上述模型；工具没有提供主代理实际模型ID，因此不据角色分工声称已验证其模型名称。
