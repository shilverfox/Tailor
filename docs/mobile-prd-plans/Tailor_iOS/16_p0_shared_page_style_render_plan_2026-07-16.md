# P0-1 最小实施计划：共享 PageStyle 与 PageRenderPlan

> 范围：只关闭编辑器、阅读预览、PDF 对页面背景、纸张边距、字体映射和 Cinema / Film 装饰的双实现偏差。

## 问题

当前 SwiftUI 的 `EditorBookPageCanvas` 直接以页面纸色作为整个画布背景；PDF 则绘制 backdrop + 18pt 内纸张。两端还分别维护色板和字体，Cinema / Film 的处理也不一致。因此即使消费相同元素坐标，也不满足“预览即成品”。

## 最小方案

1. 在领域层增加平台无关的 `MemoryBookPageStyle` 与 `MemoryBookPageRenderPlan`：
   - 5 套模板的 RGB token；
   - `paperInset`、纸张矩形、按 z-index 排序的页面元素与归一化元素矩形计算；
   - 标题/正文的同一字体 token 与尺寸规则；
   - Cinema 的本地单色图像处理标志、Film 的页面边框与图片框规则。
2. `EditorBookPageCanvas` 与 `AlbumPagesPreview` 只通过 render plan 绘制 backdrop、paper、元素位置、字体和装饰；编辑态只额外画选择框。
3. `LocalPDFExporter` 删除本地 palette/几何/字体判断，改为同一 render plan；继续只在 PDF 端做高分辨率 PhotoKit 请求。
4. 为 Cinema 的 SwiftUI 缩略图使用与 PDF 相同的 `CIPhotoEffectMono`；Film 的纸张边框和图片框同时出现在两端。
5. 增加纯模型单测，锁定 5 个 style 的 token、A4/Letter 的 paperRect 与 element 映射；现有测试全量回归。

## 非目标

- 不修改裁剪交互、元素 resize、页面管理、资产异常、自动排版或购买流。
- 不声称本次已经完成 PDF 栅格像素门禁；本次只先消除可由源码证明的共享渲染差异，后续视觉门禁仍需真实 PhotoKit 资产。

## 验收证据

- 编译通过；共享几何/样式单测覆盖 A4、Letter 与五套模板。
- SwiftUI 和 PDF 均调用 `MemoryBookPageStyle.resolve` / `MemoryBookPageRenderPlan`，不存在各自 `palette(for:)` 或各自 paper inset 常量。

## 实施记录（研发，2026-07-16）

### 本次文件范围

- `Tailor/Domain/ArchiveModels.swift`：共享 `MemoryBookPageStyle`、`MemoryBookPageRenderPlan`，以及字体与 Film 页面/图片边框的比例 token。
- `Tailor/Features/AlbumFeatureViews.swift`：编辑画布与阅读预览共同复用 `EditorBookPageCanvas`；删除遗留的独立 `AlbumPalette` / `MemoryBookPageView` 渲染路径。
- `Tailor/Services/ProductionServices.swift`：`LocalPDFExporter` 只从 RenderPlan 读取纸张、字体、Cinema treatment 与 Film 页面/图片边框。
- `TailorTests/TailorFeatureTests.swift`：覆盖五个模板 × A4/US Letter 的 PageStyle、纸张几何、Cinema/Film 指令和字体 token。

### 返工补齐（P0-1，非其它 P0）

- `MemoryBookDocument.renderManifest(watermarked:)` 生成不可变、可序列化的 `MemoryBookRenderManifest`；其 `plans` 是 Preview/PDF 使用的统一页序、元素排序、样式与水印快照。
- `MemoryBookWatermarkStyle.preview` 定义重复的 `TAILOR · PREVIEW`、透明度、旋转和两个归一化位置；Reader Preview 不再叠加硬编码 `PREVIEW`，PDF 有同一 `watermarked` 渲染分支，正式导出固定传 `false`。
- `F-RP-01` 在 XCTest 内以固定 ID 构造 cover / dedication / contents / chapter opener / photo selection / milestone / closing 七页，不请求 PhotoKit；测试覆盖 `5 template × 2 paper × 7 page = 70` 份 plan 的 Editor / Reader / PDF manifest 等值、稳定 z-index 排序和免费/已购水印差异。

### P0-1 可签核范围

本项只证明三端使用同一份**页面视觉令牌与元素几何合同**。它不等同于 PRD §7.3 的 PDF 栅格像素门禁；测试图片注入、冻结 `PageRenderPlan[]`、PDF/SwiftUI 60 页 raster diff 仍由后续验收项关闭。
