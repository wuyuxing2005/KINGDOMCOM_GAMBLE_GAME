# 素材来源

## 原创生成素材

以下素材通过 OpenAI imagegen 内置流程以全新生成模式制作，没有使用参考图片，也没有从本地商业游戏资源中抽取文件。

### 木桌纹理

- 文件：`assets/textures/wood_table.png`
- 用途：俯视骰桌表面。
- 提示词：`historical-scene, top-down orthographic texture of an old medieval tavern wooden tabletop, broad horizontal dark walnut planks, richly visible grain, scratches, dents and uneven age stains, warm amber-brown palette, soft even diffuse lighting without a directional shadow, seamless-looking full-frame surface, photorealistic game texture, no objects, no dice, no hands, no cloth, no paper, no text, no symbols, no watermark, landscape 3:2 composition.`

### 羊皮纸面板

- 文件：`assets/ui/parchment_panel.png`
- 用途：九宫格拉伸的 HUD 与弹窗底板。
- 提示词：`historical-scene, single blank aged medieval parchment sheet centered and fully visible, wide horizontal rectangle, irregular torn deckled edges, warm ivory and ochre fibers, subtle stains and worn corners, front-facing orthographic view, perfectly flat, no folds casting outside shadows, no writing, no letters, no symbols, no border ornament, isolated on a perfectly uniform pure chroma key green #00ff00 background, crisp clean silhouette, 3:2 canvas.`
- 后处理：使用 imagegen 技能附带的 `remove_background.py` 去除纯绿色背景，并裁掉透明外边距。

### 应用图标

- 文件：`assets/icons/app_icon.png`
- 用途：Android 启动图标和 Godot 项目图标。
- 提示词：`logo-brand, square mobile game app icon, one chunky antique ivory six-sided die in three-quarter view with deeply carved dark pips, resting on dark walnut wood, encircled by a simple worn golden brass ring, subtle warm medieval tavern lighting, strong centered silhouette, painterly realistic game icon, rich brown ivory and muted gold palette, no text, no letters, no numbers except natural die pips, no crest, no crown, no trademark, no watermark, full bleed, 1:1.`

## 第三方字体

- 霞鹜文楷 v1.522：<https://github.com/lxgw/LxgwWenkai>
- 许可：SIL Open Font License 1.1，许可证副本为 `licenses/LXGW-WenKai-OFL-1.1.txt`。

## 用户提供的聊天表情

- 文件：`assets/chat/stickers/*.png`
- 用途：联机对局内置图片表情。
- 来源：用户在本任务中提供的六张图片，仅用于本项目测试版；不额外声明第三方授权。
- 处理：使用 imagegen 编辑流程将背景替换为键控色，去背后裁剪主体，最长边统一为 208 像素，并居中放入 256×256 透明 PNG 画布。
