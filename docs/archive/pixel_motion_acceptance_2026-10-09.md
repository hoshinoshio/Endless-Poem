# 月璃像素动作样段验收 · 2026-10-09

> 历史样段记录：用户随后已采用本样段的尺寸与动作方向，并授权扩展角色和怪物。正常游戏现在启用全阵容像素表现，主角已由32帧扩展到48帧。本文保留当时数据；当前状态见 [2026-10-10全阵容验收](pixel_full_acceptance_2026-10-10.md)。

## 用户确认的动作标准

48×64 像素、约3–4头身。主角允许缩小；流畅指连贯的像素逐帧动画，保留适度帧感，每一步和动作切换自然。待机双腿靠拢、右手下垂准备行动。Shift 奔跑；玩法继续使用修复装置后获得停止时间、快进时间、倒退时间的规则。

## 本轮实际交付

- 工程仍位于 `C:\Users\hoshi\Endless Poem\endless-poem`。
- `scenes/previews/pixel_motion_preview.tscn` 是可操作样段，使用实际 ExplorationWorld / ExplorationPlayer 运动与碰撞；在 Godot 打开该场景按 F6 可运行。
- 32 张独立原始动作帧：待机4、行走8、奔跑8、起步2、收步2、起跳2、下落2、落地2、转身2。图集由内置 image_gen 生成，完整提示保存在 assets/pixel_v1/GENERATION.md。
- 全部按相同源缩放0.16规范为48×64 RGBA，最近邻3倍显示；实际人物约120像素高。非对称长发使用固定脚点[35,64]，源轮廓均位于帧内，没有按帧拉伸。
- walk/run共享步态相位，依据实际移动距离推进；按Shift不重置步态，受阻不持续踏步。起停、转向、落地使用各自过渡帧，输入仍直接影响物理。
- 下落拥有独立开始时刻；真实世界时间快照保存过渡名及过渡进度，回溯可以重采样正确帧。
- 默认manifest.ready仍为false，正常主菜单与正式探索继续使用此前形象；此样段用于用户视觉审阅。未获美术确认前不把样稿当作全部角色的最终资产。

## 验证证据

| 检查 | 结果 | 日志 |
|---|---|---|
| Godot4.7.2导入与依赖解析 | 通过 | pixel_import_verified_stdout.log |
| 既有像素运行器测试 | 13项通过 | pixel_actor_final_stdout.log |
| 新增动作衔接测试 | 17项通过 | pixel_continuity_final_stdout.log |
| 新增真实素材与世界快照测试 | 11项通过 | pixel_authored_assets_stdout.log |
| 新增GPU实机样段 | 10项通过 | pixel_motion_preview_fall_verified_stdout.log |
| 既有时间控制器 | 24项通过 | pixel_temporal_regression_stdout.log |
| 既有获权柄存档 | 17项通过 | pixel_store_regression_verified_stdout.log |
| 既有探索世界 | 26项通过 | pixel_world_regression_stdout.log |
| 本轮开始时91个已有测试及uid文件 | 0哈希变化 | pixel_motion_tests_after_2026-10-09.json |

最终渲染帧目录：`docs/verification/pixel_motion_frames_1791557603_92/`。视频：`docs/verification/pixel_motion_preview.mp4`，12秒、1440×900、30fps，360帧，由实际Godot场景输出；ffmpeg完整解码通过。帧表：`docs/verification/pixel_motion_contact_sheet.png`。影片展示实际模拟输入后的走跑、收步、跳跃、转身与暂停；不是人工逐帧控制角色位置的演示。

逻辑测试不能替用户判断步态是否好看、帧感是否合适。尺寸、样式和动作观感仍待用户审阅。攻击、施法、受击、倒下的像素动作，以及全部怪物、Boss、时间锚和暮笙的像素动画尚未在本轮主角样段中完成；既有地图、美术与战斗规则不计为新像素验收。

## ComfyUI

用户已授权用于必要素材。实时检查本机RTX5060Ti约16GB显存；ComfyUI选定目录`C:\Users\hoshi\ComfyUI\ComfyUI_windows_portable\ComfyUI`，服务未运行。发现Krea2 Turbo、newbieImage等模型文件，但没有找到已保存的一致性像素角色工作流。core0.36.0，工具报告最新0.39.2。未升级、安装、下载或启动服务；本轮32帧不是ComfyUI生成。后续使用前须验证具体工作流，而不能仅从模型文件名断言风格能力。

## 实际分工

- gpt-6.1-sol：像素动作运行器与运动衔接；另一个Sol：独立可操作预览及GPU渲染。
- gpt-6-luna：动作标准、角色资源盘点、既有测试哈希、ComfyUI只读盘点。
- 主代理：素材生成、统一帧与脚点、世界快照集成、解析问题修复、下落计时修复、真实素材检查与最终审阅。工具不提供主代理实际模型标识。
