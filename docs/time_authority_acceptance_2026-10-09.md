# 时间权柄、连续动作与入口引导验收 · 2026-10-09

工程：`C:\Users\hoshi\Endless Poem\endless-poem`，Godot 4.7.2，默认场景 `scenes/main.tscn`。采用 Game Studio 的角色一致性、透明素材、固定脚点与引擎内预览验收流程；运行时仍是 Godot 原生。

## 按本轮最新要求的交付状态

| 要求 | 状态 | 实际内容和边界 |
|---|---|---|
| 右手向下、随时行动的待机姿态 | 已接入并实渲染 | `neutral_idle_ready.png`；右手自然下垂，双腿收近直立。后伸草案没有进入最终绑定。 |
| 连续行走、奔跑和停步 | 已实现并验证 | 两腿独立UV蒙皮、两段骨骼、鞋部刚体变换、腰/臂/发梢/衣摆连续运动；Shift 390→624加速，松开回到行走，停步返回直立。并非逐帧重新生成图像。 |
| 怪物运动与逻辑 | 当前探索巡逻已实现 | 怪物具有连续动作；时间卡可停住/加速/回溯其巡逻。已有独立战斗状态机模块保留，但当前新规则入口不启动旧战斗。完整新敌方战斗规则待用户下一轮确定。 |
| 云和灯的动态 | 已实现 | 新增云层有独立本地时钟和移动；灯光温和闪动。可作为时间目标。获得权柄后，待机手势和钟表投影短暂影响环境表现；该效果没有改写战斗时间。 |
| 问题式入口引导 | 已实现并走通 | 寻找停摆装置→跳上真实低台→E修复。任意平地跳跃不能跳过低台要求。只展示当前情境短提示。 |
| 开局无能力、修复后赠三卡 | 已实现并持久化 | 默认入口初始没有旧卡或时间卡；修复一次原子提交 stop/fast_forward/reverse、来源标记和解锁进度。 |
| 不再使用灵性之火方案 | 当前默认流程已隔离 | 三张时间卡不调用旧伤害、费用或冷却结算。旧收藏和兼容模块仍保留，避免删除既有数据。 |
| 不限定卡牌对象类别 | 已接入多类对象 | 玩家、暮笙、巡逻怪物、云层、灯和装置使用同一个目标注册接口；无敌我类别门槛。静态物体没有可凭空创造的过去。 |
| A主菜单和原Godot工程位置 | 保持 | 正式F5入口、菜单新探索、继续探索及显现权柄均指向新流程。 |
| 既有测试不能为验收而修改 | 已核对 | 冻结清单37项全部存在、SHA-256一致，0项修改。新功能使用另外新增的测试文件。 |

## 实际验证

所有下列测试使用独立数据或隔离存档，不清空玩家旧收藏。另以默认主场景进行60帧GPU启动检查，未发现脚本错误。

| 检查 | 结果 | 日志 |
|---|---:|---|
| 默认入口→三次拒绝→接受→真实走跳→E修复→三卡点选→菜单→重建应用继续 | 36项通过，21次鼠标点击 | `verification/authority_playthrough_gpu_stdout.log` |
| Godot渲染下的行走/奔跑/返回待机、怪物局部时间、玩家回溯后mesh刷新、暂停 | 13项通过，180个视频帧 | `verification/authority_motion_gpu_stdout.log` |
| 连续动作及鞋部刚性 | 21项通过 | `verification/continuous_ready_arm_final_stdout.log` |
| 时间控制器 | 24项通过 | `verification/authority_controller_final_stdout.log` |
| 收藏保存与原子赠与 | 17项通过 | `verification/authority_store_final_stdout.log` |
| 会话/教程协调与故障保存 | 24项通过 | `verification/authority_session_final_stdout.log` |
| 世界目标与实际装置低台路径 | 26项通过 | `verification/authority_world_final_stdout.log` |
| 未修改的旧收藏兼容测试 | 48项通过 | `verification/authority_legacy_collection_stdout.log` |
| 未修改的旧Shift/暂停/移动时钟测试 | 20项通过 | `verification/authority_locomotion_regression_stdout.log` |
| 未修改的旧地图所有支路物理通行测试 | 18项通过 | `verification/authority_world_movement_regression_stdout.log` |

上述最终日志的对应 stderr 均无脚本错误。旧兼容测试通过证明保留兼容路径，不代表新流程使用旧十卡或旧战斗。

首轮 `authority_entry_render.gd` 和原始失败日志完整保留：其4项失败包括把“不可见”错误要求成“节点不存在”，以及在玩家遮挡装置的位置点击装置中心，实际命中玩家。后续新增 `authority_playthrough_render.gd` 直接验证屏幕不可见，并用实际行走让开装置后点击；同时保留玩家自身目标的点击验证，没有改动旧测试的期望。

## 可查看的画面

- `verification/authority_motion_preview.mp4`：6秒、30fps，来自Godot实际渲染的180帧；包括待机、行走、奔跑、停步和怪物巡逻，不是AI生成视频。
- `verification/authority_motion_01_ready_idle.png`：游戏内右手下垂待机和怪物。
- `verification/authority_playthrough_06_three_cards.png`：实际修复后的三卡HUD；角色和装置均在卡库上方。
- `verification/rig_idle_06.png`、`rig_walk_09.png`、`rig_run_02.png`：放大2.5倍的独立动作检视视图。

## 尚未实施与参数边界

- 三张卡的正式战斗规则、敌方伤害/费用/冷却及三阶段Boss改造等待用户后续方案；本轮不宣称已完成新的完整战斗。
- 固定失控平台、快进蓄能、倒退断桥的专用谜题仍未获确认，本轮没有加入。
- 当前探索预览快进为2倍，回溯保留最多240个实际状态；到最早记录即停止，重开会话不恢复此前所有回溯帧。这些不是已批准的战斗平衡数值。
- 局部时间的撤销/恢复目前可通过其他时间卡切换；正式交互规则待后续设计。旧数据保留在独立收藏字段和旧探索归档中。

## 实际模型分工

| 工作 | 使用模型 |
|---|---|
| 连续角色/怪物动作、网格与准备姿态绑定 | `gpt-6.1-sol`，continuous_motion |
| 时间卡控制器与三卡存档 | `gpt-6.1-sol`，temporal_cards |
| 探索会话、问题引导与三卡HUD | `gpt-6.1-sol`，authority_session |
| 世界对象、低台和环境运动 | `gpt-6.1-sol`，authority_world；主代理完成回溯刷新与构图整合 |
| 规则审查、入口复核和测试哈希 | `gpt-6-luna`，new_rules_audit |
| 方案协调、主入口、美术生成、最终集成与GPU验收 | 主代理，按用户指定Astra职责执行；工具没有独立暴露主代理型号证明 |

中途子代理发生过额度中断，后续Sol/Luna已恢复并交接；未完成的世界回溯修复由主代理接手。最终采用素材与完整提示词见 `assets/exploration/CONTINUOUS_MOTION_2026-10-09.md`。
