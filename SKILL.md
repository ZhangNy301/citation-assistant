---
name: citation-assistant
description: |
  自动化 LaTeX 学术文献引用工作流。基于 Semantic Scholar API 进行语义化文献检索，
  整合 CCF 分级、JCR 分区、中科院分区、影响因子等多维度质量评估，
  生成 BibTeX 并提供清晰的中文推荐说明。

  触发场景：
  - 用户在 LaTeX 文稿中标记 [CITE] 占位符，需要查找合适的引用文献
  - 用户粘贴论文段落，需要为其中的 [CITE] 标记寻找引用
  - 用户查询某个期刊/会议的信息（如 "TMI 是什么期刊？质量怎么样？"）
  - 用户需要根据语义上下文而非仅关键词来查找学术引用
  - 用户需要按论文质量（CCF/JCR/IF/引用量）排序推荐文献
  - 用户提及 "文献引用"、"找引用"、"citation"、"bib"、"期刊查询" 等关键词
---

# Citation Assistant 学术文献引用助手

**零依赖版本** - 仅需 `curl`、`sqlite3`、`jq`（系统自带或常见工具）

## 配置

### Semantic Scholar API Key（推荐）

```bash
# 方式 1: 使用 .env 文件（推荐）
cp .env.example .env
# 编辑 .env 填入你的 API Key

# 方式 2: 环境变量
export S2_API_KEY="your_key_here"

# 方式 3: 写入 shell 配置文件
echo 'export S2_API_KEY="your_key_here"' >> ~/.zshrc

# 获取 API Key: https://www.semanticscholar.org/product/api/api-key
```

| 模式 | 速率限制 | 推荐场景 |
|------|----------|----------|
| 有 API Key | 100 次/分钟 | 日常使用 |
| 无 API Key | 10 次/分钟 | 偶尔使用（仍可用） |

### 依赖检查

```bash
# 检查工具是否可用
which curl sqlite3 jq

# 如需安装 jq
brew install jq  # macOS
```

## 技能目录

```bash
SKILL_DIR="$HOME/.claude/skills/citation-assistant"
DATA_DIR="$SKILL_DIR/data"
```

## 核心命令

### 1. 论文搜索

```bash
# 基础搜索
s2_search() {
  local query="$1"
  local limit="${2:-20}"
  local fields="paperId,title,year,authors,venue,journal,citationCount,externalIds,url,publicationDate"

  local api_key="${S2_API_KEY:-}"
  local headers=""
  [ -n "$api_key" ] && headers="-H 'x-api-key: $api_key'"

  curl -s "https://api.semanticscholar.org/graph/v1/paper/search?query=$(printf '%s' "$query" | jq -sRr @uri)&limit=$limit&fields=$fields" $headers | jq .
}

# 使用示例
s2_search "attention mechanism transformer" 10
s2_search "LLM irrelevant context sensitivity" 20
```

### 2. 期刊/会议信息查询

```bash
# CCF 分级查询
query_ccf() {
  local name="$1"
  sqlite3 "$DATA_DIR/ccf_2022.sqlite" \
    "SELECT acronym, name, rank, field, type FROM ccf_2022 WHERE acronym LIKE '%$name%' OR name LIKE '%$name%';"
}

# 影响因子查询
query_if() {
  local name="$1"
  sqlite3 "$DATA_DIR/impact_factor.sqlite3" \
    "SELECT journal, factor, jcr, zky FROM factor WHERE journal LIKE '%$name%' LIMIT 5;"
}

# 综合查询（CCF + IF）
query_venue() {
  local name="$1"
  echo "=== CCF 分级 ==="
  query_ccf "$name"
  echo ""
  echo "=== 影响因子 ==="
  query_if "$name"
}

# 使用示例
query_venue "TMI"
query_venue "NeurIPS"
query_venue "Nature"
```

### 3. DOI 转 BibTeX

```bash
# 通过 DOI 获取 BibTeX
doi2bib() {
  local doi="$1"
  curl -sLH "Accept: text/bibliography; style=bibtex" "https://doi.org/$doi"
}

# 使用示例
doi2bib "10.1038/nature12373"
```

### 4. CrossRef 搜索（Fallback）

```bash
# 当 Semantic Scholar 不可用时使用
crossref_search() {
  local query="$1"
  local rows="${2:-10}"
  curl -s "https://api.crossref.org/works?query=$(printf '%s' "$query" | jq -sRr @uri)&rows=$rows" | \
    jq '.message.items[] | {title: .title[0], year: .published-print.date-parts[0][0], doi: .DOI, citations: ."is-referenced-by-count"}'
}
```

### 5. 批量获取作者信息

```bash
# 获取作者 h-index 等
get_authors() {
  local ids="$1"  # 逗号分隔的作者 ID
  curl -s -X POST "https://api.semanticscholar.org/graph/v1/author/batch?fields=name,hIndex,citationCount,paperCount" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${S2_API_KEY:-}" \
    -d "{\"ids\": $(echo "$ids" | jq -R 'split(",")')}" | jq .
}
```

## 工作流程

### Step 1: 解析 [CITE] 占位符

识别用户提供的段落中的 `[CITE]` 或 `[CITE:描述]` 标记，提取上下文。

### Step 2: 构造语义化查询

| 引用目的 | 查询策略示例 |
|----------|--------------|
| 事实背书 | "chest radiography most widely used imaging test globally statistics" |
| 方法引用 | "attention mechanism transformer neural machine translation" |
| 背景介绍 | "deep learning medical image analysis survey review" |
| 对比参照 | "BERT language model pretraining comparison" |

### Step 3: 执行搜索

```bash
SKILL_DIR="$HOME/.claude/skills/citation-assistant"
DATA_DIR="$SKILL_DIR/data"

# 搜索论文
results=$(curl -s "https://api.semanticscholar.org/graph/v1/paper/search?query=ATTENTION_QUERY&limit=20&fields=paperId,title,year,authors,venue,journal,citationCount,externalIds,url" \
  ${S2_API_KEY:+-H "x-api-key: $S2_API_KEY"})

# 解析结果
echo "$results" | jq -r '.data[] | "\(.title) (\(.year)) - \(.venue) [引用:\(.citationCount)]"'
```

### Step 4: 质量评估

对搜索结果进行多维度评估：

**评分维度**：
1. **CCF 分级** (A=100, B=70, C=40) - 计算机/CS 领域
2. **JCR 分区** (Q1=80, Q2=60, Q3=40, Q4=20)
3. **中科院分区** (1区=90, 2区=70, 3区=50, 4区=30)
4. **影响因子 IF** (IF × 5, 上限 50)
5. **引用量** (log₁₀(citations+1) × 10, 上限 50)
6. **年份新近度** ((year-2015) × 2, 上限 30)

**查询期刊质量**：
```bash
# 查询某个期刊/会议的完整信息
venue="Nature Medicine"

# CCF（如果是 CS 期刊/会议）
sqlite3 "$DATA_DIR/ccf_2022.sqlite" "SELECT * FROM ccf_2022 WHERE name LIKE '%$venue%' OR acronym LIKE '%$venue%';"

# 影响因子和分区
sqlite3 "$DATA_DIR/impact_factor.sqlite3" "SELECT journal, factor as IF, jcr, zky as CAS FROM factor WHERE journal LIKE '%$venue%';"
```

### Step 5: 生成 BibTeX

```bash
# 从搜索结果提取 DOI，然后获取 BibTeX
doi=$(echo "$results" | jq -r '.data[0].externalIds.DOI')
curl -sLH "Accept: text/bibliography; style=bibtex" "https://doi.org/$doi"
```

### Step 6: 生成中文推荐报告

输出格式示例：

```markdown
## 引用推荐报告

### [CITE] 位置 1

**原文上下文**：
> End-to-end attention was never trained to ignore irrelevant context [CITE]

**推荐文献**：

#### 推荐 1: Attention Is All You Need (2017)

**质量指标**：
| 维度 | 值 | 说明 |
|------|-----|------|
| CCF 分级 | A | 顶级会议 |
| 引用量 | 100000+ | 极高被引 |
| 发表年份 | 2017 | 经典文献 |

**推荐理由**：Transformer 开山之作，直接支持原文关于 attention 机制的论点。

---

**生成 BibTeX**：
```bibtex
@inproceedings{vaswani2017attention,
  title={Attention is all you need},
  author={Vaswani, Ashish and others},
  booktitle={NeurIPS},
  year={2017}
}
```

**建议用法**：将 `[CITE]` 替换为 `~\cite{vaswani2017attention}`
```

## 数据资源

### CCF 分级数据

位置：`data/ccf_2022.sqlite`

```bash
# 查询示例
sqlite3 "$DATA_DIR/ccf_2022.sqlite" "SELECT * FROM ccf_2022 WHERE acronym = 'TMI';"
sqlite3 "$DATA_DIR/ccf_2022.sqlite" "SELECT acronym, name, rank FROM ccf_2022 WHERE rank = 'A' AND type = 'conference';"
```

### 影响因子数据

位置：`data/impact_factor.sqlite3`（约 20,000 条期刊记录）

```bash
# 查询示例
sqlite3 "$DATA_DIR/impact_factor.sqlite3" "SELECT journal, factor, jcr, zky FROM factor WHERE jcr = 'Q1' ORDER BY factor DESC LIMIT 10;"
```

## 完整示例

**场景**：用户需要为 "attention cannot ignore irrelevant context" 找引用

```bash
# 1. 设置变量
SKILL_DIR="$HOME/.claude/skills/citation-assistant"
DATA_DIR="$SKILL_DIR/data"

# 2. 搜索论文
curl -s "https://api.semanticscholar.org/graph/v1/paper/search?query=attention%20mechanism%20ignore%20irrelevant%20context&limit=10&fields=paperId,title,year,venue,citationCount,externalIds" \
  ${S2_API_KEY:+-H "x-api-key: $S2_API_KEY"} | jq '.data[] | {title, year, venue, citations: .citationCount, doi: .externalIds.DOI}'

# 3. 查询期刊质量
sqlite3 "$DATA_DIR/impact_factor.sqlite3" "SELECT journal, factor, jcr FROM factor WHERE journal LIKE '%Transactions%' LIMIT 5;"

# 4. 获取 BibTeX
curl -sLH "Accept: text/bibliography; style=bibtex" "https://doi.org/10.1000/xyz123"
```

## 注意事项

1. **不自动修改文稿**：所有推荐需用户确认后再应用
2. **语义优先**：避免仅用关键词检索，理解引用意图
3. **质量把关**：综合多维度指标，不唯引用量论
4. **arXiv 审慎**：期刊投稿应控制 arXiv 引用比例
5. **API 限制**：无 API Key 时注意速率限制（10次/分钟）
