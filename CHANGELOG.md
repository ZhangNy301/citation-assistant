# 更新日志

本文件记录项目的主要变更。

格式参考 [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)。

## [未发布]

### 已修复
- 在 `s2_bulk_search.sh` 中保留 Semantic Scholar bulk search 的真实语义
- 将 bulk 搜索结果在本地按请求的 `limit` 截断输出
- 为 `s2_bulk_search.sh` 增加 `limit` 必须为正整数的校验

### 已更改
- 明确 `README.md` 与 `SKILL.md` 的文档职责边界
- 优化 `README.md` 结构，同时保留关键安装说明与使用示例

---

## [3.0.0] - 2025-03-03

### 已更改
- 从 Plugin 导向结构回归到纯 Skill 导向结构
- 使用 Shell 脚本替代 Python 脚本，以提升可移植性并简化依赖
- 将原 `references/` 中的核心内容收敛到 `SKILL.md`

### 已新增
- 模块化 `scripts/` 目录，用于搜索、质量查询和 BibTeX 生成
- arXiv 结果智能标记能力
- 搜索结果中返回作者 ID
- Semantic Scholar 请求的基础限流能力

### 已移除
- `claude-code-plugin/` 目录
- `references/` 目录
- Python 脚本实现

---

## [2.0.0] - 2025-03-02

### 已新增
- Plugin 架构版本，位于 `claude-code-plugin/` 目录
- 独立 Commands 支持
- 通过 Marketplace 安装的支持

---

## [1.0.0] - 2025-02

### 已新增
- 初始版本发布
- 单一 Skill 架构
- 语义化文献搜索
- 期刊/会议质量评估
- BibTeX 生成功能
- 中文推荐报告输出
