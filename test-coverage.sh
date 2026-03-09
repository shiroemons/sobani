#!/bin/bash
# テストカバレッジ計測スクリプト
set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$SCRIPT_DIR/tmp"
XCRESULT="$TMP_DIR/test-result.xcresult"
COVERAGE_JSON="$TMP_DIR/coverage-report.json"
TEST_LOG="$TMP_DIR/xcodebuild-test.log"

# tmp ディレクトリ準備
mkdir -p "$TMP_DIR"
rm -rf "$XCRESULT"

# テスト実行（カバレッジ有効）
echo "🧪 テスト実行中..."
xcodebuild test \
  -project "$SCRIPT_DIR/Sobani.xcodeproj" \
  -scheme Sobani \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
  -enableCodeCoverage YES \
  -resultBundlePath "$XCRESULT" \
  2>&1 | tee "$TEST_LOG"

# テスト失敗チェック
if grep -q "TEST.*FAILED" "$TEST_LOG" 2>/dev/null; then
  echo ""
  echo "⚠️  テスト失敗あり:"
  grep "TEST.*FAILED\|Executed.*with.*failure" "$TEST_LOG" || true
  echo ""
fi

# カバレッジレポート生成
echo "📊 カバレッジレポート生成中..."
xcrun xccov view --report --json "$XCRESULT" > "$COVERAGE_JSON"

# サマリー表示
jq -r '
  .targets[] | select(.name | contains("Sobani.app")) |
  "\n📊 全体カバレッジ: \(.lineCoverage * 100 | . * 10 | round / 10)% (\(.coveredLines)/\(.executableLines) lines)\n",
  "ファイル                                              カバレッジ       行数",
  "========================================================================",
  (.files | sort_by(.lineCoverage) | .[] |
    "\(.name | .[0:50] | . + (" " * (50 - length)))  \(.lineCoverage * 100 | . * 10 | round / 10)%  \(.coveredLines)/\(.executableLines)\(if .lineCoverage < 0.3 then " ⚠️" else "" end)")
' "$COVERAGE_JSON"

echo ""
echo "✅ カバレッジレポート完了"
echo "📍 ログ: $TEST_LOG"
echo "📍 レポート: $COVERAGE_JSON"
