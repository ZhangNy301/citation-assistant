#!/bin/bash
# 作者信息查询（H-index、引用量、论文数）
# 用法: bash scripts/author_info.sh "author_id"
# 示例: bash scripts/author_info.sh "1699545"
# 返回: JSON 格式的作者信息

set -e

# 初始化
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/init.sh"
source "$SCRIPT_DIR/s2_request.sh"

# 参数
AUTHOR_ID="${1:-}"

if [[ -z "$AUTHOR_ID" ]]; then
    echo '{"error": "Usage: bash scripts/author_info.sh \"author_id\""}' >&2
    exit 1
fi

# 构建请求
API_URL="https://api.semanticscholar.org/graph/v1/author/${AUTHOR_ID}"
FIELDS="name,hIndex,citationCount,paperCount,affiliations,homepage,url"

# 执行请求
RESPONSE=$(s2_request "${API_URL}?fields=${FIELDS}" 30)

# 解析响应
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

# 错误处理
case "$HTTP_CODE" in
    200)
        echo "$BODY" | jq '{
            name: .name,
            hIndex: .hIndex,
            citations: .citationCount,
            papers: .paperCount,
            affiliations: (.affiliations // []),
            homepage: .homepage,
            url: .url
        }'
        ;;
    404)
        echo '{"error": "Author not found"}' >&2
        exit 1
        ;;
    401|403)
        echo '{"error":"Semantic Scholar authentication or permission denied. Check S2_API_KEY and endpoint access."}' >&2
        exit 1
        ;;
    429)
        echo '{"error":"Rate limit exceeded after bounded retries. An API key does not guarantee availability; wait before retrying or check shared key usage."}' >&2
        exit 1
        ;;
    *)
        jq -n --arg code "$HTTP_CODE" '{error: ("Semantic Scholar HTTP " + $code)}' >&2
        exit 1
        ;;
esac
