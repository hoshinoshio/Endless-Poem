# A 模板场景与人物落地调整 · 2026-10-07

用户最新指示：使用 A 模板，取消宇宙星图设计，优化视觉，至少让主角看起来站在地面上。此前切换 C 的请求已撤销，已核对生产代码仍为 A。

## 当前已完成

- 默认主菜单保留 A 银白艺术字、五个按钮及既有功能。
- `scripts/ui/start_menu.gd` 撤下宇宙星图实例，改用 `scripts/ui/menu_environment.gd`。
- 新增独立背景 `assets/menu/night_terrace.png`：采用 A 样稿的深蓝星夜建筑、栏杆与连续石质平台，有可用于人物接地点的右侧前景地面。背景不含人物、文字或菜单。
- 取消当前菜单中的随机异常星与星图连线。独立旧星图源文件保留为历史资产，不在当前菜单引用。
- 删除整张半身人物的上下漂移，建筑和地面位置固定，仅保留极弱的环境照明变化。
- 默认入口 GPU 接入检查 26 项、0 失败；原菜单行为 headless 检查 PASS。检查确认新背景实际加载、无宇宙星图、按钮与返回流程和收藏保留正常。

## 尚未完成：人物落地

现有 `moonli_prayer_v1.png` 为腰部裁切半身像。只是更换背景还不能让它自然落地，本轮不据此宣称视觉目标已达成。

已向用户提出两个构图选项，当前等待答复：

1. 改为全身祈祷像，显示双脚，按地面透视加入接触阴影。
2. 保留半身构图，用前景石栏自然遮挡原图下缘，形成站在平台内侧的空间关系。

正面、闭眼、双手交握祈祷、月璃 v1 身份与服装、左菜单右人物的安排都保持。收到构图选择后再制作对应人物/前景资产并做最终实渲染验收。

## 文件与执行

- `gpt-6.1-sol`：菜单/环境接入、移除漂移、更新 `tests/start_menu_acceptance.gd`。
- `gpt-6-luna`：只读核对现有腰部裁切、A 样稿和验收约束，未改文件或运行 GPU。
- 主代理：使用内置 image_gen 制作独立背景、导入资源、更新 `tests/start_menu_render.gd` 并执行 GPU 检查。
- 背景完整提示与来源：`assets/menu/night_terrace_source.md`。
- 当前阶段截图：`docs/verification/grounded_start_menu_default.png`、`grounded_start_menu_small_window.png`。这两张是人物构图未处理完成的中间状态。
- 日志：`grounded_menu_headless_stdout.log`、`grounded_environment_render_stdout.log`、`grounded_menu_asset_import_stdout.log`。
