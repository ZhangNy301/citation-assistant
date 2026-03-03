#!/bin/bash
# CrossRef 搜索（Semantic Scholar 的 fallback）
# 用法: bash scripts/crossref_search.sh "query" [limit]
# 特点: 免费，无严格速率限制，适合作为 fallback
# 返回: JSON 格式的论文列表

set -e

# 参数
QUERY="${1:-}"
LIMIT="${2:-20}"

if [[ -z "$QUERY" ]]; then
    echo '{"error": "Usage: bash scripts/crossref_search.sh \"query\" [limit]"}' >&2
    exit 1
fi

# URL 编码查询
ENCODED_QUERY=$(printf '%s' "$QUERY" | jq -sRr @uri)

# CrossRef API
API_URL="https://api.crossref.org/works"
FIELDS="DOI,title,author,published-print,published-online,container-title,is-referenced-by-count,URL"

# 执行请求
RESPONSE=$(curl -s \
    "${API_URL}?query=${ENCODED_QUERY}&rows=${LIMIT}&select=${FIELDS}" \
    --max-time 30 2>/dev/null)

# 检查响应
if [[ -z "$RESPONSE" ]] || echo "$RESPONSE" | jq -e '.message == null' > /dev/null 2>&1; then
    echo '{"error": "CrossRef API request failed"}' >&2
    exit 1
fi

# 格式化输出（统一为与 s2_search 相同的格式）
echo "$RESPONSE" | jq '.message.items[]? | {
    title: (.title[0] // "N/A"),
    year: ((.["published-print"]["date-parts"][0][0] // .["published-online"]["date-parts"][0][0]) // null),
    venue: (.["container-title"][0] // "N/A"),
    citations: (.["is-referenced-by-count"] // 0),
    doi: .DOI,
    url: .URL,
    authors: ([.author[]? | ((.given // "") + " " + (.family // ""))][:3] | if length > 0 then join(", ") + (if length > 3 then " et al." else "" end) else "N/A" end)
}'
