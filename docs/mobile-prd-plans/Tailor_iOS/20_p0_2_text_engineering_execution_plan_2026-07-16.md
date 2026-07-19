# P0-2 · B 组 Text 研发执行计划（仅计划，不实施）

> 状态：待产品 / QA 审阅计划；本文不代表 B 组已实现或已签收。
>
> 权威输入：`19_p0_2_remaining_crop_text_render_save_plan_2026-07-16.md` §B、`18_p0_2_editing_interactions_qa_acceptance_2026-07-16.md` §4、`14_life_album_page_editor_v1_PRD_2026-07-15.md` §5.5，以及 `design/editor_v1/p0_2_product_design_recheck_2026-07-16.md` 的 TX-01…13。
>
> 边界：仅计划 B/Text；**不实施** B、C、P0-3，也不以本计划替代 A4/Letter 栅格或真机发布门禁。

## 1. 当前实现核对与缺口

| 当前位置 | 已有能力 | 不能作为签收的原因 |
| --- | --- | --- |
| `ArchiveModels.swift`：`MemoryBookElement` / `MemoryBookTextStyle` | text、Small/Default/Large 可 Codable；`String.count` 以 Swift `Character` 计数。 | 没有字段语义或白名单；旧文本无法区分标题、日期、注记和献词。 |
| `ArchiveModels.swift`：`textMeasurement` | Sheet 和 `checkBook()` 调用同一确定性估算。 | 基于平均字宽/行高，不等于 Preview/PDF 的字体、字距、行距和实际换行行盒；不能证明 Arabic/emoji/组合字形。 |
| `AlbumFeatureViews.swift`：`TextEditorSheet` | 输入草稿、三字号、120/240 计数、草稿测量提示已有雏形。 | 任意页可 `Add a new text box`；没有页面字段白名单、画布红框、无障碍错误标识、失败状态、输入退出三分支和稳定 UI 标识。 |
| `fitText` / `checkBook` | Fit 不再扩 frame；Book Check 有 page 级 `Go`；More→Export 会先检查 blocker。 | Fit 不以当前草稿作原子提交；`Go` 不定位 element/编辑器；没有“无新 PDF”文件系统证据、Undo/Redo/冷启动回读或真实 typography manifest。 |
| Preview / `LocalPDFExporter` | 都从 `MemoryBookPageRenderPlan.fontSize` 取得字号。 | SwiftUI `Text` 与 PDF `String.draw` 未共享 paragraph/kerning/line-break 定义；PDF manifest 未记录 text measurement/line boxes。 |

## 2. 不可变产品语义与字段白名单

新增可 Codable 的 `MemoryBookTextField`（或等价字段角色）至每个文字元素；角色是数据语义，不能由 z-index 或显示内容反推。旧草稿迁移时依据 page kind + 模板默认 element 的稳定顺序填充；无法可靠迁移的文本保留为 `legacyUserNote`，只允许编辑为该页面的 `userNote`，不得静默删除或改写。

| 页面 | 可见 / 可编辑字段 | 限制与来源 | 禁止 |
| --- | --- | --- | --- |
| Cover | pet name、subtitle、year range | name 覆盖仅作用相册；subtitle 中性默认；year range 必须由档案 arrival/departure 或已确认照片日期构成。 | 改写档案名、生成臆测事件。 |
| Dedication | dedication（用户亲写一句话） | 240 grapheme；默认空或中性占位。 | 自动代写宠物口吻。 |
| Contents | 无 | 目录条目和页码为系统生成。 | 新增/编辑任意文本。 |
| Chapter opener | chapter title、date range、user note | title/备注来自用户；date range 由该章节实际照片日期限定。 | 自由伪造日期、自动叙事。 |
| Photo selection | optional page title、photo caption | 每字段 120 grapheme；只保存原文。 | 心情标签、任意新文本框。 |
| Milestone | date/year、user note | 日期来自已有照片/档案；note 240 grapheme。 | 推测性里程碑描述。 |
| Closing | closing message（用户亲写一句话） | 240 grapheme。 | 系统代写宠物口吻。 |

`pageNumber`、watermark、模板装饰、自动目录项、未列出的结构文本为不可选中、不可编辑字段。Text 工具仅列出当前页白名单中的**既有字段**；缺少的可选字段只以明确的“Add photo caption / Add note”动作创建对应角色，移除通用 `Add a new text box`。

## 3. 目标技术合同

### 3.1 同源文字排版

引入 `MemoryBookTextLayoutSpec` 与 `MemoryBookTextMeasurement` 扩展，不再以平均字宽估算。

- 输入：`PageRenderPlan`、`MemoryBookTextField`、`MemoryBookTextStyle`、normalized frame、原始 String、页面语义与有效 text rect。
- 输出：PostScript font / fallback policy、字号、line height、kern、paragraph alignment、writing direction、最大行数、实际 occupied rect、`lineBoxes`、`requiredLines`、`availableLines`、`overflows`。
- Preview、编辑画布、Book Check 和 Quartz PDF 都消费同一 `NSAttributedString` / paragraph 定义；PDF 不再只用 `.font + .foregroundColor` 的 `String.draw`。
- 不可用展示字体时明确回退为系统字体，并把实际 font family / fallback 写入 measurement snapshot；不能将缺字渲染成空白或替换成不同文本。
- 测量以 `NSString.boundingRect`（`usesLineFragmentOrigin`、`usesFontLeading`）或等价 Core Text layout 为准；显式保留 `\n`、Unicode grapheme、RTL base direction。测量范围与 PDF 绘制范围完全相同。

### 3.2 约束、草稿与事务

- 限制使用 `String.count`（extended grapheme cluster），而非 UTF-16 `count`；粘贴文本不截断。超过 120/240 时保留草稿、红色提示、阻止 Done/Export，显示剩余或超出数。
- 输入每次变更都按**draft text + draft style + 当前 frame**测量。只有实际溢出才画红框、展示 `Fit text` 与可访问错误；字符上限和实际溢出是两个独立问题。
- `Fit text` 仅依次尝试 `Large → Default → Small` 中比当前字号更小的允许档；绝不改 text、frame、alignment、safe anchor 或其他元素。Small 仍不容纳时继续 blocker，提示“Shorten text or adjust the allowed text frame”。
- Fit 成功将当前 draft text + fitted style 作为**一个**历史事务提交并持久化，随后重置 sheet 的 baseline；Done 对尚未提交的草稿只形成一个事务。这样 Fit 后 Cancel 不会回滚已明确点击的 Fit，也不会制造第二个空事务。
- Text sheet 在键盘显示时使用 safe-area / scroll 的键盘避让；Back/Cancel 对 dirty draft 提供 `Keep editing / Save / Discard`。失焦不自动改写；Save 走同一 validation；Discard 恢复 sheet baseline。
- 文本拖动只在 `TextLayoutSpec.editableSafeRect` 内 clamp；不得覆盖页码、水印、封面保护区域或系统固定文字。宽度调整只允许 spec 给出的范围，不能靠扩框绕过 Fit。

### 3.3 Book Check 与导出

- `MemoryBookIssue` 增加可选 `elementID` / `field`，文字 blocker 的 `Go` 必须选择 page + element、打开 Text sheet，并把焦点置于对应字段；不可只跳到页首。
- `Export PDF` 预检在任何 blocking issue 时拒绝调用 exporter。测试注入独立临时 output 目录，对比导出前后文件清单 / hash，证明无新 PDF。
- 问题修复后再执行 preflight；Fit 后 Undo 恢复 overflow blocker，Redo 恢复可导出状态。

## 4. 固定夹具 `F-P02-TEXT`

夹具不使用个人 Photos，固定 document 包含 Cover、Dedication、Contents、Chapter opener、Photo selection、Milestone、Closing；每页预置角色、确定 frame 和 PageStyle。文案集合：

1. 标题、副标题、真实日期范围、120 个 grapheme 照片注记、240 个 grapheme 献词/结尾；各有“刚好适配 / 增加一个可见字形后溢出”。
2. 中文、英文、Arabic/RTL、单 emoji、ZWJ 组合 emoji（如家庭 emoji）、组合重音 grapheme 与显式换行。
3. Small / Default / Large 分别放在照片页和献词页；至少一个可 Fit 成功、一个 Small 仍失败。
4. 同一 fixture 在 Warm Paper、Quiet Night、Field Notes、Cinema、Film Album，以及 A4 / Letter 上建立行盒清单。最终像素栅格门禁仍由 G-EDITOR-03 承担。

## 5. 研发可交验批次（顺序不可跳跃）

### B1 · 语义模型、迁移与真实量测

**实现范围**：字段角色 / whitelist、旧草稿兼容迁移、`TextLayoutSpec`、实际测量、三档 token、text rect / protected rect。仅模型和 Preview/PDF 共享排版 primitive，不增加导出冻结或 P0-2 C 持久化闭环。

**模型验收测试**：

- `MemoryBookTextLayoutTests.testWhitelistForEveryPageKindAndRejectsArbitraryTextBox`
- `...testLegacyTextRoleMigrationPreservesOriginalUnicode`
- `...test120And240GraphemeBoundariesDoNotSplitEmojiOrSurrogates`
- `...testArabicChineseEmojiAndNewlineRoundTripAndMeasurement`
- `...testSmallDefaultLargeResolveDistinctSpecTokens`
- `...testDraftOneAdditionalGraphemeChangesActualOverflowNotCharacterHeuristic`
- `...testTextFrameRemainsInsideEditableSafeRect`

**交付证据**：测试 result、fixture JSON、每模板×纸张的 `TextLayoutSpec` / line-box JSON。B1 不声称 PDF raster 或真机通过。

### B2 · Text 编辑器、实时可见状态与原子历史

**实现范围**：字段选择 UI、可选字段创建、draft session、实时红框 / a11y error、计数、三字号、Fit、键盘 / Back Save Discard、safe-anchor 拖动。

**UI 验收测试**：

- `EditorP02TextUITests.testOnlyCurrentPageWhitelistedFieldsAreExposed`
- `...testDraftInputShowsAccessibleOverflowBorderAndFitText`
- `...testFitSuccessPreservesTextFrameAndCreatesOneUndoTransaction`
- `...testFitFailureKeepsErrorAndDoesNotTruncateOrResize`
- `...test120And240BoundaryWithUnicodePaste`
- `...testTextDraftCancelSaveDiscardAndKeyboardAvoidance`

**必须截图**：字段列表（Cover / photo / dedication 至少各一）、刚好适配 / 加一字红框、Fit 成功、Fit 失败、120/240 Unicode 边界、dirty-exit 三分支。每张截图配 accessibility tree / stable identifiers，而非仅断言按钮存在。

### B3 · Book Check、导出阻断与回读合同

**实现范围**：issue element 定位、`Go` → field focus、严格 exporter preflight、Fit / Done 的 undo-redo 和 repository round trip。此批次只覆盖 Text 所需状态；全 document 冻结 manifest / 导出期间编辑隔离属于后续 C，不可提前宣称完成。

**验收测试**：

- `MemoryBookTextLayoutTests.testBookCheckUsesPersistedTextLayoutSpecAndBlocksExport`
- `...testFitUndoRedoAndRepositoryRoundTrip`
- `EditorP02TextUITests.testBookCheckGoFocusesOverflowFieldAndBlockedExportCreatesNoPDF`
- `P02RenderManifestTests.testTextLayoutSnapshotMatchesPreviewAndPDFAdapterForF_P02_TEXT`

最后一项只验证 B 的 text value/style/spec/line boxes 读取同一排版合同；C 再验证完整 freeze、hash、A4/Letter PDF 结构和 export snapshot。

## 6. 验收门禁、命令与产物

每一批均须先由研发定向自测，再交 QA，再交产品 / 设计；失败只返工所属批次，不能推进 C 或 P0-3。

```bash
xcodebuild -project Tailor.xcodeproj -scheme Tailor \
  -destination 'platform=iOS Simulator,id=<current-simulator-id>' \
  -derivedDataPath /tmp/tailor-p02-text-b<1|2|3> \
  test -only-testing:TailorTests/MemoryBookTextLayoutTests \
       -only-testing:TailorUITests/EditorP02TextUITests
```

研发提交包必须含：变更文件清单、可读 xcresult 路径、`F-P02-TEXT` JSON、截图和 a11y dump、Preview/A4/Letter text-layout manifest、临时 export 目录前后目录清单、`git diff --check` 输出。QA 需独立重跑；产品 / 设计只在 B1+B2+B3 全绿且证据齐全时签收 Text。

## 7. 明确不在本批关闭的门禁

- 完整 `F-P02-PERSIST`、冻结 `MemoryBookRenderManifest`、导出中编辑隔离、完整 Reader/PDF 页序/资产持久化：C 组。
- 真机真实 Photos、5 模板 A4/Letter PDF raster / heatmap、字体元数据的发布级视觉结论：最终 `G-EDITOR-03`。
- P0-3 入口、页管理和阅读器能力：在 P0-2 A/B/C 签收前不启动。
