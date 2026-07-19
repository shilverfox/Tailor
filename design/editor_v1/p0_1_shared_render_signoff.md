# P0-1 · PageStyle / RenderPlan 产品与设计签核单

**用途：** 此页是 P0-1 的签核门槛；详细阈值与 fixture 矩阵见 [shared_render_contract_acceptance.md](shared_render_contract_acceptance.md)。任何一项 `Fail` 或 `Not run`，P0-1 均为 **不通过**，不得称“预览即成品”。

## 1. 待验收的唯一承诺

同一冻结 `MemoryBookDocument` 必须先产出不可变的 `PageRenderPlan[]`，再由三处消费：

`Editor 成品页（不含编辑控件） → 阅读预览 → PDF`。

三处不得再按页面类型、布局或模板分别猜测元素 frame、纸张 inset、字体、装饰、滤镜或水印。导出开始后的编辑只影响下一次导出。

## 2. 签核清单

| ID | 产品/设计口径 | 必须同时成立的 Editor / Reader / PDF 行为 | 通过证据 |
| --- | --- | --- | --- |
| S-01 页面与纸张 | 纸张背景、外部 backdrop、圆角/边框/阴影、A4/Letter 的边距来自同一 `PageStyle`。深绿工作区仅属于编辑器外层。 | 同页的纸张边缘、留白和背景完全一致；不出现工作区、选择框或控件。 | 同一页 Editor 成品裁切图、Reader PNG、PDF 栅格 PNG、叠图/热图；元素边界误差 ≤ 页面长边 0.5%。 |
| S-02 安全区 | 用户图片/文字只能落在 7% 安全区；标题、页码、装饰、水印是保护层。 | 三端都使用同一安全区与层级；旋转元素不越界、不覆盖模板保护层。 | plan JSON 的 safe rect、边缘/中心/旋转 fixture、边界断言。 |
| S-03 文本 | 标题与正文使用明确且可嵌入的同一字体映射；Small / Default / Large 同时定义字号、行距、字距和对齐。 | 内容、可见字符、换行、行盒、对齐和颜色一致；超出时三端均阻断，不可静默裁切。 | plan 文本行盒 JSON、PDF font metadata、中文/emoji fixture 的 Reader/PDF diff。 |
| S-04 图片 | `assetID + normalizedFrame + Fill + cropScale/Offset + rotation + zIndex` 是唯一图片指令。 | 焦点、裁剪、旋转方向和遮挡次序一致；PDF 仅提高源图清晰度，不改变构图或颜色。 | asset manifest、重叠图/±15°/横竖图 fixture；焦点误差 ≤ 容器短边 1%。 |
| S-05 五模板 | Warm Paper、Quiet Night、Field Notes、Cinema、Film Album 的颜色、字体、边距、装饰及图片处理均为共享 token。 | 五套均真实呈现其特征，不能只是换背景色。Cinema 有同源单色/低饱和效果；Film 有同源胶片边框与日期区域。 | 五模板 × A4/Letter 的 plan、PNG、PDF、热图；颜色采样差 ≤ 2/255（抗锯齿边缘除外）。 |
| S-06 水印与免费样章 | 免费阅读只展示 6–8 页代表性页面；每页重复、低对比、对角 `TAILOR · PREVIEW`。已解锁阅读和正式 PDF 无水印。 | 样章包含封面、目录、至少两个时段、照片页和结尾；水印密度、位置与透明度由 plan 提供。 | 10 页 fixture 的 page ID 清单和截图；每页至少两枚水印（或设计明确签字的等价密度）；已解锁 PDF 反证。 |
| S-07 导出快照 | 用户点 Export 时冻结 document 与 plan。 | PDF 的页序、资产、样式和水印不因导出中编辑而改变；下次导出才使用新稿。 | documentHash、plan hash、导出前后编辑测试及两份 PDF hash。 |

## 3. 最小验收矩阵与归档

固定一份含封面、目录、章节开场、单图、双图、2×2/3×2、注记、重叠元素、三档文字、单页样式覆写的 fixture：

- 5 模板 × A4 / US Letter × 每种页面类型；
- 免费样章和已解锁完整阅读各一组；
- 缺失/未授权 asset 一组（必须在导出前阻断）。

每组归档在 `artifacts/editor-render/<build>/<fixture>/<style>/<paper>/<state>/`，至少包含：`manifest.json`（build、设备、iOS、documentHash、plan hash）、Editor 成品图、Reader 图、原 PDF、PDF 栅格图、两张热图、元素/文本 metrics JSON 与 `Pass/Fail/Not run` 结论。

## 4. 签核记录

| 角色 | 签核范围 | 结论 | 证据链接 / 日期 |
| --- | --- | --- | --- |
| 研发 | S-01～S-07 的共享消费、fixture 与自动化结果 | 待研发交付 | — |
| 产品/设计 | 页面叙事、模板特征、免费水印、视觉差异 | 待复核 | — |
| 测试 | 矩阵执行、资产异常、快照一致性、结果可复现 | 待复核 | — |

**当前状态（2026-07-16）：待研发交付后复核；尚未签核通过。**
