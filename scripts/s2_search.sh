#!/bin/bash
# Semantic Scholar 论文搜索（增强版）
# 用法: bash scripts/s2_search.sh "query" [limit]
# 返回: JSON 格式的论文列表，包含作者ID、arXiv判断、推荐建议

set -e

# 初始化
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/init.sh"
source "$SCRIPT_DIR/s2_request.sh"

# 参数
QUERY="${1:-}"
LIMIT="${2:-20}"
ARXIV_THRESHOLD="${ARXIV_CITATION_THRESHOLD:-100}"

if [[ -z "$QUERY" ]]; then
    echo '{"error": "Usage: bash scripts/s2_search.sh \"query\" [limit]"}' >&2
    exit 1
fi

# URL 编码查询
ENCODED_QUERY=$(printf '%s' "$QUERY" | jq -sRr @uri)

# 构建请求
API_URL="https://api.semanticscholar.org/graph/v1/paper/search"
FIELDS="paperId,title,year,authors,venue,journal,citationCount,externalIds,url,abstract"

# 执行请求
RESPONSE=$(s2_request "${API_URL}?query=${ENCODED_QUERY}&limit=${LIMIT}&fields=${FIELDS}" 30)

# 解析响应
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

# 错误处理
case "$HTTP_CODE" in
    200)
        # 成功 - 增强输出格式
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
    401|403)
        echo '{"error":"Semantic Scholar authentication or permission denied. Check S2_API_KEY and endpoint access."}' >&2
        exit 1
        ;;
    429)
        echo '{"status":429,"error":"Rate limit exceeded after bounded retries. An API key does not guarantee availability; wait before retrying or check shared key usage. For paper searches, try crossref_search.sh."}' >&2
        exit 1
        ;;
    *)
        jq -n --arg code "$HTTP_CODE" '{error: ("Semantic Scholar HTTP " + $code)}' >&2
        exit 1
        ;;
esac
