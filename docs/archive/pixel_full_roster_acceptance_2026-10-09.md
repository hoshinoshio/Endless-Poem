# 全阵容像素动作接入验收与进度 · 2026-10-09

> 历史基线：本文保留扩展实施前的只读审计，当时的 `ready=false`、待补资源及接口缺口不代表当前状态。2026-10-10已启用8个单位、188帧并补齐空间表现接口；最新实际结果见 [全阵容最终验收](pixel_full_acceptance_2026-10-10.md)。

## 范围与进度基线

用户已接受英雄的像素尺寸与动作方向，并将范围扩展至其余七个单位。本表是只读源码审计得到的运行时基线，供后续逐个制作、接入与验收；不改变战斗规则。

- 基础规格：48×64 源像素格，通常约 3–4 头身；主角可按其构图小于该格。浮空器物以稳定中心/投影点定位，不强制成人形比例或脚步。
- “流畅”按一致的作者绘制像素帧理解，动作过渡自然且有适中帧感。逐帧动画不能用程序摆动、插值或缩放替代。
- 开局不授予 stop、fast-forward、reverse 能力；维修装置授予这三种时间能力。不要恢复 firecards。
- 本次快照：`assets/pixel_v1/manifest.json` 的 `ready` 仍为 `false`、`status` 为 `motion_pilot_awaiting_visual_review`，且只列 `player`；其帧表有 `idle/walk/run/start/stop/jump/fall/land/turn`。该字段是当前文件状态，后续接入/验收时需更新权威清单。
- 战斗资源 `chapter1_assets.gd` 仍由四姿势 atlas 与 idle atlas 生成 SpriteFrames：状态名为 `idle/cast/attack/hurt/defeat`；`cast` 与 `attack` 共用当前起势/动作姿势，`hurt` 与 `defeat` 各取姿势帧。它不是完整新绘制的逐帧动作集。

## 实际运行调用与状态名

`CombatStage` 的通用战斗路径在 `combat_actor.gd` 上实际调用：

| 状态名 | 实际触发 |
|---|---|
| `idle` | Actor 配置/生成时默认播放；标准资源缺项检查要求它。 |
| `cast` | 主角收到 `cast` 事件；Boss 收到 `phase` 事件；敌人 action index 增长时若没有 `attack` 帧则回退到它。 |
| `attack` | 标准战斗中，敌人的 `action_index` 增加且 Actor 有 `attack` 帧；空间战斗中近战/钟鸣空间攻击提交时直接调用。 |
| `hurt` | 标准战斗收到 `hit` 事件；空间战斗当前没有给被命中的敌方 Actor 调用 `hurt`。 |
| `defeat` | 标准战斗收到 `death`/`loss`，或敌人从活动列表移除；`defeat` 会关闭目标选择。空间战斗移除死亡敌人时直接释放 Actor，没有播放退场帧。 |

标准战斗初始化时会将缺失的 `idle/cast/hurt/defeat` 记入 `missing_assets`；`attack` 允许缺失，因为事件路径会回退至 `cast`。空间战斗另外使用 `EnemyBrain.motion_state()` 输出 `idle`、`walk`、`windup`、`attack`、`recovery`。PixelActor 会将 `recovery` 归一化到动画资源名 `recover`；它不会把 `windup` 自动映射到其他动作名。因此若保持这条接口，素材清单应包含 `windup` 与 `recover`。`approach/position/telegraph/strike/recovery` 是 AI 内部状态，其中 `telegraph` 输出 `windup`，`strike` 输出 `attack`，不是都要作为帧表名称。

敌方 AI 顺序：常规敌人接近/保持距离；距行动结束小于等于 0.8 秒时锁定朝向并进入 telegraph；近战/钟鸣空间动作提交后 `commit()` 转为 strike，0.32 秒后转 recovery；guard 恢复 0.45 秒、elite 0.75 秒、boss 0.65 秒后返回 approach。instrument 与 observer 从 position 起步，会在射程内慢速横向游移。anchor 不移动、不进入 windup/strike。

## 七个单位的资源、调用和待补项

| 单位 | 源码身份与当前资源 | 当前空间动作状态/触发 | 像素制作与接入验收 |
|---|---|---|---|
| 巡刻卫兵（含 tutorial 共用） | 战斗 kind `guard`（教学 id `tutorial`）；`chapter1_assets.gd` 用 `assets/chapter1/patrol_guard_atlas.png` 与 `assets/chapter1/idle/patrol_guard_atlas.png`；空间寻址映射为 `guard`。 | `idle/walk/windup/attack/recovery`；刺击由提交的空间攻击触发 `attack`。通用战斗额外用 `cast/hurt/defeat` 的标准接口。 | 48×64；待机、行走、蓄力/瞄准、前刺、受击、倒地/退场；保持普通卫兵与精英轮廓差异。戟尖不参与脚点。尚无 `pixel_v1` 专用 actor 配置。 |
| 整点卫兵 | kind `elite`；`hour_guard_atlas.png` 与 `idle/hour_guard_atlas.png`；pixel key 默认映射 `elite`。 | 同 guard；重刺 action index 仍以 `attack` 触发；AI 慢速接近，攻击后恢复 0.75 秒。 | 48×64 基础格，可因装甲适度加宽；待机、走、重刺蓄力、重刺、受击、退场。与普通卫兵可读地区分。尚无 `pixel_v1` actor 配置。 |
| 黄铜星仪 | kind `instrument`；`brass_instrument_atlas.png` 与 `idle/brass_instrument_atlas.png`；空间映射 `mechanical`。 | `idle/walk/windup` 可能由 AI 状态输出；现有意图为护持友方或生成/回收小锚。`combat_model` 对这些支援动作不排入空间攻击，故空间路径没有对应的 `commit()/attack` 动画触发。 | 48×64 为基础视觉格，非人形/悬浮造型按实体中心或投影固定锚点；待机悬浮、护持、设锚/召锚、受击、退场。动作要表现支援职责，不画成普通近战攻击。专用像素帧与明确支援触发仍待实现。 |
| 回声观测员（敌方） | kind `observer`；`echo_observer_atlas.png` 与 `idle/echo_observer_atlas.png`；空间映射 `mechanical`。 | AI 用 `idle/walk/windup`；现有规则标记友方下一次攻击并延迟复述，不产生空间攻击 action，因此无 `commit()/attack` 帧触发。标准战斗 action index 通用路径则会在具备帧时调用 `attack`，否则 `cast`。 | 48×64、约 3–4 头身；待机、标记/复述手势、受击、退场；与暮笙保持不同角色设计和资源文件。专用像素帧与支援触发仍待实现。 |
| 克洛诺斯·试炼相 | kind `boss`；`chronos_trial_atlas.png` 与 `idle/chronos_trial_atlas.png`；通用 SpriteFrames 资源水平翻转；空间映射 `boss`。 | `idle/walk/windup/attack/recovery`；普通指针斩和钟鸣空间攻击提交时为 `attack`；标准战斗阶段转换事件触发 `cast`。 | 推荐 96×128（48×64 的整数倍 2），保持 3–4 头身的压缩像素语言；待机、阶段展开/转换、指针斩、钟鸣、受击、退场。主体脚点固定，刻度环等可独立特效层。尚无 `pixel_v1` actor 配置。 |
| 时间锚/小锚 | kind `anchor`、`is_anchor=true`；`time_anchor_atlas.png` 与 `idle/time_anchor_atlas.png`；空间映射 `mechanical`。由星仪或 Boss 动态生成。 | 只有 `idle`；EnemyBrain 在 anchor 分支锁定为 position/零速度，不产生动作条或攻击。标准路径拥有通用 `hurt/defeat` 接口；空间路径目前移除 Actor 时没有击破/退场播放。 | 48×64 基础格；悬浮锚固定中心/投影点。待机、生成/显现、受击、破碎/退场；点击范围围绕可见本体。两种锚共用同一 kind 和资源，大小/外圈区分可以由外观规格确认。专用像素帧及空间销毁过渡待接入。 |
| 暮笙（探索剧情 NPC） | 独立 `MushengObserver` 实体。优先尝试 `PixelActor.configure_key("musheng")`；当前 manifest 没有 `musheng` key 时，回退 `assets/exploration/observer_npc.png` 单图。战斗敌方观测员使用的是另一资源 `assets/chapter1/echo_observer_atlas.png`，角色 ID 与文件路径均不同，不能互相替代。 | 当前单图分支只在 `exploration_world.gd::_pose_npc()` 做轻微呼吸；`talk` 只在 NPC 已是 PixelActor 时交互触发，回退单图没有对话帧切换。 | 独立按 48×64 设计，保留暮笙剧情身份/现有单图识别；待机、说话/对话、可选的冻结/恢复反馈，脚底居中，提灯不改变锚点。不要复用敌方观测员的服装/轮廓。专用像素帧和回退分支的对话触发待接入。 |

## 当前显示路径与接入风险

- 通用战斗 Actor 的原生 `SpriteFrames` 状态由 `sprite_atlas.gd` 构造；缺资源时会报告，不会自动补造动作帧。
- `combat_actor.gd::_build_continuous_motion()` 先按 `pixel_key`/敌方 kind 查询 `pixel_v1/manifest.json`。当前文件仅有 `player` 且 `ready=false`，其余战斗角色键都无法通过 PixelActor 配置，于是落入 `ContinuousMotion` 程序网格回退；实际运行显示不是完整逐帧像素动画。专用 actor 条目应让角色以作者绘制栅格帧运行，并清楚标明源帧、裁切、脚点、循环与转场。
- `MushengObserver` 的旧单图分支只作呼吸缩放；敌方 `echo_observer` 是独立战斗资源。两套资源/状态分开制作与验收。
- 战斗 Actor 的固定 idle 画布将根节点底边作为单位底部锚点；探索空间战斗地面单位以遭遇 `floor_y` 定位，anchor 用 `floor_y-110`。新增帧必须对齐共同脚点/投影点，透明留白和攻击特效不能使碰撞/选取范围跳动。
- 支援敌人（instrument、observer）在当前空间战斗模型中没有“动作提交给 Actor”的明确事件；在不改规则的前提下，资源帧表可以先完成，但要表现护持/设锚/标记的特定起势，需另行接上现有事件状态。

## 当前完成度

| 范围 | 状态 |
|---|---|
| 英雄尺寸与动作方向 | 用户已接受；像素规格/动作节奏可作为全阵容基准。 |
| 英雄 48×64 像素帧运行配置 | 当前 manifest 的技术状态仍是 `ready=false` / `motion_pilot_awaiting_visual_review`；需由资产负责人完成验收与登记。 |
| 六个战斗单位 | 当前有章一四姿势 atlas/idle 图及 SpriteFrames/程序形变运行路径；没有各自的 48×64 `pixel_v1` actor 配置和已验收逐帧新资源。 |
| 暮笙 | 独立单图回退与轻微呼吸存在；无 `musheng` PixelActor 配置，单图对话状态未实现。 |
| 规则/事件触发 | 本文记录实际接口；空间战斗中支援动作的动画触发、受击和死亡表现存在上述接口缺口。 |

本次是源码与当前资源登记的只读审计；未运行测试、修改代码或既有测试。测试基线仍使用既有 `docs/verification/pixel_motion_tests_before_2026-10-09.json`，下次验证应对照该快照，不覆盖或重建。
