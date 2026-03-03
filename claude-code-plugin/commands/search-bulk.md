---
description: 批量搜索 Semantic Scholar 论文（适合大量检索）
argument-hint: 搜索关键词（返回更多结果）
allowed-tools: Bash
---

# /citation:search-bulk

使用 Semantic Scholar Bulk Search API 进行大批量文献检索。

## 参数

**$ARGUMENTS**: 搜索查询语句

可选：使用 `--limit N` 指定返回数量（默认 100，最大 1000）
可选：使用 `--year YYYY-YYYY` 指定年份范围

## 执行

```bash
cd "$HOME/.claude/plugins/marketplaces/citation-assistant/claude-code-plugin" && \
source .env 2>/dev/null; \
QUERY="$ARGUMENTS"; \
LIMIT=$(echo "$QUERY" | grep -o -- '--limit [0-9]*' | awk '{print $2}' || echo "100"); \
YEAR_RANGE=$(echo "$QUERY" | grep -o -- '--year [0-9]*-[0-9]*' | awk '{print $2}' || echo ""); \
QUERY=$(echo "$QUERY" | sed 's/ --limit [0-9]*//g; s/ --year [0-9]*-[0-9]*//g'); \
ENCODED_QUERY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$QUERY'''))" 2>/dev/null || echo "$QUERY"); \
YEAR_PARAM=""; \
if [ -n "$YEAR_RANGE" ]; then YEAR_PARAM="&year=$YEAR_RANGE"; fi; \
curl -s "https://api.semanticscholar.org/graph/v1/paper/search/bulk?query=${ENCODED_QUERY}&limit=${LIMIT}${YEAR_PARAM}&fields=paperId,title,year,authors,venue,journal,citationCount,externalIds,url" \
  ${S2_API_KEY:+-H "x-api-key: $S2_API_KEY"} | \
python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'data' not in data:
    print('No results found')
    if 'error' in data:
        print(f\"Error: {data['error']}\")
    sys.exit(0)
print(f\"Total found: {data.get('total', len(data['data']))}\")
print(f\"Returned: {len(data['data'])}\")
print()
for i, paper in enumerate(data['data'][:20], 1):  # 只显示前20条
    print(f\"{i}. {paper.get('title', 'N/A')}\")
    print(f\"   {paper.get('year', 'N/A')} | {paper.get('venue', paper.get('journal', 'N/A'))}\")
    print(f\"   Citations: {paper.get('citationCount', 0)}\")
    doi = paper.get('externalIds', {}).get('DOI', 'N/A')
    if doi != 'N/A':
        print(f\"   DOI: {doi}\")
    print()
"
```

## 说明

- Bulk API 适合大批量检索，但响应时间可能较长
- 建议使用 `--limit` 控制返回数量
- 如需全部结果，可配合 `--year` 分段查询
