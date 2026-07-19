# P0-2 · 产品/设计独立复核记录（2026-07-16）

**依据：** [P0-2 签核验收清单](p0_2_product_design_signoff.md)  
**复核对象：** 当前工作区 `ArchiveModels.swift`、`AlbumFeatureViews.swift`、`ProductionServices.swift`；模型结果包 `/tmp/tailor-p02-model-tests2/Logs/Test/Test-Tailor-2026.07.16_14-03-35-+0800.xcresult`；UI 结果包 `/tmp/tailor-p02-ui-tests/Logs/Test/Test-Tailor-2026.07.16_14-05-11-+0800.xcresult`。  
**独立运行观察：** iPhone 17 Pro Simulator / iOS 26.5，`-uiTesting -uiDemoRoute editor`，截图：`/tmp/tailor-p02-independent-editor.png`。

## 结论

| 层级 | 结论 | 说明 |
| --- | --- | --- |
| 功能合同 | **不通过，退回研发。** | Layout 的基础迁页和已保存文本的模型测量可用，但 Crop、Text 和 Layout 都有 P0 行为缺口或错误摘要，不能签收。 |
| 设计 / 可运行 UI | **不通过。** | 独立运行仅证明 Editor 可打开；提供的 UI 自动化只断言五个版式按钮存在，未覆盖裁剪态、文字溢出/Fit text、确认/取消/Undo 或超量迁页。 |
| 真机视觉 / 发布门禁 | **未执行，仍不通过。** | 没有真机、真实照片、A4/Letter Reader/PDF raster、热图和指标；P0-1 的发布门禁也没有被本批解除。 |

因此 **P0-2 不通过，不得进入下一能力项。**

## 已核实的正向证据（不等同于签收）

1. 模型结果包为 **2/2 Passed**：
   - `testExplicitLayoutChangeMovesOverflowIntoNewChapterPagesWithoutLosingPhotos()`：6 张图片从 3×2 转 2×2 时，保留 4 张、建立 1 个同章节新页、总 asset 不丢失。
   - `testTextOverflowIsBlockingAndFitTextResolvesTheSameModelMeasurement()`：一个既有 text element 可被模型测量为溢出、Book Check 阻断、Fit text 后解除。
2. UI 结果包为 **1/1 Passed**：
   - `testEditorFixtureExposesExplicitLayoutChoices()`：Layout sheet 有 `Single / Two-up / Grid 2×2 / Grid 3×2 / Note` 五项。
3. 源码存在 `CropEditorSheet`、`TextEditorSheet`、`LayoutPickerSheet` 和 layout confirmation dialog；这说明研发已开始实现，而非仅有设计稿。

这些证据的范围严格限于上述断言；**没有**验证真实 Photos 裁剪、Cancel 回滚、Fit text 编辑中提示、文字长度、确认摘要准确性、Undo/Redo、重进保存、Reader/PDF 一致性或异常路径。

## P0 阻断项

### A. Crop：独立裁剪态不能通过（CR-01…13）

| ID | 复核结果 | 当前源码证据 / 问题 | 返工要求 |
| --- | --- | --- | --- |
| CR-01 | 部分通过 | `PhotoPickerSheet` 仅在已选 image 时显示 Crop；但底栏 `Photo` 对任何页面/选择态都可打开，未提供明确的禁用/对象上下文。 | 让 Crop 入口只在合格图片选择态可用，或在无选择时提供明确 Add/Replace 页面级语义。 |
| CR-02/03 | **Fail** | `CropEditorSheet` 是整屏深绿背景与橙框，未实现规格要求的“固定原元素框 + 72% 遮罩”的独立裁剪画面；无专门 UI 测试或截图。 | 以原页面/元素框为裁剪窗口，明确遮罩和 `Cancel / Crop photo / Done / Reset` 状态，并补 UI 证据。 |
| CR-05/06 | **Fail** | `CropEditorSheet` 有 drag/magnify，但 `PhotoAssetThumbnail` 使用通用方形 480pt 预览；未证明与统一 Fill 算法/原图比例一致。缩放下限只限到 1，普通编辑器仍允许 `cropScale` 到 0.5，两个状态不一致。 | 统一 Editor/Crop/Reader/PDF 的 Fill、最小 scale 与 offset clamp；使用横竖真实 fixture 验证无白边。 |
| CR-08 | 部分通过 | Done 才 `recordHistory()` + commit，符合“合并一条”的方向；但没有 history / 自动保存 / 重进测试。 | 新增 Done 只生成一条 history、1 秒保存、杀进程重进的自动化。 |
| CR-09 | 部分通过 | Cancel 只 `dismiss()`，由于编辑被保留在本地 state，表面上可回滚；没有 before/after JSON 或 history 测试。 | 补明确快照和 Cancel 无副作用测试。 |
| CR-10 | **Fail** | Crop 内 `Reset` 仅写 `scale = 1; offset = .zero`，没有“Reset 后 Done 再 Undo”的测试；同一 editor 还有另一个 `Reset photo`，用户难以区分影响范围。 | 把 crop reset 的默认值、提交和 Undo 作为独立事务测试，并明确两种 reset 的文案。 |
| CR-11…13 | **Fail** | Replace / general reset 存在部分代码，但没有裁剪后替换、Cancel 替换、连续 Undo/Redo 的验收；`CropEditorSheet` 也未覆盖缺失 asset 中途变化。 | 补相应模型、UI 和真实 asset 证据。 |

### B. Text：溢出与 Fit text 不能通过（TX-01…13）

| ID | 复核结果 | 当前源码证据 / 问题 | 返工要求 |
| --- | --- | --- | --- |
| TX-01 | **Fail** | `TextEditorSheet` 是通用“选中 element 或 Add a new text box”，没有按封面/章节/照片页/献词/结尾列出允许字段；可在任何页新增 text。 | 按 PRD 字段白名单实现面板与数据绑定，禁止不属于页面语义的随意字段。 |
| TX-02 | **Fail** | `save()` 一律 `text.count <= 240`；没有照片页 120 的上限、输入时的上限/剩余反馈，也未覆盖 Unicode 可见字符。 | 按页面/字段实施 120/240 限制，输入中给反馈，补中英 emoji 用例。 |
| TX-03 | 部分通过 | Done 时一次 `recordHistory()`；但未实现/验证键盘避让、失焦提交与返回三分支。 | 补键盘、Save/Discard/Keep editing 行为及 history 证据。 |
| TX-04 | 部分通过 | Small/Default/Large picker 存在；`textMeasurement` 是确定性近似，不含跨端真实字体行盒；无 RenderPlan/PDF 证据。 | 三档应有同源 typography token、行距/字距与 Reader/PDF 对照。 |
| TX-05 | **Fail** | 文本拖动仅以 7% 页面 inset clamp，不实现模板安全锚点，也没有标题/页码/水印保护区冲突判断。 | 以 PageStyle anchor/protected rect 限制可拖范围并测试。 |
| TX-06 | **Fail** | `overflowMeasurement` 读取的是 document 中**保存前**的 selected element，不读取 TextEditor 正在输入的 `text`/`textStyle`，用户输入时不会实时看到红框或 Fit text。 | 用 draft text + draft style 实时测量并绘制编辑器内红框/提示。 |
| TX-07 | **Fail** | `fitText` 在 Small/Default/Large 都失败后会自动把 `normalizedFrame.height` 扩到页面底部。这违反 P0-2 已签核的“Fit text 不改 frame/对齐/内容；不能适配则继续报错”。 | Fit text 只能选择合法字号档；仍溢出时保留错误，提示用户缩短文字或手动调整允许框。 |
| TX-08/09 | 部分通过 | `checkBook()` 有 blocking issue，编辑器 More → Export 会打开 Book Check；但没有导出拦截/无 PDF 文件、跳转到具体错误页、解决后与 Undo 恢复的测试。 | 补 Book Check → Go to page、导出前拦截、修复/Undo 的 UI 与文件系统测试。 |
| TX-10/13 | **Fail** | 没有 A4/Letter 的真实文字 Reader/PDF raster，也没有 Unicode font fallback 证据。 | 产出纸张矩阵的文本行盒/raster/PDF font metadata。 |

### C. Layout：明确布局 UI 已有，但迁页完整性不能通过（LY-01…14）

| ID | 复核结果 | 当前源码证据 / 问题 | 返工要求 |
| --- | --- | --- | --- |
| LY-01 | 部分通过 | UI 用例证明五个显式选项存在。`editorToolbar` 却不论当前页类别都开放 Layout。 | 仅照片页启用 Layout；当前项明确选中，其他结构页给解释/禁用态。 |
| LY-02 | **Fail** | `LayoutPickerSheet` 没有 page kind gate；任何页可选择 layout。 | 实施结构页 no-op/说明，注记页只允许 Note。 |
| LY-03 | 部分通过 | layout enum / `photoCapacity` 与 model 可见，但本次没有完整五选项、RenderPlan 一致性测试。 | 补容量表和 plan manifest 合同测试。 |
| LY-04 | **Fail** | `applyLayoutChange` 只保留 `retainedText` 和已锁定图片；对超量照片会重新生成元素，未证明保存用户 frame/crop/rotation/order；遇到锁定元素也没有“不能安全切换”的解释。 | 定义保留/迁移时每个 user element 的策略，失败时确认前解释，补数据 diff。 |
| LY-05/06 | 部分通过 | confirmation dialog 存在；6→4 的模型测试通过 asset 数与 chapter ID。但没有 Cancel 的 JSON equality，也没有 UI 确认/迁页证据。 | 补 Confirm/Cancel UI、asset/page manifest，含原视觉顺序。 |
| LY-07 | **Fail** | `layoutChangeSummary` 在 `Note`（capacity=0）时固定 `newPageCount = 1`，但 `applyLayoutChange` 实际将所有图按 1 张切成多个新页。因此确认摘要在 6→Note 等场景错误。 | 让 summary 与实际迁页算法共享同一计算，并覆盖 1→4、2→6、6→2、6→Note。 |
| LY-08 | **Fail** | `Note` 会把所有照片迁成多个 3×2/每页 1 张的新页，但没有专门确认文案/测试，也未对无迁移路径给阻止说明。 | 实现并验收 Note 三分支：成功、Cancel、无可迁移素材。 |
| LY-09/10 | 部分通过 | `applyLayoutChange` 在 UI 调用前 `recordHistory()`；没有 atomic undo/redo 或重进自动化。 | 以完整 document diff 验收 layout→Undo→Redo 与持久化。 |
| LY-11…14 | **Fail / Not run** | 无真实 image，无法证明成品布局、空页处理、缺失资产、A4/Letter/五模板同源。 | 提供 fixture、Reader/PDF raster、错误态和矩阵 manifest。 |

## 自动化与证据覆盖评估

| 签核领域 | 交付测试 | 通过 | 仍缺 |
| --- | --- | --- | --- |
| Crop | 无 | — | CR-01…13 的全部可执行用例；真实横竖图手势、Cancel/Done/Reset/Undo/缺 asset。 |
| Text | 1 个模型测试 | 模型 Book Check + 一种 Fit text | 字段限制、120/240、输入中溢出、Fit 失败、Undo、键盘、Unicode、PDF。 |
| Layout | 1 个模型 + 1 个 UI 测试 | 一个 6→4 迁页模型合同；五个选项可见 | page kind gate、选中态、Cancel、Note 摘要、锁定元素、Undo/恢复、渲染。 |
| 视觉/真机 | 无 | — | 真实 Photos、Crop visual state、Reader/PDF A4/Letter、真机。 |

## 重新交验的最低条件

1. 修复本报告中所有 **Fail** 的源码行为，尤其 `fitText` 自动改 frame、文本限制、非照片页布局和 Note 摘要错误。
2. 运行并提供签核清单 §5 要求的自动化结果，不以 2+1 个窄测试替代。
3. 增加裁剪、溢出/Fit text、超量确认/Cancel/Confirm/Undo 的 UI 测试和可归档截图；每项使用稳定 accessibility ID。
4. 对至少一张真实横图/竖图和一个文本/迁页页，提供 A4/Letter 的 Editor 成品区、Reader、PDF raster 证据。
5. 真机可用后补真机 Photos 手势与 UI 视觉验收；在此之前不得宣称 P0-2 产品设计通过或解除发布门禁。

**产品/设计签核：Not signed / Fail**  
**复核人 / 日期：** 产品/设计验收负责人 · 2026-07-16

---

# P0-2 · 返工复验记录（2026-07-16 14:40）

**新增证据：**

- 完整回归：`/tmp/tailor-p02-final/Logs/Test/Test-Tailor-2026.07.16_14-38-24-+0800.xcresult`，**39/39 Passed**（其中单元 37、UI 2）。
- 裁剪定向 UI：`/tmp/tailor-p02-remediation/Logs/Test/Test-Tailor-2026.07.16_14-36-42-+0800.xcresult`，**1/1 Passed**，`testEditorCropHasStableIdentifiersAndCancelDoneFlow()`。

## 返工项复核结果

| 上次问题 | 返工后的源码 / 测试证据 | 复验结论 |
| --- | --- | --- |
| Fit text 擅自扩框 | `fitText` 只从 Large → Default → Small 尝试，失败直接返回 false；`testTextOverflowIsBlockingAndFitTextOnlyChangesTypography` 断言 frame 不变。 | **功能通过** |
| 120 / 240 与草稿测量 | `textCharacterLimit(on:)` 对照片页返回 120，其它页 240；TextEditor 用 draft `text/textStyle` 测量，并显示计数和超限提示；`testTextLimitAndDraftMeasurementUseCurrentTextStyleAndPageKind` 通过。 | **功能通过，真 UI 输入验证未运行** |
| 非照片页 Layout | `canChangeLayout` 与 `layoutChangeSummary` 均限制 `.photoSelection` 且排除当前 Note 页面；`testLayoutIsUnavailableForNoteAndStructuralPages` 通过。 | **符合“不能把注记/结构页改成照片页”的保护要求** |
| 锁定元素迁页 | `applyLayoutChange` 保留 locked element 的完整实例（frame/crop/rotation/z）；`testLayoutShrinkPreservesLockedImageGeometryCropRotationAndLayer` 通过。 | **模型合同通过** |
| Crop Cancel / Done 标识 | Crop sheet 有稳定 `Crop cancel`、`Crop reset`、`Crop done primary` identifiers；定向 UI 流程 Cancel、再进入、Done 通过。 | **基础 UI 流程通过** |

## 仍然阻断 P0-2 签收的项

### B-1 · `Note` 版式被从 Layout 功能移除（P0 Fail）

PRD §5.6 和设计规格 E06 明确规定当前照片页的 Layout 选项为 **Single、Two-up、Grid 2×2、Grid 3×2、Note**，并规定切换到 Note 时须处理超量照片。当前实现反而将其移除：

- `LayoutPickerSheet.options` 只有 `.single/.diptych/.grid2x2/.grid3x2`；
- UI 测试也断言 `Note` 不存在；
- `layoutChangeSummary` / `applyLayoutChange` 显式拒绝目标 `.note`。

这不是“保护已有 Note 页面”能够替代的能力：用户必须能够在**照片页**选择 Note，并在确认前看到全部照片迁移到同章节新照片页的准确摘要。该项对应签核单 **LY-01、LY-03、LY-05…LY-09**，故 P0 不通过。

### B-2 · 版式确认对锁定元素的影响仍未解释（P0 Fail）

当 locked 图片数超过目标 layout capacity，模型保留全部 locked 图片，源页可能高于所选容量；`MemoryBookLayoutChangeSummary.message` 只写 “keep N / move M”，不显示 locked element 数或“该元素不会按新模板重排”。签核单 LY-04 要求在不能安全切换时解释，而不是静默套用布局。缺少多锁定元素、布局缩小、确认文案及 Reader/PDF 成品证据。

### B-3 · Crop 视觉和真实 PhotoKit 裁剪仍未验收（Not run，阻断设计签收）

定向 UI 测试只校验 identifiers 与 Cancel/Done 导航；没有执行 drag/magnify、Reset → Done → Undo、横竖真实图片、缺失 asset、无白边或 Crop/Reader/PDF 焦点一致性。代码仍以全屏深绿背景和新计算的展示 frame 实现，没有提供设计规格要求的原页面固定元素框与 72% 遮罩的视觉核验。功能可继续，但不满足 CR-02/03/05…13 的产品设计证据要求。

### B-4 · Text 视觉 / 导出阻断闭环未验收（Not run，阻断设计签收）

模型当前能测量 draft，但没有 UI 自动化验证输入第 121/241 字符、实时红框/Fit text、Fit 失败的可见反馈、Book Check `Go` 定位、导出拒绝且无新 PDF、Undo 后问题恢复。也没有 A4/Letter Reader/PDF 的换行、字体、可见行对照。仅有字符串计数不是完整设计签收。

### B-5 · Reader/PDF 与真机门禁没有新增证据（Not run，发布仍 Fail）

本次 39 项回归没有 P0-2 的 PDF 栅格化产物、热图或 metrics；提供的唯一 UI case 没有 attachment。无真实 Photos、A4/US Letter 的 Crop/Text/Layout 三页面 Reader-PDF 对照，也无真机证据。因此 P0-1 “预览即成品”门禁与 P0-2 成品抽检仍均未解除。

## 复验总判定

| 层级 | 结果 |
| --- | --- |
| 模型局部合同 | **部分通过**：Fit 不扩框、文本 limit/draft measure、单锁定元素保留、非照片页限制通过。 |
| P0-2 功能合同 | **Fail**：缺失 PRD 要求的照片页 → Note 版式与超量处理，且锁定元素影响摘要不完整。 |
| 产品/设计 UI | **Fail**：Crop 定向导航通过，但核心手势/状态、Text/UI/Book Check、Layout confirm/Note 未被验证。 |
| 真机视觉 / Reader-PDF 发布门禁 | **Not run / Fail**。 |

**产品/设计签核：Not signed / Fail。**

## 再次交验的最小要求

1. 恢复照片页的 `Note` layout option；实现并测试 6→Note 的准确新增页摘要、Cancel/Confirm、资产顺序、单一 Undo/Redo 和重进恢复。
2. 把 locked 元素数及其不被重排的影响写入 confirmation；对超过目标容量的 locked 情况提供明确可理解的选择或阻止说明。
3. 补 P0-2 UI 自动化与归档截图：裁剪手势/Reset/Undo、文本 120/240/实时 overflow/Fit 失败/Book Check/Export block、布局四种迁页路径及 Note。
4. 以真实横/竖 asset 生成 P0-2 三类页面的 A4/Letter Reader/PDF raster；连接真机后补同一流程真机证据。

---

# E06 返工定向复验（2026-07-16 14:55）

**范围：** 仅复验上一轮 B-1（照片页 → Note 与超量迁页）和 B-2（锁定元素影响说明）。按协调要求，Crop/Text 的完整视觉、Reader/PDF、真实 PhotoKit 与真机门禁不在本次重开范围，继续维持 `Not run`。

**证据：** `/tmp/tailor-p02-e06-final/Logs/Test/Test-Tailor-2026.07.16_14-52-44-+0800.xcresult`，iPhone 17 Pro Simulator / iOS 26.5，**43/43 Passed**；已导出 UI attachment：`/tmp/tailor-p02-e06-attachments/8C502F1E-D975-4A78-B5B2-57EC18A59AE0.png`。

## B-1 · 照片页 → Note、迁页摘要与取消：Pass

- `LayoutPickerSheet` 已重新包含 `Note`；现有 Note 页和结构页仍由 model/toolbar 禁止反向切换，符合“只允许当前照片页进入 Note”的边界。
- `layoutChangeSummary` 对 Note 使用与 `applyLayoutChange` 相同的迁页容量（3×2 = 6），不再错误写为每张一页或固定一页。
- `testSixPhotosConvertToNoteAndMigrateInOriginalOrderWithinChapter()` 通过：6 张图转换为 Note 时，源页保留 0 张并变为 Note，新增同章节的 1 个 3×2 照片页；asset 和 element 顺序均与原顺序一致。
- `testLayoutPreviewCancelLeavesCompleteCodableDocumentUntouched()` 通过：确认预览不修改 Codable document。
- UI test 已选择 `Note`、出现 `Apply layout` 与显式 `Keep current layout`；归档截图可见确认摘要“keep 0 / move 3 / 1 new page”，没有使用含混的 Cancel。

**B-1 签核：Pass。**

## B-2 · 锁定图片影响说明：Pass

- `MemoryBookLayoutChangeSummary` 新增 `lockedPhotoCount` 和 `hasLockedCapacityImpact`；确认文案明确说明锁定图片“stay exactly where placed and will not be rearranged”，并在超过目标 capacity 时说明源页可能超出模板容量。
- `testLockedPhotosOverTargetCapacityAreCalledOutAndRemainOnSourcePage()` 通过：3 个 locked 图片转 Single 时，摘要含锁定数量、保留位置与超过容量说明；操作后 3 张仍全部留在源页。
- `testLayoutShrinkPreservesLockedImageGeometryCropRotationAndLayer()` 与 `testOverflowMigrationPreservesUserImageElementInsteadOfRegeneratingIt)` 通过：锁定/用户图片保留 element identity、frame、crop、rotation、z-index，不会被重建或重复迁入新页。

**B-2 签核：Pass。**

## 本次定向结论

| 项目 | 结论 |
| --- | --- |
| B-1 照片页 → Note / 超量迁页 / 取消 | **Pass** |
| B-2 锁定元素影响说明 | **Pass** |
| P0-2 全量产品设计签核 | **仍 Not signed**：仅因先前列出的 Crop/Text/Reader-PDF/真机证据未执行，并非 E06 仍有阻断。 |
| 发布门禁 | **仍 Not run / Fail**：不受本次 E06 定向通过影响。 |
