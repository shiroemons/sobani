#!/bin/bash
# Sobani ビルドスクリプト
# 使い方: ターミナルで ./build.sh を実行

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="Sobani"

# ユニバーサルバイナリ対応
ARCH_FLAGS=""
if [ -n "$SOBANI_ARCHS" ]; then
    ARCH_FLAGS="ARCHS=$SOBANI_ARCHS ONLY_ACTIVE_ARCH=NO"
    echo "🏗️  アーキテクチャ: $SOBANI_ARCHS"
fi

# 既存のアプリがあれば削除
if [ -d "$PROJECT_DIR/$APP_NAME.app" ]; then
    rm -rf "$PROJECT_DIR/$APP_NAME.app"
    echo "🗑️  既存の $APP_NAME.app を削除しました"
fi

# SwiftLint チェック
if command -v swiftlint >/dev/null 2>&1; then
    echo "🔍 SwiftLint チェック中..."
    if swiftlint --strict; then
        echo "✅ SwiftLint: 問題なし"
    else
        echo "❌ SwiftLint: 問題が見つかりました"
        exit 1
    fi
else
    echo "⚠️  SwiftLint が未インストールです（brew install swiftlint）"
fi

echo "🔨 ビルド中..."

xcodebuild \
    -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    $ARCH_FLAGS \
    build \
    2>&1 | tail -5

# .appを探してプロジェクトフォルダにコピー
APP_PATH=$(find "$BUILD_DIR" -name "$APP_NAME.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ ビルドに失敗しました"
    exit 1
fi

cp -R "$APP_PATH" "$PROJECT_DIR/$APP_NAME.app"

# .icnsファイルをアプリに埋め込む
ICNS_FILE="$PROJECT_DIR/$APP_NAME/AppIcon.icns"
if [ -f "$ICNS_FILE" ]; then
    cp "$ICNS_FILE" "$PROJECT_DIR/$APP_NAME.app/Contents/Resources/AppIcon.icns"
    # Info.plistにアイコン設定を追加
    /usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$PROJECT_DIR/$APP_NAME.app/Contents/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$PROJECT_DIR/$APP_NAME.app/Contents/Info.plist"
    echo "🎨 アイコンを設定しました"
fi

# アプリの言語を日本語に設定（システムUIボタンが日本語になる）
PLIST="$PROJECT_DIR/$APP_NAME.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Delete :CFBundleDevelopmentRegion" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDevelopmentRegion string ja" "$PLIST"
/usr/libexec/PlistBuddy -c "Delete :CFBundleLocalizations" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations:0 string ja" "$PLIST"
echo "🌐 日本語ローカライゼーションを設定しました"

rm -rf "$BUILD_DIR"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")

echo ""
echo "✅ ビルド完了！ (v${VERSION})"
echo "📍 $PROJECT_DIR/$APP_NAME.app"
echo ""
echo "ダブルクリックで起動できます"
