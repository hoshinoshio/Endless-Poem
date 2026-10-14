# 正式2D战场与视觉修订验收 · 2026-10-05

> 历史验收记录。用户2026-10-06已确认改用半透明钟表投影、八路圆周外散流光及仅血条HUD；本文中的五束流光、状态文字、资源/行动条和debuff可见规则已被替代。最新实现与证据见 `clock_health_revision_2026-10-06.md`。

工程：`C:\Users\hoshi\Endless Poem\endless-poem`。使用本机 Godot 4.7.2，OpenGL Compatibility / NVIDIA GeForce RTX 5060 Ti。所有测试使用独立命名的测试存档，未重置用户收藏。

## 同日追加：运动、法阵及插画卡面

已按用户追加要求完成以下实现，当前默认工程直接加载这些资源：

| 子任务 | 实际执行模型/工具 | 最终产出与检查 |
|---|---|---|
| 角色、怪物与环境运动 | `gpt-6.1-sol` / motion_world；主代理生成并接入资源 | 七套四帧待机、4fps循环；原动作保留，统一比例/脚点；三处布旗、七处灯火及两个星仪局部运动。七套真实资源通过，无裁切告警 |
| 路径流光和法阵 | `gpt-6.1-sol` / motion_world | 五条错开发射的弧线流光，前端移动，0.16秒历史尾迹变细/淡出；法阵直径300px、三层反向旋转刻度与指针。战斗时钟驱动，暂停冻结 |
| UI与九类卡面 | `gpt-6.1-sol` / card_ui_polish；主代理使用 image_gen 生成插画 | 铜色边框、靛蓝面板、费用徽章、冷却环、悬停与选中反馈；九种独立插画用于战斗/收藏/装备/奖励。卡面短标签：可用、冷却、费用不足、条件不满足；完整条件悬停可看 |
| 独立规则核对 | `gpt-6-luna` / motion_acceptance_audit | `motion_ui_revision_2026-10-05.md` 中逐项核对源码、实际帧与日志 |
| 集成、实际渲染与完整战斗 | 主代理协调集成；Sol编写验收工具 | 真实GPU动态验收90项/0失败，96张1440×900连续帧；独立Boss实战30项/0失败；11套headless回归全部通过 |

所有新增源图在 `assets/chapter1/idle/` 和 `assets/cards/`，完整提示与来源记录为 `assets/motion_generation_manifest.json`。源 PNG 没有重绘或覆盖；Godot中处理透明边缘噪点、统一切帧和画布。Boss和时间锚的较宽待机帧通过整套透明边距保全，没有逐帧缩放。主角显示高度继续为217px（原310px的70%）。

新增证据：

- `verification/motion_render_final_stdout.log`：90项/0失败，RTX5060Ti实际GPU渲染，96帧、16fps、共6秒、10次真实鼠标操作。包含普通战/Boss、四个独立idle帧及运行时像素差异、真实出牌、路径流光前进/消散、Esc暂停冻结/恢复。测试通过独立奖励来源装备九种卡，以展示全部卡面；没有给玩家存档发卡。
- `verification/motion_render_evidence.json`：逐帧世界时钟、动画索引、流光头部和尾点透明度、图像hash及每项检查结果。
- `verification/motion_frames/frame_0000.png` 至 `frame_0095.png`：GPU原始连续画面；`motion_preview.gif` 是同一序列的格式转换预览，960×600、总时长6000ms。相同暂停帧可由编码器合并，完整原图保留。
- `verification/motion_boss_spell.png`、`motion_patrol_spell.png`：在光流飞行至40%—70%时捕获的实际画面；`motion_boss_cards.png`、`motion_patrol_cards.png` 展示插画与HUD布局。
- `verification/motion_production_battle_stdout.log`：默认初始10卡，鼠标选卡及目标、空格自身卡，三阶段Boss胜利，63.16战斗秒、HP12、11次时间锚点击、72次鼠标操作；同时通过自然失败、重试清冷却、收藏保留及无重复发放。
- `verification/motion_regression_*`：11套headless回归全通过。输出计数的八套共851项（card_visual为34项）；紧凑状态修正后`card_visual_acceptance`为39项/0失败，合计更新为856项。另有authority_fx、sprite_atlas、motion_world三套PASS，未把无总计测试虚构为精确总数。
- `verification/idle_motion_acceptance_stdout.log`：真实资源7/7、统一脚点/画布、原动作像素保留、主角217px及碰撞稳定。

动态不是整张背景平移：以普通战frame0与frame16作源PNG像素核对，右旗区域有9373个像素变化，灯火区域556个（最大通道变化5，属于轻微明暗变化），上方星仪区域32个像素变化。此检查只读取真实帧，不合成效果。

法术视觉旅行用0.32—0.42秒及尾迹渐隐表现路径，原战斗结算仍采用已有0.12秒施放时点；本次没有修改数值平衡，因此血量/受击提示可能先于最后一道流光到达。当前是四帧待机与原技能姿势的初版，不属于高帧数完整骨骼动作。七种战斗仍共用庭院，探索保持八节点事件路线；本轮没有新增自由行走地图。

下文保留本次运动修订之前的同日视觉验收，涉及“待机一帧”的旧状态已由上面的四帧循环替代。

## 用户要求逐项结果

| 要求 | 实现 | 验收 |
|---|---|---|
| 采用第一版A | 独立星台庭院背景、月璃、巡刻卫兵、黄铜星仪、回声观测员、整点卫兵、克洛诺斯、时间锚；正式默认启用 | 七种遭遇资源齐全，真实渲染截图 |
| 人物缩小至约70% | 月璃共享帧显示高度217，原高度310；仅主角缩放 | 生产精灵几何断言通过 |
| 魔法书施法锚点改为身后权柄 | v1衍生动作图移除手持书，保留银白发、蓝眼、黑白金服；独立时钟权柄置于角色后 | 源点坐标、层级与实际截图确认 |
| 多道时间光流 | 五束从权柄源点朝选中目标传播；自我卡仅点亮权柄；命中星屑 | 实际出牌生成五束、正确目标；暂停冻结；战斗时间推进 |
| 普通敌人debuff在血条上方 | 24px火焰和沙漏图标，显示灼烧层数/迟刻倒计时 | 实际烬印、迟刻施法及布局断言 |
| Boss debuff在血条下方并放大 | 36px图标，y103；血条仍Rect2(430,90,580,8) | 与名称/阶段/意图区域不重叠 |
| 完整进行战斗 | 初始10张卡，鼠标选牌、Area2D精灵点击、空格确认自我卡 | 三阶段Boss胜利，63.16战斗秒、剩12生命、11次时间锚点击、72次鼠标输入 |
| 保留原规则 | 战斗模型和收藏存档逻辑未修改；自然失败与新战斗冷却归零、收藏保留 | 新视觉验收及原有回归通过 |

## 验证记录

- `production_visual_acceptance`：真实GPU渲染30项、0失败；同一业务流程headless22项、0失败（差值为8张渲染截图）。无HP/能量/伤害修改，不跳过阶段。debuff展示在隔离测试收藏中通过正常奖励API取得烬印和迟刻，装备后正常施放。
- `debuff_ui_acceptance`：75项、0失败；7种遭遇、图标只读同步/清除/死亡、图标点击穿透、正式精灵点击恰好施放一次。
- `authority_fx_acceptance`：通过，覆盖五束源点、目标删除后的落点缓存、自我卡、暂停和减速。
- `sprite_atlas_acceptance`：通过，覆盖共享画布/比例/脚点、死亡姿势不独立放大、跨格武器过滤、低alpha噪点、导入资源读取。
- 原有回归：combat316、collection48、route175、world36、world_ui73、ui94，共742项、0失败。旧GUI回归99次操作，经过三阶段及11次时间锚点击。旧world_ui明确启用隔离legacy起点以检验fallback，再切fixture；正式默认由production测试覆盖。

证据在 `verification/production_visual_render_stdout.log`、`verification/debuff_ui_render_stdout.log` 及 `verification/final_*`。GPU截图：

- `verification/production_authority_cast.png`
- `verification/production_patrol_debuffs.png`
- `verification/production_boss_debuffs.png`
- `verification/production_boss_phase_2.png`
- `verification/production_boss_phase_3.png`
- `verification/production_boss_victory.png`

## 文件与模型分工

| 范围 | 实际执行模型/工具 |
|---|---|
| 世界权柄FX、角色几何、精灵资源归一 | gpt-6.1-sol 子代理 authority_fx |
| debuff、正式world入口、战斗HUD可读性、旧回归适配 | gpt-6.1-sol 子代理 debuff_ui |
| 确认规则和来源边界文档 | gpt-6-luna 子代理 visual_confirmed_docs |
| 图像生成、资源manifest、朝向和提示遮挡修复、正式渲染集成验收 | 主代理；图像使用内置image_gen，无API/CLI替代 |

主代理实际型号未由工具核验，不将角色称谓写成型号证明。

## 素材与初版边界

所有生产文件与完整生成提示在 `assets/chapter1/`；原始参考图保持不变。PNG由image_gen生成及重新排版，Godot资源层按实测边界裁切并统一画布、比例和脚点，不向源PNG绘画或覆盖。RGBA透明已检查，低alpha边缘噪点仅在运行时过滤。纹理通过导入资源读取，兼容后续导出资源包；本轮未交付独立exe。

首次视觉修订时七种战斗共用庭院，每个单位为待机、施放/攻击、受击、退场四种姿势，其中待机一帧。此项已经被同日追加的七套四帧循环待机与环境运动替代。仍保留的初版边界是共用庭院、原技能姿势、八节点探索界面，尚非高帧数长动作或自由行走地图。
