# 待机与连续动作资源 · 2026-10-09

按 Game Studio sprite-pipeline 的同角色、比例稳定、透明度与引擎渲染检查流程制作，运行时保持 Godot 原生。

## 最终采用

- `neutral_idle_ready.png`：1024 × 1536 RGBA；双腿收近直立、右手自然向下的准备姿势。
- 内置 imagegen 编辑源为 `neutral_idle.png`。返回源文件 `C:\Users\hoshi\.codex\generated_images\01a0fc86-bc4d-7db1-be83-13a229f5d520\exec-451d5c99-7ac4-4721-ad08-9a7e0de351d3.png`，原样复制进本工程。
- alpha 只读抽样：四个轮廓外位置均为 0；Godot GPU 实渲染检查轮廓透明，无矩形背景。
- `continuous_rig.json` 指向最终 ready 图；脚点 [667,1457]、统一比例 .1501，约217世界像素高。
- 运行时采用分腿UV网格、两段骨骼与刚体鞋部变换；发梢、衣摆、腰部、手臂连续运动。不存在每帧重新生成图像。
- `neutral_idle_backreach.png` 是已撤销的向后伸手草案，没有被最终绑定引用。`neutral_idle.png` 是旧的前臂抬起种子。
- 未采用前面的行走/奔跑生成条带；本轮没有用Python修改PNG。Python仅检查尺寸/alpha；视频由Godot截图后用FFmpeg编码。

## 最终精确提示词（内置工具）

Edit the supplied transparent production 2D game character sprite, 1024x1536. ONLY change the near-side anatomical RIGHT arm pose. User correction: her RIGHT ARM MUST POINT DOWNWARD beside her body in an alert relaxed ready-to-act stance, NOT reach backward, NOT reach horizontally, NOT stretch out to image left. The near right shoulder stays around x565,y310, upper arm hangs vertically beside the left edge of her torso, elbow around x550,y530 lightly bent, forearm downward along her side, wrist around x572,y705, right hand at about x580,y755 beside her upper thigh. Fingers relaxed with a slight natural curl, ready to move, no weapon. Remove the original raised right hand currently at waist x765,y445 and the forearm crossing her torso; restore underlying embroidered waist costume. The far LEFT arm on image right remains exactly as it is, naturally hanging downward. Both arms near the sides of the body, no T-pose. Preserve EXACT same character, silver-white long hair, aqua eyes, black white gold costume, face, torso, hip, proportions, direction facing right, hair silhouette, skirt, CLOSE STRAIGHT LEGS and boot shape/placement. Keep unchanged all other pixels and exact framing, especially feet/legs for existing Godot skeleton binding. Both feet remain planted at original locations, no stride, no bent knees. Single full-body sprite only. Transparent background with alpha=0 outside silhouette, no fog/glow/backdrop/shadow, no text, no book or clock. Same original art style and 1024x1536 size.

