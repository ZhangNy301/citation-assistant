# S2 429 诊断与验证（2026-10-22）

关联：Issue #8、PR #9。记录不包含密钥；真实密钥只保存在本地被忽略的 `.env`。

## 已确认和未确认的原因

- 同一作者接口，无效测试密钥返回 403，提供的密钥返回 200；初始化和真实 curl 测试确认 header 正确发送。
- 绕过项目脚本的请求也返回 429，带 `x-amzn-ErrorType: TooManyRequestsException`。直连和经代理均复现，不能归因为本地脚本或代理独有问题。
- 返回时间和请求 ID 会变化，未发现反复读取同一旧错误响应的证据。
- 仅请求标题的初始样本成功率较高，但后续轻量搜索仍可能连续 429；完整字段搜索也能成功。字段数量不是已证明的根因。
- API 响应不能区分密钥配额、其他客户端共享用量、接口容量或服务端策略。没有服务端用量数据，不能声称已确认或解除具体配额。

## 迭代实验

| 实验 | 观察 | 决策 |
|---|---|---|
| 完整 / 精简字段、代理 / 直连对照 | 成功与 429 交替出现；直连完整字段也返回 429 | 不自动绕过代理，不宣称改字段能根治 |
| 普通搜索退避 5、10、20、40 秒 | 总耗时约 83 秒，5 次请求仍 429 | 不把大幅增加等待作为默认修复 |
| 轻量搜索再 batch 补详情 | 轻量搜索可失败；另一个查询搜索成功后 batch 连续 429 | 不引入更多请求和复杂的半成品结果 |
| S2 有界重试，持续 429 后转 CrossRef | 多个真实查询完成，既覆盖 S2 直接/重试成功，也覆盖 CrossRef 降级 | 使用明确标记来源的统一入口 |
| CrossRef 检索质量检查 | 初次广泛检索返回一个补充材料 DOI | 自动降级增加论文类型过滤；直接 CrossRef 脚本保留全类型选项 |

试验均采用低频请求。不同实验的少量样本不构成性能基准或可用性保证。

## 最终行为

`search_papers.sh` 保留 S2 相关性搜索，仅在其有限次重试后的最终状态为 429 时使用 CrossRef。401/403、网络失败、空结果和格式错误不触发降级，避免掩盖其他故障。

CrossRef 只选择 `journal-article` / `proceedings-article` / `posted-content`，返回 `work_type`。所有结果标记 `source`、`search_method`、`fallback_reason`；CrossRef 不可用的 S2 作者 ID、arXiv 判断为未知，不能补造作者 H-index。不同来源的引用量统计口径不能直接等同。原始 S2 脚本保留独立调用及非零错误退出行为。

这解决的是单一来源限流导致检索中断；S2 原始接口仍可能持续 429，CrossRef 也可能不可用。两个来源都失败时明确报错，不输出伪造或部分结果。候选文献仍需要人工/助手判断是否支持原文。

## 可复现验证

```bash
python3 -m unittest discover -s tests -v
# 在本地 .env 配置自己的 Key 后显式执行；CI 不调用真实接口
python3 tests/live_search_smoke.py --rounds 2
```

- 离线测试涵盖退避、Retry-After、认证失败、真实 curl header 传递、来源切换、论文类型过滤参数、空结果、两个来源均失败、CrossRef HTTP/JSON 错误和密钥不传给 CrossRef。
- 真实验证串行检索 rPPG、医学影像 Vision Transformer、分子属性 GNN 三个主题，每次检查 2 条候选、来源/未知字段、CrossRef 论文类型，并取一个 DOI 验证 BibTeX。
- 初始两轮真实流程测试均 3/3 成功；第一轮发现补充材料问题后加入类型过滤，第二轮仍 3/3 成功，覆盖实际 S2 429 后的 CrossRef 自动降级。

- 最终 `live_search_smoke.py --rounds 2`：6/6 查询成功，全部完成 DOI→BibTeX 验证；其中 4 次为 S2 结果、2 次为真实持续 429 后的 CrossRef 降级，单次流程约 5–17 秒。该样本不能保证未来外部接口可用性。

## 依据

- [Semantic Scholar 官方教程](https://www.semanticscholar.org/product/api/tutorial)：请求限流、batch/bulk 建议、减少字段。
- [CrossRef REST API 文档](https://github.com/CrossRef/rest-api-doc#multiple-filters)：重复 type 过滤器采用 OR 语义。
