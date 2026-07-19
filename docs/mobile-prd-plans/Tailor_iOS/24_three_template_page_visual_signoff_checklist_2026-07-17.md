# Tailor · 三模板逐页视觉签收清单

状态：**待设计批准基线，不能签收为像素级通过**  
范围：Warm Paper、Quiet Night、Field Notes × A4/US Letter × 7 类相册页 = **42 个逐页签收单元**。  
固定夹具：`F-RP-01`（确定性、非个人 PhotoKit 图片）；真实相册夹具只在后续真机视觉补验使用。

本清单补足现有 PDF 结构验收：结构测试已经能证明可生成 PDF、manifest 和 raster，但不能替代设计批准后的逐页视觉判定。

## 1. 基线状态与指定资源

下列资源只能作为**待批准候选**，不得在验收记录中写为 `approved`：

| 用途 | 当前待批准候选 | 能覆盖什么 | 不能覆盖什么 |
|---|---|---|---|
| Warm Paper 材质/token | `design/assets/02_Warm_Paper.png` | 暖白纸张质感、色调、无宠物背景方向 | 不是完整页面设计，不能单独签收版式或文本。 |
| Quiet Night 材质/token | `design/assets/03_Quiet_Night.png` | 深墨绿哑光纸张方向 | 同上。 |
| Field Notes 材质/token | `design/assets/04_Field_Notes.png` | 浅鼠尾草纸张/规则线方向 | 同上。 |
| 预览页面 UI 壳层 | `design/reference/v1_1/09-preview-unpurchased-page-1.png` 至 `...-8.png`，及 `09-preview-purchased.png` | iPhone 预览入口、页码/水印状态的候选方向 | 390×844 的应用截图，不是 A4/Letter 页面基线，且 reference manifest 状态为 candidate。 |

设计师批准前，以上全部标记为 `candidate`；现有
`design/visual-qa/reference_manifest.md` 是状态权威来源。批准后必须导出以下页级基线，才能启动像素比较：

```text
design/reference/v1_1/memory-book/<template>/<paper>/<page-kind>.png
```

每张页级基线应由可编辑设计源导出，使用与 `F-RP-01` 相同的文案、元素顺序、图片焦点和水印状态；路径注册到 reference manifest 后才可改为 `approved`。

## 2. 42 个逐页签收单元

每个单元都需要 Editor、Reader、PDF raster 三端证据；同一页面的编辑选中框、拖拽手柄和辅助线不属于 PDF 差异。

| Page kind | Warm A4 | Warm Letter | Quiet A4 | Quiet Letter | Field A4 | Field Letter |
|---|---|---|---|---|---|---|
| `cover` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `dedication` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `contents` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `chapterOpener` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `photoSelection` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `milestone` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `closing` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |

签收状态仅可填写：`pass`、`fail`、`blocked-design-baseline`、`blocked-runtime`。在批准前默认均为 `blocked-design-baseline`。

## 3. 每类页的检查项

| Page kind | 通用三端检查外的逐页检查项 |
|---|---|
| `cover` | 宠物名、subtitle、年份层级；封面大图裁剪；模板纸张/背景；免费态重复 `TAILOR · PREVIEW` 水印。 |
| `dedication` | 多行正文的换行、行距、对齐和留白；无图片框残留；纸张安全区。 |
| `contents` | 目录条目、页码/对齐、标题层级；不得溢出或与纸张边距冲突。 |
| `chapterOpener` | 日期范围、章节标题、用户 note 的层级；单图位置与裁剪；中性叙事文案不被替换为推断性描述。 |
| `photoSelection` | 多图叠层顺序、归一化 frame、crop scale/offset、rotation、焦点和边界；无编辑把手进入 Reader/PDF。 |
| `milestone` | 日期/注记区、图片框、留白与边框规则；图片与文字不互相遮挡。 |
| `closing` | 结尾文字换行与居中/对齐规则；无多余图片框；模板背景与水印状态正确。 |

所有页还必须同时检查：

1. PDF page size：A4 `595×842 pt`，US Letter `612×792 pt`。
2. `paperRect`、`safeRect`、元素 z-index、asset ID、normalized frame、rotation、crop 和文本 token 与共享 render manifest 一致。
3. 未购样章每页均有水印；已购导出的完整 PDF 不得残留水印。
4. Sensitive、never-use、隐藏时期资产不进入 Editor/Reader/PDF 页。

## 4. Editor / Reader / PDF 三端比对步骤

针对每一个 `<template>/<paper>/<page-kind>`：

1. 加载固定 `F-RP-01` 文档，记录该页的 `manifest.json` plan 摘要。
2. Editor 进入非选中展示态后截图；另保留编辑态截图只用于确认可编辑性，不进入像素比对。
3. Reader 打开同一页并截图；不得重新构造 palette、paper inset、字体、元素排序或水印规则。
4. 导出同一 frozen manifest 的 PDF，栅格化该页；记录实际 PDF media box。
5. 将 Editor/Reader 归一化至同一页面可视区，再与 PDF raster 和批准设计基线叠图/热图。
6. QA 量化几何与裁剪，设计师签核 token、排版和整体视觉。任何一端不一致均为 `fail`，而不是“系统渲染差异”。

判定阈值沿用共享 render-plan 验收：元素边界误差不超过页面长边 `0.5%`；图片焦点差异不超过容器短边 `1%`；可见文字、换行、字号等级与对齐必须完全一致。

## 5. 截图与工件命名

根目录（不提交个人照片）：

```text
artifacts/visual-qa/memory-book/<build-or-sha>/F-RP-01/<template>/<paper>/<02-page-kind>/
```

固定文件名：

```text
baseline-candidate.png          # 仅候选时必须带 candidate 标记，不得命名 approved
baseline-approved.png           # 仅 reference manifest 已登记 approved 后允许存在
editor-display.png              # 无选中框/手柄的可视页
editor-editing.png              # 只记录编辑态，不参与 PDF 像素差异
reader.png
exported.pdf
pdf-raster.png
normalized-editor.png
normalized-reader.png
diff-editor-reader.png
diff-reader-pdf.png
diff-baseline-pdf.png           # 无 approved baseline 时不得生成“pass”结论
manifest.json
metrics.json
result.md
```

`result.md` 必须包含：build/SHA、fixture、模板、纸张、page kind/index、截图分辨率、PDF media box、manifest fingerprint、元素/焦点误差、文字比对、水印状态、QA 判定、设计判定、阻塞原因。

示例路径：

```text
artifacts/visual-qa/memory-book/abc123/F-RP-01/warmPaper/a4/01-cover/pdf-raster.png
```

## 6. 签收记录模板

```markdown
### <template> / <paper> / <page-kind> / page <index>

- Build/SHA:
- Fixture: F-RP-01 / F-RP-REAL:
- Baseline: candidate / approved / missing
- Baseline path:
- Editor screenshot:
- Reader screenshot:
- PDF / raster:
- Manifest fingerprint:
- Media box:
- Element edge error:
- Image focal error:
- Text match:
- Watermark state:
- QA result: pass / fail / blocked-design-baseline / blocked-runtime
- Design result: pass / fail / pending
- Notes:
```

## 7. 当前结论与外部关闭项

- 现有自动化已证明 5 个当前代码模板 × A4/Letter × 7 页的 PDF 结构和 raster 非空；本清单的正式视觉范围仅取产品承诺的三模板（Warm/Quiet/Field）。
- 本轮 42 格均为 **`blocked-design-baseline`**，不是工程视觉失败：没有一张三模板、两种纸张、七类页面的 approved 页级设计基线。
- 设计师需先批准上述三个纹理候选的模板方向，并交付/注册 42 张页级 PNG 基线；随后 QA 才能生成 diff heatmap 并进行逐格签收。
- 最终发布前还需使用真实、非提交的 `F-RP-REAL` 在真机验证照片裁剪及印刷观感；这不能由固定色块 fixture 替代。
