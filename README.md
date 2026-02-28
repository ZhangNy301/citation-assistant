# Citation Assistant

> Claude Code Skill for automated LaTeX academic citation workflow
>
> **零依赖版本** - 无需 Python，仅用 curl/sqlite3/jq

基于 Semantic Scholar API 的语义化文献检索，整合 CCF 分级、JCR 分区、中科院分区、影响因子等多维度质量评估，生成 BibTeX 并提供清晰的中文推荐说明。

## 特性

- **语义搜索** - 基于语义理解而非仅关键词的文献检索
- **多维度排序** - CCF/JCR/中科院分区/IF/引用量综合评分
- **BibTeX 生成** - 通过 DOI 自动生成标准 BibTeX
- **中文报告** - 生成清晰的中文推荐报告

## 安装

### Step 1: 克隆仓库

```bash
git clone https://github.com/ZhangNy301/citation-assistant.git ~/.claude/skills/citation-assistant
```

### Step 2: 配置 API Key（推荐）

```bash
# 复制配置模板
cp ~/.claude/skills/citation-assistant/.env.example ~/.claude/skills/citation-assistant/.env

# 编辑 .env 文件，填入你的 API Key
nano ~/.claude/skills/citation-assistant/.env
```

**获取免费 API Key**: https://www.semanticscholar.org/product/api/api-key

| 模式 | 速率限制 |
|------|----------|
| 有 API Key | 100 次/分钟 |
| 无 API Key | 10 次/分钟（仍可用） |

### 依赖

**无需安装 Python 依赖！** 只需确保系统有：
- `curl` - API 请求（系统自带）
- `sqlite3` - 本地数据库查询（系统自带）
- `jq` - JSON 解析（`brew install jq`）

## 使用

### 方式 1：直接触发

在 Claude Code 中输入 `/citation-assistant` 或提及"文献引用"、"找引用"等关键词

### 方式 2：粘贴 LaTeX 段落

```
End-to-end deep learning has revolutionized medical image analysis [CITE].
Vision-language models now generate radiologist-quality reports [CITE].
```

### 方式 3：查询期刊信息

```
TMI 是什么期刊？质量怎么样？
```

## 文件结构

```
citation-assistant/
├── SKILL.md              # Skill 定义（Claude Code 读取）
├── README.md             # 本文件
├── data/
│   ├── ccf_2022.sqlite      # CCF 分级数据库
│   └── impact_factor.sqlite3 # 影响因子数据库（20,000+ 期刊）
└── references/
    ├── ccf_guide.md         # CCF 使用指南
    └── quality_metrics.md   # 质量指标说明
```

## 致谢

- [Semantic Scholar](https://www.semanticscholar.org/) - Academic paper search API
- [impact_factor](https://github.com/suqingdong/impact_factor) - Journal impact factor database
- [CrossRef](https://www.crossref.org/) - DOI metadata API (fallback)

## License

MIT
