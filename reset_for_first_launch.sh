#!/bin/bash
# Sobani 初回起動ユーザー再現用リセットスクリプト
# アプリデータ・UserDefaults をすべて削除し、初回起動状態に戻します。

set -euo pipefail

BUNDLE_ID="com.shiroemons.Sobani"
CONTAINER_DIR="$HOME/Library/Containers/$BUNDLE_ID"
CONTAINER_APP_SUPPORT="$CONTAINER_DIR/Data/Library/Application Support/Sobani"
APP_SUPPORT_DIR="$HOME/Library/Application Support/Sobani"

echo "=== Sobani 初期化スクリプト ==="
echo ""

# Sobani が起動中なら終了させる
if pgrep -x "Sobani" > /dev/null 2>&1; then
    echo "[1/4] Sobani を終了しています..."
    pkill -x "Sobani" || true
    sleep 1
else
    echo "[1/4] Sobani は起動していません"
fi

# UserDefaults を削除（サンドボックス・非サンドボックス両方の plist を直接削除）
echo "[2/4] UserDefaults を削除しています..."
SANDBOX_PLIST="$CONTAINER_DIR/Data/Library/Preferences/$BUNDLE_ID.plist"
NONSANDBOX_PLIST="$HOME/Library/Preferences/$BUNDLE_ID.plist"
deleted=false
if [ -f "$SANDBOX_PLIST" ]; then
    rm -f "$SANDBOX_PLIST"
    echo "  - サンドボックス plist を削除しました"
    deleted=true
fi
if [ -f "$NONSANDBOX_PLIST" ]; then
    rm -f "$NONSANDBOX_PLIST"
    echo "  - 非サンドボックス plist を削除しました"
    deleted=true
fi
if [ "$deleted" = false ]; then
    echo "  - plist は存在しませんでした"
fi
# cfprefsd のキャッシュをクリア
killall cfprefsd 2>/dev/null || true

# サンドボックスコンテナ内のアプリデータを削除
echo "[3/4] サンドボックスコンテナ内のアプリデータを削除しています..."
if [ -d "$CONTAINER_APP_SUPPORT" ]; then
    rm -rf "$CONTAINER_APP_SUPPORT"
    echo "  - $CONTAINER_APP_SUPPORT を削除しました"
else
    echo "  - サンドボックスコンテナ内のアプリデータは存在しませんでした"
fi

# 非サンドボックスのアプリケーションサポートディレクトリを削除
echo "[4/4] アプリデータを削除しています..."
if [ -d "$APP_SUPPORT_DIR" ]; then
    rm -rf "$APP_SUPPORT_DIR"
    echo "  - $APP_SUPPORT_DIR を削除しました"
else
    echo "  - $APP_SUPPORT_DIR は存在しませんでした"
fi

echo ""
echo "初期化が完了しました。Sobani を起動すると初回起動状態になります。"
