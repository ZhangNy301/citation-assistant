#!/bin/bash
# Semantic Scholar 批量搜索（增强版）
# 用法: bash scripts/s2_bulk_search.sh "query" [year_range] [limit]
# 示例: bash scripts/s2_bulk_search.sh "deep learning" "2020-" 50
# 返回: JSON 格式的论文列表，包含作者ID、arXiv判断、推荐建议

set -e

# 初始化
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载配置
if [[ -f "$SKILL_ROOT/.env" ]]; then
    set -a
    source "$SKILL_ROOT/.env"
    set +a
fi

# 参数
QUERY="${1:-}"
YEAR_RANGE="${2:-}"
LIMIT="${3:-50}"
ARXIV_THRESHOLD="${ARXIV_CITATION_THRESHOLD:-100}"

if [[ -z "$QUERY" ]]; then
    echo '{"error": "Usage: bash scripts/s2_bulk_search.sh \"query\" [year_range] [limit]"}' >&2
    echo '{"example": "bash scripts/s2_bulk_search.sh \"deep learning\" \"2020-\" 50"}' >&2
    exit 1
fi

# Rate limiting
RATE_LIMIT_FILE="/tmp/.s2_rate_limit"
MIN_INTERVAL="${S2_MIN_INTERVAL:-1}"

if [[ -f "$RATE_LIMIT_FILE" ]]; then
    last_time=$(cat "$RATE_LIMIT_FILE" 2>/dev/null || echo "0")
    current_time=$(date +%s)
    elapsed=$((current_time - last_time))
    if [[ $elapsed -lt $MIN_INTERVAL ]]; then
        sleep $((MIN_INTERVAL - elapsed))
    fi
fi

# URL 编码查询
ENCODED_QUERY=$(printf '%s' "$QUERY" | jq -sRr @uri)

# 构建请求 URL
API_URL="https://api.semanticscholar.org/graph/v1/paper/search/bulk"
FIELDS="title,year,authors,venue,journal,citationCount,externalIds,url,abstract"

# 构建参数
PARAMS="query=${ENCODED_QUERY}&limit=${LIMIT}&fields=${FIELDS}"
if [[ -n "$YEAR_RANGE" ]]; then
    PARAMS="${PARAMS}&year=${YEAR_RANGE}"
fi

# 执行请求
RESPONSE=$(curl -s -w "\n%{http_code}" \
    "${API_URL}?${PARAMS}" \
    ${S2_API_KEY:+-H "x-api-key: $S2_API_KEY"} \
    --max-time 60 2>/dev/null)

# 更新 rate limit
date +%s > "$RATE_LIMIT_FILE"

# 解析响应
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

# 错误处理
case "$HTTP_CODE" in
    200)
        # 输出统计信息到 stderr，结果到 stdout
        TOTAL=$(echo "$BODY" | jq -r '.total // 0')
        RETURNED=$(echo "$BODY" | jq -r '.data | length')
        echo "{\"total\": $TOTAL, \"returned\": $RETURNED}" >&2

        # 输出格式化的论文列表（增强版）
        echo "$BODY" | jq --arg threshold "$ARXIV_THRESHOLD" '.data[]? |
            # 判断是否为 arXiv
            (.venue // .journal // "") as $venue |
            ($venue | test("(?i)arxiv")) as $is_arxiv |

            # arXiv 引用判断
            (if $is_arxiv and .citationCount < ($threshold | tonumber) then
                "caution"
            elif $is_arxiv and .citationCount >= ($threshold | tonumber) then
                "recommended"
            else
                "normal"
            end) as $arxiv_status |

            # 生成推荐建议
            (if $arxiv_status == "caution" then
                "⚠️ arXiv 低引用(" + (.citationCount | tostring) + ")，谨慎引用"
            elif $arxiv_status == "recommended" then
                "✅ 高影响力 arXiv (" + (.citationCount | tostring) + " 引用)"
            else
                "✅ 正式发表"
            end) as $recommendation |

            {
                title: .title,
                year: .year,
                venue: ($venue // "N/A"),
                citations: .citationCount,
                doi: .externalIds.DOI,
                arxiv_id: .externalIds.ArXiv,
                url: .url,
                abstract: (.abstract // ""),
                is_arxiv: $is_arxiv,
                arxiv_status: $arxiv_status,
                recommendation: $recommendation,
                authors: [.authors[]? | {
                    name: .name,
                    id: .authorId
                }][:3]
            }'
        ;;
    429)
        echo '{"error": "Rate limit exceeded. Wait 60 seconds and retry."}' >&2
        exit 1
        ;;
    *)
        echo "{\"error\": \"HTTP $HTTP_CODE: $(echo "$BODY" | jq -r '.message // .error // "Unknown error"')\"}" >&2
        exit 1
        ;;
esac
