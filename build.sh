#!/bin/bash
# Sobani ビルドスクリプト
# 使い方: ターミナルで ./build.sh を実行
# 環境変数:
#   SOBANI_ARCHS      - ビルドアーキテクチャ (例: "arm64 x86_64")
#   SKIP_CODESIGN=1   - コード署名をスキップ
#   NOTARIZE=1        - Apple 公証を有効化
#   NOTARIZE_PROFILE   - notarytool キーチェーンプロファイル名
#   CREATE_DMG=1       - DMG ファイルを作成
#   APPLE_ID          - Apple ID (公証用)
#   APPLE_ID_PASSWORD  - App 用パスワード (公証用)
#   APPLE_TEAM_ID     - Apple Developer Team ID (公証用)

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="Sobani"

# ユニバーサルバイナリ対応
ARCH_ARGS=()
if [ -n "$SOBANI_ARCHS" ]; then
    ARCH_ARGS+=(ARCHS="$SOBANI_ARCHS" ONLY_ACTIVE_ARCH=NO)
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
    "${ARCH_ARGS[@]}" \
    build

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
/usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations:1 string en" "$PLIST"
echo "🌐 日本語・英語ローカライゼーションを設定しました"

# CFBundleIdentifier のフォールバック（CODE_SIGNING_ALLOWED=NO で変数展開されなかった場合の安全策）
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$PLIST" 2>/dev/null || echo "")
if [ -z "$BUNDLE_ID" ] || [[ "$BUNDLE_ID" == *'$('* ]]; then
    /usr/libexec/PlistBuddy -c "Delete :CFBundleIdentifier" "$PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.shiroemons.Sobani" "$PLIST"
    echo "🔧 CFBundleIdentifier をフォールバック設定しました"
fi

# コード署名
if [ "${SKIP_CODESIGN:-0}" != "1" ]; then
    echo "🔏 コード署名中..."
    xattr -cr "$PROJECT_DIR/$APP_NAME.app"
    codesign --deep --force --verify --verbose \
        --sign "Developer ID Application" \
        --options runtime \
        --entitlements "$PROJECT_DIR/$APP_NAME/Sobani.entitlements" \
        "$PROJECT_DIR/$APP_NAME.app"
    echo "✅ コード署名完了"

    # 公証 (Notarization)
    if [ "${NOTARIZE:-0}" = "1" ]; then
        echo "📤 公証のため Apple に送信中..."
        ZIP_FOR_NOTARIZE="/tmp/${APP_NAME}-notarize.zip"
        ditto -c -k --keepParent "$PROJECT_DIR/$APP_NAME.app" "$ZIP_FOR_NOTARIZE"

        if [ -n "${NOTARIZE_PROFILE:-}" ]; then
            xcrun notarytool submit "$ZIP_FOR_NOTARIZE" \
                --keychain-profile "$NOTARIZE_PROFILE" \
                --wait
        elif [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_ID_PASSWORD:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ]; then
            xcrun notarytool submit "$ZIP_FOR_NOTARIZE" \
                --apple-id "$APPLE_ID" \
                --password "$APPLE_ID_PASSWORD" \
                --team-id "$APPLE_TEAM_ID" \
                --wait
        else
            echo "❌ 公証の認証情報が未設定です"
            echo "  NOTARIZE_PROFILE（キーチェーンプロファイル名）または"
            echo "  APPLE_ID, APPLE_ID_PASSWORD, APPLE_TEAM_ID を設定してください"
            rm -f "$ZIP_FOR_NOTARIZE"
            exit 1
        fi

        rm -f "$ZIP_FOR_NOTARIZE"

        echo "📎 公証チケットをステープル中..."
        xcrun stapler staple "$PROJECT_DIR/$APP_NAME.app"
        echo "✅ 公証完了"
    fi
fi

# DMG 作成
if [ "${CREATE_DMG:-0}" = "1" ]; then
    echo "💿 DMG 作成中..."
    DMG_NAME="${APP_NAME}.dmg"
    DMG_PATH="$PROJECT_DIR/$DMG_NAME"
    DMG_STAGING_DIR="$PROJECT_DIR/dmg_staging"

    rm -f "$DMG_PATH"
    rm -rf "$DMG_STAGING_DIR"
    mkdir -p "$DMG_STAGING_DIR"

    cp -R "$PROJECT_DIR/$APP_NAME.app" "$DMG_STAGING_DIR/"
    create-dmg \
        --volname "$APP_NAME" \
        --volicon "$PROJECT_DIR/$APP_NAME/AppIcon.icns" \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 150 190 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 450 190 \
        --no-internet-enable \
        "$DMG_PATH" \
        "$DMG_STAGING_DIR"

    rm -rf "$DMG_STAGING_DIR"

    # DMG の公証（アプリが公証済みの場合）
    if [ "${NOTARIZE:-0}" = "1" ] && [ "${SKIP_CODESIGN:-0}" != "1" ]; then
        echo "📤 DMG を公証中..."
        if [ -n "${NOTARIZE_PROFILE:-}" ]; then
            xcrun notarytool submit "$DMG_PATH" \
                --keychain-profile "$NOTARIZE_PROFILE" \
                --wait
        elif [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_ID_PASSWORD:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ]; then
            xcrun notarytool submit "$DMG_PATH" \
                --apple-id "$APPLE_ID" \
                --password "$APPLE_ID_PASSWORD" \
                --team-id "$APPLE_TEAM_ID" \
                --wait
        fi
        xcrun stapler staple "$DMG_PATH"
        echo "✅ DMG 公証完了"
    fi

    echo "💿 $DMG_NAME を作成しました"
fi

rm -rf "$BUILD_DIR"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")

echo ""
echo "✅ ビルド完了！ (v${VERSION})"
echo "📍 $PROJECT_DIR/$APP_NAME.app"
if [ "${SKIP_CODESIGN:-0}" != "1" ]; then
    if [ "${NOTARIZE:-0}" = "1" ]; then
        echo "🔏 署名済み・公証済み"
    else
        echo "🔏 署名済み（公証なし：NOTARIZE=1 で公証を有効化）"
    fi
else
    echo "⚠️  未署名（SKIP_CODESIGN=1 が設定されています）"
fi
if [ "${CREATE_DMG:-0}" = "1" ]; then
    echo "💿 $PROJECT_DIR/$APP_NAME.dmg"
fi
echo ""
echo "ダブルクリックで起動できます"
