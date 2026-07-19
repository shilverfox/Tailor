# P0-2 编辑交互验收增量：裁剪、文本与版式

> 状态：研发交付前基线；研发交付后由 QA 独立执行并填写第 7 节。  
> 对应：编辑器 PRD §5.4–§5.6、§6.2、§7.1–§7.3；P0-1 共享渲染合同已是前置依赖。  
> 本轮范围：独立裁剪态、文本编辑与实际溢出、明确版式选择及容量溢出迁页。  
> 非替代项：P0-1 的 PDF 栅格化/真机视觉门禁仍必须保留；本文件不因 UI 自动化通过而解除该门禁。

## 1. P0-2 签收规则

只有 A（数据/事务）、B（交互/UI）、C（持久化及同源 PDF）三层均通过，P0-2 才可进入下一项。任何一个 P0 用例失败均为 **不通过**，研发必须修复后由 QA 重新执行；测试不得改动产品代码或用 demo 路由替代真实编辑流程。

| 层级 | 必须证明 | 合格证据 |
| --- | --- | --- |
| A. 数据与事务 | Cancel 不提交；Done/Reset/布局变更各形成一次可撤销事务；照片/文本不产生非法 frame 或空白图片区域。 | 单元测试 + 文档序列化前后快照 |
| B. 可操作交互 | 用户能找到明确的 Crop、Done、Cancel、Reset、Fit text、五种 Layout；确认文案准确且页面不抖动。 | UI 测试录屏/截图 + accessibility 标识 |
| C. 保存与输出 | 重启后保存的 crop/字号/布局及迁页结果不变；阅读预览、PDF 读取同一冻结 `PageRenderPlan`，导出不重新裁剪或静默丢图。 | repository 回读 + render manifest + A4/Letter PDF 结构/栅格化证据 |

不可接受的替代证据：仅检查按钮存在、只检查 `%PDF` 文件头、只在占位图上观察、或以 `cropOffset != 0` 代替“容器无空白且取消未提交”。

## 2. 固定验收夹具

`F-P02-01` 必须可在 test target 中构造，使用 6 个稳定、不同宽高比的本地测试图片（横、竖、正方、极宽、极高、带明显中心参照物）。每页至少包含：一张图片、一个 3 行文字框；另建 6 图照片页用于 3×2 容量验证。fixture 不使用任何个人 Photos 资产。

| 夹具 | 页面/输入 | 用途 |
| --- | --- | --- |
| `F-P02-CROP` | 竖图填入横向容器，初始 scale=1、offset=0；另含已旋转 15° 图。 | 验证移动、缩放、边界无空白、Cancel、Done、Reset、Undo。 |
| `F-P02-TEXT` | 题目、120 字符照片注记、240 字符献词、汉字/emoji/组合字符。 | 验证字符限制、3 字号、实际测量溢出、Fit text。 |
| `F-P02-LAYOUT` | 当前照片页 6 图，下一页为同章节空照片页；另有锁定图片/用户文本。 | 验证 1/2/4/6 容量、超量迁页说明、锁定元素保护。 |
| `F-P02-PERSIST` | 上述操作全部提交后的文档。 | 冷启动回读、A4/Letter 的 manifest 与导出。 |

## 3. 裁剪验收矩阵

| ID | 优先级 | 操作 | 预期结果 | 必须证据 |
| --- | --- | --- | --- | --- |
| CRP-001 | P0 | 选中图片，点击 `Crop`。 | 进入独立裁剪态；元素框固定；只有图片内容可平移/捏合；显示明确 `Cancel` 与 `Done`。 | UI 层级、前后截图。 |
| CRP-002 | P0 | 在裁剪态平移、捏合到最小/最大，再向四边拖。 | 图片始终覆盖容器，无透明/背景空白；offset/scale 被约束而非回弹抖动。 | 4 边截图、模型断言。 |
| CRP-003 | P0 | 裁剪后点击 `Cancel`。 | 退出裁剪态，frame、scale、offset、rotation、锁定状态均回到进入前；不产生 undo 记录，不自动保存中间值。 | 前后 Codable 快照相等、undo 深度。 |
| CRP-004 | P0 | 裁剪后点击 `Done`，再 Undo/Redo。 | Done 仅提交一条事务；Undo 完整恢复进入前，Redo 完整恢复提交后。 | 三份快照 + undo/redo 断言。 |
| CRP-005 | P0 | 对已裁剪、旋转、调层图片执行 `Reset photo`，确认后 Undo。 | 二次确认；重置模板默认 frame/crop/rotation/z-index；Undo 恢复全部提交前属性。 | 确认弹窗、模型比对。 |
| CRP-006 | P0 | Crop 尚未 Done 时返回编辑器/切页/应用退后台。 | 出现 Keep editing / Save and leave / Discard this edit；Discard 等同 Cancel，Save 仅提交当前最终状态。 | UI 测试与冷启动回读。 |
| CRP-007 | P1 | 替换图片后进入 Crop。 | 保留元素 frame、rotation、z-index，crop 适配新图并不露空白。 | 旧/新元素属性差异。 |

## 4. 文本编辑及溢出验收矩阵

“实际溢出”指使用当前 PageStyle 的字体、字距、行距、可用 text frame 测量后的结果，不能用字符数推断。红色提示应有无障碍文字，且阻止导出直到解决。

| ID | 优先级 | 操作 | 预期结果 | 必须证据 |
| --- | --- | --- | --- |
| TXT-001 | P0 | 编辑标题、副标题、日期、照片注记、献词/结尾。 | 只暴露 PRD 允许字段；保存时原文不被 AI 改写或静默截断。 | 持久化回读。 |
| TXT-002 | P0 | 输入中文、英文、Arabic/RTL、emoji、组合 emoji、换行及粘贴文本。 | 字符完整显示、计数/限制按用户可感知字符处理；不崩溃、不出现乱码或孤立 UTF-16 surrogate。 | UI 截图 + text round trip。 |
| TXT-003 | P0 | 逐一切换 `Small / Default / Large`。 | 三档有实际不同字号 token；预览与 PDF 使用相同等级，切换为单个可 Undo 事务。 | render manifest、Undo/Redo、A4/Letter PDF。 |
| TXT-004 | P0 | 输入刚好适配、再增加一个可见字形至溢出。 | 仅溢出后出现红色边框/提示和 `Fit text`；导出 CTA 被阻止并说明原因。 | 前后截图、导出拦截。 |
| TXT-005 | P0 | 在溢出状态点 `Fit text`。 | 保留全部原文，将字号降至可容纳的最低允许档；仍不容纳时保留错误，不得截断或溢出导出。 | 文本值、字号、测量状态。 |
| TXT-006 | P0 | Fit 后 Undo/Redo、重启应用。 | Undo 恢复原字号及溢出；Redo 和重启后恢复 Fit 结果。 | 三快照 + repository 回读。 |
| TXT-007 | P1 | 超过 120/240 可见字符边界。 | 明示限制，拒绝或提示用户修正；不得悄悄截断已提交的 Unicode 文本。 | 边界输入日志。 |

## 5. 版式与容量验收矩阵

本轮“明确版式选择”必须提供可辨认的五个独立选项：`Single`、`Diptych`、`2×2 mosaic`、`3×2 mosaic`、`Note`；禁止以一个循环按钮代替。容量为 1/2/4/6/0。

| ID | 优先级 | 操作 | 预期结果 | 必须证据 |
| --- | --- | --- | --- | --- |
| LAY-001 | P0 | 打开 Layout 面板。 | 显示五种命名、缩略预览、当前选中态及容量；非照片页不能错误应用图片拼贴。 | UI 截图/accessibility。 |
| LAY-002 | P0 | 对同一 1 图页依次应用 Single、Diptych、2×2、3×2、Note。 | 页面数据/RenderPlan layout 正确；单图保留，文本/锁定元素不被删除。 | 逐项 manifest。 |
| LAY-003 | P0 | 6 图页依次改为 4 容量、2 容量、1 容量。 | 操作前展示：保留数、超出数、将新建/使用的同章节页及页数变化；确认后超出图按原相对顺序迁页，不丢图、不跨章节。 | 确认弹窗 + 前后 page/asset 序列。 |
| LAY-004 | P0 | 在超量确认弹窗选择 Cancel。 | 文档、页数、图片顺序完全不变；无新增空页。 | Codable 快照相等。 |
| LAY-005 | P0 | 超量确认后 Undo/Redo。 | 一次 Undo 恢复操作前所有页及顺序；Redo 重现相同迁页结果。 | 文档快照、undo 深度。 |
| LAY-006 | P0 | 4/6 容量页加入图片至超量。 | 使用当前页空槽；无槽时走同样迁页确认；不得覆盖已有图或创建无说明空页。 | UI + 数据断言。 |
| LAY-007 | P0 | 版式变更含锁定图片与用户文本。 | 用户文字及已锁定元素的 frame/crop/rotation/z-index 不变；报告中明确“不影响锁定元素”。 | 元素字段比较。 |
| LAY-008 | P0 | 版式应用后重启、进入阅读预览、导出 A4/Letter。 | 版式、页序、资产 ID 与迁页结果持久化；预览/PDF 从同一冻结 page-plan 读取。 | repository + two manifests/PDF。 |
| LAY-009 | P1 | 从 6 图缩到 1 图后切回 6 图。 | 所有照片仍可追溯；不会重复、丢失、跨章节或覆盖用户锁定图。 | 资产多集断言。 |

## 6. 自动化实现清单与退出门槛

研发完成后，测试 target 至少新增以下可独立执行的测试；仅命名但没有断言不算覆盖。

| 分组 | 最低测试 |
| --- | --- |
| `MemoryBookCropTests` | CRP-002/003/004/005 的模型、边界、单事务 Undo、reset round trip。 |
| `MemoryBookTextLayoutTests` | Unicode Codable、三字号 token、真实文本测量、Fit 成功/失败、导出阻断。 |
| `MemoryBookLayoutMigrationTests` | 五布局容量、确认 Cancel、迁页顺序/章节、锁定元素、Undo/Redo、持久化。 |
| `EditorP02UITests` | Crop Done/Cancel、Reset confirmation、Fit text error/recovery、布局选择与超量确认。 |
| `P02RenderManifestTests` | F-P02-PERSIST 的 Preview/A4/Letter manifest：assetID、frame、crop、rotation、z-index、text style/value、layout 与页序完全一致。 |

P0-2 可进入下一项的最低条件：所有 P0 用例绿色；新增单测/UITest 与历史全量回归均通过；`git diff --check` 通过；研发提供变更文件和测试命令；产品/设计审阅 5 个布局、裁剪态、溢出态至少各一套截图。A4/Letter raster 及真机真实照片仍挂在最终 G-EDITOR-03 门禁。

## 7. 待填写的独立验收记录

```markdown
# P0-2 验收记录

- Build SHA / 版本：
- 执行日期：
- QA：
- Fixture：F-P02-01 / 真实设备资产（如适用）
- 自动化命令与结果：
- CRP-001…007：通过 / 不通过（附证据）
- TXT-001…007：通过 / 不通过（附证据）
- LAY-001…009：通过 / 不通过（附证据）
- Preview / A4 / Letter manifest：通过 / 不通过
- P0-1 最终视觉发布门禁：仍待关闭 / 已关闭
- P0-2 结论：通过 / 不通过
- 是否进入下一项：是 / 否
- 未关闭风险与责任人：
```

## 8. 独立交验复核记录（2026-07-16）

### 8.1 研发提供的可执行证据

| 产物 | 实际内容 | 独立判定 |
| --- | --- | --- |
| `/tmp/tailor-p02-model-tests2/...14-03-35...xcresult` | 2/2：`testExplicitLayoutChangeMovesOverflowIntoNewChapterPagesWithoutLosingPhotos`、`testTextOverflowIsBlockingAndFitTextResolvesTheSameModelMeasurement`。 | 通过，但仅覆盖 LAY-003 的一个顺序分支及 TXT-004/005 的模型估算分支。 |
| `/tmp/tailor-p02-ui-tests/...14-05-11...xcresult` | 1/1：`testEditorFixtureExposesExplicitLayoutChoices`。 | 通过，但只断言五个按钮存在。 |
| QA 独立重跑 | 同一 Simulator，以上 3 个已选用例均通过；命令输出 `** TEST SUCCEEDED **`。 | 复现通过，不能扩大其覆盖范围。 |

### 8.2 源码与矩阵差异

| 矩阵项 | 结论 | 依据 / 阻断原因 |
| --- | --- | --- |
| CRP-001 | 部分通过 | 有全屏 `CropEditorSheet`、Done/Cancel；但没有实际 UI 用例。 |
| CRP-002 / CRP-003 / CRP-004 / CRP-006 | **不通过** | 无裁剪边界、Cancel 无提交、Done 单事务 Undo、裁剪中返回三选项的自动化测试。`CropEditorSheet` 的 Cancel 直接 dismiss，也没有 PRD §6.2 所要求的 Keep editing / Save and leave / Discard this edit 返回处理。 |
| CRP-005 | 部分通过，未签收 | 源码有 Reset 二次确认；无 reset 后 Undo/Redo 的独立测试。 |
| CRP-007 | 不通过 | 替换只重置 `cropScale/cropOffset`；没有断言 frame、rotation、z-index 保留且新图无空白。 |
| TXT-001 / TXT-002 / TXT-003 | **不通过** | 无允许字段、Unicode/RTL/emoji、三字号 Undo/PDF 同源用例。虽 `String.count` 按扩展字形簇计数，但没有覆盖或 UI 证据。 |
| TXT-004 / TXT-005 | 部分通过，未签收 | 模型用例通过；但 TextEditor 的 `overflowMeasurement` 读取已保存 element，不读取当前输入草稿/当前 Picker 字号，用户输入后保存前不能得到实时实际溢出提示；没有导出阻断 UI 用例。 |
| TXT-006 / TXT-007 | **不通过** | 无 Fit 后 Undo/Redo/冷启动回读及 120/240 Unicode 边界用例。 |
| LAY-001 | 部分通过 | 五个选项存在且研发 UI 用例通过；未验证当前选中态、容量文字、非照片页禁用。当前工具栏对所有页面展示 Layout。 |
| LAY-002 / LAY-004 / LAY-005 / LAY-006 / LAY-008 / LAY-009 | **不通过** | 只有一个 6→4 的模型顺序用例；无五布局、Cancel 不变、单事务 Undo/Redo、加图超量、回读、Preview/A4/Letter manifest 用例。 |
| LAY-007 | **不通过（源码风险）** | `applyLayoutChange` 仅保留落在 retained 前 N 中的锁定图；若锁定图在 overflow 中，会在新页以自动元素重建，丢失其 frame/crop/rotation/z-index。与 PRD “锁定元素不被改变”冲突。 |
| C 同源/PDF | **不通过** | 本轮无 F-P02-PERSIST、Preview/A4/Letter manifest 或 PDF raster 产物；P0-1 真机/栅格视觉门禁同样未关闭。 |

另有裁剪无空白风险：非裁剪页的照片缩放工具允许 `cropScale` 最低为 `0.5`，而 PDF 渲染也接受 `0.5`，因此不能以 CropEditor 中的 `min(1, ...)` 推导整个文档永不露空白。

### 8.3 QA 结论

**P0-2：不通过，不得进入下一项。**

本次 3 个自动化用例均绿，只能证明五布局按钮存在、一个 overflow 模型分支和一个 6→4 的迁页分支；它们不覆盖 P0-2 验收矩阵。研发须先修复锁定图片在版式缩容时的保留规则，并补齐 CRP/TXT/LAY 的 P0 用例、F-P02 fixture、保存回读及 Preview/A4/Letter manifest；随后由 QA 重新验收。PDF raster 与真实 Photos 真机视觉继续是最终发布门禁，不能标记为通过。
