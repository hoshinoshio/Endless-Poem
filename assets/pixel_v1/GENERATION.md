# 像素动作资源与生成记录

更新日期：2026-10-10。用户已认可月璃样段的尺寸和动作方向，并授权继续扩展角色与怪物。全阵容现已接入正常游戏入口，`manifest.json` 的 `ready=true`；后续新增单位仍属于沿用已认可方向的实现，不表述为用户逐一审阅过每张图。

生成方式为内置 image_gen，透明背景。用户允许使用ComfyUI；本批没有使用ComfyUI生成，也没有修改或升级本机ComfyUI。原始图集由Godot按每个单位统一的 `source_scale` 规范到48×64透明帧，最近邻采样、固定脚点、整数显示倍数；不逐帧拉伸。Python工具仅分析原图及生成裁切/脚点元数据，不绘制或重绘像素。

| 单位 | 项目内原始图集 | 源动作帧 |
|---|---|---:|
| 月璃 | `moonli_locomotion_raw.png`、`moonli_actions_raw.png`、`moonli_combat_raw.png` | 48 |
| 巡刻卫兵 | `guard_raw.png` | 20 |
| 整点卫兵 | `elite_raw.png` | 20 |
| 克洛诺斯·试炼相 | `boss_raw.png` | 20 |
| 黄铜星仪 | `instrument_raw.png` | 20 |
| 回声观测员 | `observer_raw.png` | 20 |
| 时间锚 | `anchor_raw.png` | 20 |
| 暮笙 | `musheng_raw.png` | 20 |

总计188帧。月璃的前32帧沿用已认可样段，增加16帧施法、恢复、受击及退场。其余每套图集按20个完整姿势统一生成，再登记行走/悬浮、待机、蓄力、动作、恢复、受击、退场状态；暮笙单独使用对话帧，黄铜星仪与时间锚使用悬浮循环。暮笙与敌方回声观测员分别制作，未混用身份。

月璃基础图集的原始提示保留如下。其余已保存的原始提示在本目录的 `instrument_prompt.txt`、`observer_prompt.txt`、`anchor_prompt.txt`、`musheng_prompt.txt`、`hero_extra_prompt.txt` 和 `hero_extra_clean_prompt.txt`。卫兵、精英和Boss的逐字生成提示未另存为项目文件；对应原图和当前裁切配置均已保存，不以事后概述冒充原始提示。

`tools/map_pixel_roster.py` 登记七个扩展单位，`tools/merge_pixel_roster.py` 合并主角新增帧和全阵容清单。2026-10-10验收修正了部分主角帧底部越界一行的脚点元数据；最终GPU画面与完整检查见 `docs/pixel_full_acceptance_2026-10-10.md`。

## 行走与奔跑（16帧）

Production Godot PIXEL CHARACTER ANIMATION SHEET. Use ONLY the silver-haired girl in the TOP LEFT of the supplied reference as identity reference; do not include the guards, boss, or machine. Create 16 sequential frames of this same girl, in an EXACT regular 4 columns by 4 rows grid on a genuinely transparent background. Every cell equal size, one full body entirely inside each cell, clean padding. No labels, text, borders, scenery, shadow blobs or VFX. The character is a SMALL 3.5-head-tall 48x64-native-pixel platformer sprite, face to the RIGHT in SIDE VIEW. Simplify the source to crisp deliberate pixel clusters with about24 colors, strongly visible dark boots and separate legs, silver-white hair, aqua eyes, white/black outfit with concise gold trim. Keep same face, head scale, costume, silhouette, color placement, and body volume EVERY frame. Hair and coat tails are visibly animated with a small lag. No resizing, no smooth antialiasing, no blur. Every native pixel can be enlarged as a solid square. Feet share exactly the same ground baseline within each cell; pelvis stays about the same x, weight moves subtly with gait. 16 DISTINCT poses, not repeated static portraits. Frames are read left to right then next row. Frames1-8 (top TWO rows) = one complete natural WALK CYCLE: right foot front contact, body down/weight bearing, left foot passing, left heel rising, left foot front contact, opposite weight down, right foot passing, right heel rising; arms swing opposite legs with soft elbows, moderate 1pixel bob, loop back naturally. Frames9-16 (bottom TWO rows) = one full RUN CYCLE: same gait-phase alignment as walk; stronger forward lean, larger stride, bent knees, push-off then brief airborne phase, opposite contact then opposite push-off/flight; feet and knees never reverse anatomy, skirt does not hide the boots. Keep hair lag coherent; running does not change costume or head proportions. Animate the whole body naturally but retain authentic low-resolution pixel frame feel. This must work at actual 48x64 resolution. Leave enough horizontal margin for all strides. Deliver full complete sheet, all 16 frames visible.

## 待机与过渡（16帧）

Create the MATCHING ACTION-TRANSITION sheet for the exact silver-haired pixel girl shown in the supplied WALK/RUN sheet. 16 sprites in a perfectly regular 4 columns x 4 rows grid on genuine transparent alpha. Same side view facing RIGHT, same 3.5-head small pixel character, exact same body/head scale and black/white/gold outfit, aqua eye, silver-white hair and gold hair ornament. Same compact simplified pixel clusters; image is artwork for 48x64 game frame integration, no antialiasing, no backgrounds, no text, no borders, no magic book. Use equal fixed cell sizes and baseline; all cells same body height as first walking frames of reference, each sprite entirely inside own cell with margin. FULL BODY every cell, character at equal foot anchor. Arms have anatomically clear hands. Sixteen DISTINCT poses, read left to right row by row. Row1 (frames1-4): a quiet IDLE breathing loop, legs CLOSE TOGETHER AND STRAIGHT, right arm naturally DOWN ALONG HER SIDE with hand near thigh in ready posture, small shifts in hair/coat, zero walking stride, no arm stretching backwards. Row2: frames5-6 START walking, small first step/weight transfer into regular walk; frames7-8 STOP walking, trailing foot collects into close-legged upright idle, right arm settles down; don't leave legs wide. Row3: frames9-10 JUMP rise, slight crouch/push-off then compact rising pose with bent knees; frames11-12 FALL, hair floats upward, legs extend preparing ground contact. Row4: frames13-14 LAND, knees compress with weight then recover towards upright stance; frames15-16 TURN preparation/recovery, small body twist and gathering feet, still right-facing so engine mirrors at direction change. Maintain identical garment panels, accessories, head size across every frame. Every idle standing sole shares ground baseline; airborne poses may raise feet within the fixed canvas but do not change whole-sprite scale. The output must look like a coherent hand-authored animation set with restrained frame feel. No extra objects, labels or figures. Deliver all16 separated cells.

