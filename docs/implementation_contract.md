# 首章已确认实施接口（2026-10-03）

用户新计划覆盖旧文稿的抽牌方案：探索获得实体卡永久收藏，战前选装数量不限，同名实体分别冷却；战斗无洗牌、抽牌、手牌或待抽。初始10张 fire×4 / shield×4 / charge×2，只发放一次。移除 insight/draw/foresight，保留9种卡牌。奖励来源一次性领取并保存。原始文稿只读，摘录保留历史事实。

## 文件所有权

- 战斗Sol：scripts/combat/**、tests/combat_acceptance.gd、tests/battle_policy.gd。
- 界面Sol：scripts/ui/**、scripts/progression/**、scenes/**、tests/collection_acceptance.gd；不修改原图与字体。
- 规则Luna：docs/chapter1_requirements.md、docs/acceptance_checklist.md；可给source_extracts加历史说明但不改引文。
- 主代理：本接口、project.godot、启动脚本、README、tests/ui_acceptance.gd、验证证据与集成。修复别人文件先交接。

## 战斗模型

scripts/combat/combat_model.gd extends RefCounted。

- start_battle(encounter: String, config: Dictionary = {}) -> bool。encounter：tutorial / stairs / patrol / lamp / elite / corridor / boss。无loadout参数时默认10张基础卡；显式空或全无效loadout返回false，不能偷偷补卡。
- config：hp默认50、loadout数组每项{id: String, type: String}、upgrades字典按实体id存本次远征升级、relaxed_focus布尔。拒绝重复实体id，未知类型不进入战斗；同类型不同id允许。
- tick(real_delta: float)、select_card(card_id: String) -> bool、cancel_selection()、play_selected(target_id: String = '') -> bool、set_paused(value: bool)、get_snapshot() -> Dictionary、take_events() -> Array、get_card_catalog() -> Dictionary。
- 快照：status（idle/active/won/lost）、time、time_scale、hp、max_hp、shield、energy、max_energy、focus、max_focus、selected_card_id（空字符串为未选中）、cards（稳定装备顺序）、enemies、phase、recovery、pending、last_message、paused、shield_batches。无hand/deck/draw_*。
- cards每项：id,type,name,cost,cooldown,remaining,description,target（enemy/self）、playable、state（ready/cooldown/energy/condition）、reason（中文使用条件）、selected。已使用卡仍留原数组位置，冷却后直接可用。
- enemies每项：id,kind,name,hp,max_hp,shield,burn,intent,charge,duration,is_anchor。phase普通0/Boss1至3。recovery空字典或remaining,recorded_hp,total_anchors,living_anchors；pending显示label,remaining,kind,target。
- events：type,message可附target/amount/card_id/time；cast、hit、shield、phase、anchor、win、loss等，不再有draw事件。
- 保留0.2倍减速、2真实秒单次/6真实秒专注、常速3:1恢复，统一战斗时钟。无效目标/费用不足/取消不支付；防护先于同刻攻击；Boss三阶段、锚与残响按原文。短施法0.12战斗秒仍适用。

## 收藏与界面

- 收藏中的每个副本拥有稳定唯一id，装备列表引用id，每个实体至多一次；超过12张滚动。首次默认装备10张，此后保留玩家配置，新奖励不自动装备。
- 单次写入同时保存新增卡与来源领取标记；重启/败退不重复授予。保留旧evidence/record_choice/chapter_completed。可配置save_path，便于隔离验收存档。
- UI测试可读取main的combat、snapshot、screen、collection、equipped_ids、claimed_rewards，以及card_buttons（卡id到Button）、target_buttons（敌人id到Button）、authority_button、deck_scroll。若使用独立store，把三个集合用getter暴露即可。
- 流程接口保留show_hub()、begin_expedition(quick=false)、start_encounter(encounter)（先显示战前选装）、confirm_loadout()（真正开战）、choose_card(card_id)、confirm_selected(target_id='')、toggle_deck()、next_route()。快速Boss只使用真正已拥有并装备的卡，不伪造奖励，不加属性。
- 1440×900 canvas：Boss血条上方居中约90px留白；普通敌状态各自头顶；时钟图标在卡牌左侧；下方中央6列×2行可滚动矩形牌库，开战收起，选牌保持展开，点击图标整块收起并取消选牌。人物状态固定在牌库下方、收起后仍显示。图标/滚动不暂停或减速；旧1–7键取消，鼠标+空格+Esc三层行为。
- 不继续使用此前未确认的场景/配色/怪物创作作为正式美术：仅做清晰中性功能占位、已指定时钟图标主体与v1原图。剧情沿文稿，不补写新设定。

## 验收

模型测试通过正常选卡/施放完成教学与三阶段Boss，禁止修改生命来制造胜利；覆盖失败重试、暂停、独立冷却、取消/失效目标不扣费、锚回收。收藏测试覆盖一次初始化、旧存档迁移、原子奖励领取、不同来源同名副本、装备>12、未装备排除。主代理负责Godot实际渲染、正常UI操作路径和截图复核。
