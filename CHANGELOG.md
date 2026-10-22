# 更新日志

本文件记录项目的主要变更。

格式参考 [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)。

## [未发布]

### 已新增
- Codex 用户级 / 项目级 Skill 安装说明、显式调用示例及 `agents/openai.yaml` 元数据
- 跨客户端、跨工作目录的离线回归测试，以及 Linux / macOS CI

### 兼容性
- Skill 命令改用实际安装路径，不再依赖 `CLAUDE_SKILL_ROOT`
- Semantic Scholar 脚本共用初始化逻辑，支持通过 `S2_RATE_LIMIT_FILE` 隔离限流状态（默认路径不变）

### 已修复
- 三个 S2 脚本共用有界 429 重试，支持 Retry-After / 指数退避，明确区分认证失败与限流
- 更新过时的 API 限流配置说明；密钥通过私有临时文件传给 curl，不出现在命令行参数中
- 修复期刊综合查询使用 jq 保留字 `if` 作为变量名导致的编译错误
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
