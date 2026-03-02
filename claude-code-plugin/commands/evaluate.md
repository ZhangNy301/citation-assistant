---
description: 评估论文质量（CCF/IF/引用量等多维度评分）
argument-hint: 论文信息（JSON格式或自动使用上一步结果）
allowed-tools: Bash
---

# /citation:evaluate

对论文进行多维度质量评估，整合 CCF 分级、影响因子、引用量等指标。

## 参数

**$ARGUMENTS**: 可选的论文标题或 venue 名称。如不提供，将尝试读取上一步的搜索结果。

## 执行

```bash
cd "$HOME/.claude/plugins/marketplaces/citation-assistant/claude-code-plugin" && \
python3 scripts/quality_ranker.py "$ARGUMENTS" 2>/dev/null || \
echo "质量评估需要配合搜索结果使用，请先执行 /citation:search"
```

## 评分维度

| 维度 | 权重 | 说明 |
|------|------|------|
| CCF 分级 | 基础分 | A=100, B=70, C=40 |
| JCR 分区 | 基础分 | Q1=80, Q2=60, Q3=40, Q4=20 |
| 中科院分区 | 基础分 | 1区=90, 2区=70, 3区=50, 4区=30 |
| 影响因子 | ×0.3 | IF × 5 (上限50) |
| 引用量 | ×0.2 | log₁₀(citations+1) × 10 (上限50) |
| 年份新近度 | ×0.1 | (year-2015) × 2 (上限30) |
| 作者影响力 | ×0.2 | h-index × 0.5 (上限30) |

## arXiv 处理规则

- 有正式发表版本 → 优先引用正式版本
- 无正式版本但高引用 → 可引用（不惩罚）
- 低引用 arXiv → 优先级降低 (-20分)

## 使用方法

**方式 1: 配合搜索结果**
```
/citation:search "attention mechanism"
/citation:evaluate  # 自动评估上一步结果
```

**方式 2: 查询特定期刊 CCF 等级**
```
/citation:evaluate "ICML"
/citation:evaluate "IEEE Transactions on Medical Imaging"
```
