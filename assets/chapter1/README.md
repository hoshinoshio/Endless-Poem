# 首章正式战斗素材 · 2026-10-05

来源为用户选择的A「精细像素／旧铜星台」和指定月璃v1；使用内置image_gen制作。完整提示、源文件路径与重排说明在 generation_prompts.json。正式游戏只引用本工程内资源。

| 文件 | 用途 |
|---|---|
| observatory_courtyard.png | 不含人物和HUD的独立星台庭院背景，1586×992 RGB |
| moonli_authority_atlas.png | 月璃v1衍生动作图，去手持书；显示高度217 |
| patrol_guard_atlas.png | 教学与普通巡刻卫兵 |
| hour_guard_atlas.png | 精英整点卫兵，独立轮廓与重刺姿势 |
| brass_instrument_atlas.png | 黄铜星仪 |
| echo_observer_atlas.png | 回声观测员 |
| chronos_trial_atlas.png | 克洛诺斯试炼相，运行时水平翻转面向月璃 |
| time_anchor_atlas.png | 可被点击和击破的时间锚 |

各atlas为1254×1254 RGBA四姿势图，按待机、施放/攻击、受击、退场排列；原始横向_strip图仅保留生成来源和资源测试用途。所有姿势PNG均有真实alpha0透明像素。资源归一会过滤<=0.015的边缘alpha噪点，统一比例、画布和脚点。巡刻卫兵的跨格武器采用明确多边形裁切参数，不改绘PNG。

时间权柄、五道能量流、命中星屑、debuff图标为Godot代码原生表现，不烘焙进角色或背景。动作与FX由战斗时间驱动。

本版四个绘制姿势形成短动作序列，待机一帧；不是高帧数连续动画。七种遭遇目前复用该庭院场景。原始资料库与旧月璃v1原图保持不变。
