#!/bin/bash
# 期刊/会议综合查询（CCF + IF + 分区）
# 用法: bash scripts/venue_info.sh "venue_name"
# 示例: bash scripts/venue_info.sh "Nature Medicine"
# 返回: 综合质量信息（JSON 格式）

set -e

# 初始化
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$SKILL_ROOT/data"

# 参数
NAME="${1:-}"

if [[ -z "$NAME" ]]; then
    echo '{"error": "Usage: bash scripts/venue_info.sh \"venue_name\""}' >&2
    exit 1
fi

# CCF 数据库
CCF_DB="$DATA_DIR/ccf_2022.sqlite"
# IF 数据库
IF_DB="$DATA_DIR/impact_factor.sqlite3"

# 查询 CCF
ccf_result="[]"
if [[ -f "$CCF_DB" ]]; then
    ccf_result=$(sqlite3 "$CCF_DB" -json \
        "SELECT acronym, name, rank, field, type
         FROM ccf_2022
         WHERE acronym_alnum LIKE '%${NAME}%'
            OR name LIKE '%${NAME}%'
         LIMIT 3;" 2>/dev/null)
    if [[ -z "$ccf_result" ]]; then
        ccf_result="[]"
    fi
fi

# 查询 IF
if_result="[]"
if [[ -f "$IF_DB" ]]; then
    if_result=$(sqlite3 "$IF_DB" -json \
        "SELECT journal, factor, jcr, zky
         FROM factor
         WHERE journal LIKE '%${NAME}%'
         ORDER BY factor DESC
         LIMIT 3;" 2>/dev/null)
    if [[ -z "$if_result" ]]; then
        if_result="[]"
    fi
fi

# 提取摘要信息
ccf_rank=$(echo "$ccf_result" | jq -r '.[0].rank // empty')
jcr_quartile=$(echo "$if_result" | jq -r '.[0].jcr // empty')
cas_quartile=$(echo "$if_result" | jq -r '.[0].zky // empty')
impact_factor=$(echo "$if_result" | jq -r '.[0].factor // empty')

# 构建输出
jq -n \
    --arg query "$NAME" \
    --arg ccf_rank "$ccf_rank" \
    --arg jcr "$jcr_quartile" \
    --arg cas "$cas_quartile" \
    --arg if "$impact_factor" \
    --argjson ccf "$ccf_result" \
    --argjson impact "$if_result" \
    '{
        query: $query,
        summary: {
            ccf_rank: (if $ccf_rank != "" then $ccf_rank else null end),
            jcr_quartile: (if $jcr != "" then $jcr else null end),
            cas_quartile: (if $cas != "" then $cas else null end),
            impact_factor: (if $if != "" then ($if | tonumber) else null end)
        },
        ccf_details: $ccf,
        impact_details: $impact
    }'
