# 像素单位现状核对 · 2026-10-09

范围：只读核对当前首章资源、战斗遭遇生成、探索 NPC 与运行时显示锚点，供“48×64 基础格、约 3～4 头身”的像素替换清单使用。本文件只记录现状和尺寸/动作建议，不定义新战斗或新怪物。主菜单 A、时间权柄三张卡及无能力开局均不在此项改动范围；新战斗仍待用户确认。

## 核对结论

实际运行时需要覆盖：月璃、巡刻卫兵（含教学版）、整点卫兵、黄铜星仪、回声观测员、克洛诺斯·试炼相、时间锚/小锚，以及探索剧情 NPC 暮笙。战斗敌人种类和探索 NPC 是两条独立资源路径。

`exploration_world.gd::_create_previews()` 只用普通卫兵、整点卫兵或 Boss 作为七个地图遭遇点的静态预览。它不拿黄铜星仪或回声观测员做地图预览；这不代表实际战斗不会出现它们。`combat_model.gd::start_battle()` 的实际配置中，黄铜星仪出现在 stairs、elite、corridor，回声观测员出现在 lamp、corridor；时间锚由黄铜星仪行动或 Boss 后续阶段动态生成。因此三者都属于清单。

## 单位清单

| 单位 ID / 运行时标识 | 实际资源参考 | 实际出现位置 / 当前显示尺寸 | 像素替换建议、动作和脚点 |
|---|---|---|---|
| `player` / `moonli_authority`（探索玩家） | 战斗 atlas：`assets/chapter1/moonli_authority_atlas.png`；idle：`assets/chapter1/idle/moonli_authority_atlas.png`；侧视探索素材：`assets/exploration/neutral_idle*.png`、`side_motion.png`、`continuous_rig.json`；原月璃参考副本：`assets/moonli_battle_v1.png` | 战斗章节资产标高 217；空间战斗通过 `ExplorationPlayer` 显示玩家，rig 标高 217；通用战斗场景取该资产 217。 | 基础 48×64，保持银白长发、水蓝眼、黑白金衣。待机设定为右手自然下垂、ready；另需清楚可读的走/跑、跳/落地、施法/攻击、受击、胜利/退场动作。脚底中央为地面锚点；头发和衣摆可占满 64px 高但不要把脚点漂移。保留月璃识别色与时间权柄特效由现有独立 FX 层承担。 |
| `tutorial` / `guard` / `patrol_guard`（巡刻卫兵，含教学版） | `assets/chapter1/patrol_guard_atlas.png`；idle：`assets/chapter1/idle/patrol_guard_atlas.png` | tutorial、stairs、patrol、lamp、corridor 实战出现。空间战斗资源标高 245；场景普通战斗约 245 高、宽受约 300 上限控制。 | 基础 48×64；与精英保持明显轮廓差异。需求：待机持戟、蓄力/瞄准、向前刺击、受击、退场。戟可超出 48px 主体格，单独按像素边界留透明区；角色脚底中央为地面锚点，戟尖不参与脚点计算。 |
| `elite` / `hour_guard`（整点卫兵） | `assets/chapter1/hour_guard_atlas.png`；idle：`assets/chapter1/idle/hour_guard_atlas.png` | elite 实战与地图静态预览。空间战斗资产标高 265；地图预览统一配置为 210 高。 | 基础 48×64；如轮廓或重装元素需要，可在不改基础身体比例的前提下放宽至 64px；头身保持 3～4 头。需求：待机、可识别的重刺蓄力、重刺、受击、退场；动作/装备轮廓必须与普通卫兵区分。脚底中央落地。 |
| `instrument` / `brass_instrument`（黄铜星仪） | `assets/chapter1/brass_instrument_atlas.png`；idle：`assets/chapter1/idle/brass_instrument_atlas.png` | stairs、elite、corridor 实战出现，不作为探索地图预览类型。章节资产标高 210；空间战斗Actor仍按敌人 asset 配置，通用场景对非 Boss 单位套用普通敌人尺寸。 | 基础 48×64；如果当前图是悬浮/器物造型，3～4 头身仅作视觉高度参照，不强制画成人形；可让本体占格并由悬浮部件向外扩展。需求：待机/悬浮、护持或设锚动作、受击、退场。非人形没有脚时用固定底部中心“地面投影/悬浮中心”作为稳定定位锚，勿随帧抖动。 |
| `observer` / `echo_observer`（回声观测员，敌方） | `assets/chapter1/echo_observer_atlas.png`；idle：`assets/chapter1/idle/echo_observer_atlas.png` | lamp、corridor 实战出现，不作为探索地图预览类型。章节资产标高 230。 | 基础 48×64，约 3～4 头身。需求：待机、标记/复述提示动作、受击、退场；保留与剧情 NPC 暮笙不同的敌方辨识度，不要默认复用 NPC 美术。脚底中央落地。 |
| `boss` / `chronos_trial`（克洛诺斯·试炼相） | `assets/chapter1/chronos_trial_atlas.png`；idle：`assets/chapter1/idle/chronos_trial_atlas.png` | Boss 实战与 Boss 地图预览。章节资产标高 320；通用战斗场景使用 320 高、最大宽 330；地图预览高 280。 | 建议 96×128（48×64 整数倍 2），可再用整数倍放大，但不要自由拉伸。维持 3～4 头身的压缩像素语言，避免 2 倍格变成写实比例；需求：待机、阶段切换/展开刻度环、普通攻击、重攻击/钟鸣、受击、回收/退场。主形体脚底中央固定；刻度环、星门纹样可作为独立特效层，不改变人物脚点。 |
| `anchor` / `time_anchor`（时间锚、小锚） | `assets/chapter1/time_anchor_atlas.png`；idle：`assets/chapter1/idle/time_anchor_atlas.png` | 由黄铜星仪产生生命 4 的“小锚”；Boss 第二阶段生成 2 个、第三阶段生成 1 个生命 6 的时间锚。它们共用 `anchor` kind 和同一资源。章节资产标高 145；空间战斗按 floor_y−110 放置；通用战斗场景高 145、宽 120，并由槽位定位。 | 建议 48×64 基础格；保持可点击轮廓，若实体占格较小可在格内留透明边，按整数倍显示。若是悬浮物，使用固定中心或固定投影锚点，不伪造脚步；战斗命中/点击矩形需围绕可见本体。需求：待机/生成、被击中、破碎/退场；可用同一主体图，通过稳定的颜色/外圈强调“大锚/小锚”差别，当前规则无更细分锚单位 ID。 |
| `MushengObserver` / `musheng`（暮笙，探索剧情 NPC） | `assets/exploration/observer_npc.png`；姿势/分帧处理见 `scripts/exploration/exploration_world.gd::_create_observer_npc()`、`_pose_npc()` | 探索 testimony 点附近，路径约 `x=13280`；资源按去透明边界后缩放为 225 高。与战斗 `observer` 是不同实体。 | 基础建议 48×64；维持已采用的深发、蓝灰观测员服、提灯。需求：安静待机/呼吸、对话姿势、时间冻结/恢复反馈可选；脚底中央锚定，提灯作为手持附件且不得改人物脚点。NPC 现有动作仅轻微呼吸，不要据此推断已有完整动作集。 |

## 显示和定位约定建议

48×64 指源像素基础格，不直接代表当前 Godot 世界单位。新精灵以本地底部中央为脚点，所有方向与动作帧对齐同一脚点；在场景中选统一整数缩放倍数，Boss 按 2×（96×128）或更高整数倍，避免非整数缩放导致像素模糊。浮空单位/时间锚使用固定中心或投影锚，保留透明边界；碰撞/选择区域只需随可见本体，而不应从透明留白推算。当前实现的坐标脚点约定是：`combat_actor.gd` 将精灵顶端放在角色根节点上方、底部落在根节点 y；`spatial_combat.gd` 的普通敌人 spawn 以遭遇 floor_y 为基准，锚则另加 −110 的高度偏移。替换时应保留这两个不同锚定语义。

动作最低清单应覆盖所有当前被调用的运行态：待机、移动（空间战斗敌人/NPC）、蓄力/telegraph、攻击、受击、退场；Boss 增加阶段展开/转换，锚增加生成/破碎。现有 chapter1 atlas 具有 idle、攻击/施放、受击、退场的四姿势资源，idle 子目录也提供独立待机图；探索 NPC 独立用单张图和轻微呼吸。像素替换资源需要逐状态提供帧或明确复用静态帧，不要把不存在的连贯动画算作已实现。

## 可追溯实现位置

- 资产映射与当前标高：`scripts/visuals/chapter1_assets.gd`。
- 七种遭遇所用实际敌人：`scripts/combat/combat_model.gd::start_battle()`；动态小锚和 Boss 锚生成：`_make_anchor()`、`_spawn_boss_anchors()`。
- 空间战斗实际实例化所有 `model.enemies` 的逻辑：`scripts/exploration/spatial_combat.gd::_sync_entities()`；脚点放置逻辑在同文件锚点分支。
- 地图预览种类：`scripts/exploration/exploration_world.gd::_create_previews()`，仅 guard/elite/boss。
- NPC 素材尺寸、脚点定位及呼吸：`scripts/exploration/exploration_world.gd::_create_observer_npc()`、`_pose_npc()`。
- 战斗Actor的底部对齐和目标区域：`scripts/world/combat_actor.gd::_fit_current_texture()`。

以上为源码核对；没有运行测试、修改实现或触碰既有测试文件。

