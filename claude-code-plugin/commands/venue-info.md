---
description: 查询期刊/会议的 CCF 分级和影响因子
argument-hint: 期刊或会议名称/缩写
allowed-tools: Bash
---

# /citation:venue-info

查询学术期刊或会议的 CCF 分级、影响因子、JCR/中科院分区等信息。

## 参数

**$ARGUMENTS**: 期刊或会议名称/缩写（如 "TMI", "ICML", "Nature Medicine"）

## 执行

```bash
cd "$HOME/.claude/plugins/marketplaces/citation-assistant/claude-code-plugin" && \
VENUE="$ARGUMENTS"; \
echo "查询: $VENUE"; \
echo; \
python3 -c "
import sys
import sqlite3
import re

venue = '''$VENUE'''.strip()
if not venue:
    print('错误：请提供期刊/会议名称')
    sys.exit(1)

venue_lower = venue.lower()
venue_alnum = re.sub(r'[^a-z0-9]', '', venue_lower)

try:
    conn = sqlite3.connect('data/ccf_2022.sqlite')
    cursor = conn.cursor()

    # 尝试精确匹配简称
    cursor.execute('SELECT * FROM ccf_2022 WHERE acronym_alnum = ?', (venue_alnum,))
    result = cursor.fetchone()

    if not result:
        # 模糊匹配
        cursor.execute('SELECT * FROM ccf_2022 WHERE acronym_alnum LIKE ? OR name LIKE ?',
                      (f'%\n{venue_alnum}%', f'%\n{venue_lower}%'))
        result = cursor.fetchone()

    if result:
        columns = [desc[0] for desc in cursor.description]
        data = dict(zip(columns, result))
        print('=== CCF 分级信息 ===')
        print(f\"名称: {data.get('name', 'N/A')}\")
        print(f\"简称: {data.get('acronym', 'N/A')}\")
        print(f\"CCF 等级: {data.get('rank', 'N/A')}\")
        print(f\"类型: {data.get('type', 'N/A')}\")
        print(f\"领域: {data.get('field', 'N/A')}\")
    else:
        print('未在 CCF 列表中找到该期刊/会议')

    conn.close()
except Exception as e:
    print(f'查询出错: {e}')

# 尝试查询影响因子
try:
    from impact_factor.core import Factor
    fa = Factor()
    results = fa.search(venue)
    if results:
        item = results[0] if isinstance(results, list) else results
        print()
        print('=== 影响因子信息 ===')
        print(f\"期刊: {item.get('journal', item.get('name', 'N/A'))}\")
        print(f\"影响因子: {item.get('factor', item.get('impact_factor', 'N/A'))}\")
        print(f\"JCR分区: {item.get('jcr_quartile', item.get('jcr', 'N/A'))}\")
        print(f\"中科院分区: {item.get('cas_quartile', item.get('cas', 'N/A'))}\")
except ImportError:
    pass  # impact_factor 未安装
except Exception as e:
    pass  # 其他错误忽略
"
```

## 示例

```
/citation:venue-info TMI
/citation:venue-info ICML
/citation:venue-info Nature Medicine
/citation:venue-info IEEE Transactions on Medical Imaging
```

## 说明

- 优先匹配 CCF 列表中的简称（如 TMI, ICML, CVPR）
- 支持模糊匹配全称
- 如已安装 impact_factor 库，将同时显示 IF 信息
