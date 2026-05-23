# Film Go

胶卷摄影辅助 App——*"Trust your film. Let the app do the math."*

## 状态

M0 项目骨架（2026-05）：可启动的 Flutter App、5 Tab 路由、黑白主题、Domain 层 EV / 景深公式 + 100% 测试。后续里程碑见 `docs/superpowers/`。

## 开发

```bash
cd film-go
flutter pub get
flutter test
flutter run
```

## 设计与计划

- 设计稿：`docs/superpowers/specs/2026-05-23-film-go-design.md`
- M0 计划：`docs/superpowers/plans/2026-05-23-film-go-m0-skeleton.md`

## 架构

- `lib/pages/` — UI 层，5 个 Tab 页
- `lib/widgets/` — 共享组件（含 ScaffoldShell）
- `lib/router/` — go_router 配置
- `lib/theme/` — 黑白色板与字体
- `lib/domain/` — 纯 Dart 业务逻辑（无 Flutter 依赖，100% 单测）

## 许可

Private，未公开授权。
