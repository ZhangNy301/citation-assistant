# Citation Assistant 学术文献引用助手

> 面向 Codex / Claude Code / Cursor 的学术文献引用助手，适合论文写作、BibTeX 生成与文献质量筛选。

基于 Semantic Scholar API 的语义化文献检索，整合 CCF 分级、JCR 分区、中科院分区、影响因子、作者 H-index 等多维度质量评估，生成 BibTeX 并提供清晰的中文推荐说明。

这个仓库同时服务两类场景：
- **GitHub 用户**：阅读 `README.md`，了解功能、安装方式和使用示例
- **Skill 运行时（Codex / Claude Code / Cursor）**：读取 `SKILL.md`，按既定脚本与流程执行任务

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

需要 Bash、`curl`（7.55.0+）、`jq` 和支持 `-json` 的 `sqlite3`。Windows 请在 WSL 中安装并运行；在线检索需要网络，本地期刊数据库查询无需 API Key。

### Codex

用户级安装（所有项目可用）：

```bash
mkdir -p ~/.agents/skills
git clone https://github.com/ZhangNy301/citation-assistant.git ~/.agents/skills/citation-assistant

# 可选：在安装目录创建 .env 并填入自己的 S2_API_KEY
# 已存在 .env 时不要覆盖
cp -n ~/.agents/skills/citation-assistant/.env.example ~/.agents/skills/citation-assistant/.env
```

也可仅在某个论文项目中安装，在该项目根目录执行（与用户级安装二选一）：

```bash
mkdir -p .agents/skills
git clone https://github.com/ZhangNy301/citation-assistant.git .agents/skills/citation-assistant
```

在 Codex 中输入以下内容即可调用：

```text
$citation-assistant 查询 Nature Medicine 的期刊质量，并说明数据来源。
```

也支持自然语言触发，例如“帮我给这段论文找引用”。如果安装后未显示，重启 Codex。路径规则见 [Codex 官方 Skills 文档](https://learn.chatgpt.com/docs/build-skills#where-codex-loads-local-skills)。

从任意论文目录验证用户级安装（无需联网）：

```bash
bash "$HOME/.agents/skills/citation-assistant/scripts/venue_info.sh" "Nature Medicine"
```

项目级安装时，把命令中的路径替换为该项目 `.agents/skills/citation-assistant` 的绝对路径。所有客户端共用同一份 `SKILL.md`、脚本和数据库，无需设置 `CLAUDE_SKILL_ROOT`。

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
| `s2_search.sh` | 少量高相关结果检索（含 arXiv 判断） | `bash scripts/s2_search.sh "query" [limit]` |
| `s2_bulk_search.sh` | 使用 Semantic Scholar bulk endpoint 批量拉取候选结果，并按本地 limit 输出前 N 条 | `bash scripts/s2_bulk_search.sh "query" "year_range" limit` |
| `author_info.sh` | 作者 H-index 查询 | `bash scripts/author_info.sh "author_id"` |
| `venue_info.sh` | 期刊综合查询 | `bash scripts/venue_info.sh "venue_name"` |
| `ccf_lookup.sh` | CCF 分级查询 | `bash scripts/ccf_lookup.sh "venue_name"` |
| `if_lookup.sh` | 影响因子查询 | `bash scripts/if_lookup.sh "journal_name"` |
| `doi2bibtex.sh` | DOI 转 BibTeX | `bash scripts/doi2bibtex.sh "doi"` |
| `crossref_search.sh` | CrossRef 搜索（fallback） | `bash scripts/crossref_search.sh "query" [limit]` |

> 说明：`s2_search.sh` 更适合少量高相关结果检索；`s2_bulk_search.sh` 更适合减少请求次数、先批量拉取候选文献再做筛选。

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
├── agents/openai.yaml     # Codex 展示名称和默认调用提示
├── tests/                 # 离线安装与脚本回归测试
├── scripts/               # Shell 脚本
│   ├── init.sh
│   ├── s2_request.sh       # S2 请求、限速与有界重试
│   ├── s2_search.sh
│   ├── s2_bulk_search.sh
│   ├── author_info.sh
│   ├── venue_info.sh
│   ├── ccf_lookup.sh
│   ├── if_lookup.sh
│   ├── doi2bibtex.sh
│   └── crossref_search.sh
└── data/                  # 数据库
    ├── ccf_2026.sqlite
    ├── ccf_2026.jsonl
    └── impact_factor.sqlite3
```

---

## 🔧 配置

### Semantic Scholar API Key

获取地址：`https://www.semanticscholar.org/product/api`

| 模式 | 速率限制 |
|------|----------|
| 有 API Key | 1 次/秒 |
| 无 API Key | 共享限额，极易触发 429 |

配置文件位于所安装的 Skill 根目录：Codex 用户级安装为 `~/.agents/skills/citation-assistant/.env`，项目级安装为 `<论文项目>/.agents/skills/citation-assistant/.env`；Claude Code / Cursor 则使用各自安装目录。未创建 `.env` 时，脚本也接受 shell 中导出的 `S2_API_KEY`；存在 `.env` 时以其中的配置为准。

### Semantic Scholar 限流与重试

三个 S2 脚本共用请求逻辑。HTTP 429 默认最多重试 2 次：优先遵守 `Retry-After`（秒数或 HTTP 日期），缺失或无法解析时按 2、4 秒退避。超过等待上限则停止，不提前重试。HTTP 401/403 不重试，并提示检查凭据和接口权限。诊断只写 stderr，stdout 保持最终成功结果。

可在 Skill 的 `.env` 中配置：

```bash
S2_MIN_INTERVAL=1       # 本地顺序请求的最小间隔（秒）
S2_MAX_RETRIES=2        # 重试次数；0 表示禁用
S2_RETRY_DELAY=2        # 无 Retry-After 时的初始退避（秒）
S2_MAX_RETRY_DELAY=60   # 单次退避等待上限（秒）
```

这些设置需为 0–99999 的整数。本地间隔控制不协调多个并发进程或设备；共用密钥时仍需避免并发请求。带 Key 的作者接口返回 200，并不能保证搜索接口不再限流；429 也不等同于无效密钥。若有限次重试后仍失败，等待后再试、检查其他程序的密钥用量，或联系 Semantic Scholar 核查配额；论文检索可改用 `crossref_search.sh`。参见 [官方 API 教程](https://www.semanticscholar.org/product/api/tutorial)。

### arXiv 引用阈值（可选）

```bash
# 默认 100，可在 .env 中配置
echo 'ARXIV_CITATION_THRESHOLD=100' >> ~/.agents/skills/citation-assistant/.env
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

下面这些示例是**用户在 Codex / Claude Code / Cursor 中可以直接提出的请求**，也是这个 skill 最常见的使用方式。

### 示例 1：为 LaTeX 段落找引用
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

### 示例 5：批量搜索 + 年份过滤
```
帮我找 2020 年以后关于 remote photoplethysmography (rPPG) 的论文，要高质量的，列出 10 篇推荐。
```

适合使用 `s2_bulk_search.sh` 对候选文献进行批量拉取，再结合年份、引用量、venue 质量等信息做筛选。

### 示例 6: 综合工作流（粘贴论文段落）

帮我检查这段论文的引用是否合适，如果有更好的推荐请告诉我：

```
Remote photoplethysmography (rPPG) enables non-contact heart rate estimation from facial videos [1]. Traditional methods like CHROM and POS have been widely used [2], while recent deep learning approaches have shown superior performance [3].

[1] Some arXiv paper with 5 citations
[2] A conference paper from 2015
[3] Another paper
```

---

## 🧪 开发验证

安装运行依赖后，在仓库根目录执行（测试还需 Python 3）：

```bash
python3 -m unittest discover -s tests -v
```

测试在临时安装目录中执行，覆盖包含空格的路径、从论文目录调用、配置加载、本地数据库查询，以及模拟 API 的搜索、作者信息、429 和 BibTeX 流程，不消耗真实 API 配额。GitHub Actions 在 Linux 和 macOS 上执行相同测试。

## 🙏 致谢

- [Semantic Scholar](https://www.semanticscholar.org/) - Academic paper search API
- [impact_factor](https://github.com/suqingdong/impact_factor) - Journal impact factor database
- [CrossRef](https://www.crossref.org/) - DOI metadata API

## 📖 相关链接

- [小红书教程：文献引用自动化](https://www.xiaohongshu.com/discovery/item/699eecff000000000d00ab7d?source=webshare&xhsshare=pc_web&xsec_token=ABlbc1XDsjw8TWj8fUipbvyaj7qoU9u73hL5ZmzK4n65c=&xsec_source=pc_share)

## License

MIT
