# Tailor 生命相册页面编辑器 v1 · 研发交接一致性审计

> **状态更新（2026-07-16）：** 以下正文保留为 2026-07-15 的开发前基线，不再代表当前工程。当前实现已接入编辑器路由、持久化 `MemoryBookDocument`、页面/图片/文字/样式工具、会话撤销重做、页面管理完成出口、自动排版保护及本页/章节/全册确认范围、检查器、免费样章、同元素模型 PDF 与版本化导出。iPhone 17 Pro / iOS 26.5 Simulator 全量回归为 **48/48 通过**，结果包：`/tmp/tailor-editor-final2-tests/Logs/Test/Test-Tailor-2026.07.16_11-26-26-+0800.xcresult`。
>
> **仍属发布前人工门禁而非代码缺口：** 使用真机本地 Photos 资产进行 5 套模板 × A4/Letter 的 PDF 栅格化对比，以及有限权限/删图/低内存的设备证据。此类证据不能由 demo fixture 或编译通过替代。

**审计日期：** 2026-07-15  
**审计范围：** [编辑器 PRD](../../docs/mobile-prd-plans/Tailor_iOS/14_life_album_page_editor_v1_PRD_2026-07-15.md)、`design/editor_v1` 原型/视觉规格，及当前 SwiftUI / PDF 实现。  
**审计方式：** 只读代码与设计交付检查；未修改产品源码，未将构建通过视为功能完成。  
**结论：** 当前实现是“页面模型 + 预览/PDF 技术验证”，不是可交付的 E01–E09 页面编辑器。P0 项未关闭前，不应将当前预览或 PDF 作为付费成品能力验收。

## 1. 交接判定

| 领域 | 设计/PRD要求 | 当前实现证据 | 判定 |
| --- | --- | --- | --- |
| 唯一文档模型 | `Document → Page → Element`，含样式、锁定、编辑状态 | 已有 `MemoryBookDocument/Page/Element` 与归一化 frame；模型未含 schema、页面样式覆写、锁定、来源、更新时间 | 部分具备 |
| 编辑器入口 | Timeline → E01 → E02 编辑器；已存在草稿显示 Continue editing | Timeline 仍进入 `.preview`；没有 E01 / E02 route 或主编辑器 View | 缺失 |
| 页面级画布 | 大尺寸纸张画布、选择、控制点、安全区、5 个上下文工具 | `PageElementCanvas` 被嵌在 242 × 339 的 `TabView` 预览内，仅渲染图片并提供拖动/缩放 | 缺失 |
| 图片编辑 | Add / Replace / Crop / Remove / Rotate / Layer / Reset | 当前只有拖动与 `cropScale`；无产品 UI、无裁剪提交/取消、无替换删除旋转层级 | 缺失 |
| 文本编辑 | 可选中/编辑、字号档、溢出阻断和安全锚点 | 生成了 text element，但 SwiftUI 预览没有渲染/选择它；无编辑面板 | 缺失 |
| 页面管理 | 缩略图、受限重排、新增、复制、删除 | 无页面管理器或页面增删改/重排动作 | 缺失 |
| 模板/版式 | 5 套 PageStyle、全册/单页、布局切换和恢复模板 | 仅 `AlbumStyle` 色板；没有 PageStyle token、局部覆写、布局面板或迁移逻辑 | 缺失 |
| 自动排版/检查 | scope、锁定规则、确认摘要、导出前问题清单 | 仅 builder 初稿；无重新排版、锁定或检查器 | 缺失 |
| 阅读预览 | 全屏逐页、免费 6–8 页重复水印/付费全册、纸张选择 | 现为内嵌缩略 `TabView`；水印只有单个 `PREVIEW`；未实现样章截取规则 | 缺失 |
| 一比一 PDF | 按 element frame/crop/rotation/zIndex/style 渲染 | `LocalPDFExporter` 重新根据 `kind/layout/photoIDs` 绘制；完全忽略 `elements` 的位置、裁剪、旋转和层级 | 严重不一致 |
| 草稿与恢复 | 自动保存、退出恢复、50 步会话撤销/重做 | `memoryBook` 只存在根 View 内存；仓库只保存 `ArchiveDocument`，并未持久化 `MemoryBookDocument` | 缺失 |

## 2. P0：必须在正式开发开始前/首个研发批次关闭

### P0-01 · 信息架构与真实编辑入口缺失

**差异：** PRD E01/E02 要求时间线进入“Edit album / Continue editing”，随后进入独立编辑器。当前 `TimelineFeatureView` 的下一步直接路由到 `.preview`；`PreviewFeatureView` 是旧相册预览页，不是设计稿中的深绿工作区编辑器。

**影响：** 用户无从进入产品化编辑器；设计给出的 E01、E02、E03–E07 无法接入真实流程。

**研发交付：**

1. 增加 editor 路由及 `AlbumEntryFeatureView`（E01）和 `MemoryBookEditorFeatureView`（E02）。
2. 首次创建 document，后续读取已保存 document；入口显示页数、模板、最近编辑时间、草稿状态、未导出修改状态。
3. Timeline 的 CTA 文案和路由改为 `Edit album`/`Continue editing`；`Preview album` 仅进入 E08 只读阅读模式。

**验收：** 从真实时间线、重启 App 后的已有档案均能打开同一份草稿，而不是再次调用 `MemoryBookBuilder` 重置页面。

### P0-02 · 页面画布仍是缩略预览，未按设计实现编辑器

**差异：** 设计规格要求中央 A4/Letter 纸张、深绿工作区、页面阴影、安全区、页缩略条与顶栏 Undo/Redo/More。现有 `PageElementCanvas` 固定高度 205 pt，放入 `AlbumPagesPreview` 的 242 × 339 pt 预览内；没有纸张比例映射、顶部控制或 5 个实际工具面板。

**影响：** 现有手势无法达到可用精度；视觉层级、页面级操作和“预览即成品”概念都未成立。

**研发交付：**

1. 建立 `MemoryBookPageCanvas`（编辑）与 `MemoryBookReadingPage`（只读）两个容器，均消费相同的 element/layout/style 渲染器；只允许编辑容器绘制选择框、控制点、辅助线。
2. 按纸张比例计算画布并加入 7% 安全区；Element frame 必须 clamp 到安全区，禁止当前实现中可拖出容器的情况。
3. 建立顶栏和底部 `Pages / Layout / Photo / Text / Style` 上下文菜单；无选中元素显示页面工具，选中图/文本只显示其可用操作。
4. 每次拖动/缩放结束合并为一条编辑事务；不可在手势中重复写持久化。

**验收：** 编辑截图可逐项对照 `screens/editor-key-states.svg` 的 E02；阅读预览和 PDF 不出现选择框/辅助线。

### P0-03 · `MemoryBookDocument` 不能保存正式编辑结果

**差异：** 当前 `MemoryBookDocument` 不符合 PRD §10：不是 `Codable`，没有 `archiveID/schemaVersion/updatedAt/lastExportedAt`；`MemoryBookPage` 没有 `styleOverride/isLocked/createdBy/order`；`MemoryBookElement` 没有 `styleOverride/isLayoutLocked/createdBy/updatedAt`。`memoryBook` 只保存在 `MilestoneRootView` 的 `@State` 中。

**影响：** 离开、重启、章节变更或自动排版都会丢失或重置用户布局；无法实现可撤销事务及兼容迁移。

**研发交付：**

1. 按 PRD §6.1/§10 补全可迁移 Codable schema，并持久化到现有 repository；不把绝对屏幕坐标存入草稿。
2. 实现一次性旧页迁移：旧 `photoIDs/layout/title/subtitle` 生成默认 elements，保留既有章节、封面和用户文字。
3. 维护会话内 `EditorHistory`（至少 50 个事务）及 1 秒内自动保存；退出、崩溃恢复最近提交事务。
4. `updateChapters` 不可无条件将 `memoryBook = nil`；应按产品决策只同步未覆写的字段并给出可撤销变更摘要。

**验收：** 逐页调整、模板覆写、文本编辑、页面顺序在离开/重进后仍存在；旧档案可迁移而不静默丢书。

### P0-04 · 图片编辑能力与设计稿不一致

**差异：** 当前只对 image element 提供自由拖动和 `cropScale`；`cropOffset` 从未由 UI 更新，`rotationDegrees` 从未应用；没有 Replace、Remove、Add、Crop mode、Reset、层级 UI，且没有吸附和最小/最大尺寸约束。

**影响：** 用户无法真正定制照片；现有 `cropScale` 也不能保证图片始终填满框，可能出现空白或与 PDF 不同的裁剪。

**研发交付：**

1. 实现 E04 独立裁剪模式（进入快照、Cancel 回滚、Done 提交、Reset）；拖动应写 `cropOffset`，捏合应写 crop scale，且使用同一个 Fill 算法。
2. 从本档案 eligible photos 打开添加/替换选择器；禁止 `needsReview`、敏感、neverUse、隐藏时期和缺失资产进入。
3. 实现 Remove from page、空页面后续处理、旋转 -15°…15°、层级调整、恢复模板图框与对齐/安全区吸附。
4. 图片 frame 限制为短边 12% 至安全区上限，并添加触觉/视觉越界反馈。

**验收：** 按 E04 逐项测试，且 Replace 保留 frame/rotation/zIndex、只重置新图裁剪；Remove 不改变系统相册或章节选片。

### P0-05 · 文本元素没有被产品 UI 或 PDF 消费

**差异：** builder 已创建文本 element，但当前 `MemoryBookPageView` 仍使用 `page.title/subtitle` 直接渲染；`PageElementCanvas` 过滤了 `.text`。PDF 也直接使用 title/subtitle。设计 E05 的文本面板、字号档、文本安全锚点、溢出提示皆未实现。

**影响：** 文本修改无法成为页面模型的一部分，更不可能一比一导出；部分 page kind 会出现重复/位置冲突的文本来源。

**研发交付：**

1. 从统一 element render pipeline 绘制图与文本，明确 title/subtitle 仅为旧草稿兼容字段或迁移输入，避免双来源。
2. 实现模板允许字段、Small/Default/Large token、模板安全锚点内移动和 120/240 字符限制。
3. 实现文本测量和溢出状态；Book Check 与导出前将 overflow 作为阻断项。

**验收：** 编辑后的换行、字号、对齐、位置在阅读预览/A4/Letter PDF 完全相同。

### P0-06 · 页面管理、版式、自动排版与检查器全部缺失

**差异：** 原型包含 Pages、Layout、Auto arrange、Book Check，当前 App 无相应 View/状态/操作。`MemoryBookLayout` 仅在 builder 初稿与 PDF 分支中使用，不能由用户变更。

**影响：** 自动初稿无法被组织和修订，PRD P0 的“用户可以真正定制相册”不成立。

**研发交付：**

1. E03：低清缩略图管理器，结构页锁定、合规插入位置、增/删/复制照片或注记页、章节归属和修改标识。
2. E06：Single/Two-up/Grid 2×2/Grid 3×2/Note；切换前给出 overflow 移页摘要，确认后成为单个可撤销事务。
3. E07：Auto arrange scope 与 locked element/page 保护；确认页显示受影响页数、新增/删除页和保持的手工编辑。
4. 实现 `Book Check`：缺失资产、文字溢出、无可导出照片（阻断）；重复/低清/水印（建议）；每项可跳转对应页。

**验收：** 固定页不能非法移动/删除；自动排版不改变任何已锁定 element；检查器不擅自移除用户照片。

### P0-07 · 模板系统尚非共享 `PageStyle`，五套风格没有实际还原

**差异：** `AlbumPalette` 只有若干颜色。Quiet Night、Cinema 在 PDF 中共用配色；Cinema 只在 SwiftUI cover 图片使用 `.saturation(0)`，其他页及 PDF 无同一滤镜；Film Album 的边框、Field Notes 的日期/注记卡，均未按原型模板系统实现。没有单页 style override 或 Restore page style。

**影响：** 5 套模板无法形成可售卖的视觉差异，也无法满足 PDF/预览一致性。

**研发交付：**

1. 设计/研发共同定义平台无关 `PageStyle`：background、safeInsets、typography token、image treatment、ornament、watermark、template anchor。
2. 在 SwiftUI 与 Quartz 建立同名 token/映射测试；禁止 `switch style` 各自临时猜测版式。
3. 实现全册和单页应用、Custom style 标识、Restore page style，并保持用户图片/文本内容和 frame。

**验收：** 对 5 个模板 × A4/Letter × 至少单图/拼贴/注记页的截图和 PDF 栅格化逐页比对，Cinema/Film/Field 的设计差异可见且不伤害可读性。

### P0-08 · PDF 不是编辑结果的一比一导出

**差异：** `LocalPDFExporter.export(document:)` 忽略 `bookPage.elements`，重新按 `kind`、`photoIDs`、`layout` 计算 title、图框、网格和内容页；不应用 cropOffset、cropScale、rotation、zIndex、单页模板、文本样式或水印。图片仅按 500 × 340 请求，且 `UIImage.draw(in:)` 无 Fill crop 语义。

**影响：** 这是当前最严重的付费阻断：用户在预览所见与导出文件不一致，违反 PRD §7 的核心契约。

**研发交付：**

1. 将 page render 抽为共享 `PageRenderPlan` 或等价纯数据管线；SwiftUI 编辑/阅读与 Core Graphics PDF 都按相同 normalized frame、safe area、Fill/crop transform、rotation、zIndex、PageStyle 绘制。
2. PDF 从 document 的冻结快照渲染；显式填充每页背景；输出完整水印规则（免费样章）而非单角标。
3. 预览使用同一个 `pageSize` 比例；支持 A4/Letter 选择、导出前页数/预估大小、导出 progress 与取消。
4. 增加“预览-PDF 像素对比”自动化测试，覆盖 PRD §7.3 容差。

**验收：** 元素边界 ≤ 页面长边 0.5%、裁剪焦点 ≤ 容器短边 1%；无透明黑页、缺图、重图、图层错序或不同文本换行。

### P0-09 · E08/E09 免费边界、导出流程与资产异常未实现

**差异：** `PreviewFeatureView` 显示全册 `TabView`，而不是免费 6–8 页真实带水印样章；付费状态下也没有全屏阅读、导出前规格确认。`ExportFeatureView` 在开始前就使用成功态视觉，没有 `Rendering page x of y`、取消、封面真实缩略和失败恢复流程。资产缺失没有灰色占位/Replace/导出阻断。

**影响：** 付费逻辑和恢复体验与 PRD不一致，且用户无法确认最终文件范围。

**研发交付：**

1. 明确 sample-page selection（封面/目录/两个时期/照片页/结尾，6–8 页）与重复低对比水印；已解锁显示全册无水印。
2. E08 导出准备包含纸张、页数、文件大小估计；取消购买返回同一预览页。
3. E09 实现渲染进度、取消、成功封面缩略/生成时间/页数/纸张、失败重试/返回编辑和持久归档。
4. 在选片、预览缓存和导出前统一检查 asset 可用性；缺失 asset 是阻断项。

**验收：** 未购买仍能完整编辑和保存；购买取消/导出失败不丢草稿；档案可再次分享最近 PDF，删除档案后不可访问。

## 3. P1：设计补全与实现质量门禁

### P1-01 · 原型交互当前是演示状态，不能作为研发行为唯一依据

`prototype.html` 的 Pages、Photo、Text、Style、Layout、Arrange、Book Check 主要是前端 toast 或静态模拟，未覆盖数据修改、确认弹窗、不可用态、返回恢复和约束。设计交付应增加每个操作的输入、数据变化、取消、成功、失败与 undo 规范，避免研发将点击反馈误实现为真实功能。

### P1-02 · 缺少关键状态画板

需补齐以下 E01–E09 状态，且每张标注页面/安全区/交互锚点：

- E01：首建、已保存草稿、无可入册照片。
- E02：无选择、选中图片、选中文本、保存中、Undo/Redo disabled、窄屏/键盘出现。
- E03：重排合法/非法 drop、页面复制/删除二次确认、新页选择章节、Custom style 标识。
- E04：候选照片选择器、Replace、空照片页、Rotate/Layer/Reset、资产缺失。
- E05：Small/Default/Large、溢出、Fit text、Unicode/中文字体回退。
- E06：每套模板在 cover/opener/photo grid/note page 的实际页面；局部覆写和恢复确认；layout overflow 移页说明。
- E07：三个 auto-arrange scope 的影响摘要、已锁定元素、Check 的阻断/建议/跳转结果。
- E08：免费样章、已解锁全册、纸张选择/文件估计、购买取消/失败回退。
- E09：渲染中、取消、导出失败、成功、最近 PDF、权限变化后资产缺失。

### P1-03 · 设计 token 需要从“说明”升级为可消费资产

设计规格已有色值和概念，但尚未提供工程可直接消费的 `PageStyle` token 表。需交付 JSON/Swift 常量或设计 token 文档，至少包括：A4/Letter safeInsets、背景/工作区/卡片/边框、标题/正文/页码字体映射、每模板图片处理、Film date-note 区、Cinema 满版规则、水印密度与透明度、深色对比度门槛。

### P1-04 · 图像与字体资产/授权没有闭环

原型使用 CSS 形状占位。正式视觉验收需要：

- 本地、已授权的宠物测试照片集（横/竖图、低清、连续相似图、缺失 asset）及其 fixture manifest；不得将生成宠物图作为真实用户内容验证。
- 字体可用性和导出字形回退决策（`New York` / `Iowan Old Style` / 中文及其他 Unicode）；如系统字体在 Quartz 与 SwiftUI 不一致，需要选择同一可嵌入字体或定义失败门禁。
- 图标资产命名（Pages/Layout/Photo/Text/Style、Rotate/Layer/Replace/Remove/Check）与 SF Symbol fallback；不得继续使用原型中的字符图标（`▦`、`◐` 等）。

### P1-05 · 可访问性与性能规格缺失

补充：44 pt hit target、VoiceOver 标签/当前页/选中状态、Dynamic Type 的编辑面板策略、Reduce Motion、深色模板对比度，以及 20/100/500 张入册照片下缩略缓存、全尺寸延迟加载和主线程预算。视觉验收必须在真机与 A4/Letter PDF 栅格化两条路径上进行。

## 4. 推荐研发拆分与完成定义

| 批次 | 交付 | 可关闭的 P0 |
| --- | --- | --- |
| A：数据与共享渲染基线 | schema/迁移/草稿仓库、PageStyle token、统一 element renderer、PDF snapshot 与像素基线 | P0-03、P0-07、P0-08 的基础 |
| B：编辑器主路径 | E01/E02、选择层、安全区、图片拖拽/缩放/裁剪、文本渲染与保存、Undo/Redo | P0-01、P0-02、P0-04、P0-05 |
| C：编排能力 | E03/E06/E07、页面管理、模板覆写、布局、Auto arrange、Book Check | P0-06、P0-07 |
| D：阅读与交付 | E08/E09、水印样章、购买回退、导出准备/progress/失败、归档 | P0-09、P0-08 全量 |
| E：质量门禁 | 真机手势、草稿迁移、权限/资产异常、5 模板 × 2 纸张 × 页面类型像素对比 | 发布门禁 |

## 5. 发布前必须提供的证据

1. E01–E09 真机录屏或逐页截图，含本审计 P1-02 的异常状态。
2. 同一 document 的 SwiftUI 阅读预览与导出 PDF 栅格化对比报告，按 5 模板、A4/Letter、单图/双图/2×2/3×2/注记页覆盖。
3. 持久化/迁移测试：旧草稿、编辑后杀进程、权限变更/删除系统照片、导出失败、购买取消。
4. 仅由已选且正常照片构成的 selector、页面、预览和 PDF 的数据泄漏测试。
5. `Book Check` 阻断项和非阻断项的自动化与人工验收记录。

在上述证据齐全前，当前 `PreviewFeatureView` 和 `LocalPDFExporter` 只能被标记为开发验证，不得标记为“预览即成品”或可发布的 $19.99 交付物。
