# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [3.0.0] - 2025-03-03

### Changed
- **从 Plugin 架构回归纯 Skill 架构**：删除 `claude-code-plugin/` 目录
- **删除 `references/` 目录**：内容已整合到 SKILL.md
- **使用 Shell 脚本替代 Python 脚本**：更好的可移植性和更简单的依赖

### Added
- **`scripts/` 目录**：模块化的 Shell 脚本
  - `s2_search.sh` - 论文搜索（含 arXiv 判断）
  - `s2_bulk_search.sh` - 批量搜索
  - `author_info.sh` - 作者 H-index 查询（新功能）
  - `venue_info.sh` - 期刊综合查询
  - `ccf_lookup.sh` - CCF 分级查询
  - `if_lookup.sh` - 影响因子查询
  - `doi2bibtex.sh` - DOI 转 BibTeX
  - `crossref_search.sh` - CrossRef 搜索（fallback）
- **arXiv 智能判断**：
  - 引用 ≥ 100：标记为"高影响力 arXiv"
  - 引用 < 100：标记为"低引用 arXiv，谨慎引用"
- **作者信息返回**：搜索结果包含前 3 位作者的 ID
- **完整 abstract 显示**：不再截断摘要内容
- **Rate limiting**：自动控制 API 请求频率

### Removed
- `claude-code-plugin/` 目录（Plugin 架构）
- `references/` 目录（已整合）
- Python 脚本（已替换为 Shell 脚本）

---

## [2.0.0] - 2025-03-02

### Added
- 新增 Plugin 架构版本，位于 `claude-code-plugin/` 目录
- 新增独立 Commands
- 支持通过 Marketplace 安装

---

## [1.0.0] - 2025-02

### Added
- 初始版本发布
- 单一 Skill 架构
- 零依赖设计：仅需 curl + sqlite3 + jq
- 支持语义化文献搜索
- 支持 CCF/JCR/中科院分区/影响因子多维度评估
- 支持 BibTeX 生成
- 中文推荐报告输出
