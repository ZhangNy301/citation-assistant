# Citation Assistant 学术文献引用助手

> Claude Code Skill for automated LaTeX academic citation workflow

基于 Semantic Scholar API 的语义化文献检索，整合 CCF 分级、JCR 分区、中科院分区、影响因子、作者 H-index 等多维度质量评估，生成 BibTeX 并提供清晰的中文推荐说明。

---

## ✨ 核心功能

| 功能 | 说明 |
|------|------|
| 🔍 **语义化搜索** | 基于 Semantic Scholar API（覆盖 2 亿 + 文献），理解上下文语义，无需手动构造关键词 |
| 🛡️ **真实性保障** | DOI→BibTeX 强制校验机制，确保文献真实存在，杜绝 AI 幻觉生成虚假引用 |
| 📊 **多维度质量评估** | 期刊层面（CCF 分级、JCR 分区、中科院分区、影响因子）+ 作者层面（H-index、引用量） |
| 📝 **BibTeX 生成** | 一键生成标准 BibTeX 格式，可直接用于 LaTeX 文档 |
| 📋 **推荐报告** | 结构化输出搜索结果，附推荐理由，便于快速决策 |

---

## 🚀 安装

### Claude Code

```bash
# 克隆仓库
git clone https://github.com/ZhangNy301/citation-assistant.git

# 复制到 Claude Code Skills 目录
mkdir -p ~/.claude/skills/citation-assistant
cp citation-assistant/SKILL.md ~/.claude/skills/citation-assistant/
cp -r citation-assistant/scripts ~/.claude/skills/citation-assistant/
cp -r citation-assistant/data ~/.claude/skills/citation-assistant/

# 配置 API Key（推荐）
echo 'S2_API_KEY="your_key_here"' > ~/.claude/skills/citation-assistant/.env
```

### Cursor

```bash
# 创建目录并克隆
mkdir -p ~/.cursor/skills
cd ~/.cursor/skills
git clone https://github.com/ZhangNy301/citation-assistant.git

# 配置 API Key（推荐）
echo 'S2_API_KEY="your_key_here"' > ~/.cursor/skills/citation-assistant/.env
```

获取 API Key: https://www.semanticscholar.org/product/api

---

## 📦 可用脚本

| 脚本 | 用途 | 用法 |
|------|------|------|
| `s2_search.sh` | 论文搜索（含 arXiv 判断） | `bash scripts/s2_search.sh "query" [limit]` |
| `s2_bulk_search.sh` | 批量搜索 | `bash scripts/s2_bulk_search.sh "query" "year_range" limit` |
| `author_info.sh` | 作者 H-index 查询 | `bash scripts/author_info.sh "author_id"` |
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

### 作者信息查询

搜索结果包含前 3 位作者的 ID，可用于查询 H-index：

```bash
bash scripts/author_info.sh "18119920"
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

## 📁 文件结构

```
citation-assistant/
├── SKILL.md               # Skill 主文件
├── README.md              # 本文件
├── CHANGELOG.md           # 版本历史
├── .env.example           # 配置模板
├── scripts/               # Shell 脚本
│   ├── s2_search.sh
│   ├── s2_bulk_search.sh
│   ├── author_info.sh
│   ├── venue_info.sh
│   ├── ccf_lookup.sh
│   ├── if_lookup.sh
│   ├── doi2bibtex.sh
│   └── crossref_search.sh
└── data/                  # 数据库
    ├── ccf_2022.sqlite
    ├── ccf_2022.jsonl
    └── impact_factor.sqlite3
```

---

## 🔧 配置

### Semantic Scholar API Key

| 模式 | 速率限制 |
|------|----------|
| 有 API Key | 1 次/秒 |
| 无 API Key | 共享限额，极易触发 429 |

### arXiv 引用阈值（可选）

```bash
# 默认 100，可在 .env 中配置
echo 'ARXIV_CITATION_THRESHOLD=100' >> ~/.claude/skills/citation-assistant/.env
```

---

## 📊 质量评估维度

| 维度 | 权重 | 说明 |
|------|------|------|
| CCF 分级 | 基础分 | A=100, B=70, C=40 |
| JCR 分区 | 基础分 | Q1=80, Q2=60, Q3=40, Q4=20 |
| 中科院分区 | 基础分 | 1区=90, 2区=70, 3区=50, 4区=30 |
| 影响因子 | 30% | IF × 5 (上限50) |
| 引用量 | 20% | log₁₀(citations+1) × 10 (上限50) |
| 年份 | 10% | (year-2015) × 2 (上限30) |
| 作者 H-index | 10% | 第一作者 H-index × 2 (上限30) |

---

## 📖 使用示例

### 示例 1: 为 LaTeX 段落找引用
```
我在写论文，这段话需要找引用：

  "Deep learning has achieved remarkable success in medical image analysis, particularly in radiology where chest X-rays are the most commonly performed imaging examination globally [CITE]. Recent advances in vision transformers have further improved performance on these tasks [CITE]."
```
帮我找合适的文献。

### 示例 2: 查询期刊质量
```
我想投 TMI (IEEE Transactions on Medical Imaging)，这个期刊质量怎么样？
CCF 分级是什么？影响因子多少?
```

### 示例 3: 查询作者学术影响力
```
这篇论文的第一作者 H-index 是多少?我想评估一下作者的学术影响力。
```

### 示例 4: 生成 BibTeX
```
帮我生成这篇论文的 BibTeX：
DOI: 10.1038/s41591-020-0792-9
```

### 示例 5: 批量搜索 + 年份过滤
```
帮我找 2020 年以后关于 remote photoplethysmography (rPPG) 的论文，要高质量的，列出 10 篇推荐。
```

### 示例 6: 综合工作流（粘贴论文段落）

帮我检查这段论文的引用是否合适，如果有更好的推荐请告诉我：

```
Remote photoplethysmography (rPPG) enables non-contact heart rate estimation from facial videos [1]. Traditional methods like CHROM and POS have been widely used [2], while recent deep learning approaches have shown superior performance [3].

[1] Some arXiv paper with 5 citations
[2] A conference paper from 2015
[3] Another paper
```

---

## 🙏 致谢

- [Semantic Scholar](https://www.semanticscholar.org/) - Academic paper search API
- [impact_factor](https://github.com/suqingdong/impact_factor) - Journal impact factor database
- [CrossRef](https://www.crossref.org/) - DOI metadata API

## 📖 相关链接

- [小红书教程：文献引用自动化](https://www.xiaohongshu.com/discovery/item/699eecff000000000d00ab7d?source=webshare&xhsshare=pc_web&xsec_token=ABlbc1XDsjw8TWj8fUipbvyaj7qoU9u73hL5ZmzK4n65c=&xsec_source=pc_share)

## License

MIT
