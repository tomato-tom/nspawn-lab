#!/bin/bash
# lib/assert.sh - シェルスクリプト用アサーション関数

# グローバル変数
ASSERT_COUNT=0
ASSERT_FAILED=0

# 色付きメッセージ用の定数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 基本的なアサーション関数
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"
    
    ASSERT_COUNT=$((ASSERT_COUNT + 1))
    
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓ PASS${NC}: ${message}"
    else
        echo -e "${RED}✗ FAIL${NC}: ${message}"
        echo -e "  Expected: ${YELLOW}$expected${NC}"
        echo -e "  Actual:   ${YELLOW}$actual${NC}"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
    fi
}

# 真偽値のアサーション
assert_true() {
    local condition="$1"
    local message="${2:-}"
    
    ASSERT_COUNT=$((ASSERT_COUNT + 1))
    
    if [ "$condition" = "true" ] || [ "$condition" = "0" ]; then
        echo -e "${GREEN}✓ PASS${NC}: ${message}"
    else
        echo -e "${RED}✗ FAIL${NC}: ${message}"
        echo -e "  Expected: ${YELLOW}true${NC}"
        echo -e "  Actual:   ${YELLOW}$condition${NC}"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-}"
    
    ASSERT_COUNT=$((ASSERT_COUNT + 1))
    
    if [ "$condition" = "false" ] || [ "$condition" != "0" ]; then
        echo -e "${GREEN}✓ PASS${NC}: ${message}"
    else
        echo -e "${RED}✗ FAIL${NC}: ${message}"
        echo -e "  Expected: ${YELLOW}false${NC}"
        echo -e "  Actual:   ${YELLOW}$condition${NC}"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
    fi
}

# コマンドの成功/失敗をテスト
assert_success() {
    local command="$1"
    local message="${2:-}"
    
    ASSERT_COUNT=$((ASSERT_COUNT + 1))
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: ${message}"
    else
        echo -e "${RED}✗ FAIL${NC}: ${message}"
        echo -e "  Command failed: ${YELLOW}$command${NC}"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
    fi
}

assert_failure() {
    local command="$1"
    local message="${2:-}"
    
    ASSERT_COUNT=$((ASSERT_COUNT + 1))
    
    if ! eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: ${message}"
    else
        echo -e "${RED}✗ FAIL${NC}: ${message}"
        echo -e "  Command should have failed: ${YELLOW}$command${NC}"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
    fi
}

# ファイル存在チェック
assert_file_exists() {
    local filepath="$1"
    local message="${2:-}"
    
    ASSERT_COUNT=$((ASSERT_COUNT + 1))
    
    if [ -f "$filepath" ]; then
        echo -e "${GREEN}✓ PASS${NC}: ${message}"
    else
        echo -e "${RED}✗ FAIL${NC}: ${message}"
        echo -e "  File not found: ${YELLOW}$filepath${NC}"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
    fi
}

# 数値比較
assert_greater() {
    local actual="$1"
    local expected="$2"
    local message="${3:-}"
    
    ASSERT_COUNT=$((ASSERT_COUNT + 1))
    
    if [ "$actual" -gt "$expected" ]; then
        echo -e "${GREEN}✓ PASS${NC}: ${message}"
    else
        echo -e "${RED}✗ FAIL${NC}: ${message}"
        echo -e "  Expected: ${YELLOW}$actual > $expected${NC}"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
    fi
}

# 文字列が含まれているかチェック
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"
    
    ASSERT_COUNT=$((ASSERT_COUNT + 1))
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}✓ PASS${NC}: ${message}"
    else
        echo -e "${RED}✗ FAIL${NC}: ${message}"
        echo -e "  String '${YELLOW}$needle${NC}' not found in '${YELLOW}$haystack${NC}'"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
    fi
}

# テスト結果の要約を表示
assert_report() {
    echo ""
    echo "=========================================="
    if [ "$ASSERT_FAILED" -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC} ($ASSERT_COUNT/$ASSERT_COUNT)"
    else
        echo -e "${RED}$ASSERT_FAILED tests failed.${NC} ($((ASSERT_COUNT - ASSERT_FAILED))/$ASSERT_COUNT passed)"
    fi
    echo "=========================================="
    
    # 失敗があった場合は非ゼロで終了
    if [ "$ASSERT_FAILED" -gt 0 ]; then
        exit 1
    fi
}

# テストの初期化
assert_init() {
    ASSERT_COUNT=0
    ASSERT_FAILED=0
    echo "Starting tests..."
    echo ""
}
