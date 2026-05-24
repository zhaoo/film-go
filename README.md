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

## 打包安卓 APK

一键脚本（默认产出 **arm64-v8a release**，适配小米 14 / 骁龙 8 Gen 3 等现代旗舰）：

```bash
./scripts/build_android.sh                # 仅打包
./scripts/build_android.sh --install      # 打包 + adb install 到已连接设备
./scripts/build_android.sh --run          # 打包 + 安装 + 启动 App
./scripts/build_android.sh --all-abi      # 同时产出 armeabi-v7a / arm64-v8a / x86_64 三份
./scripts/build_android.sh --debug        # debug 构建（默认 release）
```

产物会被复制到 `dist/`，文件名带版本号与时间戳：

```
dist/film_go-1.0.0+1-arm64-v8a-release-20260524-122846.apk
```

### 环境依赖

脚本会按下面的顺序自动探测，找到即用，不需要手动 `export`：

| 工具 | 探测顺序 |
| --- | --- |
| JDK 17 | `/opt/homebrew/opt/openjdk@17` → `/usr/local/opt/openjdk@17` → Android Studio 内置 jbr → Temurin 17 |
| Android SDK | `/opt/homebrew/share/android-commandlinetools` → `~/Library/Android/sdk` → `/usr/local/share/android-commandlinetools` |

如果都没装，手动安装一次即可：

```bash
brew install --cask temurin@17
brew install --cask android-commandlinetools
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
```

### 安装到小米 14

USB 调试已开启的情况下：

```bash
./scripts/build_android.sh --run
```

或手工传 APK：

```bash
adb install -r dist/film_go-*-arm64-v8a-release-*.apk
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
