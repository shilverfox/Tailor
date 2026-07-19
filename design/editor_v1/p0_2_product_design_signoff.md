# P0-2 · 裁剪、文本与版式签核验收清单

**版本：** 1.0 · 2026-07-16  
**状态：** 待研发交付；本清单不是实现说明，完成全部勾选并保留证据前不得标记 P0-2 通过。  
**验收责任：** iOS 提供可运行 build / 自动化 / 数据前后快照；产品与设计独立核对交互和视觉；QA 执行回归并归档证据。  
**依据：** [编辑器 PRD §5.4–5.7、§6.2、§7.3、§8](../../docs/mobile-prd-plans/Tailor_iOS/14_life_album_page_editor_v1_PRD_2026-07-15.md)、[设计规格 E04–E06](design_spec.md)、[编辑器测试计划 IMG-005、TXT-002/003、LAY-001、CHK-001](../../docs/mobile-prd-plans/Tailor_iOS/15_editor_test_plan_2026-07-15.md)。

## 0. P0-2 范围和判定规则

本批只验收以下三项；不得用按钮可点击、模拟路由或 demo 占位图代替真实编辑事务。

| 能力 | 完成定义 | 不在本批替代为通过的内容 |
| --- | --- | --- |
| CROP | 图片有独立沉浸裁剪态；修改的是元素 `cropOffset/cropScale`，Cancel 回滚、Done 原子提交、Reset 可撤销。 | 在普通 Photo 面板中直接微调、没有取消语义的滑块。 |
| TEXT | 对允许字段编辑文字，显示真实溢出并能 Fit text；未解决溢出阻断导出。 | 仅限制字符数、只在 Book Check 内有一条泛化提示、导出静默截字。 |
| LAYOUT | 当前照片页有明确 Single / Two-up / Grid 2×2 / Grid 3×2 / Note 选择；容量变化前说明并确认，超量图片迁到同章节新页。 | 只有一个循环切换按钮、静默删图、在原页隐藏多余图片。 |

**总判定：** 任一 P0 条目为 Fail / Not run，P0-2 即为**不通过**。视觉截图只能证明外观，必须与数据快照、Undo/Redo、重进恢复和预览/PDF 证据配对。正常路径、取消路径、异常路径均须独立运行。

### 0.1 固定验收输入

- 固定可复现 document，至少含：1 张横图、1 张竖图、4 张和 6 张照片页、文本页、已锁定图片、重叠图片、长中文/英文/emoji 文字；记录每个 `element.id` 和 `assetID`。
- 使用真实本地授权 fixture 或确定性 `AssetImageProvider`；不得以空 `localIdentifier` 或纯色占位替代图片裁剪验收。
- 记录 Build SHA、设备/模拟器与 iOS、纸张（A4 与 US Letter）、模板、动态字体倍率；测试期间关闭任何随机初稿选择。
- 证据根目录：`artifacts/editor-p02/<build>/<fixture>/<case>/`。每个 case 必须含 `before.json`、`after.json`、`after-undo.json`、截图/录屏、UI test 或 XCTest 名称和结果；影响导出的 case 还需包含 Reader 截图、PDF、PDF raster 和差异结果。

## 1. CROP · 独立裁剪状态（E04）

### 1.1 进入与视觉状态

| ID | 签核项 | 通过条件 | 必需证据 |
| --- | --- | --- | --- |
| CR-01 | 入口与对象范围 | 仅选中正常、可用的图片元素时出现 `Crop`；未选中、文字、模板背景、水印、页码均不可进入。 | 选中图片/文本/空白三张截图与 accessibility ID。 |
| CR-02 | 独立沉浸态 | 进入后固定**元素框**，非裁剪区域为 72% 深绿遮罩；顶部同时可见 `Cancel`、`Crop photo`（上下文标题）和 `Done`，底部有 `Reset`。编辑器五工具与页面重排不得在此态响应。 | 进入裁剪录屏与截图；点击工具/返回的行为记录。 |
| CR-03 | 成品不污染 | 裁剪遮罩、控制层、工作区、按钮不会进入阅读预览或 PDF。 | 同一页 Editor、Reader、PDF raster 对照。 |
| CR-04 | 无资产保护 | 已选图片在进入前变为不可用/权限收窄时，不进入裁剪；显示灰占位与 `Replace`，不写入伪 crop 参数。 | 缺失 asset UI 截图和 `after.json`。 |

### 1.2 手势、边界和变更语义

| ID | 操作 | 可签核预期 | 数据 / 自动化断言 |
| --- | --- | --- | --- |
| CR-05 | 单指拖动照片内容至四个方向 | 只改变图片内容位置，不改变 `normalizedFrame`；内容仍 Fill 容器、无空白边。 | `frame` 前后相等，`cropOffset` 改变且受边界夹紧；横/竖图各一例。 |
| CR-06 | 双指缩放至最小/最大及越界 | 改变 `cropScale`；缩小时仍无露白，越界不继续变化，并有轻触或明确视觉边界反馈。 | `cropScale` 边界单测；录屏显示无白边。 |
| CR-07 | Crop 内的旋转内容 | 裁剪态必须维持元素既有 `rotationDegrees` 的可见效果；本批不要求在裁剪态调旋转，但不得将已有旋转归零或反向。 | ±15° fixture 的 before/after/Reader/PDF 对照。 |
| CR-08 | 多次手势后 Done | Done 将全部裁剪变化合并成**一条** history 事务；1 秒内自动保存，退出/重进仍保留。 | history count 断言、repository round-trip、重进录屏。 |
| CR-09 | Cancel | Cancel 恢复进入裁剪前的完整 `cropScale/cropOffset`，不创建 history 事务、不触发保存。 | before/after-cancel JSON byte/field comparison；Undo 状态不变化。 |
| CR-10 | Reset | Reset 回到该元素模板默认 crop（Fill 初始值）；当前裁剪会话内可继续拖动；Done 后 Reset 是一条可 Undo 的提交。 | default geometry fixture、Reset → Done → Undo JSON 与画面对照。 |

### 1.3 与其它照片操作的边界

| ID | 签核项 | 通过条件 | 必需证据 |
| --- | --- | --- | --- |
| CR-11 | Replace 后裁剪 | Replace 保留元素 `normalizedFrame`、`rotationDegrees`、`zIndex`，新图片裁剪重置为 Fill；取消替换则不影响现有裁剪。 | old/new asset 数据 diff 与 UI 流程。 |
| CR-12 | Reset photo 区分 | `Reset photo` 的二次确认恢复 frame/crop/rotation/layer；`Reset`（裁剪态）仅恢复 crop。二者文案、影响范围不能混淆。 | 两个确认/按钮的截图和 JSON diff。 |
| CR-13 | Undo/Redo | Crop Done、Cancel、Reset、Replace 后的 Undo/Redo 顺序正确；Cancel 不应占用一步。 | 连续操作 history 单测；至少 5 步序列录屏。 |

## 2. TEXT · 溢出、Fit text 与导出阻断（E05）

### 2.1 字段与编辑状态

| ID | 签核项 | 通过条件 | 必需证据 |
| --- | --- | --- | --- |
| TX-01 | 合法字段 | 只显示当前页允许的文字：封面（宠物名/副标题/年份），章节开场（标题/日期/备注），照片页（标题/注记），献词/结尾（用户文字）。不得显示自动情绪/宠物口吻生成入口。 | 每页类型 Text 面板截图和字段 accessibility ID。 |
| TX-02 | 字符边界 | 照片页标题/注记最多 120；献词/结尾最多 240。第 121/241 个字符不写入 document，并有可理解的剩余/上限反馈；中文、emoji、组合字符按产品定义的可见字符规则一致。 | 英文、中文、emoji 三组单测与 UI 截图。 |
| TX-03 | 编辑提交 | 输入过程中不逐字符生成 history；失焦或 Done 才是一条 history 事务并自动保存。键盘出现不遮挡当前文本与 Done。 | history 单测、键盘截图、重进恢复。 |
| TX-04 | 三档文字 | Small / Default / Large 来自 `PageStyle` token，并改变字号、行距、字距的对应档位；不出现自由字体/颜色控件。 | 三档 Editor/Reader/PDF 截图、RenderPlan/manifest token。 |
| TX-05 | 安全锚点 | 可移动文本仅在模板许可安全锚点内；拖至边界会夹紧且不覆盖标题/页码/水印保护层。 | 边缘拖动录屏、几何断言、Reader/PDF 对照。 |

### 2.2 溢出定义、Fit text 与修复流程

| ID | 操作 | 可签核预期 | 数据 / 自动化断言 |
| --- | --- | --- | --- |
| TX-06 | 输入能放入 120/240 限制但放不进当前文本框的内容 | 立即显示红色文本框/错误色提示和可见 `Fit text`；不得静默裁切、盖住其它文字或将文字画到安全区外。 | `isTextOverflowing`（或等价）状态为 true；Editor 截图。 |
| TX-07 | 点击 Fit text | Fit text 只在 Small / Default / Large 合法档位内选择能完整显示的最小适配档；不改文字内容、frame、对齐或用户手调图片。若最小档仍不适配，保持错误并提示缩短文字/调整文本框。 | 适配与不可适配两组 before/after JSON、截图、Undo。 |
| TX-08 | 不解决溢出后运行 Book Check / Export | Book Check 明确列出 `Text overflow` 阻断项并能跳转该页；导出准备阻止开始渲染，说明需先处理，不生成半成品 PDF。 | Book Check 截图、导出拦截 UI、文件目录无新 PDF。 |
| TX-09 | 解决后复查 | 删除/缩短文字、扩大允许框或 Fit text 成功后，红框与阻断消失；Book Check 可继续；Undo 后错误再次准确出现。 | 复查录屏与 history / Book Check 断言。 |
| TX-10 | 预览/PDF一致 | 正常文字与 Fit text 后文字的内容、换行、字号、对齐、可见行完全一致；A4 和 Letter 均不因测量差重新溢出。 | 每纸张 Reader/PDF raster、文本行盒 JSON。 |

### 2.3 文本异常、返回和保护

| ID | 签核项 | 通过条件 | 必需证据 |
| --- | --- | --- | --- |
| TX-11 | 返回未提交输入 | 有输入焦点时返回编辑器/离开文档，出现 `Keep editing / Save and leave / Discard this edit`；分别验证三项，Discard 只回滚本次未提交输入。 | 三分支录屏与 document diff。 |
| TX-12 | 模板变更 | Apply book/page style 不改文本内容、用户位置或已选字号档；若新模板导致溢出，立即显示并纳入 Check。 | 模板前后 JSON diff、溢出 case。 |
| TX-13 | Unicode / 字体回退 | 中文、变音符、emoji 无 tofu/错位；若平台无法以同一字体渲染，必须作为导出阻断而非默许差异。 | Fixture 截图、PDF font/文本证据。 |

## 3. LAYOUT · 明确版式选择与超量照片处理（E06）

### 3.1 面板与可用范围

| ID | 签核项 | 通过条件 | 必需证据 |
| --- | --- | --- | --- |
| LY-01 | 明确选项 | `Layout` 面板仅在当前照片页启用，且同时列出 Single、Two-up、Grid 2×2、Grid 3×2、Note；当前选项有明确选中态。不得用单一 `Layout` 按钮轮换。 | 照片页面板截图、各 option accessibility ID。 |
| LY-02 | 非照片页 | 封面/目录/章节开场/献词/结尾进入 Layout 时给出简洁解释或禁用态，不更改 document。注记页可切为 Note，但不得伪造图片槽。 | 各页 type 截图和 no-op JSON。 |
| LY-03 | 容量定义 | 版式容量固定并可见：Single=1，Two-up=2，Grid 2×2=4，Grid 3×2=6，Note=0 图片；容量与实际元素数及 RenderPlan 相同。 | layout→capacity 单测、plan manifest。 |
| LY-04 | 用户编辑保护 | 切换版式时同页可容纳的前 N 张按视觉顺序保留；不会丢 asset、文本、用户备注或已锁定元素。受保护元素导致不能安全换版式时必须解释而非静默重排。 | 含锁定和手调元素的 before/after JSON。 |

### 3.2 超量摘要、确认、迁页与撤销

| ID | 操作 | 可签核预期 | 数据 / 自动化断言 |
| --- | --- | --- | --- |
| LY-05 | 6 图照片页切换到 Two-up | **操作前**出现确认：明确显示“保留 2 张、移动 4 张到本章节新照片页”（实际数字从 document 计算）；Cancel 不变。 | 确认态截图、cancel JSON equality。 |
| LY-06 | 确认超量迁页 | 新页插入同一 `chapterID` 的合法照片页范围；超量资产按原视觉顺序、原元素变换（除为新模板必要的默认框）迁移；所有 6 asset 各出现一次，无丢失/重复。 | before/after asset/page manifest、页面管理器截图。 |
| LY-07 | 新页计数与文案 | 摘要准确含受影响页数、将新增的页数、移动照片数；不得显示硬编码或负数/0 页的错误信息。 | 1→4、2→6、6→2、6→Note 四种截图及字符串/数字断言。 |
| LY-08 | Note 版式确认 | 从有照片页切 Note 时，所有图片迁页或用户取消；不能在 Note 中隐藏仍被 document 引用的照片。若无可迁移素材路径，阻止并解释。 | Note 成功/取消/阻止三组证据。 |
| LY-09 | 单一事务 | 版式切换、增页与资产迁移作为一个原子 history 事务；Undo 恢复原版式、原页序、asset 顺序和 frame，Redo 再现结果。 | `layout change → Undo → Redo` 单测与 JSON diff。 |
| LY-10 | 自动保存/重进 | 确认版式后自动保存；杀进程/重进不重新按 builder 初稿分组，新增页和图顺序仍在。 | repository test 与重进录屏。 |

### 3.3 渲染与错误状态

| ID | 签核项 | 通过条件 | 必需证据 |
| --- | --- | --- |
| LY-11 | 成品一致 | 所选 layout 的图片框、照片顺序、文本、背景在 Editor 成品区、Reader 与 PDF 相同；选择框/工作区不出现在成品。 | A4/Letter 的 Reader/PDF raster 与 manifest。 |
| LY-12 | 空页 | 迁图后旧页若无图片：按产品规则给出“保留为空白注记页 / 删除页面”明确选择；不得悄悄保留无意义照片页或删除用户注记。 | 交互截图、两分支 JSON。 |
| LY-13 | 无可迁移/缺失资产 | 缺失资产、受限权限、无 eligible photo 时 Layout 面板说明原因；不创建空白新照片页作为成功结果。 | 缺失/权限 fixture 录屏，Book Check 状态。 |
| LY-14 | 纸张与模板 | A4/Letter 与五模板下，切版式保持 normalized 顺序和容量规则；仅目标纸张比例变化，不能发生资产重新挑选或静默裁剪。 | 5 模板 × 2 纸张 manifest；P0-1 RenderPlan 对照。 |

## 4. 共通的保存、错误和可访问性门禁

| ID | 条目 | 通过条件 | 证据 |
| --- | --- | --- | --- |
| CM-01 | 自动保存反馈 | 任何 Done/确认后的提交在 1 秒内持久化；顶栏短暂 `Saved`，不以阻断 toast 打断操作。 | 保存时序日志/截图。 |
| CM-02 | Cancel 无副作用 | Crop Cancel、layout confirmation Cancel、文本 Discard 均不改变 document、不创建 history、不会生成 PDF。 | 各 flow JSON/hash 对比。 |
| CM-03 | 失败可恢复 | asset 读取、持久化、导出检查失败说明原因，提供可恢复操作；草稿和最近成功 PDF 不丢失。 | 故障注入 UI + filesystem 证据。 |
| CM-04 | 触控与 VoiceOver | 关键操作均 ≥44×44 pt；Crop Cancel/Done/Reset、Fit text、layout option/confirm/cancel 有稳定 identifier、清楚 VoiceOver label/hint。 | accessibility inspector / UI test 输出。 |
| CM-05 | 不泄露隐私 | 任何 Add/Replace/裁剪候选/布局迁移不引入 sensitive、hidden、neverUse、excluded 或无权限资产；所有路径均只保存标识与编辑参数，不写回系统相册。 | F-SAFE selector/manifest 自动化。 |

## 5. 签核所需最小证据包

研发交付后，以下文件缺一项即为 **Not run**：

1. `p02-contract-tests.xcresult`：至少 CR-05…10、TX-02/06…10、LY-03/05…10、CM-02 的自动化结果。
2. 真实可运行截图/录屏：Crop 进入、Cancel、Done、Reset；文本溢出、Fit text 成功与失败、导出阻断；Layout 各选项、超量摘要 Cancel/Confirm、Undo。
3. 冻结 fixture 的前后 JSON / render manifest：证明 asset、chapterID、元素几何、锁定标记、文本内容与页序。
4. Reader/PDF：至少一个带 crop/rotation 的照片页、一个 Fit text 页、一个超量迁页后的 layout 页，在 A4 和 Letter 分别出图；本批不取代 P0-1 的全矩阵热图门禁。
5. 异常证据：缺失 asset、无可入册照片/无可迁移素材、过长文本、取消路径。

## 6. 产品/设计复核记录（研发提交后填写）

| 项目 | 结果（Pass / Fail / Not run） | 证据位置 | 发现的问题 / 返工要求 |
| --- | --- | --- | --- |
| CROP：CR-01…13 | Not run |  |  |
| TEXT：TX-01…13 | Not run |  |  |
| LAYOUT：LY-01…14 | Not run |  |  |
| 共通：CM-01…05 | Not run |  |  |
| Reader/PDF 抽检 | Not run |  |  |

**产品/设计结论：** Not signed.  
**签核人 / 日期：** 待研发交付后填写。

## 7. 初始风险提示（不作为预验收）

- 现有 `cropScale/cropOffset` 需要以同一 Fill 算法驱动 Editor、Reader、PDF；仅能拖动元素框不满足 CR-05…10。
- “字符上限”与“文本溢出”是两个不同概念：120/240 限制不能代替当前 frame 的真实测量和 Fit text。
- Layout 变更属于会增页、迁资产、影响页序的结构操作，必须先展示由真实 document 计算的摘要，再经确认提交为单一可撤销事务。
- 本清单不解除 P0-1 的真实图片、五模板、A4/Letter 全矩阵和真机视觉发布门禁。
