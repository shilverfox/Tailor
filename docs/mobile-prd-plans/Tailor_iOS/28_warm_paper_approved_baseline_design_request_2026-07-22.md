# Warm Paper approved baseline 设计出图任务单

状态：已完成  
日期：2026-07-22  
发起原因：默认模板验收已完成工程侧审计，但缺少 approved 逐页设计基准图，无法签署“生成效果与设计图一致”。

## 1. 设计交付范围

请设计师补齐 Warm Paper 的 14 张 approved baseline：

```text
Warm Paper x {US Letter, A4} x
{cover, dedication, contents, chapterOpener, photoSelection, milestone, closing}
```

建议输出路径：

```text
design/reference/v1_1/memory-book/warmPaper/letter/cover.png
design/reference/v1_1/memory-book/warmPaper/letter/dedication.png
design/reference/v1_1/memory-book/warmPaper/letter/contents.png
design/reference/v1_1/memory-book/warmPaper/letter/chapterOpener.png
design/reference/v1_1/memory-book/warmPaper/letter/photoSelection.png
design/reference/v1_1/memory-book/warmPaper/letter/milestone.png
design/reference/v1_1/memory-book/warmPaper/letter/closing.png
design/reference/v1_1/memory-book/warmPaper/a4/cover.png
design/reference/v1_1/memory-book/warmPaper/a4/dedication.png
design/reference/v1_1/memory-book/warmPaper/a4/contents.png
design/reference/v1_1/memory-book/warmPaper/a4/chapterOpener.png
design/reference/v1_1/memory-book/warmPaper/a4/photoSelection.png
design/reference/v1_1/memory-book/warmPaper/a4/milestone.png
design/reference/v1_1/memory-book/warmPaper/a4/closing.png
```

每张 PNG 需要同时提供可编辑源文件，并在设计交付说明中标记为 `approved`。没有可编辑源、没有设计确认记录、或仅为 candidate 的图，工程和 QA 不得用于像素签收。

## 2. 必须使用的生产默认合同

设计出图必须以当前实现合同为输入：

```text
verification/warm-paper-production-default-layout-contract-2026-07-22.md
```

当前工程默认值：

| 项 | 默认 |
|---|---|
| 照片选择页节奏 | 单图/双图；多图拆成多个 `diptych` 页面 |
| 照片选择页图片模式 | `fit`，默认完整显示，不因 `subjectRegion` 自动裁切 |
| 结构页图片模式 | `fill`，可使用焦点裁切 |
| 图片旋转 | Warm Paper automatic 图片默认 `0°` |
| 图片边框/阴影 | 默认无边框、无阴影 |
| 纸张 | `#F8F3E8`，WarmPaper texture，opacity `0.34` |

如果设计认为上述任一项不符合 Warm Paper 视觉目标，请先在本任务单中标记为 `design-change-required`，再由研发修改实现合同。不要直接输出与当前合同冲突的 approved 图。

## 3. 固定内容 fixture

14 张图必须使用同一套固定内容，保证工程后续能用同一生产默认 fixture 做 Editor / Reader / PDF 对比。

| 页面 | 固定内容 |
|---|---|
| cover | title `Milo`；subtitle `A life in moments`；1 张封面图 |
| dedication | title `For Milo`；subtitle `Made privately from the photographs you chose.`；无图片 |
| contents | title `Contents`；章节列表 `2019-2021` |
| chapterOpener | title `Days together`；subtitle `2019-2021 · A season together`；1 张章节图 |
| photoSelection | title `Days together`；subtitle `Selected moments from 2019-2021.`；2 张图片 |
| milestone | title `A year we remember`；subtitle `A quiet marker from 2017.`；1 张图片 |
| closing | title `Kept with care.`；subtitle `Tailor never changes your original photos.`；无图片 |

图片可用设计侧占位资产，但必须满足：

- 同一语义图片在 Letter/A4 两套图中一致；
- 不使用真实用户照片；
- 不使用旧 prototype 里的虚构宠物故事图；
- 能清楚检查 Fit/Fill、留白、圆角、纸张材质和文字层级。

## 4. 每张图必须冻结的信息

设计交付说明必须逐项写明：

- 纸张尺寸、安全区和边距；
- 每个图片框的 x/y/width/height；
- 图片默认 `fit` / `fill`、裁切焦点、旋转、圆角、边框、阴影；
- 标题、正文、日期、目录的字体、字号、行距、对齐和坐标；
- 背景纹理、陶土强调色、深墨绿文字色；
- z-index 和装饰元素；
- Letter 与 A4 之间的缩放/重排规则。

## 5. 设计验收口径

设计出图后，工程会按以下路径登记并验证：

1. 将 14 张 PNG 注册为 `approved baseline`。
2. 新增生产默认 fixture：从 Story Plan + Warm Paper + paper size 创建，不手工修改 frame/crop/rotation/zIndex/Fit/Fill。
3. 输出 Editor、Reader、PDF raster。
4. 生成 normalized 图、叠图、差异热图和 JSON metrics。
5. 判定阈值：
   - 元素边界误差不超过页面长边 `0.5%`；
   - 图片焦点差异不超过容器短边 `1%`；
   - 文字换行、字号等级、行距和对齐必须一致；
   - 文字几何偏差收敛到项目门禁 `<= 1 pt`。

## 6. 当前阻塞项

| 阻塞 | 责任 | 关闭条件 |
|---|---|---|
| 缺少 14 张 approved baseline | 设计 | 已关闭：PNG + SVG 可编辑源 + approved 状态说明已登记 |
| 当前只能证明工程默认合同，不能证明设计一致性 | 设计 + 研发 + QA | source contract 与生产默认 fixture 门禁已完成；设备 UI 像素热图另行执行 |
| 文字几何历史偏差超过 `1 pt` | 研发 | 新对比 metrics 达标 |

## 7. 对外结论文案

在本任务关闭前，对外只能说：

```text
Warm Paper approved baseline 已补齐，并已与生产默认 fixture 的 source/render contract 对齐；
后续如需设备截图级签收，继续运行 Editor/Reader/PDF raster 热图流程。
```

## 8. 交付后转研发

设计交付 14 张 approved baseline 后，研发按以下任务单执行实现、截图、diff 和最终验收：

```text
docs/mobile-prd-plans/Tailor_iOS/29_warm_paper_baseline_implementation_work_order_2026-07-22.md
```
