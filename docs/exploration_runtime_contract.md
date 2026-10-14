# 横版探索实施接口 — 2026-10-07

用户已批准完整计划。项目仅在本目录实现；资料库原文只读。A 主菜单不重新设计。

## 所有权
- 地图 Sol：`scripts/exploration/exploration_world.gd`、`exploration_player.gd`、`chapter_map.gd`、可自增同目录以 map_/player_ 开头文件、`scenes/exploration/`、`tests/exploration_world_*.gd`。不修改 main、战斗、存档或 onboarding。
- 战斗 Sol：`scripts/combat/combat_model.gd`、新增 `scripts/exploration/spatial_combat.gd` 和 spatial_* 文件、`tests/spatial_combat_*.gd`；允许必要战斗测试兼容调整，不修改旧世界美术或 main。
- 开场 Sol：`scripts/onboarding/`、`scenes/onboarding/`、`tests/onboarding_*.gd`，不修改 main/存档/地图。
- 集成 Sol（第二批）：新增 `scripts/exploration/exploration_session.gd`、session_* 文件、`scripts/ui/main.gd`、`scripts/progression/collection_store.gd`、project.godot、集成测试。
- 主代理：本接口、`assets/exploration/` 新素材、独立验收、协调；共享文件修复先交接。

## 世界 API（Node2D）
`ExplorationWorld` 通过 preload 使用，不依赖 class_name 扫描。
- signals: `encounter_requested(encounter_id: String)`、`interaction_requested(event_id: String)`、`tutorial_event(event: String, data: Dictionary)`、`checkpoint_requested(position: Vector2, region: int)`。
- `configure(run: Dictionary)` 建立地图/角色并应用已完成状态；`apply_run(run: Dictionary)` 更新门槛及完成标记，不重建角色。
- `advance_simulation(sim_delta: float)` 唯一推动玩家/环境/触发逻辑；自己不运行 _physics_process，集成层驱动。`set_paused(bool)` 控制输入和镜头。
- `set_movement_input(axis: float, jump_pressed: bool)` 供统一输入层及物理操作测试使用；空格只跳跃。`interact()` 发出最近交互信号。
- `get_player_position() -> Vector2` / `set_player_position(Vector2)` 为脚点世界坐标；`get_player_hitbox() -> Rect2` 为世界受击框。
- `get_encounter_spec(id: String) -> Dictionary` 返回 `{rect: Rect2, floor_y: float, spawns: Array[Vector2], region: int}`；战斗运行时在这些空间里生成实际敌人。
- `set_encounter_active(id: String, active: bool)` 显示边界并隐藏该遭遇的装饰敌人；`finish_encounter(id: String)` 标记/隐藏已胜利遭遇；`leave_encounter(id: String)` 解除边界并抑制同位置立即重入。
- `get_player_visual()` 返回已有角色展示对象，战斗可调用它的动作方法；`play_player_action(action: String)` 提供稳定封装。
- `presentation_state() -> Dictionary` 返回可审查的区域/脚点/着地/当前动画/平台/岔路及缺失资源；地图坐标转换用 CanvasItem 自带 get_global_transform_with_canvas。
- camera 由世界独占，菜单停用时需 `set_paused(true)` 并禁用 camera；恢复重新启用。暂停中不推进运动。

地图约 24000x2700；8区按主线顺序，既有7遭遇 id = tutorial/stairs/patrol/lamp/elite/corridor/boss。交互 id = tutorial_lantern、bridge_before、bridge_after、testimony、supply_lamp、supply_tower、rest、anchor_key、final_dial。桥调查在安全立足点进行。两个分叉允许全访问。
探索 run 最少包含 `position:[x,y]`, `region`, `completed:Array[String]`, `interactions:Array[String]`, `tutorial_step:int`, `hp`, `coins`, `upgrades`。完成门槛仅由当前 run 决定，不能用旧永久证据跳过新章。
教程事件 = walked / jump_landed / investigated / fork_completed，data 可有 position/interaction。最初安全样段顺序 walk→jump→lantern→fork，完成后到 tutorial 遭遇。不要在教程阶段触发战斗。

## 空间战斗 API（Node2D）
`SpatialCombat` 对象连接同一世界，不另建玩家或相机。`configure(model, world)`；`start(encounter:String, config:Dictionary) -> bool` 启用空间模式、世界遭遇边界与实际敌人。`advance(real_delta:float)` 按固定小步先推进模型再按模型实际时间差推进 world、敌人、攻击体与命中，集成层此时不得再 advance_world。`set_paused(bool)`、`finish()` 清理过期攻击、恢复世界。
`get_target_rect(id:String) -> Rect2` 返回屏幕坐标供 HUD/鼠标使用；`get_target_world_position(id)`；`presentation_state()` 返回攻击/实体的诊断数据。`target_clicked(id:String)` 信号可选，集成层亦可依 rect 命中。
模型是唯一 HP/护盾/资源权威。空间攻击带 action_id，提交一次扣费、真实碰撞一次结算，落空不退已提交费用。基础火延至法术抵达才伤害；迟刻等状态保持锁定规则。敌人近战方向锁定；Boss 钟鸣贴地冲击可跳，残响重演原路径，只有真实命中才登记后续残响。
主角法术视觉保留权柄四周外散再汇敌、多道尾迹；多道表现只对应一次命中。原模型直接结算可保留给旧隔离测试/快速试炼，但新生产路径必须显式空间模式，不可自动回退。

## 开场/教程 API
`scripts/onboarding/opening_sequence.gd` extends Control，signal `accepted`，默认自行播放，可 `advance(delta)` 手工驱动测试；`presentation_state()` 暴露阶段/refusal_count/可见按钮。字体预载 res://assets/msyh.ttc。Canvas 1440x900 自适应。
原文：沉睡的神明即将苏醒 / 世界在崩坏 / 你是最终的幸存者、亦是被寄以希望的无暇之人 / 你是否愿意拯救这个世界？
初次否不计数；弹窗内“但是，我拒绝”第三次后只显示“好吧，那我别无选择”；提示“你真的想拒绝吗？”。接受信号只发一次。无强闪屏，实际逐字裂解/局部畸变。
`scripts/onboarding/exploration_tutorial.gd` extends Control，signal `step_changed(step:int)` / `completed`；`configure(step:int)`，`observe(event:String,data:Dictionary={})`；4步对应世界事件。只教探索，不发卡、不战斗教学；一行短提示/局部标记。step=4完成。自己不写存档，由集成层响应信号。

## 存档及集成
CollectionStore 保留永久收藏/旧来源/证据/不可改写原件；新增原子方法把探索 metadata 与领取/购买同步提交。探索 session 自包含世界、空间战斗、CanvasLayer HUD、开场/教程及暂停/调查/商店/奖励。main 只接入菜单 new/continue/session return，不把旧 clear_page 用来销毁共享世界。
检查点包含当前 run，交易成功与检查点同步；战斗前写安全快照；战败/战中重启恢复战前，不序列化半空弹道。已结算遭遇不重发结晶，rest和免费升级每远征一次；卡永久 source 保持原chapter1:battle:*及shop:3/5:*映射。
保持六列两行卡牌、滚动、独立冷却、无数值血条和时钟入口。自身卡再次点同实体施放，空格不施放。Esc 取消选牌→收牌库→暂停。所有验证用隔离 user:// 路径。
