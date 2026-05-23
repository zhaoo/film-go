# Film Go 设计方案

> 日期：2026-05-23
> 状态：Draft，待用户审阅
> 作者：兆兆 + Claude

---

## 一、产品定位

**Film Go** 是一款"陪你拍完一卷胶卷"的辅助工具。它不是滤镜美化类 App，定位是解决胶卷拍摄全流程中真实存在的计算与记忆负担：测光 → 对焦 → 曝光补偿 → 拍摄记录 → 冲洗参数。

- **目标用户**：胶卷新手与进阶玩家兼顾，UI 默认极简，进阶功能折叠在二级菜单
- **核心价值主张**：*"Trust your film. Let the app do the math."*
- **关键差异化**：黑白暗房美学、双端原生桌面小部件、专注胶卷流程而不做胶片滤镜
- **平台**：iOS 15+ / Android 8+（含小米 MIUI 13+ / HyperOS 1+ / 2）
- **数据策略**：纯本地存储 + 导出，1.0 不做账号与云同步

---

## 二、信息架构

5 个一级 Tab，底部导航。所有图标均为 1.5pt 黑白线性。

```
Film Go
├─ ① 取景 (Meter)        — 默认首屏，相机取景测光
├─ ② 计算 (Calc)         — 景深 / 超焦距 / 滤镜 / 互易律 / Sunny 16
├─ ③ 胶卷 (Rolls)        — Film Log 列表与当前在拍卷
├─ ④ 暗房 (Darkroom)     — 冲洗计时器与显影配方
└─ ⑤ 我的 (Me)           — 设备库 / 胶卷库 / 数据导出 / 设置
```

测光是高频入口，置于第 1 位。每个 Tab 内可向下钻取至详情页与设置页。

---

## 三、功能模块（1.0 MVP）

### 3.1 测光 Meter

| 子功能 | 说明 |
|---|---|
| 取景实时测光 | 调用相机预览帧，取 YUV 平均亮度，转 EV |
| 测光模式 | 点测（手指点选区域 5%）/ 中央重点（中心 25%，边缘加权 75%）/ 平均 |
| 传感器测光 | 调用 `light` 插件读取 ALS（仅 Android 部分机型），iOS 与无 ALS 设备入口禁用 |
| 手动 EV 输入 | 直接输入 EV 数值，跳过相机/传感器 |
| 锁定与组合推荐 | 锁定 EV 后，按当前胶卷 ISO 输出多组光圈/快门组合（半挡/三分挡可切） |
| 互易律联动 | 推荐快门 > 1s 时自动按胶卷曲线补偿 |
| 滤镜补偿联动 | 已启用滤镜时，最终建议含补偿值并显示来源 |

**算法基线**
- 亮度 → EV：`EV = log2(L · K / (ISO · S))`，K=12.5（反射光测光常数），S 取自相机 sensor metadata，缺省时校准
- 校准流程：首次进入 Meter 页提供"用已知 EV 校准"流程（用户在已知光照场景手动输入参考 EV，存入设备 profile）
- 帧处理：在 isolate 内做下采样（160×120）+ 亮度均值，避免主线程卡顿

### 3.2 景深 DoF

输入：画幅（135 / 120 6×6 / 120 6×7 / 4×5 自定义）、焦距、光圈、对焦距离
输出：近景 / 远景 / 景深范围 / 超焦距

公式（Wikipedia 标准 DOF，H 含 +f 修正项）：
```
H  = f² / (N · c) + f                 // 超焦距
Dn = d · (H − f) / (H + d − 2f)       // 近景
Df = d · (H − f) / (H − d)            // 远景，d ≥ H 时为 ∞
```
- `c` 弥散圆默认按画幅查表，可自定义
- 与 Meter 同屏联动：在 Meter 页右上角浮窗显示当前对焦距离对应的景深范围

### 3.3 胶卷库 Film DB

内置 60+ 常见胶卷条目，含：型号 / 品牌 / ISO / 类型（彩负 / 彩正 / 黑白 / 电影卷）/ 宽容度 / 推拉范围 / 互易律曲线 / 显影建议。

数据来源：Kodak / Fuji / Ilford / Cinestill 官方 datasheet。结构定义：

```json
{
  "id": "kodak-portra-400",
  "name": "Portra 400",
  "brand": "Kodak",
  "iso": 400,
  "type": "color_negative",
  "latitudeStops": [-2, 3],
  "pushPullRange": [-1, 2],
  "reciprocityCurve": [
    { "metered": 1,   "corrected": 1 },
    { "metered": 2,   "corrected": 2.3 },
    { "metered": 8,   "corrected": 10 },
    { "metered": 30,  "corrected": 60 }
  ]
}
```

打包于 `assets/films/films.json`，支持 OTA 增量更新（1.x 阶段简化为 App 升级带版本号）。

### 3.4 互易律修正 Reciprocity

选定胶卷后，凡 Meter 推荐快门 > 1s，自动按曲线插值（线性 + 端点截断）输出补偿后值。无曲线数据的胶卷给通用经验公式 `t' = t^1.3` 并标注"估算"。

### 3.5 滤镜补偿 Filter

| 滤镜类型 | 补偿值 |
|---|---|
| ND 1–10 档 | 按档数减档，整数 |
| 偏振 CPL | −1.5 EV |
| 黄 #8 | 黑白 −2/3 EV |
| 橙 #21 | 黑白 −1.5 EV |
| 红 #25 | 黑白 −3 EV |
| 绿 #58 | 黑白 −2.5 EV |

可叠加多片。彩色胶卷上的彩色滤镜不给出补偿建议，仅显示警告。

### 3.6 Film Log

新建胶卷"卷宗" → 选择胶卷型号 + 相机 + 镜头 + 推拉档位 → 进入拍摄阶段。

每张照片作为一条 `Frame` 记录：
- 张序号（1..36，或自定义最大张数）
- 拍摄时间（默认 now）
- 光圈 / 快门
- Meter EV（来自当时测光）
- GPS 坐标（用户授权后自动；可关闭）
- 滤镜栈
- 缩略图（可选，从相册引用 / 实拍占位 / 不存）
- 备注

完成卷后 → `finished` 状态 → 可继续推进到 `developing` / `scanned` 状态，记录显影日期与扫描日期。

导出：JSON / CSV / 含缩略图的 ZIP。

### 3.7 冲洗计时器 Dev Timer

多步骤计时：预浸 / 显影 / 停显 / 定影 / 水洗 / 稳定。

- 内置一批通用配方（按胶卷 + 显影液 + 温度 + 推拉档位），数据自行整理自显影液厂商官方说明，不直接复制 Massive Dev Chart 数据库
- 用户可自建配方（步骤 + 时长 + 提示音）
- 计时支持后台运行（iOS 申请 background audio，Android 用前台服务 + 通知），到点震动 + 音频
- 每 30 秒可设置"翻搅提醒"

### 3.8 Sunny 16 速查

基于天气（晴 / 多云 / 阴 / 室内 / 阴影下）和胶卷 ISO，输出推荐光圈 / 快门组合。

可基于设备时间和 GPS 自动推荐"当前时段建议"，但不强制联网。

### 3.9 进阶：超焦距 / Zone System

折叠在 Calc Tab 二级页：

- 超焦距快查表：常用画幅 × 焦距 × 光圈，结果可加入收藏
- Zone System：用户输入多个点测 EV → App 算出动态范围、推荐曝光中心点

---

## 四、技术架构

### 4.1 技术栈

- **框架**：Flutter 3.x（Stable）
- **语言**：Dart 3
- **状态管理**：Riverpod 2.x
- **路由**：go_router（支持 deep link，Widget 点击直达）
- **数据库**：Drift（SQLite，类型安全 + 迁移）
- **数据模型**：freezed + json_serializable
- **相机**：camera 官方插件，备选 camerawesome
- **传感器**：light + sensors_plus
- **桌面小部件桥接**：home_widget
- **国际化**：flutter_intl（首发 zh-CN，预留 en）
- **CI**：GitHub Actions + Codemagic（iOS 构建）/ 自建 runner

### 4.2 分层架构

```
┌─────────────────────────────────────────────────────────┐
│  Presentation                                           │
│   • pages/        meter, calc, rolls, darkroom, me      │
│   • widgets/      B&W design system, atoms/molecules    │
│   • controllers/  Riverpod providers                    │
├─────────────────────────────────────────────────────────┤
│  Domain (pure Dart, 100% testable)                      │
│   • metering/     EV 换算、Sunny 16、滤镜叠加            │
│   • dof/          景深、超焦距、CoC                      │
│   • reciprocity/  互易律曲线插值                         │
│   • film/         胶卷模型与查询                         │
│   • dev_timer/    步骤建模与计时                         │
├─────────────────────────────────────────────────────────┤
│  Data                                                   │
│   • repositories  Roll / Frame / Film / Camera / Lens   │
│   • Drift schema  数据库表与迁移                         │
│   • assets        films.json, dev_recipes.json          │
├─────────────────────────────────────────────────────────┤
│  Platform Adapters (MethodChannel / Plugin)             │
│   • CameraService                                       │
│   • LightSensorService                                  │
│   • WidgetBridgeService (home_widget)                   │
│   • ExportService (share_plus / file_picker)            │
└─────────────────────────────────────────────────────────┘
```

**Domain 层零 Flutter 依赖**，所有公式 100% 单元测试覆盖。

### 4.3 关键工程约定

- 一个 page 一个目录，包含 `view.dart` / `controller.dart` / `widgets/`
- 单文件不超过 300 行，超过则拆分子组件
- 所有不变量（如 ISO 必须 > 0、光圈必须在档位序列内）在构造时校验，不在使用处重复校验
- 错误处理只在系统边界（用户输入、相机权限、数据库 IO）做，内部代码相信契约
- 任何与平台相关的代码全部走 Adapter 层，Domain 与 Presentation 不直接 import dart:io 之外的平台 API

---

## 五、桌面小部件设计

桥接方案：`home_widget` 插件——Flutter 端写 KV，原生侧渲染 UI。

### 5.1 iOS WidgetKit（SwiftUI）

| 尺寸 | 内容 | 数据 |
|---|---|---|
| Small (2×2) | Sunny 16 当前时段推荐 | 时段 / ISO / 推荐 f & 1/x |
| Medium (4×2) | 当前胶卷 + 已拍 N/36 + 一键测光 | 胶卷型号、ISO、计数、按钮 |
| Lock Screen accessoryRectangular | 当前 EV（最近一次测光） | EV 数值 + 时间戳 |

数据通道：App Group `group.com.zhaoo.filmgo`，Flutter 写入 → SwiftUI Provider 读取 → TimelineProvider 每 1 小时刷新（Sunny 16 时段切换）。

### 5.2 Android AppWidget + MIUI 兼容（Kotlin RemoteViews）

| 尺寸 | 内容 | 备注 |
|---|---|---|
| 1×1 | "测光"按钮 | PendingIntent → MainActivity?route=meter |
| 2×2 | Sunny 16 速查 | 时段图标 + 推荐组合 |
| 4×2 | 完整面板 | 胶卷状态 + 当前 EV + 测光按钮 |

数据通道：SharedPreferences（home_widget 默认实现）。

**MIUI / HyperOS 适配**
- 申请桌面快捷方式权限（小米独有 `com.miui.home.permission.INSTALL_WIDGET`），HyperOS 1/2 路径变化时回退到标准 Android 接口
- 不做后台定时刷新，规避 MIUI 省电策略限制
- 刷新策略：① App 前后台切换时 `WidgetBridgeService.update()` 写入最新值；② Widget 点击 deep link 拉起 App 时刷新；③ 用户明确进行测光后写入

### 5.3 Widget 数据键约定

```
filmgo.currentEV          : Double
filmgo.currentEV.takenAt  : ISO8601 String
filmgo.activeRoll.name    : String?
filmgo.activeRoll.iso     : Int?
filmgo.activeRoll.shot    : Int?
filmgo.activeRoll.total   : Int?
filmgo.sunny16.aperture   : String   // "f/16"
filmgo.sunny16.shutter    : String   // "1/400"
filmgo.sunny16.context    : String   // "晴 · 正午"
```

---

## 六、数据模型

```
Film (内置, 不可写)
  id, name, brand, iso, type, latitudeStops, pushPullRange,
  reciprocityCurve

Camera (用户自建)
  id, name, format(135/120/4×5), notes

Lens (用户自建)
  id, name, mount, focalLength, maxAperture, notes

Roll (一卷胶卷)
  id, filmId, cameraId, lensId, pushPull,
  startedAt, finishedAt, status, notes
  // status: active | finished | developing | scanned

Frame (单张)
  id, rollId, index, shotAt,
  aperture, shutter, meteredEV,
  gpsLat, gpsLng, filterStack(JSON), thumbnailPath, notes

MeterReading (匿名快速测光，不强制绑卷)
  id, ev, iso, suggestedPairs(JSON), takenAt

DevSession (冲洗会话)
  id, filmId, recipeId, startedAt, finishedAt,
  steps(JSON: [{name, duration, doneAt}])
```

存储：Drift / SQLite，缩略图存 `documents/thumbs/<frameId>.jpg`，导出 JSON + CSV，可选打包 ZIP。

数据库迁移采用 Drift 的 `MigrationStrategy`，每次 schema 变化独立迁移函数 + 测试。

---

## 七、UI 设计原则（黑白色调）

### 7.1 配色

- 主色：`#0A0A0A`（纯黑）/ `#FAFAFA`（纯白）
- 灰阶 5 级：`#1F1F1F / #3A3A3A / #6B6B6B / #B5B5B5 / #E5E5E5`
- 强调色（仅一处例外）：暗房红 `#C8302A`，仅用于①测光"超出范围"警示，②冲洗计时器界面氛围。其他任何场景禁止使用红色或其他彩色

### 7.2 字体

- 英文 / 数字：JetBrains Mono（仪表盘感）
- 中文：iOS 落 PingFang SC，Android 落 HarmonyOS Sans

### 7.3 图标

统一使用 Phosphor Icons (Regular 1.5pt 线性)，禁止填充图标混用。

### 7.4 关键 UI 隐喻

- **Meter 主界面**：模仿手持测光表的圆形指针 + 扇形刻度（用 CustomPainter 绘制）
- **Sunny 16 卡片**：仿胶卷盒（黑白排版 + 齿孔装饰）
- **胶卷列表**：每卷一张"胶卷盒"卡片，已拍张数化作"胶片透出量"的进度条
- **冲洗计时器**：暗房红光氛围 + 大数字倒计时

### 7.5 主题模式

- 默认跟随系统
- Light：灯箱审片白
- Dark：暗房黑
- 两者均为正交黑白，不带蓝/暖色调

### 7.6 跨平台一致性

按钮 / Switch / 对话框 / 导航栏等，使用 `Adaptive*` 控件按平台呈现 Material 3 或 Cupertino 风格，业务页面布局保持一致。

---

## 八、兼容性策略

### 8.1 系统与机型矩阵

| 维度 | 最低支持 | 重点验证机型 |
|---|---|---|
| iOS | 15.0 | iPhone SE (3rd) 小屏、iPhone 14 Pro 灵动岛、iPhone 15 Pro Max |
| Android | API 26 (8.0) | 小米 13 / 14、Redmi Note 12 / 13、HyperOS 1 / 2、一加 / 三星各一台抽样 |
| Lock Screen Widget | iOS 16+ | iOS 15 不展示锁屏入口 |
| 折叠屏 | 兼容（落普通手机布局） | 不做特殊适配 |
| 车载 / 平板 | 1.0 不支持 | 显式屏蔽，启动页提示 |

### 8.2 相机与传感器

- Camera2 / AVFoundation 标准接口；小米超广角、徕卡定制色彩管线不依赖
- 低端机检测：若 `MediaQuery.devicePixelRatio < 2.5` 或 RAM < 3GB，预览分辨率降级到 720p
- 无 ALS 机型：UI 上禁用"传感器测光"入口，不弹错

### 8.3 权限

| 权限 | 用途 | 拒绝后行为 |
|---|---|---|
| 相机 | 取景测光 | Meter 页提示并降级到手动 EV 输入 |
| 定位 | Frame GPS 元数据 | 仅记录无 GPS 的 Frame |
| 通知 | 计时器到点提醒 | 计时仍可用，仅震动 |
| 相册写入 | 导出缩略图 ZIP | 改为分享 sheet |

全部运行时申请，首次申请前展示前置说明 sheet。

### 8.4 性能基线

- 取景测光帧率 ≥ 20 fps（骁龙 6 Gen 1 / A12 测试基线）
- 首屏冷启动 ≤ 1.5s
- 安装包：Android < 25MB（拆分 ABI），iOS < 40MB
- 内存峰值 < 200MB

### 8.5 小米生态专项

- 桌面 Widget 在 MIUI 14 / HyperOS 1 / HyperOS 2 各跑一次
- 省电策略开启时，验证 Widget 点击仍能拉起 App
- 应用商店：上架小米应用商店需准备工信部备案号、合规自查表、隐私政策

---

## 九、测试策略

### 9.1 测试金字塔

| 层 | 范围 | 工具 |
|---|---|---|
| Unit | Domain 层全部公式与模型 | flutter_test, mocktail |
| Widget | 每页一个 golden test | flutter_test golden |
| Integration | 相机 / 传感器 / Widget 桥接 | integration_test，真机 |
| E2E 手动 | 上架前回归矩阵 | 真机 checklist |

### 9.2 强制 TDD 范围

所有 Domain 层公式（EV / DoF / 互易律 / 滤镜 / Sunny 16）必须先写测试再写实现，每个公式至少 3 个已知 case 对照（教材或在线计算器）。

UI 层不强制 TDD，但每个页面上线前必须有 golden test 保证黑白主题不被回归带跑。

### 9.3 真机回归矩阵

每次发版前必跑：
- iPhone SE (3rd) + iPhone 14 Pro
- 小米 13 / 14（HyperOS 2）
- Redmi Note 12（HyperOS 1）
- 任一三星或一加抽样

每台机型跑 checklist：取景测光、景深、新建卷、计时器、Widget 点击拉起、Widget 数据刷新。

### 9.4 CI

- PR 触发：Unit + Widget + 静态分析
- Main merge：增量 Integration（Firebase Test Lab 小米机型矩阵）
- Tag 触发：Release build + 上传 TestFlight / 应用商店内测包

---

## 十、里程碑

| 阶段 | 周数 | 产出 |
|---|---|---|
| M0 项目骨架 | 1 周 | Flutter 工程、CI、主题系统、tab 路由、空页框架 |
| M1 测光 + 景深 | 2 周 | Meter 页可用（取景 + 传感器 + 手动）、DoF 页、胶卷库装载 |
| M2 Film Log + 互易律 + 滤镜 | 2 周 | Roll/Frame CRUD、本地存储、补偿联动、导出 |
| M3 暗房计时 + Sunny 16 + 进阶页 | 1 周 | Dev Timer、Sunny 16、超焦距、Zone System |
| M4 双端 Widget | 1.5 周 | iOS WidgetKit、Android/MIUI AppWidget |
| M5 兼容性回归 + 上架 | 1.5 周 | 真机矩阵、商店素材、备案、TestFlight 内测 |
| **MVP 总计** | **~9 周** | 1.0 上架 |

---

## 十一、2.0 Backlog（不做）

- 账号体系 + 云同步（Supabase 或自建）
- 胶片风格拍照模块（LUT / Skia 滤镜）
- Apple Watch 测光表
- 社区分享（看片 / 互评 / 胶卷推荐）
- HyperOS 车机 / 平板 / 折叠屏定制布局
- AR 取景构图辅助
- 胶卷库扫码识别（拍胶卷盒条码自动选型号）

---

## 十二、风险与开放问题

### 12.1 已识别风险

| 风险 | 缓解 |
|---|---|
| 不同机型相机预览帧格式差异（YUV 各种 layout） | 用 camerawesome 作为兜底；首版仅支持主流 layout，其他降级到手动输入 |
| 测光绝对精度难达专业测光表水平 | 提供首次校准流程；UI 明确标注"仅供参考"；与已知胶卷盒上的 Sunny 16 印刷指南对齐 |
| MIUI / HyperOS Widget API 漂移 | 不依赖小米私有 API，标准 AppWidget 实现；专门留 1.5 周做小米回归 |
| 显影配方数据版权 | 仅打包基于厂商官方 datasheet 的通用配方；提供用户自建配方导入；不复制第三方数据库内容 |
| Flutter 包体积超标 | 拆分 ABI、按需引入 Skia、首发不打包字体（用系统字体） |

### 12.2 待用户确认

无（所有关键决策点已在 brainstorming 阶段确认）。

---

## 附录 A：关键公式参考

```
EV (反射光测光):
  EV = log2(L · K / (ISO · S))
  K = 12.5 (反射光常数)

EV → 光圈快门:
  EV = log2(N² / t) ⇔ N² / t = 2^EV

景深 (Wikipedia 标准, H 含 +f 修正项):
  H  = f² / (N · c) + f
  Dn = d · (H − f) / (H + d − 2f)
  Df = d · (H − f) / (H − d)         // d ≥ H 时为 ∞

互易律 (经验):
  t' = t^p,  p ∈ [1.2, 1.5] (按胶卷)

Sunny 16:
  晴天: f/16, 1/ISO
  多云: f/11, 1/ISO
  阴天: f/8,  1/ISO
  阴影: f/5.6, 1/ISO
```

## 附录 B：胶卷库初始清单（节选）

- Kodak: Portra 160 / 400 / 800, Gold 200, Ektar 100, Tri-X 400, T-Max 100/400, Ultramax 400
- Fuji: Pro 400H, C200, Superia 400/X-Tra 800, Velvia 50/100, Provia 100F, Acros II 100
- Ilford: HP5 Plus 400, Delta 100/400/3200, FP4 Plus 125, Pan F Plus 50, XP2 Super 400
- Cinestill: 50D, 400D, 800T
- 其他：Lomography Color Negative 100/400/800、Rollei Retro、Adox CHS、Foma Fomapan

完整清单与参数随 `assets/films/films.json` 发布。

---

*— Spec ends —*
