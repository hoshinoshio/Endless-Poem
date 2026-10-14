# 失刻星台：连续探索交付与验收

2026-10-08。工程仍为 `C:\Users\hoshi\Endless Poem\endless-poem\project.godot`。默认主场景 `scenes/main.tscn` 保留已认可的 A 银白主菜单与落地场景；“新的探索”进入本轮黑屏开场或连续地图。用户已确认主代理为 Astra。独立子任务明确指定 `gpt-6.1-sol`、`gpt-6-luna`。

## 逐项完成状态

| 计划项 | 状态 | 实际产出与证据 | 模型 |
|---|---|---|---|
| 规则及受影响文案 | 完成 | 需求、接口契约、README、规则审计；旧按钮路线、Space 施法、仅内存续玩说明已替换 | gpt-6-luna；Astra 复核 |
| 连续地图与自由运动 | 完成首版 | 24000×2700 世界、八区、单跳、相机、坡道、落地；灯廊上补给/中巡逻/下未亮灯三路，钟楼上下回环；18 项实际输入移动检查 | gpt-6.1-sol；Astra 复核 |
| 场景空间与人物表现 | 完成首版 | 阶梯分层、断桥及检修道、观测环内廊、钟楼多层回廊、末端考核平台；侧向动作图集、环境运动、已采用暮笙；GPU 地图截图 7 项 | gpt-6.1-sol；Astra 接入素材和截图检查 |
| 原地战斗及空间命中 | 完成 | 同一玩家/相机；方向锁定近战、指针斩、可跳过钟鸣、残响原路径；火焰抵达只结算一次；空间模块 43+10 项 | gpt-6.1-sol；Astra 集成 |
| 黑屏开场与拒绝循环 | 完成 | 全部原文、银白渐显/碎裂/畸变/消散；初次否不计，弹框内三次拒绝后仅接受；GPU 实际按钮验证与 11 帧截图 | gpt-6.1-sol；Astra 复核 |
| 四步探索教程 | 完成 | 实际行走、跳跃着地、E 调查、走入任一岔路；无强制战斗教学；step 1/2 退出重建后继续 | gpt-6.1-sol；Astra 集成 |
| 卡牌、收藏与装备 | 完成 | 起始十张、九种卡、实体独立冷却、无抽牌、战前装备；六列两行、14 张滚动、二次点自身卡；48 项收藏检查与 GPU 实测 | 既有 Sol 实现；Astra 集成 |
| 主入口、存档与恢复 | 完成 | 持久继续、遭遇前检查点、真实死亡重试、一次性奖励、购买原子提交、开场写失败可见重试、待领奖恢复 | Astra 接手集成；gpt-6.1-sol 恢复验收 |
| 首章完整流程 | 完成 | 八区、七战、三份证据、暮笙矛盾记录、Boss 三阶段/时间锚、拨针、夜色、不可改写原件；最终旅程 66 项通过 | gpt-6.1-sol；Astra 检查实际日志 |
| 独立审计与交付 | 完成 | Luna 只读核对，Astra 检查实际代码、日志与渲染；补齐审查发现的灯廊第三条路及灯状态 | gpt-6-luna、Astra，gpt-6.1-sol 修复 |

集成阶段一次 Sol 调用遇到模型额度限制，主代理接手 `exploration_session.gd`、存档和主入口，没有把失败调用记成 Sol 已完成。后续恢复和地图收尾由显式 Sol 子代理完成。未改原始设定文稿。

## 本轮实际验证

引擎：Godot `4.7.2.stable.official.ed1daf0bf`，本机路径 `C:\Users\hoshi\Godot\Godot.exe`。GPU：NVIDIA GeForce RTX 5060 Ti，OpenGL Compatibility，逻辑画布 1440×900；菜单另测 1152×720 窗口。`start_game.ps1 -CheckOnly` 已确认启动器找到实际引擎。

| 测试 | 结果 | 日志（docs/verification 下） |
|---|---:|---|
| 最终整章物理旅程 | 66 通过，0 失败 | `exploration_three_route_finish_journey_stdout.log` |
| 三路移动与返回 | 18 通过，0 失败 | `exploration_three_route_finish_movement_stdout.log` |
| 门槛、镜头、夜色与灯 | 21 通过，0 失败 | `exploration_three_route_finish_gates_stdout.log` |
| session 集成 | 42 通过，0 失败 | `exploration_session_current_stdout.log` |
| 中断、故障与死亡恢复 | 23 通过，0 失败 | `exploration_recovery_stdout.log` |
| 实际 GPU 输入与首战 | 29 通过，0 失败，17 次鼠标点击 | `exploration_session_render_current_stdout.log` |
| 主菜单路由 | PASS | `start_menu_current_stdout.log` |
| 主菜单 GPU/小窗口 | 27 通过，0 失败，6 次鼠标点击 | `start_menu_render_current_stdout.log` |
| 收藏/迁移/重复来源 | 48 通过，0 失败 | `collection_current_stdout.log` |
| 开场逻辑及 GPU 演出 | 两项 PASS | `onboarding_acceptance_stdout.log`、`onboarding_render_current_stdout.log` |
| 新地图 GPU 布局 | 7 通过，0 失败 | `exploration_map_render_current_stdout.log` |
| 空间命中/法术时点 | 43 通过，0 失败 | `spatial_combat_fx_final_stdout.log` |
| 空间战斗共用世界 | 10 通过，0 失败 | `spatial_world_polish_final_stdout.log` |
| 既有卡牌模型回归 | 316 通过，0 失败 | `spatial_model_legacy_stdout.log` |

这些测试有交叉覆盖，不把计数相加冒充互不重复的功能数量。最新三路移动、关卡与整章 stderr 均为空。恢复和 session 的写入失败、重复领取警告来自故意注入；没有 SCRIPT ERROR。

完整章节使用真实 Input action 和物理帧驱动角色，在实际位置按 E，正常选择卡实体和目标、消耗资源、等待冷却，七场均由模型胜利结算；未传送过门、改生命或直接调用伤害绕过战斗。唯一开局 fixture 是“之前已接受开场并完成操作教程”，开场及教程另行完整验证。首场 GPU 验收实际使用鼠标点击卡与目标完成战斗。自动化测试不等于人工长时间手感评测。

全章实际顺序：外缘 → 阶梯 → 两次断桥调查 → 灯廊下层灯遭遇 → 返回入口、中层巡逻 → 返回入口、上层补给 → 暮笙 → 钟楼下层精英 → 返回上层补给/休整 → 回廊 → 锚钥匙 → Boss → 拨针 → 保留《观测环刻录》。七战均 won；Boss 阶段 `[1,2,3]`，通过正常施法处理时间锚。末态：16 张实体卡、7 个唯一奖励来源、0 结晶、2 张合法升级、三份证据、`lamp_lit=true`、`chapter_night=true`、不可改写原件。账本见 `exploration_three_route_finish_journey.json`。

恢复验收包含真实站在敌人攻击范围内、不出牌，承受 25 次碰撞、100 秒后自然 HP 0，再点击重试回到战前位置和生命。教程在 step 1、step 2 分别销毁并重建游戏后续玩。待领奖重建及 14 张卡滚动用明确 fixture；不把它们称为正常探索获得十四张或真实战后断电。收藏测试另外覆盖旧存档迁移、写入失败不变更实体/来源、备份恢复 fixture。没有进行物理断电测试或单独的 Boss 死亡重试长跑。

## 画面与美术

- `map_current_three_lanes_unlit.png` / `map_current_three_lanes_lit.png`：三层地图和灯状态，实际 GPU；采用布局定位 fixture，不用来证明行走通路。
- `map_current_bridge_service.png`：断桥下检修道。
- `map_current_observer_ring.png`：暮笙与观测环分层通路。
- `exploration_live_07_cards.png` / `exploration_live_08_cast.png`：真实首战卡库与施法。
- `exploration_live_11_fourteen_cards.png`：超过十二张的滚动卡组 fixture。
- `onboarding_03_fracture.png` / `onboarding_07_final_acceptance.png`：字形碎裂、第三次拒绝后的单按钮。

以上均为 Godot 渲染，不是界面样稿。角色及地图的生成素材已放在 `assets/exploration/`，透明素材实际 alpha 为 0–255；工具路径和最终提示词规格见 `assets/exploration/GENERATION.md`。本轮保留已批准画风；动作是初版有限帧表现，尚非高帧长动作或完整骨骼动画。

## 启动与操作

打开本目录 `project.godot` 后按 **F5**，或双击 `开始游戏.cmd`。按 F6 只会运行编辑器当前场景，因此检查默认入口应使用 F5。

- A/D 或方向键：移动；Space：单次跳跃；E：调查。
- 时钟图标：展开/收起卡库；攻击牌再点目标；自身牌再次点击同一张。
- Esc：取消选牌 → 收起卡库 → 暂停；暂停菜单可返回主界面。
- 战斗中退出应用按计划恢复遭遇前检查点；不保存半空弹道。

用户计划中的初版实现和上述验收已完成。独立 Windows exe 安装包、高帧动画、后续五区内容和长期数值平衡不在本次完成声明中。生产存档未被测试重置。
