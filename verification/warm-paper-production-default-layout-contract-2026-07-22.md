# Warm Paper 生产默认布局合同

- 日期：2026-07-22
- 范围：`MemoryBookBuilder.build(... style: .warmPaper ...)` 的生产默认输出
- 目的：冻结当前代码实际生成的 Warm Paper 默认页面结构，供设计基准图验收使用
- 结论：这是“当前实现合同”，不是设计通过证明；是否符合设计仍需批准基准图逐页对比

## 1. 代码依据

- 页面生成入口：`Tailor/Domain/ArchiveModels.swift` 的 `MemoryBookBuilder.build`
- 默认元素入口：`MemoryBookBuilder.elements`
- Warm Paper 排版策略：`MemoryBookTemplatePolicy.capacity/layout`
- 自动模板修饰：`MemoryBookDocument.applyAutomaticTemplateAccents`
- 自动焦点裁切：`MemoryBookDocument.applyAutomaticFocalCrops`
- 渲染坐标口径：`MemoryBookPageRenderPlan.rect(for:)`

## 2. 坐标口径

元素的 `normalizedFrame` 不是相对整张纸，而是相对 `paperRect`：

```text
paperInsetRatio = 18 / 612
paperRect = pageRect.insetBy(dx: pageWidth * paperInsetRatio,
                             dy: pageWidth * paperInsetRatio)
```

因此：

| 纸型 | pageRect | paperRect |
|---|---:|---:|
| US Letter | 612 x 792 pt | x 18.00, y 18.00, w 576.00, h 756.00 |
| A4 | 595 x 842 pt | x 17.50, y 17.50, w 560.00, h 807.00 |

## 3. Warm Paper 默认模板策略

| 条件 | 默认结果 |
|---|---|
| `capacity(for: .warmPaper, pageOrdinal)` | 每页最多 2 图 |
| `layout(for: .warmPaper, photoCount: 1, ...)` | `single` |
| `layout(for: .warmPaper, photoCount: 2, ...)` | `diptych` |
| `layout(for: .warmPaper, photoCount > 1, ...)` | `diptych` |
| 结构页图片 | 单图，默认 `fill` |
| 照片选择页图片 | 默认 `fit`，即使有 `subjectRegion` 也不自动裁切；随后按资产宽高比收缩到实际可见照片边界 |
| Warm Paper 自动旋转 | 所有 automatic 图片 `rotationDegrees = 0` |
| Warm Paper 图片边框/阴影 | 默认 `borderStyle = none`，`shadowOpacity = 0` |
| Warm Paper 图像处理 | `imageTreatment = original` |
| Warm Paper 纸张 | `#F8F3E8`，texture `WarmPaper`，opacity `0.34` |

## 4. 默认元素 normalizedFrame

所有页面默认都有标题：

| 元素 | normalizedFrame | zIndex |
|---|---:|---:|
| title | x 0.08, y 0.08, w 0.84, h 0.10 | 10 |
| subtitle | x 0.08, y 0.17, w 0.84, h 0.06 | 9 |

结构页有照片时使用单图：

| 页面 | 图片 normalizedFrame | mode | rotation |
|---|---:|---|---:|
| cover | x 0.08, y 0.27, w 0.84, h 0.40 | fill | 0 |
| chapterOpener | x 0.08, y 0.27, w 0.84, h 0.40 | fill | 0 |
| milestone | x 0.08, y 0.27, w 0.84, h 0.40 | fill | 0 |

照片选择页 `diptych` 初始槽位：

| 槽位 | normalizedFrame | 初始 mode | rotation |
|---|---:|---|---:|
| 1 | x 0.08, y 0.27, w 0.41, h 0.40 | fit | 0 |
| 2 | x 0.51, y 0.27, w 0.41, h 0.40 | fit | 0 |

生产文档初始化会运行 `normalizeFitImageFramesToAssetAspect()`。因此 approved baseline 和 render manifest 中的照片选择页实际可见图片 frame 为：

| 槽位 | 资产比例 | 实际 normalizedFrame | mode | rotation |
|---|---:|---:|---|---:|
| 1 | 16:9 landscape | x 0.08, y 0.3546875, w 0.41, h 0.230625 | fit | 0 |
| 2 | 9:16 portrait | x 0.6025, y 0.27, w 0.225, h 0.40 | fit | 0 |

## 5. 换算后的 Letter 点位

| 元素 | frame points |
|---|---:|
| title | x 64.08, y 78.48, w 483.84, h 75.60 |
| subtitle | x 64.08, y 146.52, w 483.84, h 45.36 |
| structural single image | x 64.08, y 222.12, w 483.84, h 302.40 |
| diptych initial slot 1 | x 64.08, y 222.12, w 236.16, h 302.40 |
| diptych initial slot 2 | x 311.76, y 222.12, w 236.16, h 302.40 |
| diptych actual image 1 | x 64.08, y 286.14, w 236.16, h 174.35 |
| diptych actual image 2 | x 365.04, y 222.12, w 129.60, h 302.40 |

## 6. 换算后的 A4 点位

| 元素 | frame points |
|---|---:|
| title | x 62.30, y 82.06, w 470.40, h 80.70 |
| subtitle | x 62.30, y 154.69, w 470.40, h 48.42 |
| structural single image | x 62.30, y 235.39, w 470.40, h 322.80 |
| diptych initial slot 1 | x 62.30, y 235.39, w 229.60, h 322.80 |
| diptych initial slot 2 | x 303.10, y 235.39, w 229.60, h 322.80 |
| diptych actual image 1 | x 62.30, y 303.74, w 229.60, h 186.08 |
| diptych actual image 2 | x 354.90, y 235.39, w 126.00, h 322.80 |

## 7. 验收含义

这份合同可以用于设计验收的第一步：设计师先确认这些默认 frame、mode、rotation、边框、阴影和纸张质感是否就是 Warm Paper 应有的默认生成效果。

若设计确认通过，应把相同 fixture 输出为 14 张批准基准图，再做 approved baseline x Editor x Reader x PDF 的叠图和热图。

若设计不接受，应先改 `MemoryBookTemplatePolicy`、`MemoryBookBuilder.elements` 或 `applyAutomaticTemplateAccents`，再重新生成默认合同和基准图。
