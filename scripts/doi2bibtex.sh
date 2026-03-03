#!/bin/bash
# DOI 转 BibTeX
# 用法: bash scripts/doi2bibtex.sh "doi"
# 示例: bash scripts/doi2bibtex.sh "10.1038/nature12373"
# 返回: BibTeX 格式的引用

set -e

# 参数
DOI="${1:-}"

if [[ -z "$DOI" ]]; then
    echo '{"error": "Usage: bash scripts/doi2bibtex.sh \"doi\""}' >&2
    exit 1
fi

# 清理 DOI（移除可能的 URL 前缀）
DOI=$(echo "$DOI" | sed 's|https://doi.org/||g; s|http://doi.org/||g; s|doi.org/||g; s|^ *||; s| *$||')

# 通过 DOI 内容协商 API 获取 BibTeX
RESPONSE=$(curl -sL \
    -H "Accept: text/bibliography; style=bibtex" \
    -H "Accept-Language: en" \
    "https://doi.org/${DOI}" \
    --max-time 30 2>/dev/null)

# 检查响应
if [[ -z "$RESPONSE" ]] || [[ "$RESPONSE" == "<!DOCTYPE"* ]]; then
    echo "{\"error\": \"Failed to fetch BibTeX for DOI: $DOI\"}" >&2
    exit 1
fi

# 输出 BibTeX
echo "$RESPONSE"
