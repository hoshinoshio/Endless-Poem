# 持续演变与随机异常星图 · 2026-10-06

后续集成已完成：用户选择 A 银白样式后，该背景已接入默认主界面。运行项目 F5 即可看到新菜单；下文保留独立背景预览阶段记录，最新验证见 `../../docs/start_menu_integration_2026-10-06.md`。

用户已确认：背景持续缓慢演变，不按现实早晚切换；星星需要随机、不固定的异常变化，例如变红或变得怪异。本轮完成独立 Godot 背景动态预览，尚未将其接入正式启动菜单。三种旧主题图里的建筑背景均已被该要求替代；标题和按钮样式仍待用户选择。

## 交付

- `cosmic_star_map_preview.gif`：24 秒、360 帧、15 fps、960×600、1,924,585 字节，由真实 1440×900 GPU 帧编码。GIF 是一次随机运行的循环展示，不代表游戏采用固定动画循环。
- `预览宇宙星图.cmd`：打开独立实时预览。每次启动重新随机主星分布与异常序列；关闭窗口退出预览。
- Godot 场景：`res://scenes/previews/cosmic_star_map.tscn`。可在编辑器打开该场景后按 F6。

## 当前效果

- 260 个有深度差异的主星，加 1500 个细密远星尘；低亮青蓝、深紫薄雾及暗尘带，少量星图连线和弧线。星点缓慢漂移，薄雾持续演变。
- 异常目标、发生间隔、类型、相位与持续时间由运行时随机数产生。首次约等待 2.5–4.5 秒，后续间隔 4–8 秒，持续 9–18 秒，同时最多 3 颗异常星。
- 暗红异常：星点逐渐变红，伴随局部红色柔光，再恢复原色。
- 明暗异常：慢速、不规则起伏，逐渐进入和结束。
- 形态异常：轻微偏心的双重星芒和不规则八向轮廓，局部呈紫色。用于当前“怪异程度”评审，未扩展成新角色或剧情设定。
- 左侧标题区域与右侧人脸区域的星云亮度受到抑制，为后续叠加 UI 和主角留出可读性。

录制按 1/15 秒推进同一 `advance(delta)` 时钟，未覆盖随机种子或强制触发某种异常。正式自动更新使用同一逻辑；shader 由 elapsed uniform 驱动，与星点和异常保持同一时间。录制只检查视觉与行为，不作为实机帧率性能测试。

本次随机录制中，约 3.93 秒开始一颗红星变化，约 9.13 秒出现偏心星芒，约 14.67 秒出现不规则明暗。红星在约 17.89 秒结束并恢复。这些时间是该次采样的记录，不是固定脚本。

## 验证与模型分工

- `gpt-6.1-sol` 实现背景、预览场景、shader 与行为检查；主代理检查随机逻辑，执行 GPU 渲染并目视检查普通状态、红星及异常星芒。
- `gpt-6-luna` 两次调用均返回容量不足，没有完成本轮独立审查；主代理接手，未将其记为通过。
- Headless 行为验收 PASS：不同种子的主星和事件序列不同，异常目标/类型/时长有变化，事件结束，上限受控，亮度平滑，返回快照不改变内部数据。
- 最终实际 GPU 验证 7 项检查全部通过，360 帧中观察到三种异常及自然结束。Godot 4.7.2 Compatibility/OpenGL，NVIDIA GeForce RTX 5060 Ti。行为与渲染两份 stderr 日志均为空。
- 源码检查确认正式 `_ready()` 调用 `RandomNumberGenerator.randomize()`；固定 seed 只由显式测试接口设置；录制没有调用该接口。

证据均在项目 `docs/verification/`：`cosmic_star_map_acceptance_stdout.log`、`cosmic_star_map_render_stdout.log`、`cosmic_star_map_render_evidence.json`、`cosmic_star_map_frames/`、`cosmic_star_map_idle.png`、`cosmic_star_map_dark_red.png`、`cosmic_star_map_asymmetric_rays.png`。

## 文件范围

- `scripts/ui/cosmic_star_map.gd`
- `shaders/cosmic_star_map.gdshader`
- `scenes/previews/cosmic_star_map.tscn`
- `tests/cosmic_star_map_acceptance.gd`
- `tests/cosmic_star_map_render.gd`
- 本评审目录及自动生成的验证证据。

未修改 `scripts/ui/main.gd`、游戏启动入口、战斗和存档逻辑。完整主菜单仍需确定标题/按钮样式，制作独立祈祷半身素材，再接入五个按钮；本轮背景效果不代表整套主菜单已经完成。
