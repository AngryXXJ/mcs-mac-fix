#!/usr/bin/env bash
# 用 CrossOver 容器里自带的 csc.exe 编译 MCSResolutionFix.dll。
# Mac 上不需要安装 .NET SDK —— CrossOver 26 自带可用的 CLR 和编译器。
set -euo pipefail

# ---- 可按需修改 ----------------------------------------------------------
BOTTLE="${BOTTLE:-Steam}"                 # CrossOver 容器名
STEAM_APPS="$HOME/Library/Application Support/CrossOver/Bottles/$BOTTLE/drive_c/Program Files (x86)/Steam/steamapps"
GAME="${GAME:-$STEAM_APPS/common/觅长生}"                 # 游戏目录
BEPINEX="${BEPINEX:-$STEAM_APPS/workshop/content/1189490/2824349934/BepInEx}"
PLUGINS="${PLUGINS:-$BEPINEX/plugins}"                    # 编译产物输出目录
OUT="${OUT:-MCSResolutionFix.dll}"
# -------------------------------------------------------------------------

CX_WINE="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
CSC="C:\\windows\\Microsoft.NET\\Framework64\\v4.0.30319\\csc.exe"

SRC="$(cd "$(dirname "$0")" && pwd)/src/Plugin.cs"
MANAGED="$GAME/觅长生_Data/Managed"
CORE="$BEPINEX/core"

# 容器内的纯 ASCII 构建目录：中文路径传给 csc/wine 容易出问题，先拷出来再编。
WORK_NAME="mcsbuild"
WORK_UNIX="$HOME/Library/Application Support/CrossOver/Bottles/$BOTTLE/drive_c/$WORK_NAME"
WORK_WIN="C:\\$WORK_NAME"

for f in "$SRC" "$MANAGED/Assembly-CSharp.dll" "$CORE/BepInEx.dll" "$CORE/0Harmony.dll"; do
  [ -f "$f" ] || { echo "找不到: $f" >&2; exit 1; }
done
[ -x "$CX_WINE" ] || { echo "找不到 CrossOver: $CX_WINE" >&2; exit 1; }

echo "==> 准备编译目录 $WORK_UNIX"
rm -rf "$WORK_UNIX"
mkdir -p "$WORK_UNIX"

cp "$SRC"                                                              "$WORK_UNIX/Plugin.cs"
cp "$MANAGED/Assembly-CSharp.dll"                                      "$WORK_UNIX/"
cp "$MANAGED/UnityEngine.dll" "$MANAGED/UnityEngine.CoreModule.dll"    "$WORK_UNIX/"
cp "$MANAGED/UnityEngine.UI.dll"                                       "$WORK_UNIX/"
cp "$CORE/BepInEx.dll" "$CORE/0Harmony.dll"                            "$WORK_UNIX/"

echo "==> 编译"
"$CX_WINE" --bottle "$BOTTLE" --cx-app "$CSC" /nologo /target:library /codepage:65001 \
  "/out:$WORK_WIN\\$OUT" \
  "/r:$WORK_WIN\\BepInEx.dll" \
  "/r:$WORK_WIN\\0Harmony.dll" \
  "/r:$WORK_WIN\\Assembly-CSharp.dll" \
  "/r:$WORK_WIN\\UnityEngine.dll" \
  "/r:$WORK_WIN\\UnityEngine.CoreModule.dll" \
  "/r:$WORK_WIN\\UnityEngine.UI.dll" \
  "$WORK_WIN\\Plugin.cs"

echo "==> 部署到 $PLUGINS"
mkdir -p "$PLUGINS"
cp "$WORK_UNIX/$OUT" "$PLUGINS/$OUT"
ls -la "$PLUGINS/$OUT"
echo "==> 完成。重启游戏后查看 LogOutput.log 确认加载。"
