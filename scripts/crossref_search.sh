#!/bin/bash
# CrossRef 搜索（Semantic Scholar 的 fallback）
# 用法: bash scripts/crossref_search.sh "query" [limit] [all|papers]
# 特点: 独立的文献元数据来源，适合作为 fallback（仍可能受限）
# 返回: JSON 格式的论文列表

set -e

# 参数
QUERY="${1:-}"
LIMIT="${2:-20}"
SCOPE="${3:-all}"

if [[ -z "$QUERY" ]]; then
    echo '{"error": "Usage: bash scripts/crossref_search.sh \"query\" [limit]"}' >&2
    exit 1
fi

if ! [[ "$LIMIT" =~ ^[1-9][0-9]{0,3}$ ]] || (( LIMIT > 1000 )); then
    echo '{"error":"limit must be an integer between 1 and 1000"}' >&2
    exit 1
fi

if [[ "$SCOPE" != all && "$SCOPE" != papers ]]; then
    echo '{"error":"scope must be all or papers"}' >&2
    exit 1
fi

# URL 编码查询
ENCODED_QUERY=$(printf '%s' "$QUERY" | jq -sRr @uri)

# CrossRef API
API_URL="https://api.crossref.org/works"
FIELDS="type,DOI,title,author,published-print,published-online,container-title,is-referenced-by-count,URL"

REQUEST_URL="${API_URL}?query=${ENCODED_QUERY}&rows=${LIMIT}&select=${FIELDS}"
if [[ "$SCOPE" == papers ]]; then
    # Repeated type filters are ORed by CrossRef. Exclude supplements/components.
    REQUEST_URL="${REQUEST_URL}&filter=type:journal-article,type:proceedings-article,type:posted-content"
fi

# 执行请求
if ! RESPONSE=$(curl -s -w "\n%{http_code}" \
    "$REQUEST_URL" \
    --max-time 30 2>/dev/null); then
    echo '{"error":"CrossRef network request failed"}' >&2
    exit 1
fi
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')
if [[ "$HTTP_CODE" != 200 ]]; then
    jq -cn --arg status "$HTTP_CODE" '{error: ("CrossRef HTTP " + $status)}' >&2
    exit 1
fi

# A valid empty result list is success; malformed/non-JSON errors are not.
if ! echo "$BODY" | jq -e '.message.items | type == "array"' >/dev/null 2>&1; then
    echo '{"error":"CrossRef returned an invalid response"}' >&2
    exit 1
fi

# 格式化输出（统一为与 s2_search 相同的格式）
echo "$BODY" | jq '.message.items[]? | {
    title: (.title[0] // "N/A"),
    work_type: .type,
    year: ((.["published-print"]["date-parts"][0][0] // .["published-online"]["date-parts"][0][0]) // null),
    venue: (.["container-title"][0] // "N/A"),
    citations: (.["is-referenced-by-count"] // null),
    doi: .DOI,
    url: .URL,
    author_details: [.author[]? | {
        name: (((.given // "") + " " + (.family // "")) | ltrimstr(" ") | rtrimstr(" ")),
        id: null
    }][:3],
    authors: ([.author[]? | ((.given // "") + " " + (.family // ""))][:3] | if length > 0 then join(", ") + (if length > 3 then " et al." else "" end) else "N/A" end)
}'
