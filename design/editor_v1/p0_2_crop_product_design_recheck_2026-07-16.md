# P0-2 / A 组 Crop 产品与设计独立复验（第二轮）

- 复验日期：2026-07-16
- 复验范围：`19_p0_2_remaining_crop_text_render_save_plan_2026-07-16.md` §A；`18_p0_2_editing_interactions_qa_acceptance_2026-07-16.md` §3。
- 结论：**不通过（不得进入 B 组 Text）**。
- 复验方式：源码、测试实现、xcresult 结果和现有 Simulator UI 用例的独立审阅；不以按钮存在或测试绿灯替代视觉/交互审阅。

## 已核实的实现与可采信证据

| 项目 | 结论 | 证据 |
| --- | --- | --- |
| Fill 数学约束 | 部分通过 | `FillCropConstraint` 在 `ArchiveModels.swift:349-422` 统一约束最小缩放与 offset；`F-P02-CROP` 覆盖 6 个宽高比及 ±15°（`TailorFeatureTests.swift:695-727`）。模型 45/45 通过。 |
| 本地草稿与 Done 事务 | 部分通过 | `MemoryBookCropSession` 的 draft 与 document 分离（`ArchiveModels.swift:427-498`）；`CropEditorSheet.apply()` 在 Done 前一次 `recordHistory()`，后调用 `applyCrop`（`AlbumFeatureViews.swift:762-770`）。取消时没有写 document 的模型用例存在。 |
| Crop 入口及基本 Cancel/Done | 部分通过 | UI 用例 `testEditorCropHasStableIdentifiersAndCancelDoneFlow` 通过，xcresult：`/tmp/tailor-crop-ui/Logs/Test/Test-Tailor-2026.07.16_15-15-47-+0800.xcresult`，1/1。 |
| 未提交退出三选项 | 部分通过 | UI 用例 `testEditorCropDraftExitOffersKeepSaveAndDiscard` 通过，xcresult：`/tmp/tailor-crop-qa-ui/Logs/Test/Test-Tailor-2026.07.16_15-27-25-+0800.xcresult`，1/1；源码有 Keep / Save and leave / Discard 文案及稳定 ID（`AlbumFeatureViews.swift:716-720`）。 |
| 跨 Preview / A4 / Letter 的**数据**同源 | 部分通过 | `testCommittedCropIsIdenticalInPreviewAndBothPaperRenderPlans` 比较 asset、frame、crop、rotation、z-index（`TailorFeatureTests.swift:779-802`）。这仅证明 render plan 字段相同，不证明三种渲染像素或裁切顺序相同。 |
| 代码健康 | 通过 | 指定模型测试结果为 45/45：`/tmp/tailor-crop-tests2/Logs/Test/Test-Tailor-2026.07.16_15-14-44-+0800.xcresult`；本次复验 `git diff --check` 无输出。 |

## P0 阻断项

### CRP-001 / CRP-002：Crop 画面与最终结果在旋转图片上不一致

`F-P02-CROP` 明确包含初始旋转 ±15° 的图片；但 Crop stage 仅对 `PhotoAssetThumbnail` 做缩放与 offset，**没有**应用 `target.element.rotationDegrees`（`AlbumFeatureViews.swift:684-699`）。同一元素在编辑画布中则在裁切之后才 `.rotationEffect`（`AlbumFeatureViews.swift:284-288`），PDF 中则是先在裁剪容器内旋转真实 CGImage（`ProductionServices.swift:188-205`）。

这不是抽象的实现差异：用户在未旋转的 Crop stage 中选择的焦点，会在编辑器和 PDF 中以旋转后的内容出现；且 SwiftUI Preview 的 `clip → rotation` 与 PDF 的 `clip container → rotate image` 并非同一裁切顺序。现有测试只比较 `MemoryBookPageRenderPlan` 字段，未对旋转 fixture 做任一截图或像素/焦点比对，因此不能证明 “原元素固定框、横竖图焦点一致、Preview/PDF 同源”。

**返工要求：**抽出同一个 image-transform render helper，Crop stage、Editor/Reader 和 PDF 均以 `container clip → transform(scale/offset/rotation) → source` 的同一几何顺序绘制；为横框竖图、竖框横图、+15°/-15° 添加截图/fixture 断言。裁剪 stage 需直观显示最终旋转状态，而不是只在导出时旋转。

### CRP-002：72% 遮罩规格没有可验证的视觉证据

源码有 `Color.black.opacity(0.72)`（`AlbumFeatureViews.swift:681-683`）和固定比例的 aperture 计算，但 UI 测试只断言 Reset/Cancel/Done 元素存在；没有 Crop stage 截图、无 72% 覆盖区域的视觉审阅或尺寸断言。当前结构把图像限制在 aperture 内，外围是纯黑；未证明设计要求的“固定原元素框 + 72% 非编辑区域遮罩”在横竖图上可理解、可对照。

**返工要求：**归档横、竖、旋转 fixture 的 Crop stage 截图，明确标注原元素比例窗口；测试/截图必须能审阅遮罩、边框、操作区与图片焦点，而非仅按钮存在。

### CRP-003 / CRP-004：Cancel、Done、Undo 的视觉流只验证控件路径，未验证用户结果

当前 Cancel/Done UI 用例未执行拖拽或捏合，只测试 “打开 → Cancel → 再打开 → Done”。它没有比对 Cancel 前后 frame / scale / offset / rotation / lock 状态，也没有通过 UI 执行 Undo/Redo。模型测试是有价值的事务证据，但无法替代真实编辑流的验证。

**返工要求：**通过稳定的 nudge/zoom 测试入口或坐标手势制造 draft；录制/截图并断言 Cancel 恢复、Done 后 Undo/Redo 的缩略图或导出的 document 值。保留当前模型快照断言。

### CRP-005：Crop 内 Reset 缺少规格要求的确认与完整回退证据

独立 Crop stage 的 `Reset` 直接修改 draft（`AlbumFeatureViews.swift:748-752`），没有确认；照片工具的 `Reset photo` 虽有二次确认，但不是本次 Crop stage 用例。现有测试没有覆盖 “Reset → Done → Undo 恢复裁剪、frame、rotation、z-index”。

若产品意图是将 Crop 内 Reset 定义为无副作用的草稿回退，应在 PRD/验收矩阵中明确该例外；否则需补齐二次确认及该完整事务验证。

### CRP-006：三选项仅覆盖一个 Cancel 路径，不覆盖切页和退后台

`leave()` 只由顶部 Cancel 触发（`AlbumFeatureViews.swift:756-760`）。未见页面切换、应用退后台（scene phase）或系统关闭全屏裁剪时复用同一状态机的实现/自动化证据。验收矩阵要求 “返回编辑器 / 切页 / 应用退后台” 都显示 Keep editing / Save and leave / Discard this edit。

**返工要求：**禁止 dirty crop 被交互式关闭，或截获所有退出源后统一进入三选项；对切页/返回/退后台至少提供可自动化的状态机与回读证据。

### CRP-007：Replace 的产品路径缺少独立验收

生产 `PhotoPickerSheet.insert` 的确保留既有 element 的 frame / rotation / z-index，并按新 asset 重新计算 Fill（`AlbumFeatureViews.swift:528-540`）。但现有单测在一个局部 `MemoryBookElement` 上手工赋值，不经该 production path；没有替换后进入 Crop、实际图片无白边的 UI/渲染证据。

**返工要求：**添加生产级 document 操作（或 UI）测试：已裁剪/旋转/调层图片 Replace 后，属性保持，新的 source aspect 在 Editor/Reader/PDF 都无白边。

## 矩阵判定

| 用例 | 判定 | 原因 |
| --- | --- | --- |
| CRP-001 | 不通过 | 独立 stage 和按钮存在，但旋转元素在 Crop stage 不呈现最终状态。 |
| CRP-002 | 不通过 | 数学 clamp 通过；旋转渲染顺序与最终输出不一致，且无四边真实 UI/视觉证据。 |
| CRP-003 | 部分通过，未签收 | 模型 draft 不写 document；未验证真实编辑后的 Cancel 前后状态。 |
| CRP-004 | 部分通过，未签收 | 模型有 baseline 恢复思路；无 Done→Undo→Redo UI 或完整 undo stack 验证。 |
| CRP-005 | 不通过 | Crop stage Reset 无确认，且无 Reset→Done→Undo 证据。 |
| CRP-006 | 不通过 | 仅顶部 Cancel 的一个 dirty 流；切页、退后台/关闭未覆盖。 |
| CRP-007 | 部分通过，未签收 | 源码路径正确倾向，但生产路径/UI/渲染无验收。 |
| Preview / A4 / Letter / PDF | 不通过 | 仅 manifest 字段等值；没有冻结 manifest 后的实际 PDF 结构/渲染、无 raster 比对。组 C 才可关闭其数据/输出层，最终 PDF raster/真机仍为 G-EDITOR-03。 |

## 不属于本次签收、但必须继续保留的最终门禁

- 真实设备 + 真正 Photos 资产的 Crop 操作、滚动和导出验证：**未执行**。
- A4 与 US Letter 的真实 PDF raster / heatmap（含 5 个模板）：**未执行**。
- P0-1 视觉发布门禁：**仍待关闭**。

上述项目不得被本次 Simulator 45/45 模型绿灯或两条 UI 绿灯标记为完成。

## 复验结论

**A 组 Crop 不签收。** 研发应先修正旋转照片的统一裁剪渲染顺序与退出状态机覆盖，再补足上表 P0 证据；产品/设计与 QA 需在返工后重新独立验收。B 组 Text 不应启动。
