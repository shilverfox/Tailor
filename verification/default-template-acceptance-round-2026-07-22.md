# 默认模板验收轮次记录

- 日期：2026-07-22
- 默认模板：Warm Paper
- 默认纸型：US Letter；同步覆盖 A4
- 验收对象：模板生成页面中的默认图片布局、大小、样式、裁切和旋转
- 轮次结论：**contract PASS；Warm Paper approved baseline 已登记，生产默认 fixture 已通过 source/render contract 门禁。设备 UI 像素热图证据可作为后续增强项补采。**

## 1. 需求来源

PRD 对本轮验收的约束：

- 首次创建默认推荐 `Warm Paper`，美国市场默认 `US Letter`，可切换 `A4`。
- 五套模板必须改变字体、留白、图片处理、页面配方权重、章节开场和整书节奏，不允许只换配色。
- Warm Paper 的页面语言是“暖白、大留白、单图/双图、陶土日期、纸本感”。
- 图片默认 `Fit` 完整显示；只有 `Fill/Crop` 才允许裁切，并且要明确体现裁切状态。

代码依据：

- `Tailor/Domain/ArchiveModels.swift:4474`：`MemoryBookTemplatePolicy`
- `Tailor/Domain/ArchiveModels.swift:4543`：`applyAutomaticTemplateAccents`
- `Tailor/Domain/ArchiveModels.swift:4641`：`MemoryBookBuilder.elements`
- `Tailor/Domain/ArchiveModels.swift:4668`：`MemoryBookBuilder.build`
- `Tailor/Domain/ArchiveModels.swift:957`：`MemoryBookPageRenderPlan`

## 2. 本轮交付物

| 交付物 | 路径 | 状态 |
|---|---|---|
| Warm Paper 单模板设计验收报告 | `verification/warm-paper-template-design-acceptance-2026-07-22.md` | 已完成，结论 FAIL/PENDING |
| Warm Paper 生产默认布局合同 | `verification/warm-paper-production-default-layout-contract-2026-07-22.md` | 已完成，冻结当前实现默认值 |
| Warm Paper approved baseline | `design/reference/v1_1/memory-book/warmPaper/APPROVED.md` | 已完成，14 张 PNG + SVG 源已登记 |
| Warm Paper approved baseline preflight | `verification/memorybook_v2/warm_paper_approved_baseline_preflight_after_design_2026-07-23.json` | 通过 |
| Warm Paper source contract report | `verification/memorybook_v2/warm_paper_approved_baseline_contract_2026-07-23.json` | 通过 |
| 本轮默认模板验收矩阵 | `verification/default-template-acceptance-round-2026-07-22.md` | 当前文件 |

## 3. 验收矩阵

| 验收项 | 当前证据 | 判定 |
|---|---|---|
| 默认模板是否为 Warm Paper | `MilestoneRootView` 初始 `style = .warmPaper`；PRD 指定 Warm Paper 推荐默认 | 通过 |
| 默认纸型是否覆盖 US Letter | PRD 指定美国市场默认 US Letter；现有 Warm Paper/Letter PDF raster 和 manifest 存在 | 通过 |
| A4 是否同步覆盖 | 现有 Warm Paper/A4 PDF raster 和 manifest 存在 | 通过 |
| 七类页面是否能生成 | 现有证据包含 `cover`、`dedication`、`contents`、`chapterOpener`、`photoSelection`、`milestone`、`closing` | 通过 |
| 生产默认图片 frame 是否明确 | 已在默认布局合同中冻结 normalizedFrame 与 Letter/A4 点位 | 通过 |
| 生产默认 rotation 是否明确 | Warm Paper automatic 图片由 `applyAutomaticTemplateAccents` 归零 | 通过 |
| 生产默认边框/阴影是否明确 | 默认 `MemoryBookElementAppearance` 为无边框、无阴影；Warm Paper 未额外加相框 | 通过 |
| 生产默认 Fit/Fill 规则是否明确 | 结构页默认 Fill；Warm Paper 照片选择页默认 Fit，不因 `subjectRegion` 自动裁切 | 通过 |
| 当前 runtime/PDF 证据是否代表生产默认布局 | `MemoryBookProductionDefaultFixture` 已新增；contract 单测覆盖 Letter/A4、7 页、文案、style token、frame、Fit/Fill、rotation、照片顺序 | 通过 |
| 是否存在 approved 逐页设计基准图 | `design/reference/v1_1/memory-book/warmPaper/<paper>/<page-kind>.png` 14 张已存在，并有 SVG 源与 approved 说明 | 通过 |
| 是否能签“与设计图一致” | source contract 与生产默认 fixture render contract 已一致；设备 UI 像素热图未在本轮采集 | contract 通过 |
| 是否能签“当前实现默认合同已冻结” | 默认 frame、mode、rotation、纸张、坐标口径已登记，并由单测门禁保护 | 通过 |

## 4. 14 格页面结论

| 页面 | US Letter | A4 | 当前阻塞 |
|---|---|---|---|
| cover | contract PASS | contract PASS | 无 |
| dedication | contract PASS | contract PASS | 无 |
| contents | contract PASS | contract PASS | 无 |
| chapterOpener | contract PASS | contract PASS | 无 |
| photoSelection | contract PASS；Fit 实际 frame 已按资产比例收缩 | contract PASS；Fit 实际 frame 已按资产比例收缩 | 无 |
| milestone | contract PASS | contract PASS | 无 |
| closing | contract PASS | contract PASS | 无 |

## 5. 当前证据边界

本轮已关闭原先“缺 approved baseline”阻塞，并完成 source/render contract 级放行。证据边界如下：

- 14 张 approved baseline PNG 已补齐，且 SVG 源通过 `verify_warm_paper_approved_baseline_contract.py`。
- `MemoryBookProductionDefaultFixture` 从生产 builder 构建，不手工改 frame、crop、rotation、zIndex 或 Fit/Fill。
- `testProductionDefaultFixtureUsesBuilderDefaultsForWarmPaperBaseline` 覆盖生产默认 render contract，确保代码输出与 approved baseline 合同一致。
- 本轮未采集真实设备 Editor/Reader 截图，也未生成 UI 像素热图；如需要像素级签收，应继续执行 29 工单中的截图/diff 步骤。

## 6. 下一步关闭条件

原关闭条件完成情况：

1. 设计确认默认 frame、mode、rotation、边框、阴影和纸张处理：已完成，见 `APPROVED.md`。
2. 设计输出并登记 14 张 approved baseline：已完成。
3. 新增生产默认 fixture：已完成。
4. 用同一 fixture 做硬门禁：source/render contract 已完成；设备截图热图未采集。
5. 文字几何门禁：render contract 单测通过；设备截图级文字 bbox 差异未在本轮采集。

设计出图任务已登记：

```text
docs/mobile-prd-plans/Tailor_iOS/28_warm_paper_approved_baseline_design_request_2026-07-22.md
```

设计交付后的研发实现任务已登记：

```text
docs/mobile-prd-plans/Tailor_iOS/29_warm_paper_baseline_implementation_work_order_2026-07-22.md
```

## 7. 本轮结论

默认模板验收当前结论为 **contract PASS**：

- 可以确认当前代码的 Warm Paper 默认生成合同与 approved baseline source contract 一致。
- 可以确认照片页默认已对齐单图/双图、Fit、rotation 0，并按资产比例收缩到真实可见图片边界。
- 可以发布为“默认模板生成合同已与 approved baseline 对齐”；若对外声称“像素级一致”，仍需补充设备截图热图。
