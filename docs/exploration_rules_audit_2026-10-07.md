# 横版探索规则审计 — 2026-10-08 最终复核

主代理 Astra（用户确认）负责集成和验收，gpt-6.1-sol 实现与恢复测试，gpt-6-luna 只读核对及文档修订。本文在 Luna 审查基础上由主代理核对最新代码、日志和 GPU 截图后收尾；原始设定摘录保持原样。完整交付见 `exploration_acceptance_2026-10-08.md`。

## 当前规则

- 连续 24000×2700 世界、八区；A/D 或方向键移动，Space 单跳，E 调查。相机跟随，共用探索/战斗玩家。
- 灯廊上层补给、中层巡逻桥、下层未点亮灯三路；钟楼上下回环；路径由真实运动选择，可以往返。其他区补齐阶梯平台、断桥下检修道、观测环内廊、钟楼多层长廊。
- 主线关卡门检查本轮桥调查、暮笙证词、回廊、钥匙和 Boss。可选支路遭遇没有被强制改为全部必打；独立整章验收主动走完全部支路和七战。
- 卡牌为永久实体收藏，战前装备、独立冷却，无抽牌。攻击牌选择后点目标，自身牌再次点同一实体；Space 不施法。
- 牌库六列两行可见，超过十二张滚动；收合/滚动不额外减速。选牌减速由同一模拟时间驱动移动、重力、敌人、碰撞与弹道，专注按实际 delta 消耗。暂停冻结模型和世界。
- 初次新探索显示全部确认原文。初次“否”不计数，弹框内三次拒绝后仅接受；接受之前退出会重播，拒绝计数清零符合用户规定。
- 教程只要求行走、跳跃着地、调查提灯、上下任一支路到共同出口；不要求同时走两路，也不含强制战斗教学。
- 保存接受状态、教程步骤、位置、遭遇、交易、休整和待领奖。战中重启恢复战前检查点；永久卡牌与来源保留。结局保存当前脚点、夜色、待选原件及不可改写记录。
- 下层灯是实际场景地标；lamp 胜利后同时保存本轮状态与永久 lamp_lit，后续探索保持点亮。

## 实际验收证据

日志均位于 `docs/verification/`。

| 范围 | 最新结果 | stdout 文件 |
|---|---|---|
| 三路完整章节 | 66 项，0 失败 | exploration_three_route_finish_journey_stdout.log |
| 真实移动/分路返回 | 18 项，0 失败 | exploration_three_route_finish_movement_stdout.log |
| 关卡/夜色/灯状态 | 21 项，0 失败 | exploration_three_route_finish_gates_stdout.log |
| 实际 GPU 输入和首战 | 29 项，0 失败，17 次鼠标 | exploration_session_render_current_stdout.log |
| 中断与战败恢复 | 23 项，0 失败 | exploration_recovery_stdout.log |
| session 整体接入 | 42 项，0 失败 | exploration_session_current_stdout.log |
| 收藏及旧存档迁移 | 48 项，0 失败 | collection_current_stdout.log |
| 主菜单及 GPU | 逻辑 PASS；GPU 27 项，0 失败 | start_menu_current_stdout.log、start_menu_render_current_stdout.log |
| 空间战斗 | 43 项及10项，0失败 | spatial_combat_fx_final_stdout.log、spatial_world_polish_final_stdout.log |
| 开场原文/拒绝及GPU | PASS | onboarding_acceptance_stdout.log、onboarding_render_current_stdout.log |
| 地图 GPU 布局 | 7 项，0 失败 | exploration_map_render_current_stdout.log |

整章自动验收从起点以真实物理输入走八区、打七战、获得三证据，正常施放卡牌完成 Boss 三阶段和时间锚，再拨针与保存原件。没有传送过门或修改生命直接致胜。其开局只跳过已另行验证的开场/教程；整章使用 headless 物理与正常模型 API，并非人工手玩或整章 GPU 点击记录。首战鼠标目标命中和完整胜利另由 GPU 测试证明。

恢复验收通过真实站近敌人、不出牌，100 秒内承受25次碰撞自然死亡，再重试恢复位置、生命与探索状态；step1/2分别销毁重建游戏后能继续教程。开场保存故障注入可见重试成功，不重复starter实体和visit。session交易测试注入写失败，确认扣款与卡实体均不变；collection覆盖旧迁移和备份恢复fixture。待领奖重启和14张卡滚动使用明确fixture，地图截图也采用布局定位fixture；不把这些称为正常探索获得或实际断电。

## 旧审查结论的处置

1. 拒绝计数重开清零：旧审计误判，符合用户规则。
2. 教程必须走上下两路：旧审计误判，任一路即满足；整章另行走全部支路。
3. 接受后写入失败无可见重试：已修复，23项恢复测试包含故障注入与实际重试。
4. 暂停返回主菜单与相机恢复待验证：GPU实际输入流程已通过。
5. 失败重试没有运行证据：已补真实普通遭遇死亡重试；没有单独声称完成Boss死亡长跑。
6. 灯廊地图缺少中层路：已补齐三层物理通路及真实返回验收；下层未亮灯也已有状态驱动的实体地标。
7. 结局保存位置落后于脚点：已修复，66项整章日志包含拨针、原件提交两次实际脚点断言。

本轮初版功能验收已经完成。没有实施物理断电实验、人工长时间手感评测或高帧骨骼动画；这些不属于已完成测试的声明。Godot实际路径为 `C:\Users\hoshi\Godot\Godot.exe`，`start_game.ps1 -CheckOnly` 已确认4.7.2。