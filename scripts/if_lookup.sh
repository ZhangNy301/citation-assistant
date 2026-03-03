#!/bin/bash
# 影响因子查询
# 用法: bash scripts/if_lookup.sh "journal_name"
# 示例: bash scripts/if_lookup.sh "Nature Medicine"
# 返回: 影响因子和分区信息（JSON 格式）

set -e

# 初始化
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$SKILL_ROOT/data"

# 参数
NAME="${1:-}"

if [[ -z "$NAME" ]]; then
    echo '{"error": "Usage: bash scripts/if_lookup.sh \"journal_name\""}' >&2
    exit 1
fi

# 检查数据库
DB_FILE="$DATA_DIR/impact_factor.sqlite3"
if [[ ! -f "$DB_FILE" ]]; then
    echo "{\"error\": \"Impact factor database not found. Download from: https://github.com/suqingdong/impact_factor\"}" >&2
    exit 1
fi

# 查询（使用 LIKE 匹配）
sqlite3 "$DB_FILE" -json \
    "SELECT journal, factor, jcr, zky
     FROM factor
     WHERE journal LIKE '%${NAME}%'
     ORDER BY factor DESC
     LIMIT 5;" 2>/dev/null | jq '.[]?' || echo '[]'
