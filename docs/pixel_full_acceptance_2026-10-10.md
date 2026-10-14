# 像素角色与怪物扩展：实现与验收

日期：2026-10-10。工程：`C:\Users\hoshi\Endless Poem\endless-poem`。引擎实测版本：Godot 4.7.2。

用户已采用主角样段的尺寸与动作方向，并要求继续扩展角色与怪物。本轮将该方向接入默认游戏，完成月璃、暮笙和六类战斗单位的像素资源与动作状态；主菜单保持已认可的A银白版本。按F5启动 `scenes/main.tscn` 即可使用，不需要切到样段场景。

## 完成范围

| 项目 | 结果 |
|---|---|
| 主角尺寸与逐帧动作 | 沿用48×64透明帧、最近邻3倍显示，主体约120像素高。48张源动作帧涵盖待机、走、跑、起停、转身、跳跃、下落、落地、施法、受击与退场。 |
| 步态衔接 | 行走和奔跑各8帧，共用步态相位；以实际位移推进，Shift切换不重置相位，受阻时不会按期望速度空踏步。动作过渡不延迟物理输入。 |
| 巡刻卫兵、整点卫兵 | 分别制作20帧；接入行走、蓄力、攻击、恢复、受击与退场。保留原有敌人决策和实际命中系统。 |
| 黄铜星仪、时间锚 | 分别制作20帧；使用悬浮循环和各自的动作、受击、击破表现。星仪支援动作接上现有行动事件。 |
| 回声观测员、克洛诺斯·试炼相 | 分别制作20帧；独立角色外观及行动表现，接入现有战斗状态。未借此重新定义三张时间卡的战斗规则。 |
| 暮笙 | 独立20帧资源，正常探索使用像素角色；交互进入对话动作，结束回到待机。仍是剧情NPC，与敌方回声观测员分开。 |
| 状态与时间 | 成功应用时间能力后播放主角施法；无效目标不新增施法表现。暂停冻结逐帧动画，回溯恢复位置、动画状态、过渡进度与可见帧。 |
| 连续施法与完整播放 | 相同动作再次触发时重新从第0帧开始。播放时长取实际帧数/FPS，施法完整播放0.5秒；移动、跳跃可同时进行，不再在0.4秒提前切回待机。 |
| 小尺寸人物的法术起点 | 根据当前像素人物可见边界计算，随人物移动更新；不再沿用旧大人物头顶上方的固定起点。原空间法术飞行时间、伤害与模型时钟不变。 |
| 退场 | 空间战斗中的死亡单位先禁用选取，再完成退场动画；最后一名敌人的结算不直接吞掉退场表现。 |
| 默认入口 | `manifest.ready=true`，8个单位合计188张源动作帧已用于正常游戏。新游戏仍无能力，修复装置后恰好获得停止时间、快进时间、倒退时间。 |
| 资源边界 | 修正主角8帧底边越出1行的脚点问题。独立分析188帧，规范化后无透明通道有效像素被画布裁掉。 |

所有单位统一使用48×64固定画布，每套图集共用缩放与脚点规则；不把每个姿势独立拉伸到相同外接框。单位显示倍数依体型不同，整点卫兵的像素块比主角粗，保留了装甲敌人的大小层级。这是当前可见效果，不表述为每个单位的像素密度完全相同。

## 实机画面

- [全阵容动作短片](verification/pixel_roster_motion.mp4)：Godot实际渲染，1440×900、30fps、8秒、240帧。展示生产用角色渲染器的待机、移动、蓄力/施法、动作、恢复、受击与退场；这是动作陈列场景，不是一次完整战斗录像。
- [全阵容待机](verification/pixel_roster_2026-10-10.png) / [全阵容移动](verification/pixel_roster_2026-10-10_moving.png)。
- [正常地图入口](verification/pixel_world_start_2026-10-10.png) / [正常地图中的月璃与暮笙](verification/pixel_world_musheng_2026-10-10.png)。
- [默认入口流程日志](verification/pixel_final_main_playthrough_stdout.log)：正常主菜单、三次拒绝、无能力开始、实际走跳至装置、E修复、三张时间卡、目标使用、暂停、继续与重新建立应用后的存档恢复。

画面由Godot读取实际项目资源生成，未用宣传效果图替代。MP4已完成解码检查。

## 检查结果

| 检查 | 结果 | 证据 |
|---|---:|---|
| 正常世界像素接入、脚点、NPC、暂停与回溯 | 18项通过 | `verification/pixel_final_world_integration_duration_20261010_stdout.log` |
| 八个单位的动作状态与配置 | 205项通过 | `verification/pixel_full_monsters_fixed_stdout.log` |
| 空间战斗受击、支援、退场及主角施法反馈 | 22项通过 | `verification/pixel_final_spatial_feedback_duration_20261010_stdout.log` |
| 连续施法重播、法术起点与旧规则不变 | 16项通过 | `verification/pixel_final_action_replay_duration_20261010_stdout.log` |
| 完整动作播放、移动施法及空中施法 | 14项通过 | `verification/pixel_final_action_duration_20261010_stdout.log` |
| GPU全阵容及正常地图渲染 | 34项通过，240帧 | `verification/pixel_roster_render_stdout.log` |
| 原有正式入口流程测试，在像素版本运行 | 36项通过，21次实际UI点击 | `verification/pixel_final_main_playthrough_stdout.log` |
| 原有时间权柄会话测试 | 24项通过 | `verification/pixel_full_session_stdout.log` |
| 原有空间战斗测试，最终动作修复后重跑 | 43项通过 | `verification/pixel_final_spatial_after_actions_stdout.log` |
| 静态透明边界与裁切核对 | 188帧源区域有效，0个有效alpha像素被裁掉 | `verification/pixel_final_asset_audit_2026-10-10.json` |
| 早期冻结测试清单 | 37/37 SHA-256一致 | 同上 |
| 像素改造前冻结清单，含测试及UID文件 | 91/91 SHA-256一致 | 同上 |

表中Godot运行记录的stderr均为空；判定依据是各测试自己的结果汇总，不仅依赖PowerShell的退出状态。独立Luna资源检查是静态分析，不冒充GPU运行。

主代理在最后动作修复后再次运行正常入口GPU流程与空间战斗回归，分别得到36项/21次点击及43项通过，Godot退出码均为0。交付前再次逐文件读回两份冻结清单，仍为37/37与91/91一致；单独结果在 `verification/pixel_delivery_test_integrity_2026-10-10.json`。

**保留的失败：**原样运行 `tests/pixel_authored_assets.gd`，11项中9项通过、2项失败。两项仍固定要求32张主角源帧及32张不同帧，当前主角按已授权扩展为48帧。详见 `verification/pixel_pilot_contract_final_unchanged_stdout.log`。没有改动这些断言、删除测试或回退资源以让它变绿；因此本轮不宣称所有历史测试通过。

## 文件与模型分工

| 工作 | 实际执行模型 | 主要产出 |
|---|---|---|
| 主角运动、过渡与探索接入 | `gpt-6.1-sol` | `exploration_player.gd`、`exploration_world.gd`、`pixel_actor.gd`及新增检查 |
| 战斗单位渲染接入 | `gpt-6.1-sol` | `combat_actor.gd`、`chapter1_assets.gd` |
| 扩展图集帧定位与共同锚点 | `gpt-6.1-sol` | `tools/map_pixel_roster.py`、`roster_frames.json` |
| 空间动作反馈及GPU证据 | `gpt-6.1-sol` | `exploration_session.gd`、`spatial_combat.gd`及新增反馈/渲染检查 |
| 资源、冻结测试与旧断言独立核对 | `gpt-6-luna` | `pixel_readonly_audit_2026-10-10.md`、独立JSON审计记录 |
| 最后画面与动作接口修复 | `gpt-6.1-sol`，主代理复核 | 连续施法重播、完整动作时长、像素人物法术起点；新增两份回归检查 |
| 美术生成、资源合并、集成复核与交付说明 | 主代理 | 10张原始透明图集、`manifest.json`、合并工具、README及本报告 |

子代理均通过代理工具显式选择上述模型。当前工具没有提供主代理自身的实际模型ID，因此本报告不把角色分工当作“已切换为Astra”的证据。

本批美术使用内置image_gen生成，遵循Game Studio精灵流程；ComfyUI是用户允许的可选工具，本批没有通过ComfyUI生成。生成方式与已保存提示见 `assets/pixel_v1/GENERATION.md`。

## 范围边界

本轮完成的是已确认像素方向下的角色/怪物扩展和动作接入。当前三张时间卡的新战斗系统由用户后续确定；本次没有恢复灵性之火或开局十张卡，也不把旧规则的Boss测试记录当作新三卡战斗验收。没有以新增动作之名改写伤害、费用、冷却或探索奖励规则。

历史样段和网格形变验收报告保留，并已注明历史状态。新增检查保存在独立文件；原有测试与两份冻结基线均未修改。
