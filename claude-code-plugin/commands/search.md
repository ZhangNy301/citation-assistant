---
description: 搜索 Semantic Scholar 论文
argument-hint: 搜索关键词或查询语句
allowed-tools: Bash
---

# /citation:search

搜索 Semantic Scholar API 并返回结构化结果。

## 参数

**$ARGUMENTS**: 搜索查询语句（支持自然语言描述）

可选：使用 `--limit N` 指定返回数量（默认 10）
可选：使用 `--year YYYY-` 指定年份范围

## 执行

```bash
cd "$HOME/.claude/plugins/marketplaces/citation-assistant/claude-code-plugin" && \
source .env 2>/dev/null; \
QUERY="$ARGUMENTS"; \
LIMIT=$(echo "$QUERY" | grep -o -- '--limit [0-9]*' | awk '{print $2}' || echo "10"); \
QUERY=$(echo "$QUERY" | sed 's/ --limit [0-9]*//g'); \
ENCODED_QUERY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$QUERY'''))" 2>/dev/null || echo "$QUERY"); \
curl -s "https://api.semanticscholar.org/graph/v1/paper/search?query=${ENCODED_QUERY}&limit=${LIMIT}&fields=paperId,title,year,authors,venue,journal,citationCount,externalIds,url,abstract" \
  ${S2_API_KEY:+-H "x-api-key: $S2_API_KEY"} | \
python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'data' not in data:
    print('No results found')
    sys.exit(0)
for paper in data['data']:
    print(f\"Title: {paper.get('title', 'N/A')}\")
    print(f\"  Year: {paper.get('year', 'N/A')}\")
    print(f\"  Venue: {paper.get('venue', paper.get('journal', 'N/A'))}\")
    print(f\"  Citations: {paper.get('citationCount', 0)}\")
    print(f\"  DOI: {paper.get('externalIds', {}).get('DOI', 'N/A')}\")
    print(f\"  URL: {paper.get('url', 'N/A')}\")
    authors = ', '.join([a.get('name', '') for a in paper.get('authors', [])[:3]])
    if len(paper.get('authors', [])) > 3:
        authors += ' et al.'
    print(f\"  Authors: {authors}\")
    print()
"
```

## 输出示例

```
Title: CheXpert: A large chest radiograph dataset...
  Year: 2020
  Venue: Radiology
  Citations: 3500
  DOI: 10.1148/radiol.2020191075
  URL: https://www.semanticscholar.org/paper/...
  Authors: Joy T Wu, Justin Wong, William Hsu et al.
```
