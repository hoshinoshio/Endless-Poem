# 主界面 A 整体还原与动效验收

## 本轮依据与完成范围

用户确认“整体视觉还原加使用动效”，采用此次提供的三联参考图最上方 A「星夜银辉」。参考原件保存在 `art_review/2026-10-11-menu-a/user_reference_comparison.png`。工程中较早的 v2 对照稿人物更小，不能作为此次图的同一版本。本轮按当前参考重建独立美术图层和实时 Godot 菜单，不是将三联参考板整体贴入游戏，也不宣称逐像素复制原稿。

工程固定为 `C:\Users\hoshi\Endless Poem\endless-poem`，默认场景仍为 `res://scenes/main.tscn`。打开 `project.godot` 后按 F5，或使用根目录 `开始游戏.cmd`。

| 要求 | 状态 | 实际产出 |
|---|---|---|
| A 的整体视觉 | 完成 | 深蓝哥特观测台与远城、银白艺术标题、左列星形菜单、右侧大幅祈祷半身像 |
| 人物构图 | 完成 | 闭眼、双手交握、头顶靠近上沿、腰部沿画面下沿裁切；补绘原素材两侧发丝，去掉竖直硬切边缘 |
| 艺术字和按钮 | 完成 | 标题透明独立图层；五个实时按钮带星徽、底线与末端菱形；本机使用宋体，缺失时回退到项目中文字体 |
| 动效 | 完成 | 天空稀疏星光缓慢明暗、悬停/焦点星徽与底线渐亮、按下反馈、约半秒入场淡显；祈祷姿势固定 |
| 五个入口功能 | 完成 | 新探索、继续探索、权柄收藏、手札、退出保持原路由；无存档时继续为禁用状态 |
| 缩放 | 完成 | 1440×900 逻辑画布等比缩放；1152×720 实际窗口已检查；画布裁切避免人物侵入宽屏留边 |
| 原有测试保护 | 完成 | 修改前 111 个测试/UID 文件的大小与 SHA-256 全部不变 |

本轮生产代码只涉及主菜单，未调整地图像素动作、靠近 E 交互、权柄三卡、开场或战斗规则。主角半身插画用于主菜单，地图像素小人仍沿用现有实现。

## 修改文件与素材来源

- 修改：`scripts/ui/start_menu.gd`、`scripts/ui/menu_environment.gd`。
- 新增：`scripts/ui/menu_a_button.gd`、`scripts/ui/menu_a_sky.gd`。
- 新增最终素材：`assets/menu/menu_a_reference_background.png`、`menu_a_reference_portrait.png`、`menu_a_reference_title.png`。人物和标题为 RGBA，已核对实际 alpha 范围 0–255。
- 更新 `README.md`；新增本报告、独立核对报告、参考素材记录及实机证据。
- 新增验证脚本：`tests/menu_a_reference_render.gd`、`tests/menu_a_quit_acceptance.gd`。原有测试内容未改。

使用内置 `image_gen` 依据参考图制作分层素材，没有调用 ComfyUI。用户允许使用 ComfyUI，但未要求必须由它生成。最终素材全部复制进工程目录，运行不依赖 `.codex/generated_images`。原有素材保留。原始提示词在 `art_review/2026-10-11-menu-a/reference_asset_prompts.json`，最终标题和人物侧缘修订提示分别为 `title_revision_prompt.txt`、`portrait_edge_revision_prompt.txt`。最终尺寸、生成文件名及 SHA-256 在 `asset_manifest.json`。审阅素材和录制帧目录设有 `.gdignore`，避免作为游戏纹理批量导入。

## 实际验证

运行环境：Godot **4.7.2**，Compatibility / OpenGL，NVIDIA GeForce RTX 5060 Ti。采用唯一临时存档，清理测试存档，不覆盖玩家存档。

1. 最终 GPU 脚本：**56 项检查通过，0 失败，8 次真实鼠标点击**。从项目配置的默认主场景创建实际游戏，验证素材加载、禁用继续、按钮互不重叠且可点击、鼠标悬停和焦点动画、淡显结束后天空像素变化、人物位置固定、手札与收藏返回、开场进入地图、同一会话继续、重新创建主场景后从持久存档继续、缩小窗口布局，以及收藏不被这些菜单操作修改。
2. 退出单独用实际主菜单鼠标点击验证：退出码 **0**，同时记录 `MENU_A_QUIT_BEFORE_REAL_MOUSE_RELEASE` 与 `MENU_A_QUIT_TREE_EXIT`。
3. 原有 `tests/start_menu_acceptance.gd` 保持原样运行，**仍有 2 项失败**：`Existing battle route still opens` 与 `Battle UI instances restore intact`。该脚本在新存档无卡时调用旧版 boss 战斗入口；当前无能力新开局不会发放旧十张卡，而战斗模型拒绝空装备，因此停留于 equip。未通过修改测试、补发旧卡或改变新规则规避失败；本轮不声称整个历史测试集通过。
4. 原有 `start_menu_render.gd` 还固定断言旧人物矩形为 540×675；本次获确认的大幅半身构图已经替代该规格。该旧脚本未改，本轮使用新增脚本验证新规格。
5. 独立核对确认 111 个基线测试文件大小和哈希全部一致。新增测试目录文件共 9 个，包括两个新脚本、对应 UID，以及 Godot 为既有脚本补生成的 5 个 UID；无原文件消失或变化。

本轮验收覆盖主界面、进入/恢复探索与菜单返回；不等于完成尚待用户制定的新战斗系统。

## 证据

- 默认界面：`docs/verification/menu_a_default.png`。
- 悬停效果：`docs/verification/menu_a_hover.png`。
- 焦点效果：`docs/verification/menu_a_focus.png`。
- 小窗口：`docs/verification/menu_a_small_window.png`。
- 星光动效预览：`docs/verification/menu_a_motion_preview.mp4`，由 60 张实际 GPU 截帧构成，按截帧文件时间间隔近似播放；这是抽样画面预览，不用来判定实时帧率。原帧和时间记录在 `menu_a_motion_frames/`。
- 最终日志：`menu_a_reference_final_stdout.log` / `menu_a_reference_final_stderr.log`，stderr 为空。
- 退出日志：`menu_a_quit_acceptance_stdout.log` / `menu_a_quit_acceptance_stderr.log`。
- 保留的旧失败：`menu_a_existing_acceptance_stderr.log`。
- 测试保护清单：`menu_a_tests_before_2026-10-11.json` / `menu_a_tests_after_2026-10-11.json`。
- 独立核对：`docs/menu_a_independent_audit_2026-10-11.md`。

## 实际模型分工

| 任务 | 模型 | 文件边界与结果 |
|---|---|---|
| 参考与现有入口核查 | `gpt-6.1-sol` | 只读，辨认此次参考与旧 v2 的差别 |
| 布局、按钮与动效实现 | `gpt-6.1-sol` | 主菜单四份脚本；完成后由主代理接手构图微调 |
| 新增 GPU / 退出验证脚本 | `gpt-6.1-sol` | 两份新增验证脚本，实际运行由主代理执行 |
| 独立检查与测试哈希保护 | `gpt-6-luna` | 只读工程，写入独立报告和前后清单 |
| 素材制作、集成、实际渲染检查 | 主代理 | 调用图像工具、修正素材边缘、整合并运行 Godot、审阅截图 |

子代理调用均显式选择上述模型并传递文件所有权。工具未提供主代理实际模型标识，因此无法以工具证据确认主代理为 Astra；协调和最终验收由本会话主代理完成。
