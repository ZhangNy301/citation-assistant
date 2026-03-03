#!/bin/bash
# CCF 分级查询
# 用法: bash scripts/ccf_lookup.sh "venue_name"
# 示例: bash scripts/ccf_lookup.sh "TMI"
# 返回: CCF 分级信息（JSON 格式）

set -e

# 初始化
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$SKILL_ROOT/data"

# 参数
NAME="${1:-}"

if [[ -z "$NAME" ]]; then
    echo '{"error": "Usage: bash scripts/ccf_lookup.sh \"venue_name\""}' >&2
    exit 1
fi

# 检查数据库
DB_FILE="$DATA_DIR/ccf_2022.sqlite"
if [[ ! -f "$DB_FILE" ]]; then
    echo "{\"error\": \"CCF database not found at $DB_FILE\"}" >&2
    exit 1
fi

# 查询（转为小写匹配）
sqlite3 "$DB_FILE" -json \
    "SELECT acronym, name, rank, field, type, publisher, url
     FROM ccf_2022
     WHERE acronym_alnum LIKE '%${NAME}%'
        OR name LIKE '%${NAME}%'
     LIMIT 5;" 2>/dev/null | jq '.[]?' || echo '[]'
