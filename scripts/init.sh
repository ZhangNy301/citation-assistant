#!/bin/bash
# 初始化脚本 - 加载配置和设置路径变量
# 用法: source scripts/init.sh

# 获取 Skill 根目录
if [[ -n "${CLAUDE_SKILL_ROOT:-}" ]]; then
    # 由 Claude Code 自动设置
    SKILL_ROOT="${CLAUDE_SKILL_ROOT}"
else
    # 手动运行时推导
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SKILL_ROOT="$(dirname "$SCRIPT_DIR")"
fi

# 加载 .env 文件（如果存在）
if [[ -f "$SKILL_ROOT/.env" ]]; then
    set -a
    source "$SKILL_ROOT/.env"
    set +a
fi

# 设置数据目录
export SKILL_DATA_DIR="$SKILL_ROOT/data"

# Rate limit 配置
export S2_RATE_LIMIT_FILE="/tmp/.s2_rate_limit"
export S2_MIN_INTERVAL="${S2_MIN_INTERVAL:-1}"  # 默认 1 秒

# 颜色输出（可选）
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export NC='\033[0m' # No Color

# 辅助函数：打印错误
error_msg() {
    echo -e "${RED}Error:${NC} $1" >&2
}

# 辅助函数：打印警告
warn_msg() {
    echo -e "${YELLOW}Warning:${NC} $1" >&2
}

# 辅助函数：打印成功
success_msg() {
    echo -e "${GREEN}✓${NC} $1"
}
