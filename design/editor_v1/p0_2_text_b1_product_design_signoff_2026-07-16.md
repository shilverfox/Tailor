# P0-2 / B1 Text：产品与设计独立验收

- 验收日期：2026-07-16
- 验收范围：仅 `20_p0_2_text_engineering_execution_plan_2026-07-16.md` §5 的 **B1**（字段语义、迁移、真实量测、共享排版合同）。
- 验收方法：读取当前生产源码、固定 fixture、line-box manifest 与 xcresult；不以总测试绿替代逐条合同核对，也不提前验收 B2 编辑交互、B3 导出/回读、真机或 PDF raster。
- 初始结论：**FAIL — B1 不得签收，不得进入 B2。**

> 该初始结论已由文末「19:08 返工复验」**正式取代**；保留在此仅为了审计三个已修复阻断项。

## 已独立确认的交付

| 项目 | 证据 | 判定 |
| --- | --- | --- |
| 定向结果 | `/tmp/tailor-p02-text-b1/Logs/Test/Test-Tailor-2026.07.16_18-37-01-+0800.xcresult`：53/53 Passed。 | 通过；仅证明实际已执行的测试。 |
| 字段语义 / 白名单 | `MemoryBookTextField` 明确定义 Cover、Dedication、Chapter、Photo、Milestone、Closing 字段；Contents 没有 allowed 字段。`testTextFieldWhitelistMatchesEveryPageSemanticAndRejectsContents` 有定位断言。 | 通过。 |
| 旧数据迁移 | `migratedLegacyTextFields()` 将可由 title/subtitle 对应的字段迁移，用户原文保留为 `legacyUserNote`；`testLegacyTextFieldMigrationPreservesUnicodeAndOnlyAdoptsUserNotes` 断言 Arabic、中文、ZWJ 与组合重音原文不变。 | 通过。 |
| 120 / 240 可感知字符 | `.count` 使用 Swift `Character`；测试断言家庭 ZWJ emoji 与 `é` 各为一个 grapheme，120/240 与 +1 的字符边界。 | 通过字符边界本身。 |
| 三档字号 / 真实行盒 | `MemoryBookTextLayoutSpec`、Core Text `CTFramesetter`、`lineBoxes` 已存在；`testTextLayoutUsesDistinctSizeTokensAndActualLineBoxes` 断言 Small/Default/Large token 与行盒。 | 部分通过，见阻断项。 |
| 安全编辑区域 | `editableRect`、footer / watermark `protectedRects` 与 `clampedTextFrame` 已存在；`testTextEditableRectClampsAwayFromProtectedFooter` 可定位。 | 通过 B1 模型层。 |
| 模板 / 纸张 manifest | `F-P02-TEXT-line-box-manifest.json` 可读，含 10 份 manifest（5 模板 × A4/Letter）、每份 7 页、每份 14 个 text layout。 | 通过产物完整性；内容覆盖不完整，见下。 |
| 代码卫生 | `git diff --check` 无输出。 | 通过。 |

## B1 阻断项

### TXT-B1-001：执行计划列明的第 6 个模型测试没有直接覆盖

计划 B1 要求的 7 项中，当前可定位的是 6 个测试函数：

1. `testTextFieldWhitelistMatchesEveryPageSemanticAndRejectsContents`
2. `testLegacyTextFieldMigrationPreservesUnicodeAndOnlyAdoptsUserNotes`
3. `testTextGraphemeLimitsAndUnicodeRoundTripDoNotSplitVisibleCharacters`
4. `testTextLayoutUsesDistinctSizeTokensAndActualLineBoxes`
5. `testTextEditableRectClampsAwayFromProtectedFooter`
6. `testFP02TextManifestContainsLineBoxesForEveryTemplateAndPaper`

但执行计划明确要求 `testDraftOneAdditionalGraphemeChangesActualOverflowNotCharacterHeuristic`：同一 text rect / style 下，先验证“刚好适配”，再只增加 **一个** 可见 grapheme 后验证真实 line-box `overflows` 翻转。当前 `testTextLayoutUsesDistinctSizeTokensAndActualLineBoxes` 仅比较 `"WW"` 与 `String(repeating: "WW", count: 24)` 的 requiredLines 增长，未验证单一 grapheme 边界、也未断言 `overflows` 由 false 变 true。53/53 不能补足缺失用例。

**返工要求：**新增与计划同名或等价、可定位的 test，固定 frame/style，断言 `exactFit.overflows == false`、`exactFit + oneGrapheme` 的 `.overflows == true`，且不能以字符数阈值替代 Core Text line boxes。

### TXT-B1-002：F-P02-TEXT 的 Preview/A4/Letter line-box manifest 未覆盖 Arabic/RTL 和显式换行

固定 JSON 声称包含 Arabic/RTL、中文、emoji、ZWJ、组合 grapheme 和 newline；实际 fixture 构造中仅将中文、240 个组合重音、120 个 ZWJ emoji 写入七页 document。Arabic/RTL 与显式换行只在独立 JSON round-trip 字符串中出现。

独立解析 `/tmp/tailor-p02-text-b1-evidence/F-P02-TEXT-line-box-manifest.json` 的 10 份产物：

- `arabic_manifest = 0`
- `newline_manifest = 0`

所以没有任何一个模板 × A4/Letter 的共享 line-box contract 能证明 Arabic 基方向、混合中文/emoji 或显式换行的量测及输出。

**返工要求：**把 Arabic/RTL、中文、ZWJ、组合字符、显式换行加入真实 F-P02-TEXT 页面元素，并在每模板 × A4/Letter manifest 中输出相应 `value`、`writingDirection`、lineBoxes；测试至少检查换行产生预期多行、RTL/混合文本未被替换或丢失。

### TXT-B1-003：Preview 与 PDF 尚不能称为“真正复用同一 paragraph / attributed layout”

PDF 在 `ProductionServices.swift` 通过 `textLayout.spec.attributedString(...).draw(in:)` 使用 `MemoryBookTextLayoutSpec` 的 UIKit font、kern、paragraph alignment、base writing direction 与 line-height。

预览 `AlbumFeatureViews.swift` 则把一部分 token 手工映射为 SwiftUI：`.font`、`.tracking`、`.lineSpacing`，并固定 `.multilineTextAlignment(.leading)`。它没有消费 `spec.paragraphStyle()` / `spec.attributedString()`，也没有应用 `spec.alignment` 或 `spec.writingDirection`。当前 spec 恰好是 `.leading` / `.natural` 并不构成同源保证；当 RTL 或 alignment 改变时，Preview 与 PDF 可以漂移。

此外 `testFP02TextManifestContainsLineBoxesForEveryTemplateAndPaper` 将 `book.renderManifest(watermarked: true)` 连续调用两次并命名为 `preview` / `pdfAdapter`；它未调用 Preview renderer 或 PDF adapter，故不能证明二者真正消费同一段落合同。

**返工要求：**提供一个共享 text renderer / adapter，或在可验证边界上让 Preview 直接消费 `NSAttributedString` / Core Text layout（包括 paragraph / base direction）；补一个 test 对同一 F-P02-TEXT layout 比较 Preview adapter 与 PDF adapter 的 `fontPostScriptName`、fallback、kern、alignment、writingDirection、line-height、textRect、lineBoxes，而不是比较同一 manifest 函数的两次返回值。

## 不属于本次失败但不得提前签收的项

- B2：字段选择 UI、实时红框/无障碍错误、Fit 事务、dirty-exit、键盘避让。目前 `TextEditorSheet` 仍有通用 `Add a new text box`，这属于 B2 后续范围，不能用作 B1 通过依据。
- B3：Book Check 精确定位、导出无新 PDF、Undo/Redo、repository round trip。
- 真机真实 Photos，以及 5 模板 × A4/US Letter PDF raster / heatmap：仍 **Not run**。

## 重新验收门槛

补齐上述三项后，研发须提供新的定向 xcresult、更新的 fixture JSON / line-box manifest 与 Preview/PDF adapter 对比。QA 重跑、产品/设计复验均通过后，B1 才可进入 B2。

## 19:08 返工复验（最终 B1 结论）

### 独立读取的证据

| 证据 | 复核结果 |
| --- | --- |
| `/tmp/tailor-p02-text-b1-r5/Logs/Test/Test-Tailor-2026.07.16_19-08-50-+0800.xcresult` | **56/56 Passed**；结果包可读，iPhone 17 Pro Simulator。 |
| `/tmp/tailor-p02-text-b1-evidence/F-P02-TEXT-line-box-manifest.json` | 可读的 **10** 份 manifest（5 模板 × A4/Letter），每份 7 页、14 个 text layout。 |
| 当前生产代码 | Preview 使用 UIKit `UILabel` bridge；PDF 和 Preview adapters 均委托 `MemoryBookTextRenderer` factory；字体名来自实际解析后的 PostScript name。 |
| `git diff --check` | 无输出。 |

### 上次三个阻断项逐项复核

| 原阻断 | 当前实现与测试 | 判定 |
| --- | --- | --- |
| TXT-B1-001：缺少 exact fit + 一个 grapheme 的真实 overflow 边界 | `testDraftOneAdditionalGraphemeChangesActualOverflowNotCharacterHeuristic` 固定 frame/style，分别断言 caption 120 与 dedication 240 字符在真实 Core Text 行盒内刚好适配，追加一个完整 `Character` 后 requiredLines +1 且 `overflows == true`。 | **已解决**。 |
| TXT-B1-002：manifest 不含 Arabic / CJK / ZWJ / combining / newline | `p02TextFixtureBook` 的真实 `chapterNote` 现在包含 Arabic、`点点`、家庭 ZWJ emoji、`é` 与显式换行；独立解析 manifest：10/10 都有该字段，`writingDirection = rightToLeft`，`requiredLines = availableLines = 2`，有两条 lineBoxes。`testFP02TextManifestContainsLineBoxesForEveryTemplateAndPaper` 对每个模板/纸张逐项断言这些内容、RTL 和行数。 | **已解决**。 |
| TXT-B1-003：Preview / PDF 不是同一 paragraph factory | `MemoryBookTextRenderer.attributedString` 是唯一 factory；`MemoryBookPreviewTextAdapter` 与 `MemoryBookPDFTextAdapter` 都委托该 factory。Preview 的 `MemoryBookAttributedTextPreview` 直接将 adapter 的 attributedString 赋给 `UILabel.attributedText`，并同步 alignment / `semanticContentAttribute`；PDF 直接绘制 PDF adapter 的 attributedString。`testTextRenderContractUsesExplicitUIKitAndCoreTextResolvableFonts` 覆盖 5×2，验证 UIKit 和 Core Text 都可解析实际 PostScript font，且 Preview/PDF attributed string 相等；`testPreviewAndPDFAdaptersConsumeTheSameAttributedParagraphContract` 比较 font、fallback、kern、alignment、direction、line-height、textRect、lineBoxes。 | **已解决**。 |

### 最终判定

**P0-2 B1 Text：PASS。允许研发启动 B2（Text 编辑器、实时状态与原子历史）。**

此签收只证明 B1 的语义模型、真实量测与共享排版合同；它**不等同**以下任一事项通过：

- B2 UI / 可访问性 / Fit / Save-Discard / 键盘验收；
- B3 Book Check、导出阻断和持久化回读；
- P0-2 整体通过；
- G-EDITOR-03 真机真实 Photos、五模板 × A4/US Letter PDF raster / heatmap 或发布门禁通过。
