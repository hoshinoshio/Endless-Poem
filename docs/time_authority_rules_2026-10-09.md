# 时间权柄新流程规则（2026-10-09）

> 最终集成补记：右手下垂的 ready 图已接入；默认入口36项GPU实点检查、动作/回溯13项GPU检查均通过。完整结果见 `time_authority_acceptance_2026-10-09.md`，下文首轮GPU问题保留为审查历史。

本文记录用户于 2026-10-09 明确提出的新规则，并持续区分规则确认、当前实现和验收边界。后续用户更正优先于先前的视觉描述；代码现状与验收证据按审查时点注明。新战斗规则仍未确定。

## 已确认的新规则

### 角色动作与时间权柄

- 月璃停止走动时采用直腿站立姿势，双腿收近；不能沿用当前站立姿势中的弯腿或行走残留。最新视觉更正要求待机右手自然向下放松、保持随时行动的状态，不向后舒展；该姿势约束优先于先前任何相反的手臂示意。
- 已获得时间权柄后，月璃在 idle 时会拨动时间权柄，并与背景产生短暂联动。尚未获得权柄时，使用普通待机，不出现拨针和对应背景联动。该动作需兼容最新确认的自然垂手待机表现。
- 角色、怪物使用连续动作系统；怪物另有独立 AI。云层持续移动，灯光持续闪动。
- Shift 按住时奔跑已获授权。速度暂定 walk=390、run=624；这两个数值仍是暂定参数。

### 开局、引导与权柄卡

- 新流程从月璃没有能力开始。开局先处理停摆装置问题，修复装置后才获得时间权柄。
- 获得权柄时仅赠送三张卡：停止时间、快进时间、倒退时间。三张卡的对象范围不限。
- 新流程不使用旧的“灵性之火”或“初始10张卡”方案；旧存档保留，但旧火牌不在当前新流程激活。
- 首次引导以解决当前问题为推进方式，不照搬旧的四步行走、跳跃、调查、岔路教学结构。
- 战斗系统稍后由用户修改。在用户给出新战斗规则前，不得把旧战斗卡牌费用、火伤数值或相关旧规则当成新规则。

### 明确未确认的教学内容

目前没有确认是否要教以下用法，也没有确认“只获得权柄卡、暂不教用法”的方案：

- 固定失控平台
- 快进蓄能
- 倒退断桥

实现或叙事方案不得把上述任一选项写成已定设计。当前新流程没有要求解开这些谜题；具体权柄卡演示教学等待用户确认后再纳入流程。

## 替代或暂停沿用的旧规则

| 旧规则或旧实现所表达的行为 | 本轮处理 |
| --- | --- |
| 首次初始化自动发放灵性之火×4、书页护幕×4、蓄势×2，共10张并全部装备 | 新流程改为修复停摆装置后获得权柄，并仅赠三张时间卡。旧存档数据保留；不可因此继续给新流程发10张旧卡。 |
| 开场时月璃已持有克洛诺斯授予的时间权柄 | 新流程开局无能力，修复停摆装置后才获得权柄。 |
| 观测环外缘旧战斗教学：选牌减速、护幕防守、灵性之火反击及独立冷却 | 暂停用于新流程；战斗规则待用户后续修改。 |
| 旧四步探索教程：行走、跳跃着地、调查提灯、走任一岔路 | 由“围绕解决开局问题推进”的引导方向取代；新教程具体步骤尚未全部确定。 |
| 旧战斗 HUD 的时间权柄按钮只展开或收起旧卡库 | 此行为属于旧战斗 HUD。新探索 HUD 已用独立三卡界面接入时间能力；idle 拨针与环境短暂联动由探索世界/ambient 表现。不要将旧战斗按钮行为当成新 HUD 的最终交互要求。 |
| 旧战斗系统中的灵性之火伤害、费用、冷却及其余旧卡效果 | 不作为新战斗系统规则。待用户修改战斗系统后再确定。 |

这份替代关系只约束新流程。它不要求删除旧存档，也不授权改写旧测试或历史验收资料。旧测试文件与 `docs/verification/tests_frozen_2026-10-09.json` 中的冻结清单应保持原样；不得为了让旧测试通过而改动测试。冻结清单的哈希复核结果记录在本文验收补记中。

## 当前代码接口核对

以下记录关键接口及当前实现状态；生产界面的完整 GPU 验收范围见末尾。

| 接口 | 当前代码位置 | 当前情况与接入注意点 |
| --- | --- | --- |
| 收藏初始化与首发卡 | `scripts/progression/collection_store.gd:3-4,19-88,91-120` | 旧 `initialize()` 仍保留旧九种卡与十张 starter 兼容行为；主启动使用 `initialize_time_authority()`，隔离存放旧收藏与新权柄收藏。修复装置后 `unlock_time_authority()` 幂等地发放 stop、fast_forward、reverse 三张卡，并同一事务保存授权标记和探索进度。 |
| 卡牌定义 | `scripts/combat/combat_model.gd:4-10` | 卡牌定义包含旧火、护幕、蓄势及其他旧卡的名称、费用、冷却和效果。三张新时间卡的具体数值、费用、冷却和效果尚未由本轮规则给出；旧费用与火伤不能直接复用为新规则。 |
| 玩家移动输入 | `scripts/exploration/exploration_player.gd:35-36,60-79`；`scripts/exploration/exploration_session.gd:169-173`；`project.godot:45-48` | 当前已有 `SPEED=390`、`RUN_SPEED=624`；`explore_run` 绑定 Shift，physics session 将按住状态传入奔跑接口。数值仍按本轮确认标为暂定。 |
| 连续动作与权柄状态 | `scripts/visuals/continuous_motion.gd:16-17,102-128,251-270`；`scripts/exploration/exploration_player.gd:120-130,281-282`；`scripts/exploration/map_ambient.gd:15-61` | 连续动作层已有解锁控制、idle 权柄脉冲及角色 mesh 更新；新流程通过 run 解锁状态切换权柄表现，ambient 根据解锁和脉冲更新云层、灯光、装置。最新 ready PNG 采用右手自然下垂方向，正在集成；最终待机姿势、双腿收近、背景联动仍需检查实际画面。 |
| 首章开场与战斗引导 | `scripts/ui/main.gd:358-361`；`scripts/exploration/exploration_session.gd:52-107,814-835` | `begin_expedition(false)` 转入新探索；新 ruleset 打开 opening sequence，按世界教程推进至停摆装置，修复保存成功后解锁权柄。旧观测环外缘文案仍存在于旧兼容入口代码；当前新流程入口走新 session。 |
| 权柄按钮 | 旧战斗 HUD：`scripts/ui/main.gd:597-602,835-845`；新探索 HUD：`scripts/exploration/exploration_session.gd:774-812` | 旧战斗 HUD 的按钮仍绑定旧 `toggle_deck()`。新探索 HUD 独立构建时间卡 UI，并按权柄解锁状态显示按钮。不能把旧战斗 HUD 现状当作新探索 HUD 的现状；三张时间能力的实际效果由 temporal controller 处理。 |
| 教程状态 | `scripts/exploration/exploration_session.gd:52-107,147-167,814-835`；事件条件：`scripts/exploration/exploration_world.gd:202-222,274-280` | 当前新引导用短提示推进真实行走、跳跃到装置低台、按 E 修复；装置修复成功写盘后才授予权柄。阶段状态可保存及重载。当前流程不要求固定失控平台、快进蓄能或倒退断桥谜题。 |

## 尚待后续明确

- 三张时间卡的数值、费用、冷却、目标限制和具体效果。
- 新战斗系统的整体规则及教学顺序。
- 是否采用固定失控平台、快进蓄能、倒退断桥中的任一教学场景，或先只赠卡而暂不教学。
- 新存档/旧存档当前由 active ruleset 分流；旧收藏和章节元数据保留，旧进行中的探索 run/checkpoint 归档。后续存档版本变更仍需维持该隔离，不能把旧 starter 自动算作新流程的三张权柄卡。
- 云层移动与灯光闪动的具体节奏、强度和场景范围。

## 实现审查补记（2026-10-09）

本节记录当前实现、独立模块检查及已知的实际 GPU 新流程运行结果。生产新入口已实际 GPU 运行，但首次检查中有断言失败且目标拾取尚未实点验证；不代表整段生产 GPU 验收最终通过。

### 当前接入与流程隔离

- `scripts/ui/main.gd:153-160,358-361`：主菜单“新的探索”进入 `begin_expedition(false)`，该分支直接调用 `start_exploration_session(true)` 并返回；这条默认新开局进入新探索，不进入旧首章战斗流程。这里已核对分支函数体。
- `scripts/ui/main.gd:1069-1079`：正式启动读取存档走 `initialize_time_authority()`。该初始化把新时间权柄数据放在独立字段中，并在 ruleset 切换时归档旧探索 run/checkpoint；它不会调用旧 `initialize()` 的 starter 发放逻辑。
- `scripts/progression/collection_store.gd:19-62,65-88,91-120`：`initialize_time_authority()`保留旧 `collection`、装备、奖励记录及元数据；新权柄卡使用独立的 `authority_collection` / `authority_equipped_ids`。修复解锁以 `authority_granted` 保证幂等，并把三张卡与 run/checkpoint 解锁字段一次提交。旧 `initialize()` 仍保留“starter_granted=false 时发10张旧卡”的兼容行为；新入口当前不调用它，因此未来若有新流程代码误用旧初始化器，会重新引入旧 starter。
- `scripts/exploration/exploration_session.gd:109-140,774-812`：时间权柄 ruleset 构建专用 HUD；未解锁时没有卡按钮，权柄钟按钮不可见；解锁后从 `get_authority_loadout()` 显示 stop、fast_forward、reverse 三卡。`request_encounter()`、奖励领取和旧商店流程在新 ruleset 下受到限制；`authority_session_acceptance` 也断言新流程不创建旧战斗 adapter，不能进入旧教学战。
- 旧卡牌定义、旧首章文案和旧收藏界面仍在主程序中，但当前 ruleset 分支会隔离入口：主菜单“显现权柄”调用 `show_collection()`，函数体按 `active_ruleset == "time_authority_v2"` 转到 `show_time_authority_collection()`（`scripts/ui/main.gd:452-468`），展示独立时间卡收藏；旧 `show_loadout(true)` 仅由旧 ruleset 执行。旧快速试炼和战斗实现仍保留兼容代码。结合新会话专用 HUD 与 `authority_session_acceptance` 的隔离断言，当前新探索路径未把 fire 能力接入新卡库。

### 目标拾取、暂停与回溯刷新

- 目标注册和拾取见 `scripts/exploration/exploration_world.gd:491-502` 与 `scripts/exploration/exploration_session.gd:197-222`。环境节点绘制层为 `z_index=-10`（world:494），作为 Node2D 背景绘制，没有 GUI `Control` 拦截点击；鼠标目标由 `TemporalController.target_at_point()` 按目标屏幕矩形命中（`scripts/authority/temporal_controller.gd:115-122`）。当前模块验收证明云目标已注册，并证明玩家屏幕坐标可选中；没有针对每个目标被云图像覆盖时的实际 GPU 鼠标命中测试。代码层未见云层 GUI 阻挡，但目标矩形重叠时遵循注册顺序反向命中，应由生产 GPU 验收补实点覆盖。
- 全局 pause 时 `TemporalController.advance()` 直接返回（`scripts/authority/temporal_controller.gd:42-43,87-89`）；世界模块验收检查了 pause 冻结云层 phase。此项目前有模块级数据证据。
- 玩家回溯调用 `scripts/exploration/exploration_world.gd:511-552` 的 `_restore_player()` / `_restore_rig()`。当前恢复路径捕获并恢复角色 rig 状态后直接调用 `continuous_motion._sample()` 更新 pose/mesh，以覆盖 TemporalController reverse 只恢复、不推进对象的情况。该修复已接入代码；回溯后角色像素是否符合预期仍需实际 GPU 帧验证。

### 生产入口首次 GPU 检查

首次 GPU 实际流程中，以下步骤报告通过：主菜单 New、剧情拒绝/接受、权柄获得前无能力、实际走动与跳跃抵达停摆装置低台、E 修复并获得三卡、继续探索、磁盘重载。教程通过场景短提示引导真实操作，不依赖固定失控平台、快进蓄能或倒退断桥谜题。

同次运行报告4项失败断言。已查明的问题有两类：测试把解锁前“钟节点存在但不可见”误判为失败（测试错误要求节点不存在）；另一次点击落在月璃和装置重叠位置的中心，实际选择了玩家，因此没有验证装置目标拾取。4项失败的最终计数与其他 GPU 项目由集成验收报告补齐，不在此猜测。独立 GPU 实点验证仍在追加。

### 冻结测试清单

只读读取 `docs/verification/tests_frozen_2026-10-09.json`，按其 `path` 与 `sha256` 逐一计算并比对测试文件：清单共37项，37项均存在且 SHA-256 匹配，0项缺失、0项不匹配。最终复核仍为37项匹配；清单未被修改。此次只做哈希核对，没有为本次审查运行或修改旧测试。

### 当前证据边界

现有证据包括 store/session/world/temporal 独立模块验收及生产新流程首次 GPU 实际运行。GPU 已证明新入口、拒绝/接受开场、锁定态、真实走跳至低台、装置修复、三卡授予和存档继续/重载路径可运行；首次运行的4项断言失败及未验证的装置拾取命中如上所述。云图像重叠情况下的对象命中和 mesh 回溯刷新仍待额外实际 GPU 画面/鼠标检查。三卡谜题未获批准，战斗系统待用户重新设计；因此不把旧全章七场战斗或 Boss 记录作为当前新流程结果，也不把本轮写成全章战斗已验收。
