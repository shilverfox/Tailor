# Tailor 五模板完整页面族与盲测门禁报告

日期：2026-07-21  
状态：页面族证据与 5 个隔离 AI-agent 独立盲测完成；内部视觉门禁通过。

## 1. 页面族证据

- 使用最新冻结工作区与 `MemoryBookVisualQAFixture`。
- 设备：iPhone 17 Pro Simulator，iOS 26.5。
- 同一份 7 页文档、相同文本、相同照片源、相同 US Letter 页面尺寸，仅切换模板。
- 五套模板各取得 `cover`、`chapterOpener`、`photoSelection`、`closing` 四类页面，共 20 张。
- 自动化截图用例执行结果：1/1 通过；业务代码未修改，临时截图用例已移除。
- 截图目录：`screenshots/`；导出清单：`screenshots/manifest.json`。

## 2. 匿名题集

- 题集：`questions.md`。
- 答案：`answer-key.md`，与题集物理分离；独立评审不得读取。
- 20 道题覆盖 5 模板 × 4 页面族，每套模板在题集中出现 4 次。
- 每位评审必须完成全部 20 题，只能从五个冻结模板名中单选。

## 3. 独立性要求

- 需要 5 个 `fork_turns=none` 的独立评审流程。
- 评审只能读取 `questions.md` 及其直接链接的 20 张截图。
- 禁止读取 `answer-key.md`、`screenshots/manifest.json`、源码和其他评审答案。
- 当前执行环境的并发槽被产品、研发、测试和设计占满，因此本角色没有伪造或代填答案。

## 4. 独立盲测结果

| 评审 | 正确数 / 20 | 识别率 |
|---|---:|---:|
| R1 | 18 / 20 | 90% |
| R2 | 20 / 20 | 100% |
| R3 | 20 / 20 | 100% |
| R4 | 20 / 20 | 100% |
| R5 | 20 / 20 | 100% |
| 总计 | 98 / 100 | 98% |

混淆矩阵（行=真实模板，列=回答模板）：

| 真实\\回答 | Warm Paper | Quiet Night | Field Notes | Film Album | Cinema |
|---|---:|---:|---:|---:|---:|
| Warm Paper | 20 | 0 | 0 | 0 | 0 |
| Quiet Night | 0 | 19 | 0 | 0 | 1 |
| Field Notes | 0 | 0 | 20 | 0 | 0 |
| Film Album | 0 | 0 | 0 | 20 | 0 |
| Cinema | 0 | 1 | 0 | 0 | 19 |

唯一混淆发生在 `Cinema` 与 `Quiet Night`；其余三套模板为 100% 对角命中。五位评审均为 `fork_turns=none` 且禁止访问答案的独立 AI-agent，因此该结果是内部一致性门禁证据，不等同于真实用户或市场研究。

## 5. 当前门禁结论

- “五模板完整页面族有运行证据”：通过。
- “至少五名独立评审”：通过（5 个隔离 AI-agent）。
- “20 题/人”：通过（100 次判断）。
- “总体识别率 >=80%”：通过（98%）。
- Quiet Night：即使盲测达到 80%，仍需真机确认 Material 合成表现；Simulator 证据不能解除该条件门禁。
