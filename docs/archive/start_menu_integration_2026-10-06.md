# 默认主界面实际接入与验证

用户反馈从 Godot 运行仍显示旧版。根因是上一轮仅交付了独立背景预览，默认入口 `scenes/main.tscn` 内 `_ready()` 仍调用 `show_intro()`。本轮已实际改为 `show_start_menu()`，并按用户新确认的 A 银白样式完成启动菜单。工程路径保持 `C:\Users\hoshi\Endless Poem\endless-poem`。

## 实际结果

- 启动显示动态宇宙星图，复用已确认的随机红星、不规则明暗和形态异常。
- 左侧为独立透明艺术字“未尽之诗”及依序排列的五个按钮：新的探索、继续探索、显现权柄、探索手札、退出游戏。
- 右侧为月璃 v1 衍生的独立透明半身像：正面、双眼闭合、双手交握祈祷，保持银白长发与黑白金服装。参考区域为 540×675，位于 1440×900 的右半屏；轻微呼吸运动。
- 主菜单绕过旧章节背景、顶部栏和介绍文案；旧剧情介绍函数仍保留供原流程使用。
- 两张新素材均为内置 image_gen 生成的 RGBA PNG，alpha 范围 0..255，已检查实际透明合成。提示及来源见 `assets/menu/README.md`。

## 五个按钮与当前边界

| 按钮 | 行为 |
|---|---|
| 新的探索 | 原有路线从节点 0 开始，保留永久收藏、装备和奖励领取记录 |
| 继续探索 | 恢复本次运行中挂起的探索页面或暂停战斗，保留原模型时间与 UI；没有挂起远征时禁用 |
| 显现权柄 | 进入现有永久收藏/装备页面，返回按钮回到主菜单 |
| 探索手札 | 打开现有调查记录，关闭或 Esc 回到主菜单 |
| 退出游戏 | 退出 Godot 游戏进程 |

当前没有新增远征磁盘 checkpoint。因此关闭游戏后不能续接远征或战斗，重新启动时“继续探索”禁用；永久收藏和调查元数据继续按原规则保存。不使用存档文件存在或初始收藏存在来冒充已有可恢复远征。

非战斗页面通过左上标题返回主菜单，暂停菜单新增返回主菜单动作。当前暂停探索先挂起真实页面和战斗节点；菜单内查看收藏或手札不会丢弃它，继续时恢复原实例。

## 验证

- 默认入口 GPU 验证：从 `ProjectSettings.application/run/main_scene` 读取实际配置再实例化，23 项检查、0 失败，5 次鼠标操作。实际素材加载、五按钮、布局、动态星图推进、手札/收藏返回、新探索、会话恢复和收藏保留均通过。
- 实际查看 1440×900 和 1152×720 窗口截图，无原介绍页或旧顶部栏，人物及艺术字未被遮挡。
- 普通 Godot 启动 smoke：仅使用 `--path` 加自动退出参数，不指定测试脚本或独立场景；退出码 0、stderr 为空。
- `start_menu_acceptance.gd`：PASS，包含暂停战斗返回菜单、战斗时钟冻结及同一实例恢复。
- 受影响回归：UI 94 项、world UI 73 项、仅血条 HUD 414 项，全部 0 失败。
- 图像资源导入退出码 0，验证日志中无引擎或脚本错误。

证据位于 `docs/verification`：`start_menu_default.png`、`start_menu_continue.png`、`start_menu_small_window.png`、`start_menu_render_stdout.log`、`start_menu_default_launch_stdout.log`、`menu_start_menu_acceptance_stdout.log`、`menu_ui_acceptance_stdout.log`、`menu_world_ui_acceptance_stdout.log`、`menu_health_only_hud_acceptance_stdout.log`。

## 文件与执行分工

- `gpt-6.1-sol`：修改 `scripts/ui/main.gd`，新增 `scripts/ui/start_menu.gd`、`tests/start_menu_acceptance.gd`；原 main 首次备份为 `docs/verification/start_menu_before_main.gd.txt`。
- 主代理：生成并导入 `assets/menu/moonli_prayer_v1.png`、`assets/menu/title_logo_silver.png`；新增 `tests/start_menu_render.gd`；完成默认启动、GPU 画面与回归检查，更新文档。
- `project.godot` 的主场景配置保持 `res://scenes/main.tscn`，无需改到预览场景。战斗模型和存档模型未修改。

打开本工程的 `project.godot` 后按 F5 运行项目。已有旧运行窗口时先 F8 停止，再 F5。F6 运行当前场景，可能运行的是打开的战斗或独立预览页，不能用它判断默认入口是否更新。
