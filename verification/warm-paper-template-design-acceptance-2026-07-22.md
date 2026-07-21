# Warm Paper 单模板生成效果设计验收

- 日期：2026-07-22
- 当前代码基线：`b6bb6e0`（工作区另有法务链接改动，不影响模板渲染）
- 范围：Warm Paper × US Letter/A4 × 7 类页面
- 验收目标：确认生成页面的默认图片布局、大小、裁切、旋转、边框与视觉样式是否和批准设计图一致
- 总结论：**FAIL/PENDING — 缺少批准的逐页设计基线，且现有 fixture 不代表生产默认生成值，不能签署一致性通过**

## 0. 2026-07-23 状态更新

2026-07-22 的结论是基于“缺少 approved baseline”的历史状态。2026-07-23 已补齐 Warm Paper × Letter/A4 × 7 页 approved baseline，并完成 source/render contract 门禁：

- approved baseline：`design/reference/v1_1/memory-book/warmPaper/APPROVED.md`
- preflight：`verification/memorybook_v2/warm_paper_approved_baseline_preflight_after_design_2026-07-23.json`
- source contract：`verification/memorybook_v2/warm_paper_approved_baseline_contract_2026-07-23.json`
- 研发结果：`verification/memorybook_v2/approved_baseline_warm_paper_20260723/result.md`

当前状态为 **contract PASS**。设备截图级像素热图仍未在本报告中补采。

## 1. 基线审计

当前可找到的设计输入：

- `design/assets/02_Warm_Paper.png`：只定义暖白纸张材质和色调，不包含页面布局、图片框或文字坐标。
- `design/editor_v1/screens/template-system.svg`：单页概念方向，只覆盖一个示意布局，不是 7 类页面 × 2 纸型的批准基线。
- `design/auto-book-v2/screens/03-book-style.png`：模板选择页面原型，不是相册页设计基线。

要求的批准基线路径尚不存在：

```text
design/reference/v1_1/memory-book/warmPaper/<paper>/<page-kind>.png
```

现有 PDF metrics 也明确声明证据仅用于 deterministic raster/manifest，不是 approved-reference pixel comparison。

## 2. 14 个验收单元

| 页面类型 | US Letter | A4 | 结论 |
|---|---|---|---|
| cover | blocked-design-baseline | blocked-design-baseline | 无批准的图片框位置、尺寸、旋转及标题坐标基准 |
| dedication | blocked-design-baseline | blocked-design-baseline | 无批准的文字区域、换行及留白基准 |
| contents | blocked-design-baseline | blocked-design-baseline | 无批准的目录网格、页码及间距基准 |
| chapterOpener | blocked-design-baseline | blocked-design-baseline | 无批准的章节图框、裁切及标题层级基准 |
| photoSelection | blocked-design-baseline | blocked-design-baseline | 无批准的多图 frame、叠层、rotation、crop 基准 |
| milestone | blocked-design-baseline | blocked-design-baseline | 无批准的图片/日期/注记区域基准 |
| closing | blocked-design-baseline | blocked-design-baseline | 无批准的结尾排版、对齐及留白基准 |

以上状态不是判定当前实现错误，而是说明“与设计图一致”这一命题目前没有可比较的正式设计图。

## 3. 当前可以确认的工程证据

- Warm Paper 的 Letter/A4 均能生成 7 页 Reader 与 PDF raster。
- PDF media box 正确：Letter `612 × 792 pt`，A4 `595 × 842 pt`。
- 页面类型完整：cover、dedication、contents、chapterOpener、photoSelection、milestone、closing。
- Reader 与 PDF 使用共享 render manifest；这些证据可以检查两端内部一致性。
- 现有 fixture 图片是确定性色块/焦点探针，不足以签署真实照片的默认裁切观感。

## 4. 当前证据不等于“默认生成布局”

- `cover` fixture 人为加入约 `6°` 旋转，而生产 Warm Paper 自动生成默认 rotation 为 `0`。
- `photoSelection` fixture 人为设置重叠、`-8°/+12°` 旋转及混合 Fit/Fill；生产 builder 默认使用 Warm Paper 单图/双图规则，照片选择页默认 Fit、rotation 为 `0`。
- 因此当前截图能验证 Reader/PDF 对同一编辑结果的一致渲染，却不能验证用户首次选择 Warm Paper 后的默认图片位置、大小、裁切和样式。
- 现有证据主要覆盖 Reader/PDF，没有形成 approved baseline × Editor × Reader × PDF 的完整四方对照。
- 最新已记录文字几何偏差为 A4 `1.538 pt`、Letter `1.447 pt`，仍高于项目 `≤ 1 pt` 的文字门禁。

## 5. 关闭验收所需输入

需要以同一固定 fixture 输出 Warm Paper 的 14 张批准设计图：

```text
Warm Paper × {US Letter, A4} ×
{cover, dedication, contents, chapterOpener, photoSelection, milestone, closing}
```

每张设计图必须冻结：

- 纸张尺寸、安全区和页面边距；
- 每个图片框的 x/y/width/height；
- 默认 fill/fit、焦点、裁切、旋转、圆角、边框和阴影；
- 标题、正文、日期的字体、字号、行距、对齐和坐标；
- 装饰元素、z-index、背景纹理和强调色；
- 与固定 fixture 对应的内容、图片顺序和页面类型。

同时需要新增“生产默认生成”fixture：直接由 Story Plan + Warm Paper + paper size 创建文档，禁止测试代码手工修改 frame、rotation、crop、z-index 或 Fit/Fill。该 fixture 才能回答默认布局是否符合设计。

基线登记为 `approved` 后，再生成 Editor/Reader/PDF 归一化图、叠图和差异热图。验收阈值沿用项目合同：元素边界误差不超过页面长边 `0.5%`，图片焦点差异不超过容器短边 `1%`，文字换行、字号等级及对齐必须一致。

## 6. 放行结论

Warm Paper 当前只能签署“可生成、双纸型和七类页面齐全”以及“既有编辑结果在 Reader/PDF 内部的图片几何一致”；不能签署“默认图片布局、大小、裁切和样式与模板设计图一致”。关闭本阻塞需要批准并注册 14 张逐页设计基线、新建生产默认 fixture、完成 Editor/Reader/PDF 叠图，并将文字偏差收敛至 `≤ 1 pt`。
