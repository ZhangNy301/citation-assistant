---
name: citation-assistant
description: |
  学术文献引用助手：基于 Semantic Scholar API 的语义化文献检索与引用管理。

  触发场景：
  - 用户在 LaTeX 文稿中标记 [CITE] 占位符，需要查找合适的引用文献
  - 用户粘贴论文段落，需要为其中的 [CITE] 标记寻找引用
  - 用户需要根据语义上下文查找学术引用
  - 用户需要验证/替换不规范的引用格式（如 "PMC Articles"）
  - 用户需要查询期刊/会议质量（CCF/JCR/IF/引用量）
  - 用户需要查询作者 H-index 和引用量
  - 用户需要判断 arXiv 文章是否值得引用
  - 用户提及 "文献引用"、"找引用"、"citation"、"bib"、"参考文献"
  - 用户需要完整的引用推荐到 BibTeX 生成的端到端服务

allowed-tools: Bash, Read, Grep, Glob
---

# Citation Assistant 学术文献引用助手

## ⚠️ 核心原则

1. **必须通过 `scripts/` 目录中的脚本执行**，禁止手动编写 curl 命令
2. **禁止使用 Tavily、WebSearch 等非学术搜索工具**进行文献检索
3. **语义优先**：理解引用意图，避免仅用关键词检索
4. **不自动修改文稿**：所有推荐需用户确认后再应用

---

## 📦 可用脚本

| 脚本 | 用途 | 用法 |
|------|------|------|
| `s2_search.sh` | 论文搜索（含arXiv判断） | `bash scripts/s2_search.sh "query" [limit]` |
| `s2_bulk_search.sh` | 批量搜索（含arXiv判断） | `bash scripts/s2_bulk_search.sh "query" "year_range" limit` |
| `author_info.sh` | 作者信息查询（H-index） | `bash scripts/author_info.sh "author_id"` |
| `venue_info.sh` | 期刊综合查询 | `bash scripts/venue_info.sh "venue_name"` |
| `ccf_lookup.sh` | CCF 分级查询 | `bash scripts/ccf_lookup.sh "venue_name"` |
| `if_lookup.sh` | 影响因子查询 | `bash scripts/if_lookup.sh "journal_name"` |
| `doi2bibtex.sh` | DOI 转 BibTeX | `bash scripts/doi2bibtex.sh "doi"` |
| `crossref_search.sh` | CrossRef 搜索（fallback） | `bash scripts/crossref_search.sh "query" [limit]` |

---

## 🆕 增强功能

### arXiv 文章智能判断

搜索结果会自动标记 arXiv 文章的引用状态：

| 状态 | 条件 | 推荐建议 |
|------|------|----------|
| `recommended` | arXiv + 引用 ≥ 100 | ✅ 高影响力 arXiv，可引用 |
| `caution` | arXiv + 引用 < 100 | ⚠️ 低引用 arXiv，谨慎引用 |
| `normal` | 正式发表 | ✅ 正式发表 |

**配置引用阈值**（默认 100）：
```bash
export ARXIV_CITATION_THRESHOLD=100
```

### 作者信息查询

搜索结果包含前 3 位作者的 ID，可用于查询 H-index：

```bash
# 查询作者 H-index、总引用量、论文数
bash "${CLAUDE_SKILL_ROOT}/scripts/author_info.sh "18119920"
```

返回示例：
```json
{
  "name": "Daquan Zhou",
  "hIndex": 25,
  "citations": 8500,
  "papers": 42
}
```

---

## 🔄 工作流程

### Step 1: 解析需求

识别用户需求类型：
- **[CITE] 占位符**：提取上下文，构造语义查询
- **替换不规范引用**：分析原文引用的语义意图
- **期刊查询**：直接查询 CCF/IF 数据库
- **作者质量评估**：查询第一/通讯作者的 H-index

### Step 2: 语义化查询构造

| 引用目的 | 查询策略示例 |
|----------|--------------|
| 事实背书 | "chest radiography most widely used imaging test globally statistics" |
| 方法引用 | "attention mechanism transformer neural machine translation" |
| 背景介绍 | "deep learning medical image analysis survey review" |

### Step 3: 执行搜索

```bash
bash "${CLAUDE_SKILL_ROOT}/scripts/s2_bulk_search.sh "YOUR_QUERY" "2020-" 20
```

**如果返回 429 错误**，使用 CrossRef fallback：
```bash
bash "${CLAUDE_SKILL_ROOT}/scripts/crossref_search.sh "YOUR_QUERY" 20
```

### Step 4: 评估文献质量

```bash
# 查询期刊质量
bash "${CLAUDE_SKILL_ROOT}/scripts/venue_info.sh "Nature Medicine"

# 查询作者 H-index
bash "${CLAUDE_SKILL_ROOT}/scripts/author_info.sh "AUTHOR_ID"
```

### Step 5: 生成 BibTeX

```bash
bash "${CLAUDE_SKILL_ROOT}/scripts/doi2bibtex.sh "10.1038/s41591-020-0792-9"
```

### Step 6: 生成中文推荐报告

输出格式示例：

```markdown
## 引用推荐报告

### [CITE] 位置 1

**原文上下文**：
> In chest radiography---arguably the most widely used imaging test globally [CITE]---

**推荐文献**：

#### 推荐 1: Wu2020 - CheXpert: A large chest radiograph dataset...

**质量指标**：
| 维度 | 值 | 说明 |
|------|-----|------|
| CCF 分级 | N/A | 非CS领域期刊 |
| JCR 分区 | Q1 | 顶级医学影像期刊 |
| 影响因子 | 29.1 | 极高影响力 |
| 引用量 | 3500+ | 高被引文献 |
| arXiv 状态 | normal | 正式发表 |

**推荐理由**：顶级期刊发表，直接支持原文论点。

**BibTeX**：
```bibtex
@article{Wu2020, ... }
```

**建议用法**：将 `[CITE]` 替换为 `~\cite{Wu2020}`
```

---

## ⚙️ 配置

### Semantic Scholar API Key（强烈推荐）

```bash
# 在 Skill 目录创建 .env 文件
echo 'S2_API_KEY="your_key_here"' > "${CLAUDE_SKILL_ROOT}/.env"

# 获取 API Key: https://www.semanticscholar.org/product/api/api-key
```

| 模式 | 速率限制 | 推荐场景 |
|------|----------|----------|
| 有 API Key | 1 次/秒 | 日常使用（推荐） |
| 无 API Key | 共享限额 | 极易触发 429 |

### arXiv 引用阈值（可选）

```bash
# 默认 100，可在 .env 中配置
echo 'ARXIV_CITATION_THRESHOLD=100' >> "${CLAUDE_SKILL_ROOT}/.env"
```

---

## 🚨 错误处理

### 429 Rate Limit

1. 等待 1-2 秒后重试
2. 使用 `s2_bulk_search.sh`
3. 使用 `crossref_search.sh`（无严格限制）

### 无搜索结果

1. 简化关键词
2. 使用英文查询
3. 尝试 CrossRef fallback

---

## 📊 质量评估维度

| 维度 | 权重 | 计算 |
|------|------|------|
| CCF 分级 | 基础分 | A=100, B=70, C=40 |
| JCR 分区 | 基础分 | Q1=80, Q2=60, Q3=40, Q4=20 |
| 中科院分区 | 基础分 | 1区=90, 2区=70, 3区=50, 4区=30 |
| 影响因子 | 30% | IF × 5 (上限50) |
| 引用量 | 20% | log₁₀(citations+1) × 10 (上限50) |
| 年份 | 10% | (year-2015) × 2 (上限30) |
| 作者 H-index | 10% | 第一作者 H-index × 2 (上限30) |

**arXiv 处理**：
- 引用 ≥ 100：正常评分
- 引用 < 100：降低优先级 (-20 分)
- 有正式发表版本优先
