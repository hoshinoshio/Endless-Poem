# 阶段 B：拖拽时间卡、五类目标与 NPC 态度

分支：`stage-b-drag-cast`。提交标题：`Drag-to-cast time cards with world slow-mo, target categories and NPC attitude`。

## 实现与范围

权柄解锁后常驻底部居中的三张 compact 手牌；6px 拖拽阈值、真实时间 0.1 秒悬停放大、0.16 秒取消飞回、遮挡主角时 0.45 透明度。拖拽期间世界保持 0.05x，松手、右键、Esc、模态、挂起与场景退出均恢复 1x。没有使用 Engine.time_scale。

时间缩放位于 exploration_world.advance_simulation 入口。主角物理/动画、敌人 AI/攻击/动画、环境、NPC、temporal 效果时长/冷却与态度防刷共用世界时间。停止 2 秒 / 冷却 6 秒；快进 2 倍、4 秒 / 冷却 8 秒；瞬时倒退 3 秒 / 冷却 10 秒。灰盒数值及五类性质集中在 time_card_config.gd。

compact 裁剪到 250×238，并在底边补黄铜切角；收藏仍为完整卡。历史默认 30Hz、128 帧，覆盖约 4.27 秒世界时间；不足三秒时回到最早可用快照。主角历史不含 HP。重叠优先级为 hero > monster > npc > item > scene。

暮笙态度与 buff 防刷计时写入 exploration_run.npc_attitudes。友善交互一次情报、达到信赖一次赠礼；奖励记录与证据原子提交，同时保留安全检查点位置。敌对拒绝交互、改 monster 类别并走开 180px，没有新增伤害或战斗规则。

独立预览：scenes/previews/drag_cast_preview.tscn。复用主角、巡逻者与暮笙，另有可推木箱与灯。预览使用临时存档并在退出时清理；F1/F2/F3/F4 调试四种性质，保留 buff 防刷冷却，没有接入主流程。

## 旧断言逐条更新

| 文件 | 原覆盖 | 本阶段等价覆盖 |
|---|---|---|
| tests/authority_session_acceptance.gd | 修复前后时钟按钮显隐、点击展开与选卡；首次 Esc 取消、再次关闭卡库、第三次暂停；重载恢复入口 | 修复前后手牌显隐与三张卡；拖拽进入 0.05x；首次 Esc 取消并恢复 1x，第二次暂停、第三次恢复；重载恢复常驻手牌 |
| tests/proximity_interaction_session_acceptance.gd | 重访装置关闭卡库并清除选中卡 | 重访装置打开面板强制取消拖拽并恢复 1x；原生 E 信号、修复幂等与所有原交互覆盖保留 |
| tests/card_frame_acceptance.gd | 点击时钟后卡库可容纳卡面、避开血条与时钟、卡间不重叠 | 常驻手牌可容纳卡面，避开移至左下的血条、卡间不重叠；新增描述隐藏与 250×238 缩放尺寸两条；收藏完整卡覆盖保留 |
| tests/oct12_enemy_time_delta.gd | 重叠处优先选敌人、先选卡再点敌人；永久停止主角的测试前提 | 重叠处按新规则优先主角；拖到敌人露出的上缘施放。跳跃躲避夹具使用实际向上速度，适配停止不再永久持续；敌人冻结、攻击只命中一次、躲避、死亡/重试及藏品保留覆盖均保留 |
| tests/authority_world_acceptance.gd | 倒退后继续 advance 才检查云相位变小 | 施放瞬间检查云相位已回到历史；暂停与其他世界覆盖保留 |
| tests/pixel_world_integration.gd | 持续倒退一段时间后恢复最近的 NPC 帧 | 瞬时倒退恢复最早可用的已记录 NPC 完整状态；停止、暂停与视觉资产覆盖保留 |
| tests/temporal_controller_acceptance.gd | 持续倒退、永久停止、倒退保持模式直到 reset、空历史保持不动 | 瞬时恢复深拷贝历史、有界历史钳制、停止到期恢复、恢复后正常推进、新目标只能恢复初始状态；任意对象注册、解锁、独立局部时间、2 倍速、无效目标、暂停、历史上限及卡组件覆盖保留 |

## 最终测试原文

命令：`powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1`

```text
PASS authority_dial_acceptance
PASS authority_session_acceptance
PASS authority_world_acceptance
PASS card_frame_acceptance
PASS drag_cast_acceptance
PASS exploration_world_gates_test
PASS exploration_world_movement_test
PASS locomotion_acceptance
PASS menu_a_quit_acceptance
PASS npc_attitude_acceptance
PASS oct12_enemy_time_delta
PASS oct12_fork_delta
PASS pixel_actor_acceptance
PASS pixel_authored_assets
PASS pixel_motion_continuity
PASS pixel_world_integration
PASS proximity_interaction_session_acceptance
PASS sprite_atlas_acceptance
PASS start_menu_acceptance
PASS temporal_controller_acceptance
PASS time_authority_store_acceptance
0 failed
```

新增两个测试文件合计恰好 20 项检查：

```text
DRAG_CAST_CHECKS=12 FAILURES=0
NPC_ATTITUDE_CHECKS=8 FAILURES=0
```

Godot 导入完成，退出码 0，无脚本错误。`git diff --check` 通过。

GPU 预览使用 NVIDIA RTX 5060 Ti / OpenGL Compatibility，在 RenderingServer.frame_post_draw 后截图；通过预览内相同鼠标按下/移动路径进入拖拽，没有新增截图验收脚本。

```text
DRAG_CAST_PREVIEW_CAPTURE=OK
```

截图：`logs/drag_cast_preview.png`（1440×900，已确认在 Git 忽略目录，未加入提交）。截图可见五类目标高亮、暮笙悬停标签与效果预览、compact 占位与幽灵、降饱和暗角。

## 偏离及实现选择

无已知功能范围偏离。没有修改主地图布局、角色美术或开场流程。血条移至左下，给常驻居中手牌留空间。register_target 的 category 作为末尾参数并默认 scene，保留旧通用调用兼容；生产注册点均显式给出类别。控制器保留低层 select_card/select_target 兼容接口，探索会话已经移除旧点击施放入口。collection_store.gd 无需改动：现有字典与原子提交接口可直接持久化新增字段。NPC 敌对标记持续保留，未添加未定义的战斗或解除敌对机制。

## 仍需人工试玩确认

- 0.05x 下移动、跳跃和施放节奏，以及恢复 1x 的突变感。
- 0.1 秒悬停抬卡、0.16 秒飞回、小幽灵尺寸及遮挡时 0.45 透明度。
- 主角优先的重叠目标选择手感，尤其角色贴身与木箱附近；目标框大小和标签是否易读。
- NPC 档位气泡约 2 秒的可读性、走开 180px 的距离，以及额外情报与赠礼日志的呈现。

自动化与 GPU 截图已验证行为和当前画面，未将其表述为完整人工试玩。

## 改动文件清单

- `scripts/authority/card_frame_preview.gd`
- `scripts/authority/temporal_controller.gd`
- `scripts/authority/time_card.gd`
- `scripts/exploration/exploration_session.gd`
- `scripts/exploration/exploration_world.gd`
- `tests/authority_session_acceptance.gd`
- `tests/authority_world_acceptance.gd`
- `tests/card_frame_acceptance.gd`
- `tests/oct12_enemy_time_delta.gd`
- `tests/pixel_world_integration.gd`
- `tests/proximity_interaction_session_acceptance.gd`
- `tests/temporal_controller_acceptance.gd`
- `scenes/previews/drag_cast_preview.tscn`
- `scripts/authority/drag_cast_hand.gd`
- `scripts/authority/drag_cast_hand.gd.uid`
- `scripts/authority/drag_focus.gdshader`
- `scripts/authority/drag_focus.gdshader.uid`
- `scripts/authority/time_card_config.gd`
- `scripts/authority/time_card_config.gd.uid`
- `scripts/exploration/npc_attitude.gd`
- `scripts/exploration/npc_attitude.gd.uid`
- `scripts/previews/drag_cast_preview.gd`
- `scripts/previews/drag_cast_preview.gd.uid`
- `scripts/previews/drag_cast_world.gd`
- `scripts/previews/drag_cast_world.gd.uid`
- `tests/drag_cast_acceptance.gd`
- `tests/drag_cast_acceptance.gd.uid`
- `tests/npc_attitude_acceptance.gd`
- `tests/npc_attitude_acceptance.gd.uid`
- `docs/drag_cast_stage_b_report.md`（本报告）
