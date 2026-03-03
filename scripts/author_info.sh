#!/bin/bash
# 作者信息查询（H-index、引用量、论文数）
# 用法: bash scripts/author_info.sh "author_id"
# 示例: bash scripts/author_info.sh "1699545"
# 返回: JSON 格式的作者信息

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
AUTHOR_ID="${1:-}"

if [[ -z "$AUTHOR_ID" ]]; then
    echo '{"error": "Usage: bash scripts/author_info.sh \"author_id\""}' >&2
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

# 构建请求
API_URL="https://api.semanticscholar.org/graph/v1/author/${AUTHOR_ID}"
FIELDS="name,hIndex,citationCount,paperCount,affiliations,homepage,url"

# 执行请求
RESPONSE=$(curl -s -w "\n%{http_code}" \
    "${API_URL}?fields=${FIELDS}" \
    ${S2_API_KEY:+-H "x-api-key: $S2_API_KEY"} \
    --max-time 30 2>/dev/null)

# 更新 rate limit
date +%s > "$RATE_LIMIT_FILE"

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
    429)
        echo '{"error": "Rate limit exceeded. Wait 1-2 seconds and retry."}' >&2
        exit 1
        ;;
    *)
        echo "{\"error\": \"HTTP $HTTP_CODE: $(echo "$BODY" | jq -r '.message // .error // "Unknown error"')\"}" >&2
        exit 1
        ;;
esac
