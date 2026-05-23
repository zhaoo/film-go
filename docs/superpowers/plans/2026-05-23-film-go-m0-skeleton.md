# Film Go M0 — 项目骨架 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成 Film Go 项目的工程骨架——可运行的 Flutter App、5 Tab 路由、黑白主题、CI 流水线、Domain 层基础公式（EV / DoF），为 M1 起的特性开发提供干净的 TDD 起点。

**Architecture:** 分层 Clean Architecture：Presentation（Flutter + Riverpod + go_router）/ Domain（pure Dart，零 Flutter 依赖，100% 单元测试）/ Data 层在 M2 引入。M0 只搭骨架，不实现业务功能；任何"看起来像功能"的代码必须有公式 + 教科书对照测试。

**Tech Stack:** Flutter 3.x · Dart 3 · flutter_riverpod 2.x · go_router · google_fonts (JetBrains Mono) · phosphor_flutter · flutter_lints。Drift / camera / home_widget 等留到对应里程碑再加。

**重要约定：**
- **Git 根在 `/Users/zhaoo/Desktop/code/zhaoo/`**，是多项目共仓。Film Go 在子目录 `film-go/`。所有 git 命令在仓根执行；`flutter` 命令在 `film-go/` 目录执行。
- **commit 消息风格**：`type(film-go): 中文描述`，type ∈ {feat, fix, docs, chore, test, refactor}
- **每个 task 末尾必须 commit**，且只 add 本 task 涉及文件，不要 `git add .`

---

## 文件结构（M0 完成后的样子）

```
film-go/
├─ .github/workflows/ci.yml          # CI: format / analyze / test
├─ pubspec.yaml                       # 依赖清单
├─ analysis_options.yaml              # 严格 lint
├─ README.md                          # 项目说明
├─ lib/
│  ├─ main.dart                       # 入口 + ProviderScope
│  ├─ app.dart                        # MaterialApp.router
│  ├─ theme/
│  │  ├─ app_colors.dart              # 黑白 + 灰阶 + 暗房红
│  │  ├─ app_typography.dart          # JetBrains Mono + 系统中文
│  │  └─ app_theme.dart               # ThemeData light/dark
│  ├─ router/
│  │  └─ app_router.dart              # go_router StatefulShellRoute
│  ├─ widgets/
│  │  └─ scaffold_shell.dart          # 底部导航壳
│  ├─ pages/
│  │  ├─ meter/meter_page.dart
│  │  ├─ calc/calc_page.dart
│  │  ├─ rolls/rolls_page.dart
│  │  ├─ darkroom/darkroom_page.dart
│  │  └─ me/me_page.dart
│  └─ domain/
│     ├─ shared/
│     │  ├─ aperture.dart             # 光圈值对象
│     │  └─ shutter_speed.dart        # 快门值对象
│     ├─ metering/
│     │  └─ ev_calculator.dart        # EV ↔ 光圈快门 换算
│     └─ dof/
│        └─ depth_of_field.dart       # 景深 / 超焦距
└─ test/
   ├─ theme/app_theme_test.dart
   └─ domain/
      ├─ shared/aperture_test.dart
      ├─ shared/shutter_speed_test.dart
      ├─ metering/ev_calculator_test.dart
      └─ dof/depth_of_field_test.dart
```

---

## Task 1: 初始化 Flutter 工程

**Files:**
- Create: `film-go/` 下的整个 Flutter scaffold（由 `flutter create` 生成）

- [ ] **Step 1: 检查 Flutter 版本**

Run（在任意目录）：
```bash
flutter --version
```
Expected: Flutter 3.x（3.16+ 优先）。若没装/版本太低，先 `fvm use 3.x` 或安装。

- [ ] **Step 2: 在 `film-go/` 目录运行 flutter create**

Run（在 `/Users/zhaoo/Desktop/code/zhaoo/film-go/`）：
```bash
flutter create . --project-name film_go --org com.zhaoo.filmgo --platforms=ios,android --description "Film photography assistant"
```
Expected: 生成 `lib/main.dart`、`pubspec.yaml`、`ios/`、`android/`、`test/widget_test.dart` 等。无报错。

- [ ] **Step 3: 验证工程能跑通分析**

Run（在 `film-go/`）：
```bash
flutter pub get && flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 4: 验证默认 widget test 能跑**

Run：
```bash
flutter test
```
Expected: `All tests passed!`（默认计数器测试）

- [ ] **Step 5: Commit 初始 scaffold**

Run（在仓根 `/Users/zhaoo/Desktop/code/zhaoo/`）：
```bash
git add film-go/
git commit -m "chore(film-go): 初始化 Flutter 工程骨架"
```

---

## Task 2: 配置严格 lint

**Files:**
- Modify: `film-go/analysis_options.yaml`

- [ ] **Step 1: 用以下内容替换默认 analysis_options.yaml**

写入 `film-go/analysis_options.yaml`：

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    invalid_annotation_target: ignore
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "build/**"

linter:
  rules:
    - prefer_single_quotes
    - prefer_const_constructors
    - prefer_const_literals_to_create_immutables
    - prefer_final_locals
    - require_trailing_commas
    - sort_child_properties_last
    - unawaited_futures
    - avoid_print
    - always_declare_return_types
    - avoid_unused_constructor_parameters
```

> 不启用 `prefer_relative_imports`：本计划全程使用 `package:film_go/...` 绝对导入，与该规则冲突。

- [ ] **Step 2: 跑 analyze 确认通过**

Run（在 `film-go/`）：
```bash
flutter analyze
```
Expected: 默认 scaffold 可能因 `prefer_single_quotes` / `require_trailing_commas` 报警告，临时改 `lib/main.dart` 与 `test/widget_test.dart` 让 analyze 全绿。这是清理而不是功能改动。

- [ ] **Step 3: Commit**

Run（仓根）：
```bash
git add film-go/analysis_options.yaml film-go/lib/main.dart film-go/test/widget_test.dart
git commit -m "chore(film-go): 启用严格 lint 与 trailing comma 规则"
```

---

## Task 3: 添加 M0 必需依赖

**Files:**
- Modify: `film-go/pubspec.yaml`

- [ ] **Step 1: 替换 dependencies / dev_dependencies 段**

在 `film-go/pubspec.yaml` 中找到 `dependencies:` 段，调整为：

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  go_router: ^14.2.0
  google_fonts: ^6.2.1
  phosphor_flutter: ^2.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  mocktail: ^1.0.4
```

> 注：Drift / camera / home_widget 等到 M1+ 再加，不要在这里提前引入。

- [ ] **Step 2: 拉依赖**

Run（在 `film-go/`）：
```bash
flutter pub get
```
Expected: 成功，无依赖冲突。若 google_fonts 因网络拉不到，先尝试 `flutter pub get --offline` 或挂代理；失败时记录 issue，本步阻塞需用户介入。

- [ ] **Step 3: 跑 analyze + test 双确认**

Run：
```bash
flutter analyze && flutter test
```
Expected: 全绿。

- [ ] **Step 4: Commit**

```bash
git add film-go/pubspec.yaml film-go/pubspec.lock
git commit -m "chore(film-go): 引入 riverpod / go_router / google_fonts / phosphor 依赖"
```

---

## Task 4: GitHub Actions CI

**Files:**
- Create: `.github/workflows/film-go-ci.yml`（**仓根**，不是 `film-go/.github/workflows/`）

> ⚠️ GitHub Actions 只识别仓根 `.github/workflows/` 下的 workflow，子目录里的不会被触发。多项目共仓时，用 `paths: 'film-go/**'` filter + `working-directory: film-go` 实现项目隔离。

- [ ] **Step 1: 写 CI 配置**

写入 `.github/workflows/film-go-ci.yml`（**注意是仓根，不是 film-go 子目录**）：

```yaml
name: film-go CI

on:
  push:
    branches: [daily/**, main]
    paths:
      - 'film-go/**'
  pull_request:
    paths:
      - 'film-go/**'

defaults:
  run:
    working-directory: film-go

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.x'
          channel: stable
          cache: true

      - name: Pub get
        run: flutter pub get

      - name: Format check
        run: dart format --output=none --set-exit-if-changed .

      - name: Analyze
        run: flutter analyze --fatal-infos

      - name: Test
        run: flutter test --coverage

      - name: Upload coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: film-go/coverage/lcov.info
```

- [ ] **Step 2: 本地用 act 或手动跑一遍模拟**

最简单是直接在本地跑这三个命令确认无误：
```bash
cd film-go && dart format --output=none --set-exit-if-changed . && flutter analyze --fatal-infos && flutter test
```
Expected: 全绿。

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/film-go-ci.yml
git commit -m "ci(film-go): 增加 GitHub Actions 流水线（format/analyze/test）"
```

---

## Task 5: 主题——颜色

**Files:**
- Create: `film-go/lib/theme/app_colors.dart`

- [ ] **Step 1: 写 AppColors**

写入 `film-go/lib/theme/app_colors.dart`：

```dart
import 'package:flutter/material.dart';

/// Film Go 黑白色板。
///
/// 全局唯一允许的非黑白色是 [darkroomRed]，仅用于：
///   ① 测光"超出范围"警示
///   ② 冲洗计时器氛围
/// 任何其他场景禁止使用红色或彩色。
class AppColors {
  const AppColors._();

  // 主色
  static const Color black = Color(0xFF0A0A0A);
  static const Color white = Color(0xFFFAFAFA);

  // 5 级灰阶（深→浅）
  static const Color gray900 = Color(0xFF1F1F1F);
  static const Color gray700 = Color(0xFF3A3A3A);
  static const Color gray500 = Color(0xFF6B6B6B);
  static const Color gray300 = Color(0xFFB5B5B5);
  static const Color gray100 = Color(0xFFE5E5E5);

  // 唯一强调色
  static const Color darkroomRed = Color(0xFFC8302A);
}
```

- [ ] **Step 2: 写一个最小测试确保常量值不被改坏**

写入 `film-go/test/theme/app_colors_test.dart`：

```dart
import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColors', () {
    test('黑白主色 hex 与 spec 一致', () {
      expect(AppColors.black.value, 0xFF0A0A0A);
      expect(AppColors.white.value, 0xFFFAFAFA);
    });

    test('灰阶 5 级单调递增', () {
      final grays = [
        AppColors.gray900,
        AppColors.gray700,
        AppColors.gray500,
        AppColors.gray300,
        AppColors.gray100,
      ];
      for (var i = 1; i < grays.length; i++) {
        expect(
          grays[i].computeLuminance() > grays[i - 1].computeLuminance(),
          isTrue,
          reason: 'gray index $i 应比上一个更亮',
        );
      }
    });

    test('暗房红是唯一允许的彩色', () {
      expect(AppColors.darkroomRed.value, 0xFFC8302A);
    });
  });
}
```

- [ ] **Step 3: 跑测试**

Run（在 `film-go/`）：
```bash
flutter test test/theme/app_colors_test.dart
```
Expected: All tests passed!

- [ ] **Step 4: Commit**

```bash
git add film-go/lib/theme/app_colors.dart film-go/test/theme/app_colors_test.dart
git commit -m "feat(film-go): 引入 AppColors 黑白色板与暗房红强调色"
```

---

## Task 6: 主题——字体

**Files:**
- Create: `film-go/lib/theme/app_typography.dart`

- [ ] **Step 1: 写 AppTypography**

写入 `film-go/lib/theme/app_typography.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Film Go 字体方案。
///
/// - 数字 / 英文：JetBrains Mono（仪表盘观感）
/// - 中文：iOS=PingFang SC，Android=系统默认（落 HarmonyOS Sans 或 Noto）
class AppTypography {
  const AppTypography._();

  static TextTheme buildTextTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? Typography.whiteMountainView
        : Typography.blackMountainView;
    return GoogleFonts.jetBrainsMonoTextTheme(base).apply(
      // 中文回落由 fontFamilyFallback 控制
      fontFamilyFallback: const ['PingFang SC', 'HarmonyOS Sans', 'Noto Sans CJK SC'],
    );
  }
}
```

- [ ] **Step 2: 跑 analyze 确认无 lint 报错**

Run：
```bash
flutter analyze lib/theme/app_typography.dart
```
Expected: No issues found!

- [ ] **Step 3: Commit**

```bash
git add film-go/lib/theme/app_typography.dart
git commit -m "feat(film-go): 增加 AppTypography（JetBrains Mono + 中文回落）"
```

---

## Task 7: 主题——AppTheme

**Files:**
- Create: `film-go/lib/theme/app_theme.dart`
- Create: `film-go/test/theme/app_theme_test.dart`

- [ ] **Step 1: 先写 AppTheme 测试（行为契约）**

写入 `film-go/test/theme/app_theme_test.dart`：

```dart
import 'package:film_go/theme/app_colors.dart';
import 'package:film_go/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    test('light 主题背景为白、前景为黑', () {
      final theme = AppTheme.light();
      expect(theme.scaffoldBackgroundColor, AppColors.white);
      expect(theme.colorScheme.onSurface, AppColors.black);
      expect(theme.brightness, Brightness.light);
    });

    test('dark 主题背景为黑、前景为白', () {
      final theme = AppTheme.dark();
      expect(theme.scaffoldBackgroundColor, AppColors.black);
      expect(theme.colorScheme.onSurface, AppColors.white);
      expect(theme.brightness, Brightness.dark);
    });

    test('两套主题都使用 Material 3', () {
      expect(AppTheme.light().useMaterial3, isTrue);
      expect(AppTheme.dark().useMaterial3, isTrue);
    });
  });
}
```

- [ ] **Step 2: 跑测试看到红**

Run：
```bash
flutter test test/theme/app_theme_test.dart
```
Expected: 失败，`AppTheme` 类不存在。

- [ ] **Step 3: 写实现**

写入 `film-go/lib/theme/app_theme.dart`：

```dart
import 'package:film_go/theme/app_colors.dart';
import 'package:film_go/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Film Go 主题构建器。
///
/// Light = 灯箱审片白；Dark = 暗房黑。两套主题均为正交黑白，不带蓝/暖色调。
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(brightness: Brightness.light);
  static ThemeData dark() => _build(brightness: Brightness.dark);

  static ThemeData _build({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? AppColors.black : AppColors.white;
    final fg = isDark ? AppColors.white : AppColors.black;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: fg,
      onPrimary: bg,
      secondary: fg,
      onSecondary: bg,
      error: AppColors.darkroomRed,
      onError: AppColors.white,
      surface: bg,
      onSurface: fg,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: colorScheme,
      textTheme: AppTypography.buildTextTheme(brightness),
    );
  }
}
```

- [ ] **Step 4: 跑测试看到绿**

Run：
```bash
flutter test test/theme/app_theme_test.dart
```
Expected: All tests passed!

- [ ] **Step 5: Commit**

```bash
git add film-go/lib/theme/app_theme.dart film-go/test/theme/app_theme_test.dart
git commit -m "feat(film-go): 实现 AppTheme（light=灯箱白 / dark=暗房黑）"
```

---

## Task 8: 五个空白 Tab 页

**Files:**
- Create: `film-go/lib/pages/meter/meter_page.dart`
- Create: `film-go/lib/pages/calc/calc_page.dart`
- Create: `film-go/lib/pages/rolls/rolls_page.dart`
- Create: `film-go/lib/pages/darkroom/darkroom_page.dart`
- Create: `film-go/lib/pages/me/me_page.dart`

- [ ] **Step 1: 写 MeterPage（占位）**

写入 `film-go/lib/pages/meter/meter_page.dart`：

```dart
import 'package:flutter/material.dart';

class MeterPage extends StatelessWidget {
  const MeterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Meter\n取景测光将在 M1 实现', textAlign: TextAlign.center),
      ),
    );
  }
}
```

- [ ] **Step 2: 复刻 4 份生成 calc/rolls/darkroom/me page**

`film-go/lib/pages/calc/calc_page.dart`：

```dart
import 'package:flutter/material.dart';

class CalcPage extends StatelessWidget {
  const CalcPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Calc\n景深 / 超焦距 / 滤镜 / 互易律 / Sunny 16',
            textAlign: TextAlign.center),
      ),
    );
  }
}
```

`film-go/lib/pages/rolls/rolls_page.dart`：

```dart
import 'package:flutter/material.dart';

class RollsPage extends StatelessWidget {
  const RollsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Rolls\nFilm Log 将在 M2 实现')),
    );
  }
}
```

`film-go/lib/pages/darkroom/darkroom_page.dart`：

```dart
import 'package:flutter/material.dart';

class DarkroomPage extends StatelessWidget {
  const DarkroomPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Darkroom\n冲洗计时器将在 M3 实现')),
    );
  }
}
```

`film-go/lib/pages/me/me_page.dart`：

```dart
import 'package:flutter/material.dart';

class MePage extends StatelessWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Me\n设置 / 设备库 / 导出')),
    );
  }
}
```

- [ ] **Step 3: 跑 analyze 确认无报错**

Run：
```bash
flutter analyze lib/pages
```
Expected: No issues found!

- [ ] **Step 4: Commit**

```bash
git add film-go/lib/pages/
git commit -m "feat(film-go): 添加 5 个空白 Tab 页占位"
```

---

## Task 9: 底部导航壳

**Files:**
- Create: `film-go/lib/widgets/scaffold_shell.dart`

- [ ] **Step 1: 写 ScaffoldShell**

写入 `film-go/lib/widgets/scaffold_shell.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// 5 Tab 底部导航壳，由 go_router 的 StatefulShellRoute 注入 [navigationShell]。
class ScaffoldShell extends StatelessWidget {
  const ScaffoldShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _items = <_NavItem>[
    _NavItem(label: '取景', icon: PhosphorIconsRegular.aperture),
    _NavItem(label: '计算', icon: PhosphorIconsRegular.ruler),
    _NavItem(label: '胶卷', icon: PhosphorIconsRegular.filmReel),
    _NavItem(label: '暗房', icon: PhosphorIconsRegular.timer),
    _NavItem(label: '我的', icon: PhosphorIconsRegular.user),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: [
          for (final item in _items)
            NavigationDestination(
              icon: Icon(item.icon),
              label: item.label,
            ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}
```

- [ ] **Step 2: 跑 analyze**

Run：
```bash
flutter analyze lib/widgets/scaffold_shell.dart
```
Expected: No issues found!

- [ ] **Step 3: Commit**

```bash
git add film-go/lib/widgets/scaffold_shell.dart
git commit -m "feat(film-go): 增加 5 Tab 底部导航壳 ScaffoldShell"
```

---

## Task 10: go_router 路由配置

**Files:**
- Create: `film-go/lib/router/app_router.dart`

- [ ] **Step 1: 写 AppRouter（含 Riverpod Provider 暴露）**

写入 `film-go/lib/router/app_router.dart`：

```dart
import 'package:film_go/pages/calc/calc_page.dart';
import 'package:film_go/pages/darkroom/darkroom_page.dart';
import 'package:film_go/pages/me/me_page.dart';
import 'package:film_go/pages/meter/meter_page.dart';
import 'package:film_go/pages/rolls/rolls_page.dart';
import 'package:film_go/widgets/scaffold_shell.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/meter',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/meter',
                builder: (_, __) => const MeterPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calc',
                builder: (_, __) => const CalcPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rolls',
                builder: (_, __) => const RollsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/darkroom',
                builder: (_, __) => const DarkroomPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/me',
                builder: (_, __) => const MePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
```

- [ ] **Step 2: 跑 analyze**

Run：
```bash
flutter analyze lib/router
```
Expected: No issues found!

- [ ] **Step 3: Commit**

```bash
git add film-go/lib/router/app_router.dart
git commit -m "feat(film-go): 配置 go_router StatefulShellRoute（5 Tab 独立堆栈）"
```

---

## Task 11: 串起整个 App

**Files:**
- Create: `film-go/lib/app.dart`
- Modify: `film-go/lib/main.dart`
- Modify: `film-go/test/widget_test.dart`

- [ ] **Step 1: 写 FilmGoApp**

写入 `film-go/lib/app.dart`：

```dart
import 'package:film_go/router/app_router.dart';
import 'package:film_go/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FilmGoApp extends ConsumerWidget {
  const FilmGoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Film Go',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Step 2: 替换 main.dart**

写入 `film-go/lib/main.dart`：

```dart
import 'package:film_go/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: FilmGoApp()));
}
```

- [ ] **Step 3: 替换默认 widget_test 为冒烟测试**

写入 `film-go/test/widget_test.dart`：

```dart
import 'package:film_go/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App 启动后默认进入 Meter Tab', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FilmGoApp()));
    await tester.pumpAndSettle();

    expect(find.text('取景'), findsOneWidget);
    expect(find.text('计算'), findsOneWidget);
    expect(find.text('胶卷'), findsOneWidget);
    expect(find.text('暗房'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    expect(find.textContaining('Meter'), findsOneWidget);
  });

  testWidgets('点击「计算」Tab 切换到 Calc 页', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FilmGoApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('计算'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Calc'), findsOneWidget);
  });
}
```

- [ ] **Step 4: 跑全量测试**

Run：
```bash
flutter test
```
Expected: All tests passed!（含主题、widget 冒烟）

- [ ] **Step 5: 真机/模拟器跑一次目测**

Run（任选一个 device）：
```bash
flutter run -d <device-id>
```
Expected: 启动后停在 Meter Tab，5 个 Tab 可点击切换。点完即可退出。

- [ ] **Step 6: Commit**

```bash
git add film-go/lib/app.dart film-go/lib/main.dart film-go/test/widget_test.dart
git commit -m "feat(film-go): 串接 ProviderScope + MaterialApp.router 完成首屏跑通"
```

---

## Task 12: Domain — 光圈值对象

**Files:**
- Create: `film-go/lib/domain/shared/aperture.dart`
- Create: `film-go/test/domain/shared/aperture_test.dart`

> Domain 层 100% TDD：先写测试。光圈是值对象，封装 f 值与档位序列，避免到处出现魔法数字。

- [ ] **Step 1: 先写测试**

写入 `film-go/test/domain/shared/aperture_test.dart`：

```dart
import 'package:film_go/domain/shared/aperture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Aperture', () {
    test('整档序列覆盖 f/1 到 f/64', () {
      final stops = Aperture.fullStops;
      expect(stops.first.fNumber, closeTo(1.0, 1e-9));
      expect(stops.last.fNumber, closeTo(64.0, 1e-9));
      // 整档比相邻 f 值约 √2
      for (var i = 1; i < stops.length; i++) {
        final ratio = stops[i].fNumber / stops[i - 1].fNumber;
        expect(ratio, closeTo(1.41421356, 0.01));
      }
    });

    test('display 字符串符合摄影惯例 f/2.8', () {
      expect(const Aperture(2.8).display, 'f/2.8');
      expect(const Aperture(8).display, 'f/8');
      expect(const Aperture(1.4).display, 'f/1.4');
    });

    test('两个相同 f 值的 Aperture 相等', () {
      expect(const Aperture(2.8), const Aperture(2.8));
      expect(const Aperture(2.8).hashCode, const Aperture(2.8).hashCode);
    });

    test('非正 f 值抛 ArgumentError', () {
      expect(() => Aperture(0), throwsArgumentError);
      expect(() => Aperture(-1), throwsArgumentError);
    });
  });
}
```

- [ ] **Step 2: 跑测试看到红**

Run：
```bash
flutter test test/domain/shared/aperture_test.dart
```
Expected: 全部失败（类不存在）。

- [ ] **Step 3: 写实现**

写入 `film-go/lib/domain/shared/aperture.dart`：

```dart
import 'package:meta/meta.dart';

@immutable
class Aperture {
  Aperture(this.fNumber) {
    if (fNumber <= 0) {
      throw ArgumentError.value(fNumber, 'fNumber', '必须为正数');
    }
  }

  const Aperture._unchecked(this.fNumber);

  final double fNumber;

  String get display {
    final s = fNumber == fNumber.roundToDouble()
        ? fNumber.toStringAsFixed(0)
        : fNumber.toStringAsFixed(1);
    return 'f/$s';
  }

  static const List<Aperture> fullStops = <Aperture>[
    Aperture._unchecked(1.0),
    Aperture._unchecked(1.4),
    Aperture._unchecked(2.0),
    Aperture._unchecked(2.8),
    Aperture._unchecked(4.0),
    Aperture._unchecked(5.6),
    Aperture._unchecked(8.0),
    Aperture._unchecked(11.0),
    Aperture._unchecked(16.0),
    Aperture._unchecked(22.0),
    Aperture._unchecked(32.0),
    Aperture._unchecked(45.0),
    Aperture._unchecked(64.0),
  ];

  @override
  bool operator ==(Object other) =>
      other is Aperture && other.fNumber == fNumber;

  @override
  int get hashCode => fNumber.hashCode;
}
```

> 说明：`fullStops` 用 `_unchecked` 私有构造跳过校验（编译期已知合法），实例化都是 const。

- [ ] **Step 4: 跑测试看到绿**

Run：
```bash
flutter test test/domain/shared/aperture_test.dart
```
Expected: All tests passed!

- [ ] **Step 5: Commit**

```bash
git add film-go/lib/domain/shared/aperture.dart film-go/test/domain/shared/aperture_test.dart
git commit -m "feat(film-go): 增加 Aperture 值对象（含整档序列与 display）"
```

---

## Task 13: Domain — 快门值对象

**Files:**
- Create: `film-go/lib/domain/shared/shutter_speed.dart`
- Create: `film-go/test/domain/shared/shutter_speed_test.dart`

- [ ] **Step 1: 先写测试**

写入 `film-go/test/domain/shared/shutter_speed_test.dart`：

```dart
import 'package:film_go/domain/shared/shutter_speed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShutterSpeed', () {
    test('seconds 必须 > 0', () {
      expect(() => ShutterSpeed.seconds(0), throwsArgumentError);
      expect(() => ShutterSpeed.seconds(-0.5), throwsArgumentError);
    });

    test('display 在 ≥1s 时输出秒、<1s 时输出 1/x', () {
      expect(ShutterSpeed.seconds(1).display, '1s');
      expect(ShutterSpeed.seconds(2).display, '2s');
      expect(ShutterSpeed.seconds(30).display, '30s');
      expect(ShutterSpeed.seconds(0.5).display, '1/2');
      expect(ShutterSpeed.seconds(1 / 250).display, '1/250');
      expect(ShutterSpeed.seconds(1 / 1000).display, '1/1000');
    });

    test('display 对长曝光保留 1 位小数', () {
      expect(ShutterSpeed.seconds(1.5).display, '1.5s');
    });

    test('相等性按 seconds 比较', () {
      expect(ShutterSpeed.seconds(0.5), ShutterSpeed.seconds(0.5));
      expect(
        ShutterSpeed.seconds(0.5).hashCode,
        ShutterSpeed.seconds(0.5).hashCode,
      );
    });
  });
}
```

- [ ] **Step 2: 跑测试看到红**

```bash
flutter test test/domain/shared/shutter_speed_test.dart
```
Expected: 失败。

- [ ] **Step 3: 写实现**

写入 `film-go/lib/domain/shared/shutter_speed.dart`：

```dart
import 'package:meta/meta.dart';

@immutable
class ShutterSpeed {
  ShutterSpeed.seconds(this.seconds) {
    if (seconds <= 0) {
      throw ArgumentError.value(seconds, 'seconds', '必须为正数');
    }
  }

  final double seconds;

  String get display {
    if (seconds >= 1) {
      if (seconds == seconds.roundToDouble()) {
        return '${seconds.toStringAsFixed(0)}s';
      }
      return '${seconds.toStringAsFixed(1)}s';
    }
    final denom = (1 / seconds).round();
    return '1/$denom';
  }

  @override
  bool operator ==(Object other) =>
      other is ShutterSpeed && other.seconds == seconds;

  @override
  int get hashCode => seconds.hashCode;
}
```

- [ ] **Step 4: 跑测试看到绿**

```bash
flutter test test/domain/shared/shutter_speed_test.dart
```
Expected: All tests passed!

- [ ] **Step 5: Commit**

```bash
git add film-go/lib/domain/shared/shutter_speed.dart film-go/test/domain/shared/shutter_speed_test.dart
git commit -m "feat(film-go): 增加 ShutterSpeed 值对象（带分数/秒双格式 display）"
```

---

## Task 14: Domain — EV 换算

**Files:**
- Create: `film-go/lib/domain/metering/ev_calculator.dart`
- Create: `film-go/test/domain/metering/ev_calculator_test.dart`

> 公式：EV(at ISO 100) = log2(N² / t)，其中 N=光圈 f 值，t=快门秒数。
> ISO 修正：EV(@ISO) = EV(@100) + log2(ISO/100)。
> 教科书对照 case 来源：Adams "The Negative" / Kodak Pocket Photoguide。

- [ ] **Step 1: 先写测试**

写入 `film-go/test/domain/metering/ev_calculator_test.dart`：

```dart
import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:film_go/domain/shared/aperture.dart';
import 'package:film_go/domain/shared/shutter_speed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EvCalculator.fromExposure', () {
    test('f/1, 1s, ISO 100 = EV 0', () {
      final ev = EvCalculator.fromExposure(
        aperture: Aperture(1),
        shutter: ShutterSpeed.seconds(1),
        iso: 100,
      );
      expect(ev, closeTo(0, 1e-6));
    });

    test('f/16, 1/100s, ISO 100 ≈ EV 15（晴天 Sunny 16）', () {
      final ev = EvCalculator.fromExposure(
        aperture: Aperture(16),
        shutter: ShutterSpeed.seconds(1 / 100),
        iso: 100,
      );
      // log2(16²/(1/100)) = log2(25600) ≈ 14.643（教科书 Sunny 16 取 EV 15，浮动 0.5 内合理）
      expect(ev, closeTo(14.64, 0.01));
    });

    test('ISO 提升 1 档等价于 EV +1', () {
      final at100 = EvCalculator.fromExposure(
        aperture: Aperture(8),
        shutter: ShutterSpeed.seconds(1 / 60),
        iso: 100,
      );
      final at200 = EvCalculator.fromExposure(
        aperture: Aperture(8),
        shutter: ShutterSpeed.seconds(1 / 60),
        iso: 200,
      );
      expect(at200 - at100, closeTo(1.0, 1e-9));
    });
  });

  group('EvCalculator.suggestPairs', () {
    test('给定 EV 与 ISO，输出整档光圈对应的整档快门组合', () {
      final pairs = EvCalculator.suggestPairs(ev: 15, iso: 100);
      // f/16 → 1/100s 附近（Sunny 16）应该出现
      final hasSunny16 = pairs.any(
        (p) =>
            p.aperture == const Aperture(16) &&
            (p.shutter.seconds - 1 / 125).abs() < 1 / 80,
      );
      expect(hasSunny16, isTrue);
      expect(pairs, isNotEmpty);
    });
  });
}
```

- [ ] **Step 2: 跑测试看到红**

```bash
flutter test test/domain/metering/ev_calculator_test.dart
```
Expected: 失败。

- [ ] **Step 3: 写实现**

写入 `film-go/lib/domain/metering/ev_calculator.dart`：

```dart
import 'dart:math' as math;

import 'package:film_go/domain/shared/aperture.dart';
import 'package:film_go/domain/shared/shutter_speed.dart';
import 'package:meta/meta.dart';

@immutable
class ExposurePair {
  const ExposurePair({required this.aperture, required this.shutter});
  final Aperture aperture;
  final ShutterSpeed shutter;
}

class EvCalculator {
  const EvCalculator._();

  /// EV (at given ISO) = log2(N² / t) + log2(ISO / 100)
  static double fromExposure({
    required Aperture aperture,
    required ShutterSpeed shutter,
    required int iso,
  }) {
    final n2OverT = (aperture.fNumber * aperture.fNumber) / shutter.seconds;
    final isoTerm = math.log(iso / 100) / math.ln2;
    final base = math.log(n2OverT) / math.ln2;
    return base + isoTerm;
  }

  /// 给定 EV 与 ISO，遍历整档光圈给出对应快门组合。
  ///
  /// 推荐快门 = N² / 2^(EV - log2(ISO/100))
  static List<ExposurePair> suggestPairs({
    required double ev,
    required int iso,
  }) {
    final isoTerm = math.log(iso / 100) / math.ln2;
    final ev100 = ev - isoTerm;
    final pairs = <ExposurePair>[];
    for (final ap in Aperture.fullStops) {
      final shutterSec = (ap.fNumber * ap.fNumber) / math.pow(2, ev100);
      if (shutterSec <= 0 || shutterSec.isInfinite || shutterSec.isNaN) {
        continue;
      }
      // 限制实用范围：1/8000s ~ 30s
      if (shutterSec < 1 / 8000 || shutterSec > 30) continue;
      pairs.add(
        ExposurePair(
          aperture: ap,
          shutter: ShutterSpeed.seconds(shutterSec),
        ),
      );
    }
    return pairs;
  }
}
```

- [ ] **Step 4: 跑测试看到绿**

```bash
flutter test test/domain/metering/ev_calculator_test.dart
```
Expected: All tests passed!

- [ ] **Step 5: Commit**

```bash
git add film-go/lib/domain/metering/ev_calculator.dart film-go/test/domain/metering/ev_calculator_test.dart
git commit -m "feat(film-go): 实现 EvCalculator（EV 双向换算 + 推荐组合）"
```

---

## Task 15: Domain — 景深 / 超焦距

**Files:**
- Create: `film-go/lib/domain/dof/depth_of_field.dart`
- Create: `film-go/test/domain/dof/depth_of_field_test.dart`

> 公式：
> H = f²/(N·c) + f （超焦距）
> Dn = H·d / (H + (d − f)) （近景）
> Df = H·d / (H − (d − f)) ， d ≥ H 时 Df = ∞ （远景）
>
> 教科书对照（引自 *Kodak Professional Photoguide*）：
> 35mm 画幅 c=0.030mm，50mm 镜头 f/8 → H ≈ 10.5m。

- [ ] **Step 1: 先写测试**

写入 `film-go/test/domain/dof/depth_of_field_test.dart`：

```dart
import 'package:film_go/domain/dof/depth_of_field.dart';
import 'package:film_go/domain/shared/aperture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DepthOfField', () {
    test('35mm + 50mm + f/8，超焦距约 10.5m', () {
      final h = DepthOfField.hyperfocalMeters(
        focalLengthMm: 50,
        aperture: const Aperture(8),
        circleOfConfusionMm: 0.030,
      );
      expect(h, closeTo(10.47, 0.1));
    });

    test('对焦距离等于超焦距时，Df 为无穷', () {
      final result = DepthOfField.compute(
        focalLengthMm: 50,
        aperture: const Aperture(8),
        circleOfConfusionMm: 0.030,
        focusDistanceMeters: 10.47,
      );
      expect(result.farMeters, isNull, reason: '∞ 用 null 表示');
    });

    test('近景 < 对焦距离 < 远景', () {
      final result = DepthOfField.compute(
        focalLengthMm: 50,
        aperture: const Aperture(2.8),
        circleOfConfusionMm: 0.030,
        focusDistanceMeters: 3.0,
      );
      expect(result.nearMeters, lessThan(3.0));
      expect(result.farMeters, isNotNull);
      expect(result.farMeters, greaterThan(3.0));
    });

    test('光圈缩小景深变深（远景延伸）', () {
      double dfAt(double n) {
        final r = DepthOfField.compute(
          focalLengthMm: 50,
          aperture: Aperture(n),
          circleOfConfusionMm: 0.030,
          focusDistanceMeters: 3.0,
        );
        return r.farMeters!;
      }
      expect(dfAt(2.8), lessThan(dfAt(8)));
      expect(dfAt(8), lessThan(dfAt(16)));
    });

    test('CoC ≤ 0 抛 ArgumentError', () {
      expect(
        () => DepthOfField.hyperfocalMeters(
          focalLengthMm: 50,
          aperture: const Aperture(8),
          circleOfConfusionMm: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
```

- [ ] **Step 2: 跑测试看到红**

```bash
flutter test test/domain/dof/depth_of_field_test.dart
```
Expected: 失败。

- [ ] **Step 3: 写实现**

写入 `film-go/lib/domain/dof/depth_of_field.dart`：

```dart
import 'package:film_go/domain/shared/aperture.dart';
import 'package:meta/meta.dart';

@immutable
class DofResult {
  const DofResult({
    required this.nearMeters,
    required this.farMeters,
    required this.hyperfocalMeters,
  });

  /// 近景距离（米）。
  final double nearMeters;

  /// 远景距离（米）；当 ≥ 超焦距时为 null（视为无穷）。
  final double? farMeters;

  /// 超焦距（米）。
  final double hyperfocalMeters;
}

class DepthOfField {
  const DepthOfField._();

  /// H = f²/(N·c) + f
  ///
  /// [focalLengthMm] 焦距，毫米
  /// [aperture] 光圈
  /// [circleOfConfusionMm] 弥散圆，毫米
  ///
  /// 返回值单位：米。
  static double hyperfocalMeters({
    required double focalLengthMm,
    required Aperture aperture,
    required double circleOfConfusionMm,
  }) {
    if (circleOfConfusionMm <= 0) {
      throw ArgumentError.value(
        circleOfConfusionMm,
        'circleOfConfusionMm',
        '必须为正数',
      );
    }
    if (focalLengthMm <= 0) {
      throw ArgumentError.value(focalLengthMm, 'focalLengthMm', '必须为正数');
    }
    final hMm = (focalLengthMm * focalLengthMm) /
            (aperture.fNumber * circleOfConfusionMm) +
        focalLengthMm;
    return hMm / 1000.0;
  }

  static DofResult compute({
    required double focalLengthMm,
    required Aperture aperture,
    required double circleOfConfusionMm,
    required double focusDistanceMeters,
  }) {
    if (focusDistanceMeters <= 0) {
      throw ArgumentError.value(
        focusDistanceMeters,
        'focusDistanceMeters',
        '必须为正数',
      );
    }
    final h = hyperfocalMeters(
      focalLengthMm: focalLengthMm,
      aperture: aperture,
      circleOfConfusionMm: circleOfConfusionMm,
    );
    final fMeters = focalLengthMm / 1000.0;
    final d = focusDistanceMeters;

    final near = (h * d) / (h + (d - fMeters));
    final farDenominator = h - (d - fMeters);
    final double? far;
    if (farDenominator <= 0) {
      far = null; // ∞
    } else {
      far = (h * d) / farDenominator;
    }
    return DofResult(
      nearMeters: near,
      farMeters: far,
      hyperfocalMeters: h,
    );
  }
}
```

- [ ] **Step 4: 跑测试看到绿**

```bash
flutter test test/domain/dof/depth_of_field_test.dart
```
Expected: All tests passed!

- [ ] **Step 5: 跑全量测试 + analyze**

```bash
flutter test && flutter analyze --fatal-infos
```
Expected: 全绿。

- [ ] **Step 6: Commit**

```bash
git add film-go/lib/domain/dof/depth_of_field.dart film-go/test/domain/dof/depth_of_field_test.dart
git commit -m "feat(film-go): 实现 DepthOfField（超焦距 + 景深范围 + 无穷处理）"
```

---

## Task 16: README

**Files:**
- Create: `film-go/README.md`

- [ ] **Step 1: 写 README**

写入 `film-go/README.md`：

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add film-go/README.md
git commit -m "docs(film-go): 增加 README，说明 M0 状态与开发命令"
```

---

## Task 17: 打 M0 完成标签

- [ ] **Step 1: 跑全套验证**

```bash
cd film-go && flutter analyze --fatal-infos && flutter test
```
Expected: 全绿。

- [ ] **Step 2: 在仓根打 tag**

Run（仓根）：
```bash
git tag -a film-go-m0 -m "Film Go M0 skeleton complete"
git log --oneline | head -20
```

- [ ] **Step 3: 确认 tag**

```bash
git tag -l 'film-go-*'
```
Expected: 输出 `film-go-m0`。

---

## 验收清单（M0 完成判据）

- [ ] `flutter analyze --fatal-infos` 全绿
- [ ] `flutter test` 全绿，覆盖以下：
  - AppColors / AppTheme
  - Aperture / ShutterSpeed
  - EvCalculator（含教科书对照 case）
  - DepthOfField（含 ∞ 边界与单调性）
  - Widget 冒烟测试（5 Tab 切换）
- [ ] `flutter run` 真机/模拟器上能正常启动，5 Tab 切换无卡顿
- [ ] CI workflow 至少跑通一次（push 后 GitHub Actions 全绿）
- [ ] 所有 commit 都用了 `type(film-go):` 前缀
- [ ] Tag `film-go-m0` 已打
