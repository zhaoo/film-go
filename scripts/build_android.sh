#!/usr/bin/env bash
#
# Film Go - Android 一键打包脚本
#
# 默认产出 arm64-v8a release APK（适配小米 14 / 骁龙 8 Gen 3 等现代旗舰）。
#
# 用法：
#   ./scripts/build_android.sh                # 仅打包
#   ./scripts/build_android.sh --install      # 打包后通过 adb install 推送到已连接设备
#   ./scripts/build_android.sh --run          # 打包 + 安装 + 启动 App
#   ./scripts/build_android.sh --all-abi      # 同时产出 armeabi-v7a / arm64-v8a / x86_64 三份
#   ./scripts/build_android.sh --debug        # debug 构建（默认 release）
#
# 输出目录：./dist/
#

set -euo pipefail

cd "$(dirname "$0")/.."

# 自动探测 JAVA_HOME（Flutter Gradle 需要 JDK 17+）
if [ -z "${JAVA_HOME:-}" ]; then
  for cand in \
      /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home \
      /usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home \
      "/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
      /Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home; do
    if [ -d "$cand" ]; then
      export JAVA_HOME="$cand"
      break
    fi
  done
fi
if [ -n "${JAVA_HOME:-}" ]; then
  export PATH="${JAVA_HOME}/bin:${PATH}"
fi

# 自动探测 Android SDK
if [ -z "${ANDROID_HOME:-}" ]; then
  for cand in \
      /opt/homebrew/share/android-commandlinetools \
      "$HOME/Library/Android/sdk" \
      /usr/local/share/android-commandlinetools; do
    if [ -d "$cand" ]; then
      export ANDROID_HOME="$cand"
      export ANDROID_SDK_ROOT="$cand"
      break
    fi
  done
fi

INSTALL=0
RUN=0
ALL_ABI=0
BUILD_MODE="release"

for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=1 ;;
    --run) INSTALL=1; RUN=1 ;;
    --all-abi) ALL_ABI=1 ;;
    --debug) BUILD_MODE="debug" ;;
    --release) BUILD_MODE="release" ;;
    -h|--help)
      sed -n '2,18p' "$0"
      exit 0
      ;;
    *)
      echo "未知参数: $arg" >&2
      exit 2
      ;;
  esac
done

VERSION=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')
TS=$(date +%Y%m%d-%H%M%S)
DIST_DIR="dist"
mkdir -p "$DIST_DIR"

echo "==> Flutter 版本"
flutter --version | head -1
echo "==> 应用版本：${VERSION}"
echo "==> 构建模式：${BUILD_MODE}"

echo "==> 清理 pub 缓存（可选可注释）"
flutter pub get

BUILD_ARGS=("--${BUILD_MODE}")
if [ "$ALL_ABI" -eq 1 ]; then
  BUILD_ARGS+=(--split-per-abi)
else
  BUILD_ARGS+=(--target-platform android-arm64)
fi

echo "==> flutter build apk ${BUILD_ARGS[*]}"
flutter build apk "${BUILD_ARGS[@]}"

OUT_DIR="build/app/outputs/flutter-apk"
COPIED=()

if [ "$ALL_ABI" -eq 1 ]; then
  for abi in armeabi-v7a arm64-v8a x86_64; do
    SRC="${OUT_DIR}/app-${abi}-${BUILD_MODE}.apk"
    if [ -f "$SRC" ]; then
      DEST="${DIST_DIR}/film_go-${VERSION}-${abi}-${BUILD_MODE}-${TS}.apk"
      cp "$SRC" "$DEST"
      COPIED+=("$DEST")
    fi
  done
else
  SRC="${OUT_DIR}/app-${BUILD_MODE}.apk"
  DEST="${DIST_DIR}/film_go-${VERSION}-arm64-v8a-${BUILD_MODE}-${TS}.apk"
  cp "$SRC" "$DEST"
  COPIED+=("$DEST")
fi

echo
echo "==> 产物："
for f in "${COPIED[@]}"; do
  size=$(du -h "$f" | awk '{print $1}')
  echo "    ${f}  (${size})"
done

if [ "$INSTALL" -eq 1 ]; then
  if ! command -v adb >/dev/null 2>&1; then
    echo "未找到 adb，跳过安装。请先安装 Android Platform Tools 并加入 PATH。" >&2
    exit 0
  fi
  TARGET="${COPIED[0]}"
  if [ "$ALL_ABI" -eq 1 ]; then
    for f in "${COPIED[@]}"; do
      [[ "$f" == *arm64-v8a* ]] && TARGET="$f"
    done
  fi
  echo
  echo "==> adb install -r ${TARGET}"
  adb install -r "$TARGET"

  if [ "$RUN" -eq 1 ]; then
    PKG=$(grep -E '^\s*applicationId' android/app/build.gradle | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -n "$PKG" ]; then
      echo "==> adb shell monkey -p ${PKG} 1"
      adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
    fi
  fi
fi

echo
echo "==> 完成。"
