# BigWuXia — 美术流水线文档

本文档定义 BigWuXia 的美术资产管理流程，包括 Tiny Swords 素材审计清单、角色↔sprite 映射表、UI 武侠化方案、缺口清单、以及 AI 生成规格。

## 1. Tiny Swords 素材审计

### 1.1 素材来源

- **Pack 名称**: Tiny Swords (Free Pack)
- **绝对路径**: `/Users/xiaochunliu/Downloads/Tiny Swords (Free Pack)/`
- **包含内容**: Buildings / Particle FX / Terrain / UI Elements / Units
- **总文件数**: 410 张 PNG
- **风格**: 欧洲中世纪 / 像素艺术 / 五色系变体（Black/Blue/Purple/Red/Yellow）
- **授权**: 免费商用（https://pixelfrog-assets.itch.io/tiny-swords）

### 1.2 目录结构速览

```
Tiny Swords (Free Pack)/
├─ Buildings/              # 建筑（城堡/塔/兵营/房屋/寺院）
│  ├─ Black Buildings/     # 黑色系（8 个建筑 × 5 色系 = 40）
│  ├─ Blue Buildings/
│  ├─ Purple Buildings/
│  ├─ Red Buildings/
│  └─ Yellow Buildings/
├─ Particle FX/            # 粒子特效（灰尘/爆炸/火焰/水花，11 张）
│  ├─ Dust_01.png / Dust_02.png
│  ├─ Explosion_01.png / Explosion_02.png
│  ├─ Fire_01/02/03.png
│  └─ Water Splash.png
├─ Terrain/                # 地形（Tileset + 装饰 + 资源）
│  ├─ Tileset/             # 5 色系 tilemap（576×384）+ 水/阴影
│  │  ├─ Tilemap_color1~5.png
│  │  ├─ Water Background color.png
│  │  ├─ Water Foam.png
│  │  └─ Shadow.png
│  ├─ Decorations/         # 装饰（灌木/云/石头/橡皮鸭）
│  └─ Resources/           # 资源（金矿/羊/树/工具）
├─ UI Elements/            # UI 元素（按钮/血条/头像/光标/羊皮纸）
│  ├─ UI Banners from the store page/  # 旗帜/丝带
│  └─ UI Elements/
│     ├─ Banners/          # Banner.png + Slots
│     ├─ Bars/             # BigBar / SmallBar（Base + Fill）
│     ├─ Buttons/          # Blue/Red 按钮（Big/Small/Tiny，Regular/Pressed）
│     ├─ Cursors/          # 4 种光标
│     ├─ Human Avatars/    # 25 张人脸头像（256×256）
│     ├─ Icons/            # 12 个图标（64×64）
│     ├─ Papers/           # 羊皮纸（Regular/Special）
│     ├─ Ribbons/          # 丝带（Big/Small）
│     ├─ Swords/           # 剑图标
│     └─ Wood Table/       # 木桌/槽位
└─ Units/                  # 单位（5 色系 × 5 职业 = 25 套）
   ├─ Black Units/
   │  ├─ Archer/           # 弓箭手（Idle/Run/Shoot + Arrow）
   │  ├─ Lancer/           # 长枪兵（8 方向攻击/防御）
   │  ├─ Monk/             # 僧侣（Idle/Run/Heal + Heal_Effect）
   │  ├─ Pawn/             # 工人（各种工具 Idle/Run/Interact）
   │  └─ Warrior/          # 战士（Idle/Run/Attack1/Attack2/Guard）
   ├─ Blue Units/
   ├─ Purple Units/
   ├─ Red Units/
   └─ Yellow Units/
```

### 1.3 关键素材尺寸速查

| 素材类型 | 分辨率 | 帧结构 | 备注 |
|---|---|---|---|
| Tilemap（地形）| 576×384 | 9×6 tiles（64×64/tile） | 5 色系变体 |
| Warrior sprite | 1536×192 / 768×192 / 1152×192 | 横向 spritesheet，192×192/帧 | Idle 8f / Run 6f / Attack 4f / Guard 6f |
| Monk sprite | 1152×192 / 768×192 / 2112×192 | 同上 | Idle 6f / Run 4f / Heal 11f |
| Archer sprite | 1152×192 / 768×192 / 1536×192 | 同上 | Idle 6f / Run 4f / Shoot 8f；Arrow 单独 64×64 |
| Lancer sprite | 3840×320 | 20 帧，8 方向攻击/防御 | **复杂**，MVP 不用 |
| Pawn sprite | 1536×192 + 变体 | 工人（各种工具）| MVP 不用 |
| UI 按钮 | 320×320（Big）/ 64×64（Small） | 单帧 | Regular/Pressed 两态 |
| 血条 | 320×64 | Base + Fill 两层 | Big/Small 两种 |
| 头像 | 256×256 | 25 种（人脸） | 可做角色立绘占位 |
| 羊皮纸 | 320×320 | Regular/Special | UI 背景框 |

## 2. 角色 ↔ Sprite 映射表

BigWuXia 的 3 个可玩角色和敌方单位全部映射到 Tiny Swords Units 素材。

### 2.1 玩家角色映射

| 角色 | Sprite 来源 | 色系 | 动画映射 | 备注 |
|---|---|---|---|---|
| **徐凤年** | `Units/Blue Units/Warrior/` | 蓝色（玩家主色） | Idle: `Warrior_Idle.png` (8f)<br>Run: `Warrior_Run.png` (6f)<br>Attack: `Warrior_Attack1.png` (4f)<br>Skill（两袖青蛇）: `Warrior_Attack2.png` (4f)<br>Death: 自定义（fade out） | 刀客形象，近战主 T |
| **姜泥** | `Units/Blue Units/Monk/` | 蓝色 | Idle: `Monk/Idle.png` (6f)<br>Run: `Monk/Run.png` (4f)<br>Heal: `Monk/Heal.png` + `Heal_Effect.png` (11f)<br>Skill（轻功）: `Run.png` 快速播放 + 残影<br>Death: fade out | 僧侣改为女性轻功形象（MVP 无法改，后期 AI 替换） |
| **李淳罡** | `Units/Purple Units/Warrior/` | **紫色**（区别于徐凤年） | Idle: `Warrior_Idle.png` (8f)<br>Run: `Warrior_Run.png` (6f)<br>Attack: `Warrior_Attack1.png` (4f)<br>Skill（剑气）: `Warrior_Attack2.png` (4f) + 剑气粒子<br>Ultimate（剑开天门）: `Warrior_Attack2.png` 慢放 + 大 AOE 特效<br>Death: fade out | 剑客形象，紫色做区分 |

**重要**: 徐凤年和李淳罡都用 Warrior sprite（动作完全一致），MVP 靠**颜色**区分（Blue vs Purple）；长期需 AI 重绘立绘。

### 2.2 敌方单位映射

| 敌方单位 | Sprite 来源 | 色系 | 动画映射 | 备注 |
|---|---|---|---|---|
| **普通兵（近战）** | `Units/Red Units/Warrior/` | **红色**（敌方主色） | Idle/Run/Attack1 | 低血量低攻击（HP 15 ATK 5） |
| **弓箭手** | `Units/Red Units/Archer/` | 红色 | Idle/Run/Shoot + Arrow.png | 远程单位（range 2-3） |
| **BOSS（黑甲武将）** | `Units/Black Units/Warrior/` | **黑色**（精英色） | Idle/Run/Attack1/Attack2 + 技能 | 高血量高攻击（HP 35 ATK 10） |
| **友军/中立** | `Units/Yellow Units/Warrior/` | 黄色 | （MVP 不用，后续版本） | 预留 |

**阵营配色方案**：
- 玩家: Blue
- 敌方普通兵: Red
- 敌方精英/BOSS: Black
- 友军/中立: Yellow
- 特殊角色（李淳罡）: Purple

## 3. 地形素材使用

### 3.1 TileMapLayer 源图

**选用**: `Terrain/Tileset/Tilemap_color1.png`（绿色春草，最通用）

- **分辨率**: 576×384（9×6 tiles，每 tile 64×64）
- **包含地形**:
  - 平地（绿色草地，多变体）
  - 路（土路/石板路）
  - 水域（蓝色，需配合 Water Foam.png 做动画）
  - 山/石（灰色，做障碍物）
  - 沙地/枯草（边缘地形）

**导入 Godot 配置**:
- Import 为 TileSet
- Tile Size: 64×64
- Autotile: 启用（自动边缘拼接）

**地形类型 → Tile ID 映射**（具体 tile 坐标在 Sprint 2 实施时确定）:

| 地形类型 | TileData ID | Tilemap 区域（估算） | 移动消耗 | 闪避加成 |
|---|---|---|---|---|
| 平地（Grass） | `grass` | 绿色草地区域 | 1.0 | 0 |
| 草丛（Bush） | `bush` | 深绿草丛（用 Decorations/Bushes/ 叠加） | 1.0 | +10% |
| 林地（Forest） | `forest` | 深绿 + 树装饰（Trees/） | 2.0 | +20% |
| 山地（Mountain） | `mountain` | 灰色石头区域 | ∞ | — |
| 水域（Water） | `water` | 蓝色区域 | ∞ | — |
| 路（Road） | `road` | 土路/石板路区域 | 0.5 | 0 |

**装饰物叠加**（TileMapLayer 上方用 Sprite2D/StaticBody2D 放置）:
- 树: `Terrain/Resources/Wood/Trees/Tree1~4.png`
- 灌木: `Terrain/Decorations/Bushes/Bushe1~4.png`
- 石头: `Terrain/Decorations/Rocks/Rock1~4.png`
- 云: `Terrain/Decorations/Clouds/Clouds_01~08.png`（背景层，视差滚动）

### 3.2 地形动画（水面）

水域需要动画效果（波浪）：
- 用 `Water Background color.png` 做底层
- 用 `Water Foam.png` 做动画覆盖层（AnimatedSprite2D，循环播放）

**实现方式**（Sprint 2）:
1. TileMapLayer 渲染静态水域底色
2. 在水域上方放 AnimatedSprite2D 节点，播放 Foam 动画（4-6 帧循环）

## 4. UI 武侠化方案

### 4.1 目标风格

BigWuXia 的 UI 需要从"欧式中世纪"向"中式武侠"转换，策略是：

> **MVP 用原 Tiny Swords sprite + 武侠 UI 框（羊皮纸/毛笔字/山水底），角色立绘后期 AI 生成替换**

### 4.2 UI 元素映射

| UI 元素 | Tiny Swords 素材 | 武侠化处理 | 优先级 |
|---|---|---|---|
| **主菜单背景** | — | AI 生成：雪山/北凉城/水墨山水 | S1 |
| **按钮** | `UI Elements/Buttons/BigBlueButton_Regular.png` | 保留 + 换毛笔字体（"开始游戏"/"教程"/"退出"） | S1 |
| **角色卡片背景** | `UI Elements/Papers/RegularPaper.png` | 羊皮纸直接用（古风兼容） | S1 |
| **战斗 UI 背景** | `UI Elements/Wood Table/WoodTable.png` | 木质背景（古风兼容） | S3 |
| **血条** | `UI Elements/Bars/SmallBar_Base.png` + `SmallBar_Fill.png` | 保留（通用） | S3 |
| **角色头像** | `UI Elements/Human Avatars/Avatars_01~25.png` | **MVP 占位**；S6 用 AI 生成徐凤年/姜泥/李淳罡立绘替换 | S1（占位）、S6（替换） |
| **技能图标** | `UI Elements/Icons/Icon_01~12.png` | **MVP 占位**；S6 用 AI 生成刀/剑/治疗图标 | S4（占位）、S6（替换） |
| **光标** | `UI Elements/Cursors/Cursor_01.png` | 可选替换为毛笔笔头光标 | S6（polish） |
| **胜利/失败界面** | `UI Elements/Papers/SpecialPaper.png` | 羊皮纸 + 毛笔字"胜利"/"失败" | S5 |

### 4.3 字体方案

**目标**: 武侠风需要书法/宋体，避免无衬线现代字体。

| 字体用途 | 字体选择 | 授权 | 文件路径（导入后） |
|---|---|---|---|
| 主标题（"雪中悍刀行"） | **思源宋体 Heavy**（Noto Serif CJK SC Heavy） | 免费商用（SIL OFL 1.1） | `resources/fonts/noto_serif_cjk_heavy.ttf` |
| UI 正文（按钮/面板） | **思源宋体 Regular** | 同上 | `resources/fonts/noto_serif_cjk_regular.ttf` |
| 伤害浮字 | **思源宋体 Bold** | 同上 | `resources/fonts/noto_serif_cjk_bold.ttf` |

**下载链接**: https://github.com/adobe-fonts/source-han-serif/releases

**Godot 配置**:
- Import 为 `FontFile`
- MSDF（Multi-channel Signed Distance Field）启用（缩放不模糊）
- Oversampling: 2.0（提高清晰度）

### 4.4 UI 布局风格

- **主菜单**: 山水背景 + 大标题（思源宋体 Heavy 72pt）+ 羊皮纸按钮
- **战斗 UI**: 木质边框 + 羊皮纸信息面板 + 思源宋体正文
- **伤害浮字**: 思源宋体 Bold + 描边（黑色外描边 2px）+ 动画（向上飘 + fade out）

## 5. 缺口清单（需 AI 生成素材）

Tiny Swords 素材无法直接满足武侠风的部分：

### 5.1 背景资产

| 资产 | 规格 | 用途 | 生成方式 | 优先级 |
|---|---|---|---|---|
| **主菜单背景** | 1366×768 | MainMenu 背景 | MidJourney/Stable Diffusion：雪山/北凉城/水墨山水 | S1 |
| **战斗场景背景** | 1366×768 | Battle 远景层 | 同上：江湖道路/山林/城墙 | S2 |
| **胜利界面背景** | 1366×768 | Victory 背景 | 同上：庆祝/夕阳 | S5 |

**Prompt 示例**（MidJourney）:
```
A snowy mountain landscape in the style of Chinese ink painting, 
ancient northern city walls in the distance, 
warm sunset light, cinematic widescreen 16:9, 
high detail, inspired by Snow Sword Stride (雪中悍刀行)
```

### 5.2 角色立绘（后期替换）

| 角色 | 规格 | 用途 | 生成方式 | 优先级 |
|---|---|---|---|---|
| **徐凤年立绘** | 512×512 | 头像 + 角色卡片 | Stable Diffusion：年轻男性，持刀，北凉世子服饰 | S6 |
| **姜泥立绘** | 512×512 | 头像 + 角色卡片 | Stable Diffusion：少女，轻功姿态，白衣 | S6 |
| **李淳罡立绘** | 512×512 | 头像 + 角色卡片 | Stable Diffusion：老年剑客，仙风道骨，紫衣 | S6 |

**Prompt 示例**（Stable Diffusion）:
```
Portrait of a young Chinese nobleman in ancient armor, 
holding a blade sword, confident expression, 
northern Liang dynasty style, 
anime art style, clean background, 512x512
```

### 5.3 技能特效（粒子/sprite）

| 特效 | 规格 | 用途 | 生成方式 | 优先级 |
|---|---|---|---|---|
| **刀气** | 256×256（spritesheet 4-6 帧） | 徐凤年"两袖青蛇" | Tiny Swords `Particle FX/Explosion_01.png` 改色 + AI 生成刀光 | S4 |
| **剑气** | 256×256（spritesheet 4-6 帧） | 李淳罡"剑气·如雷" | 同上，改为蓝色剑光 | S4 |
| **剑开天门（大招）** | 512×512（spritesheet 8 帧） | 李淳罡终极技能 | AI 生成：十字剑气爆炸 + Tiny Swords Fire/Explosion 拼装 | S5 |
| **治疗光效** | 128×128（spritesheet 4 帧） | 姜泥"回春术" | Tiny Swords `Monk/Heal_Effect.png` 改色（绿 → 金） | S4 |
| **轻功残影** | 192×192（4 帧） | 姜泥"轻功·掠影" | 角色 sprite 半透明拖尾 + 粒子 | S5 |

**拼装策略**（优先于 AI 生成）:
1. 复用 Tiny Swords `Particle FX/` 的 Fire/Explosion，改色（蓝/金/紫）
2. 叠加到角色 sprite 上做混合模式（Additive）
3. 只有"剑开天门"这种大招需要 AI 生成独立特效

### 5.4 音效/音乐（MVP 后期，S6）

| 资产 | 规格 | 用途 | 来源 | 优先级 |
|---|---|---|---|---|
| **主菜单 BGM** | .ogg 循环 | MainMenu 背景音乐 | freesound.org / YouTube Audio Library：古风/古琴 | S6 |
| **战斗 BGM** | .ogg 循环 | Battle 背景音乐 | 同上：紧张武侠配乐 | S6 |
| **攻击音效** | .wav | 普攻/技能 | freesound.org：刀剑碰撞/剑气 | S6 |
| **治疗音效** | .wav | 姜泥治疗 | freesound.org：钟声/清脆音 | S6 |
| **UI 点击音** | .wav | 按钮点击 | freesound.org：竹简展开 | S6 |

**授权注意**: 所有音效必须是 CC0 或免费商用授权。

## 6. 素材导入流程（Godot）

### 6.1 导入 Tiny Swords 素材

**步骤**（Sprint 1-2）:
1. 在项目根目录创建 `resources/sprites/` 目录
2. 从 `/Users/xiaochunliu/Downloads/Tiny Swords (Free Pack)/` **拷贝**（不是引用）以下素材到项目：
   - `Units/Blue Units/Warrior/` → `resources/sprites/units/blue_warrior/`
   - `Units/Blue Units/Monk/` → `resources/sprites/units/blue_monk/`
   - `Units/Purple Units/Warrior/` → `resources/sprites/units/purple_warrior/`
   - `Units/Red Units/Warrior/` → `resources/sprites/units/red_warrior/`
   - `Units/Red Units/Archer/` → `resources/sprites/units/red_archer/`
   - `Units/Black Units/Warrior/` → `resources/sprites/units/black_warrior/`
   - `Terrain/Tileset/Tilemap_color1.png` → `resources/sprites/terrain/`
   - `UI Elements/` 整个目录 → `resources/sprites/ui/`
   - `Particle FX/` 整个目录 → `resources/sprites/vfx/`
3. 打开 Godot 编辑器，等待自动 import（`.import` 文件生成）
4. 检查 import 配置：
   - **Sprite sheets**: Filter = Nearest（像素艺术）, Mipmaps = Off
   - **TileSet**: 自动识别 64×64 tile

### 6.2 创建 SpriteFrames（AnimatedSprite2D）

**步骤**（Sprint 3）:
1. 在 Godot 编辑器中，创建 `AnimatedSprite2D` 节点
2. 点击 `SpriteFrames` → `New SpriteFrames`
3. 添加动画：
   - `idle`: 导入 `Warrior_Idle.png`，Hframes = 8，FPS = 8
   - `run`: 导入 `Warrior_Run.png`，Hframes = 6，FPS = 12
   - `attack`: 导入 `Warrior_Attack1.png`，Hframes = 4，FPS = 10
   - `skill`: 导入 `Warrior_Attack2.png`，Hframes = 4，FPS = 10
   - `death`: 自定义（fade out Tween，不用 sprite）
4. 保存为 `.tres`：`resources/data/units/warrior_sprite_frames.tres`
5. 徐凤年/李淳罡/敌方普通兵共用此 SpriteFrames（只改 modulate 颜色）

**注意**: Monk sprite 帧数不同，需单独创建 `monk_sprite_frames.tres`。

### 6.3 TileSet 配置

**步骤**（Sprint 2）:
1. 创建 `TileMapLayer` 节点
2. 在 Inspector 中，`Tile Set` → `New TileSet`
3. 添加图集：
   - 源图: `resources/sprites/terrain/tilemap_color1.png`
   - Texture Region: 整个图（576×384）
   - Tile Size: 64×64
4. 在 TileSet 编辑器中：
   - Physics Layer: 添加 1 层（用于碰撞，可选）
   - Custom Data Layer: 添加 `tile_id`（String）字段
   - 逐个 tile 设置 `tile_id`（例如 tile (0,0) = "grass"）
5. 保存为 `.tres`：`resources/data/terrain/main_tileset.tres`

**GridSystem 集成**:
- TileMapLayer 只负责**视觉渲染**
- GridSystem 脚本独立管理 `Dictionary[Vector2i → TileData]`（逻辑网格）
- 在关卡加载时，读取 TileMapLayer 的 `tile_id` 自定义数据，填充 GridSystem

## 7. 美术资产清单（按 Sprint 分配）

| Sprint | 需要的资产 | 来源 | 状态 |
|---|---|---|---|
| S1 | 主菜单背景、按钮、字体、角色头像占位 | AI 生成背景 + Tiny Swords UI + 思源宋体 | S1 实施时准备 |
| S2 | TileSet（地形）、装饰物 | Tiny Swords Terrain/ | 已有 |
| S3 | 角色 sprite（3 玩家 + 2-3 敌方）、血条 | Tiny Swords Units/ + UI Bars/ | 已有 |
| S4 | 技能图标占位、基础粒子特效（刀气/剑气/治疗） | Tiny Swords Icons + Particle FX 改色 | 已有（改色在 S4） |
| S5 | 大招特效（剑开天门）、胜利/失败背景 | AI 生成 + Tiny Swords 拼装 | S5 准备 |
| S6 | 角色立绘（徐凤年/姜泥/李淳罡）、音效/BGM | AI 生成 + freesound.org | S6 polish |

## 8. AI 生成素材规范

### 8.1 背景图生成

**工具**: MidJourney v6 或 Stable Diffusion XL

**规格**:
- 分辨率: 1366×768（16:9）
- 风格: 中国水墨画 / 古风 / 雪中悍刀行 IP 风格
- 输出格式: PNG（无损）

**Prompt 模板**:
```
[场景描述] in the style of Chinese ink painting, 
[具体元素（雪山/城墙/江湖）], 
warm/cold color tone, cinematic widescreen 16:9, 
high detail, inspired by Snow Sword Stride (雪中悍刀行),
--ar 16:9 --v 6
```

### 8.2 角色立绘生成

**工具**: Stable Diffusion + ControlNet（人物控制）

**规格**:
- 分辨率: 512×512
- 风格: 半写实 anime art style
- 输出格式: PNG 带透明背景（抠图）

**Prompt 模板**:
```
Portrait of [角色描述：young nobleman / elderly swordsman / teenage girl], 
Chinese ancient [服饰：armor / white robe / purple robe], 
[持物：holding blade / sword / empty hands], 
[表情：confident / serene / fierce] expression, 
[朝代风格：Tang dynasty / northern Liang style], 
anime art style, clean background, 512x512,
--no background, transparent PNG
```

### 8.3 粒子特效生成

**工具**: Aseprite（像素艺术）或 Stable Diffusion（spritesheet 生成）

**规格**:
- 分辨率: 256×256（单帧）或 1024×256（4 帧横向 spritesheet）
- 风格: 像素艺术（匹配 Tiny Swords）
- 输出格式: PNG 带透明背景

**Prompt 模板**（Stable Diffusion）:
```
Pixel art sprite sheet of [特效描述：sword slash / blade aura / healing light], 
4 frames animation, horizontal layout, 
[颜色：blue / purple / golden] color, 
transparent background, 256x256 per frame,
pixel art style, retro game
```

## 9. 版权与授权

### 9.1 Tiny Swords 素材授权

- **授权**: 免费商用（Free for commercial use）
- **来源**: https://pixelfrog-assets.itch.io/tiny-swords
- **要求**: 建议在游戏 Credits 中注明 "Tiny Swords by Pixel Frog"

### 9.2 思源宋体授权

- **授权**: SIL Open Font License 1.1（免费商用）
- **来源**: https://github.com/adobe-fonts/source-han-serif
- **要求**: 无需署名（但建议在 Credits 中注明）

### 9.3 AI 生成素材授权

- **MidJourney**: 付费订阅后拥有商用权
- **Stable Diffusion**: 开源模型，生成图像无版权限制（注意训练数据授权）
- **freesound.org**: 选择 CC0 或 CC-BY 授权音效

## 10. 美术资产验收标准

每个 Sprint 完成后，需验收美术资产是否符合要求：

| 验收项 | 标准 | 验收方式 |
|---|---|---|
| **分辨率** | 符合规格表（64×64 tile / 192×192 sprite / 1366×768 背景） | 用 `file` 命令检查 PNG 分辨率 |
| **透明背景** | 角色 sprite / UI 元素 / 特效必须带 alpha 通道 | 用 Godot 导入检查（是否有透明区） |
| **帧数/布局** | Spritesheet 横向排列，帧数符合设计（Idle 8f / Run 6f） | 在 Godot AnimatedSprite2D 中预览 |
| **风格一致性** | AI 生成素材与 Tiny Swords 风格兼容（色调/像素密度） | 截图放在一起对比 |
| **文件命名** | snake_case，无空格，有语义（`xu_fengnian_portrait.png`） | 人工检查 |
| **授权清晰** | 所有外部素材有明确授权（CC0 / 商用许可） | 记录在 `docs/design/CREDITS.md`（MVP 后期） |

---

**下一步**：阅读 [04-tech-stack.md](./04-tech-stack.md) 了解技术栈选型和实现思路。
