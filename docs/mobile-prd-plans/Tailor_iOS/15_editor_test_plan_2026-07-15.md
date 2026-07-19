# Tailor 生命相册页面编辑器 v1 测试计划与验收矩阵

> 状态：测试基线 / **未通过发布门禁**  
> 输入：[编辑器 v1 PRD](14_life_album_page_editor_v1_PRD_2026-07-15.md)  
> 审计对象：2026-07-15 当前 `Tailor/` 工程、`TailorTests`、`TailorUITests`  
> 适用阶段：P0-A / P0-B / P0-C；iOS 17+、iPhone、A4 与 US Letter

> 2026-07-16 增量：P0-1 共享 PageStyle / PageRenderPlan 的独立验收矩阵、70 页组合覆盖、PDF 栅格化产物与签核模板见 [17_p0_1_shared_render_plan_qa_acceptance_2026-07-16.md](17_p0_1_shared_render_plan_qa_acceptance_2026-07-16.md)。该增量在研发交付前仍为待执行，不覆盖本基线中的其他 P0 阻断项。

## 1. 结论

当前工程**不能通过编辑器 v1 的验收**。它已有 `MemoryBookDocument → MemoryBookPage → MemoryBookElement` 的初步模型，并能在预览页中对图片元素进行拖动和缩放；但该模型没有持久化、没有独立编辑器入口/状态机，PDF 也没有按元素坐标、裁剪、旋转、层级与文本进行绘制。因此现有能力只能定义为技术验证（spike），不能称为“预览即成品”的正式功能。

本文件把 PRD 转换为可自动化、可手工执行并可留档的测试集。任何标记为 **P0 阻断** 的项未关闭，不得将页面编辑器、完整 PDF 或 $19.99 解锁对外发布。

## 2. 当前实现审计

| 编号 | PRD 要求 | 当前证据 | 结论 / 风险 | 优先级 |
| --- | --- | --- | --- | --- |
| GAP-01 | E01–E09 编辑器状态机与独立入口 | `MilestoneRootView` 路由只有 `preview`，无 `editor.loading/editing/previewing/export.preparing/rendering/completed`；时间线直接进入 preview。 | 用户无法进入产品化编辑器，也无法按页编辑。 | P0 阻断 |
| GAP-02 | `MemoryBookDocument` 为唯一且可保存的页面源 | `MemoryBookDocument` 不是 `Codable`，没有 `schemaVersion/updatedAt/lastExportedAt`；`ArchiveDocument`/`StoredPetProfile` 不存 `memoryBook`。 | 离开或重启后页面元素、编辑结果必然丢失；无法迁移旧稿。 | P0 阻断 |
| GAP-03 | 图片完整编辑：添加、替换、删除、裁剪、旋转、层级、约束与提示 | `PageElementCanvas` 仅实现无边界/吸附的 `DragGesture` 和 `MagnifyGesture`；缩放修改 `cropScale`，没有 crop mode/替换/删除/旋转/z-index UI。 | 页面编辑不符合 E04，且元素能被拖出可视安全区。 | P0 阻断 |
| GAP-04 | 文本编辑、文本溢出、三档字号与安全区 | 页面文本由 `MemoryBookPageView` 的 `Text(page.title/subtitle)` 静态显示，`PageElementCanvas` 只渲染图片元素。 | 标题/备注不可编辑，文本元素模型虽存在却不参与预览。 | P0 阻断 |
| GAP-05 | 页面管理、复制/新增/删除/受限重排 | 没有 Pages 管理器、页缩略图、固定结构页限制或二次确认。 | 无法完成 E03，也无法验证文档页序。 | P0 阻断 |
| GAP-06 | 撤销/重做、自动保存、放弃未完成修改 | 无 history、undo/redo UI、1 秒自动保存或编辑事务；`persistDocument()` 只保存 `ArchiveDocument`。 | 用户修改不可恢复且不能安全退出。 | P0 阻断 |
| GAP-07 | 自动排版、锁定规则、Check book | 仅 `MemoryBookBuilder` 初次构建；没有 `isLayoutLocked`、自动排版事务、缺图/溢出/重复检查器。 | 自动初稿会覆盖/丢弃人工意图的风险无法控制。 | P0 阻断 |
| GAP-08 | 预览/PDF 同一元素模型与 7.3 一比一 | Preview 使用 SwiftUI 固定层级与 `PageElementCanvas`；`LocalPDFExporter` 重新使用 `title/subtitle/photoIDs/layout` 直接绘制，忽略 `elements.normalizedFrame/cropScale/cropOffset/rotationDegrees/zIndex/text`。 | 已编辑预览和导出 PDF 必然不一致，不能收费。 | P0 阻断 |
| GAP-09 | 5 模板完整同步，Cinema/Film 为本地视觉处理 | Preview 有 5 个选项；PDF 将 Cinema 和 Quiet Night 复用同一 palette，未使用滤镜，Film 只在照片格画边框。 | 模板成品不一致，视觉承诺无法验收。 | P0 阻断 |
| GAP-10 | 免费仅 6–8 页水印样章；已购完整无水印全册 | Preview 对 `document.pages` 全量展示并只覆一枚 `PREVIEW`；未限制 6–8 页、未定义样章页选择；PDF 没有水印参数。 | 免费/付费边界与内容口径不符合 PRD。 | P0 阻断 |
| GAP-11 | 导出准备/进度/取消/冻结快照/多版本保留 | `ExportState` 未接入；`exportPDF()` 没有页数进度、取消、快照 hash、版本化命名；导出固定覆盖 `profileID-life-archive.pdf`。 | 无法验证取消恢复、导出稳定性与旧文件保留。 | P0 阻断 |
| GAP-12 | 资产缺失和权限变化阻断导出并提供 Replace | `LocalPDFExporter.thumbnail` 取不到 `PHAsset` 时直接 `continue`；无占位、检测、Replace 入口或阻断。 | 用户会拿到缺图但“成功”的 PDF。 | P0 阻断 |
| GAP-13 | 手动编辑不被模板/预览/自动操作重置 | `PreviewFeatureView` 的 `documentBinding` 可在 `memoryBook == nil` 重建；更新时间线时 `memoryBook = nil`。 | 页面编辑结果无跨流程保护。 | P0 阻断 |
| GAP-14 | 购买中、取消、pending、失败、恢复均有可用状态 | `PurchaseFeatureView` 无 loading/禁重复；`purchase()` 只处理 entitled/restored/failed，忽略 cancelled/purchasing。 | 用户可能重复点击或卡在 pending/cancelled 状态。 | P0 阻断 |
| GAP-15 | 现有自动化覆盖 | 单测仅验证 PDF `%PDF` 头、Builder 的基本可入册过滤；UI 测试仅验证 preview 文案/按钮和 demo route 截图。 | 没有编辑手势、保存恢复、PDF 像素、权限资产、付费边界的有效覆盖。 | P0 阻断 |

### 2.1 可复用的现有基础

- `ArchivePhoto.isEligibleForArchive` 已覆盖 selected + normal 的基础过滤；现有单测验证 normal/sensitive/deferred/neverUse。
- `MemoryBookBuilder` 已支持封面、献词、目录、章节开场、照片页、里程碑、结尾及超过 6 张分页。
- PDF 显式填充页面背景，可作为“无透明黑页”回归起点。
- Preview 和 PDF 接口已能传递 `MemoryBookDocument`，但必须改为共同消费 `MemoryBookElement` 与 `PageStyle` 才能作为同源渲染。

## 3. 测试环境、数据与证据规范

### 3.1 环境矩阵

| 环境 | 必测内容 | 证据 |
| --- | --- | --- |
| iPhone 6.1-inch Simulator / iOS 17 最低版本 | 可访问性、路由、基础编辑、UI 自动化 | `.xcresult`、截图 |
| 最新 iOS Simulator | SwiftUI 手势、动态字体、深浅系统外观回归 | `.xcresult`、截图 |
| 实体 iPhone / 完整照片权限 | 真实 PHAsset、相册删除、权限改变、高分辨率导出、Share Sheet | 录屏、设备/系统版本、导出 PDF |
| 实体 iPhone / 有限照片权限 | 选择器、撤销访问后缺图、管理访问入口 | 录屏、导出检查截图 |
| 飞行模式实体机 | 编辑、预览、PDF；购买入口应提示 StoreKit 不可用而不丢草稿 | 录屏、草稿恢复证据 |

### 3.2 固定测试素材

所有素材必须由 QA 本地导入测试设备；不得上传或提交用户个人照片。

| Fixture | 内容 | 覆盖 |
| --- | --- | --- |
| F-01 | 1 张 4:3 清晰宠物图 | 单图/封面/最小素材 |
| F-02 | 2 张横竖混合图 | 双图、裁剪、替换 |
| F-04 | 4 张不同日期图 | 2×2 拼贴、章节排序 |
| F-06 | 6 张不同日期与比例图 | 3×2 拼贴、自动分页 |
| F-20 | 20 张，3 个年份，包含近似连拍 | 自动排版、重复提醒 |
| F-100 / F-500 | 100 / 500 张，真实本地 asset | 翻页、内存、导出稳定性 |
| F-MISSING | 已入册后从系统 Photos 删除 1 张 | 占位、Replace、导出阻断 |
| F-LIMITED | 先完整授权后收窄到仅一部分图 | 权限撤销、访问管理、导出检查 |
| F-SAFE | selected + sensitive + hidden + neverUse + excluded 的混合集 | 选择器、预览、PDF 防泄露 |

### 3.3 共通前置与证据要求

1. 每个 UI 用例记录 Build SHA、设备型号、iOS 版本、纸张、模板和 fixture。
2. 每个 PDF 对比用例保留：编辑器截图、阅读预览截图、原 PDF、PDF 栅格化 PNG、比对热图及差异统计。
3. PDF 对比必须以相同页面尺寸和 1× 基准栅格化，按 PRD 7.3 判定：元素位置 ≤ 长边 0.5%，图片焦点 ≤ 容器短边 1%，文字换行/可见内容完全一致。
4. 使用测试专用 `AssetImageProvider` / PDF 输出目录；不得以 simulator demo 的空 `localIdentifier` 截图替代真机资产证据。

## 4. 可执行验收矩阵

状态定义：`待实现` 表示当前代码未提供完成测试所需入口；这不是跳过理由，而是研发完成后必须转为 `通过/失败` 的测试项。

### 4.1 E01–E03：入口、主画布、页面管理

| ID | 优先级 | 操作 | 预期结果 | 自动化 / 证据 | 当前 |
| --- | --- | --- | --- | --- | --- |
| ED-001 | P0 | 从时间线点 Edit album，首次使用 F-06。 | 创建并保存初稿；含固定页、章节开场与照片页；无空付费相册。 | UI + repository 单测 | 待实现 |
| ED-002 | P0 | 已编辑封面后退出、杀进程、重进 Continue editing。 | 加载同一 document id、页序和元素参数，不重建初稿。 | 真机录屏 + 持久化单测 | 待实现 |
| ED-003 | P0 | 无可入册照片进入入口。 | 显示 Choose photos to begin，跳确认页；无 document/PDF 产生。 | UI | 待实现 |
| ED-004 | P0 | 在画布点图片、文本、空白。 | 仅可编辑元素被选中；陶土描边/控制点；空白取消；模板/水印/页码不可选。 | UI + accessibility | 待实现 |
| ED-005 | P0 | 打开 Pages，查看 20+ 页、点击缩略图、长按照片页拖动。 | 缩略图低清加载；跳转正确；只允许照片页/里程碑页在合法范围重排。 | UI + 性能录屏 | 待实现 |
| ED-006 | P0 | 尝试移动封面、目录、结尾、章节开场到非法位置。 | 禁止且有简洁说明；文档不变。 | 单测 + UI | 待实现 |
| ED-007 | P0 | 新增照片页/注记页，复制照片页，删除照片页并确认/取消。 | 章节归属正确；复制后元素独立；取消无改动；删除不删资产或章节。 | 单测 + UI | 待实现 |
| ED-008 | P1 | 在小屏打开全部 Pages。 | 页面管理器可滚动、无滚动抖动、当前页可见、VoiceOver 可读页码/类型。 | 真机 UI | 待实现 |

### 4.2 E04：图片编辑

| ID | 优先级 | 操作 | 预期结果 | 自动化 / 证据 | 当前 |
| --- | --- | --- | --- | --- | --- |
| IMG-001 | P0 | 选择添加图片，检查列表包含 F-SAFE。 | 仅 `selected && normal && !hidden` 资产可选；敏感/neverUse/hidden/excluded 不出现。 | 单测 + UI | 部分模型，UI待实现 |
| IMG-002 | P0 | Add、Replace、Remove 各一次。 | Add 使用空槽或新页；Replace 保持 frame/rotation/zIndex 并重置裁剪；Remove 只移除页面元素。 | 单测 + UI | 待实现 |
| IMG-003 | P0 | 单指拖动到四边、中心线及另一个元素边缘。 | 保持安全区内；边缘/中心/相邻元素吸附与辅助线；结束后仅生成一次 history 事务。 | 手势 UI + history 单测 | 待实现 |
| IMG-004 | P0 | 双指缩放至低于/高于限制。 | 框最小为短边 12%，最大不超安全区；图片填满框且不露白。 | UI + geometry 单测 | 待实现 |
| IMG-005 | P0 | Crop 模式拖动图片、缩放、Cancel、Done。 | 框不动；Cancel 完全恢复；Done 保存 crop；任何状态无空白边。 | UI + PDF 比对 | 待实现 |
| IMG-006 | P0 | 旋转到 -16°、+16°，长按复位。 | 限制在 -15°…15°，1° 步进或控制柄；复位可撤销。 | 单测 + UI | 待实现 |
| IMG-007 | P0 | 两个元素重叠后 Bring forward/Send backward。 | 预览与 PDF 均按 zIndex 显示；背景永远最底层。 | PDF 像素比对 | 待实现 |
| IMG-008 | P0 | Reset photo 后确认，再 undo。 | 恢复模板默认 frame/crop/rotation/layer；undo 还原用户编辑。 | 单测 + UI | 待实现 |
| IMG-009 | P1 | 将已用照片再加到其他页。 | 允许，明确提示 Already used on page X；自动排版不重复。 | UI | 待实现 |

### 4.3 E05–E07：文本、模板、自动排版、检查器

| ID | 优先级 | 操作 | 预期结果 | 自动化 / 证据 | 当前 |
| --- | --- | --- | --- | --- | --- |
| TXT-001 | P0 | 编辑封面名、副标题、年份；编辑章节标题/备注、照片页注记、献词/结尾。 | 仅指定字段可编辑；不回写宠物档案名；无自动宠物口吻或虚构叙事。 | 单测 + UI | 待实现 |
| TXT-002 | P0 | 输入 121 / 241 字符及超长本地化文本。 | 限制为 120/240；显示文本溢出提示；导出前阻断未解决溢出。 | 单测 + UI | 待实现 |
| TXT-003 | P0 | 在安全区移动文本、改三档字号、Fit text。 | 文字框不越安全区；小/默认/大 token 一致；预览/PDF 换行一致。 | PDF 比对 | 待实现 |
| STY-001 | P0 | 对 F-06 分别 Apply 全册 5 模板。 | 仅 style token/装饰改变；页序、元素 frame/crop、文字内容不变。 | 文档 diff + PDF 比对 | 部分预览，待实现 |
| STY-002 | P0 | Apply to this page 后 Restore page style，确认并 undo。 | 仅当前页有 override 标记；恢复/撤销正确。 | 单测 + UI | 待实现 |
| STY-003 | P0 | Cinema/Film Album 在 5 张不同亮度图片上预览与导出。 | Cinema 为本地低饱和/黑白全幅规则；Film 有可辨识胶片边框/日期区；不改源图。 | 真机截图 + PDF | 待实现 |
| LAY-001 | P0 | 当前照片页从单图→双图→拼贴，容量不足时确认。 | 前 N 保留，超出资产移至同章节新页；展示影响摘要；无资产丢失。 | 单测 + UI | 待实现 |
| LAY-002 | P0 | This page/This chapter/Entire book 自动排版，含已编辑元素。 | 先展示影响；已锁定元素不动；操作作为单一 undo 事务；中性标题。 | 单测 + UI | 待实现 |
| CHK-001 | P0 | 制造空框、溢出文本、缺失资产、低清、重复、禁用资产泄露。 | Check book 分类展示；缺图/溢出/无照片阻断导出；其余仅提醒且不自行删除。 | 单测 + UI | 待实现 |

### 4.4 保存、撤销/重做与迁移

| ID | 优先级 | 操作 | 预期结果 | 自动化 / 证据 | 当前 |
| --- | --- | --- | --- | --- | --- |
| SAV-001 | P0 | 连续执行 50 次拖动/裁剪/文本/页操作，再 Undo 到起点、Redo 到终点。 | 每次结束手势仅一条记录；50 个事务可逆；文档完全一致。 | history 单测 | 待实现 |
| SAV-002 | P0 | 拖动结束后 1 秒内杀进程并重开。 | 恢复最近提交 frame；不要求恢复未结束手势。 | 真机录屏 + repository 单测 | 待实现 |
| SAV-003 | P0 | 裁剪中或文本输入中点返回。 | 显示 Keep editing / Save and leave / Discard this edit；选择行为符合文案。 | UI | 待实现 |
| SAV-004 | P0 | 切模板、页面重排、自动排版后重进。 | 事务与选择结果持久化；没有 `memoryBook=nil` 重建。 | repository 单测 + UI | 待实现 |
| SAV-005 | P0 | 解码无 `elements` 的旧草稿；解码未知新字段/损坏页。 | 旧页一次迁移为默认 elements；保留标题/顺序/封面/样式；损坏时只读恢复/迁移提示，不能静默整本丢弃。 | Codable 迁移单测 | 部分 `elements` fallback，待实现 |

### 4.5 预览、PDF 一比一与导出

| ID | 优先级 | 操作 | 预期结果 | 自动化 / 证据 | 当前 |
| --- | --- | --- | --- | --- | --- |
| RND-001 | P0 | 使用单图、双图、拼贴、注记、章节、封面各一页，逐页阅读预览并导出。 | SwiftUI 与 PDF 同 assetID、frame、crop、rotation、zIndex、文字、页序、背景。 | 栅格化 diff | 待实现 |
| RND-002 | P0 | 对 A4 与 Letter、每套模板运行 RND-001。 | 每组合满足 7.3 容差；无黑页/透明页/空白页/重复页/错序。 | 10 份 PDF + 热图 | 待实现 |
| RND-003 | P0 | 未购买、F-20、页数大于 8。 | 仅 6–8 页真实样章；包含封面/目录/两个时段/照片页/结尾；每页为 `TAILOR · PREVIEW` 水印；可回编辑。 | UI + PDF/截图 | 待实现 |
| RND-004 | P0 | 已购/Debug 显式 bypass 导出 F-20。 | 全册、无水印、与当前冻结文档一致；绕过只在 Debug，Release 无 bypass。 | 配置审计 + 真机 | 待实现 |
| RND-005 | P0 | 导出开始后修改编辑器中的文字/图片。 | 本次 PDF 用开始时 snapshot；后续编辑只影响下一次导出。 | 单测 + 两份 PDF 比对 | 待实现 |
| RND-006 | P0 | 渲染中取消、磁盘满/写失败、图片缺失。 | 显示页数进度；取消/失败无可分享半成品；保留草稿和最近成功 PDF；可重试/回编辑。 | 故障注入 + UI | 待实现 |
| RND-007 | P0 | 连续导出两次，不选 Replace latest。 | 两个不同文件可访问；archive 显示 latest；旧文件未被覆盖。 | 文件系统集成测试 | 待实现 |
| RND-008 | P1 | 高分辨率与低分辨率资产导出。 | 导出阶段请求高质量 asset；低质量只提示 May print softly，不伪造 DPI。 | 真机 PDF 检查 | 待实现 |

### 4.6 权限、资产、安全与离线

| ID | 优先级 | 操作 | 预期结果 | 自动化 / 证据 | 当前 |
| --- | --- | --- | --- | --- | --- |
| AST-001 | P0 | F-SAFE 的 sensitive/neverUse/hidden/excluded 进入编辑选择器、预览、PDF。 | 四类均绝不出现；现有已放入页的禁用资产变占位并被 Check book 阻断。 | 模型单测 + PDF asset manifest | 部分过滤，待实现 |
| AST-002 | P0 | 入册后删除系统 Photos 中的资产。 | 页面显示灰占位 + Replace；导出阻断，不静默漏图。 | 真机录屏 + PDF 校验 | 待实现 |
| AST-003 | P0 | 完整访问改为有限/拒绝，重开编辑器。 | 标出受影响资产，提供 Manage photo access；草稿、其他可访问页保持。 | 真机 | 待实现 |
| AST-004 | P0 | 飞行模式下编辑、预览、PDF；再尝试购买。 | 前三者全部可用；购买失败/不可用不影响草稿。 | 真机录屏 | 待实现 |
| AST-005 | P0 | 删除档案并确认，检查本地 document/cache/PDF/video；检查 Photos。 | 删除本地页模型、缩略缓存、导出文件与索引；原图不变；购买权益不变。 | repository/filesystem/真机 | 部分 archive，待实现 |
| AST-006 | P1 | 后台/前台、低内存警告、100/500 资产翻页。 | 页面不抖动/崩溃；未提交编辑按事务恢复；不全量加载原图到主线程。 | Instruments + 录屏 | 待实现 |

### 4.7 付费边界

| ID | 优先级 | 操作 | 预期结果 | 自动化 / 证据 | 当前 |
| --- | --- | --- | --- | --- | --- |
| PAY-001 | P0 | 未购用户完成全部编辑、保存、阅读。 | 不限创作；只能获得水印样章；完整无水印导出触发 purchase.required。 | UI | 部分 preview，待实现 |
| PAY-002 | P0 | 点击完整导出后取消购买。 | 返回同一阅读页和页码，草稿/选择/模板不变。 | StoreKit config UI | 待实现 |
| PAY-003 | P0 | purchase pending、失败、网络不可用、重复点击。 | loading、禁重复、正确中性提示与 retry/restore；不丢草稿。 | StoreKit config + UI | 待实现 |
| PAY-004 | P0 | 成功购买、重启、Restore purchase。 | 解锁完整无水印导出；既有编辑器仍可编辑；恢复可用。 | Sandbox/StoreKit config | 部分 service，待实现 |
| PAY-005 | P0 | Release 配置静态审计与真机启动。 | 不包含 `isPurchaseBypassed`、`-uiBypassPurchase` 或默认 Debug 解锁路径。 | CI grep + Archive build | 待实现 |

## 5. 自动化测试拆分

### 5.1 必须新增的单元/集成测试

| 测试组 | 最低断言 |
| --- | --- |
| `MemoryBookDocumentPersistenceTests` | Codable schema、旧页迁移、损坏稿只读恢复、所有 element 字段 round-trip。 |
| `EditorHistoryTests` | 50 步 undo/redo、手势合并、原子事务、退出后草稿存在但 history 不要求持久化。 |
| `PageMutationTests` | 新增/复制/删除/重排不破坏固定页；图片替换/删除/布局迁移资产完整。 |
| `EligibilityAndAssetTests` | `selected/normal/hidden/neverUse/excluded/missing/limited` 的统一选择器、预览与 exporter 过滤。 |
| `PageStyleTests` | 5 模板 token、全册/单页覆写、Restore、Cinema/Film 的渲染指令。 |
| `ExportSnapshotTests` | 开始导出后 document 修改不影响已冻结输出；取消/失败不生成可分享文件；多版本文件。 |
| `PDFRenderContractTests` | element frame/crop/rotation/zIndex/text 坐标映射到 A4/Letter，显式背景、页码、水印。 |

### 5.2 必须新增的 UI 测试

| 测试组 | 最低断言 |
| --- | --- |
| `EditorEntryAndPagesUITests` | E01/E02/E03 的入口、页码、选择态、页面限制、确认弹窗。 |
| `ImageAndTextEditorUITests` | 添加/替换/删除/裁剪/旋转/层级/文本长度与溢出。 |
| `EditorRecoveryUITests` | 自动保存、返回三选项、重启恢复、权限缺失提示。 |
| `PreviewExportUITests` | 6–8 页水印样章、购买取消回原页、导出准备/进度/取消/完成。 |
| `PurchaseBoundaryUITests` | pending/cancel/fail/restore/Release 无 bypass。 |

UI 测试必须提供稳定 accessibility identifier（例如 `editor.canvas`、`editor.page.4`、`element.<UUID>`、`tool.photo.crop`、`check.issue.missingAsset`），不得依赖容易本地化变化的展示文案作为唯一定位方式。

## 6. PDF 像素一致性执行方法

1. 构造固定 `MemoryBookDocument`，其页面包含非整数 frame、裁剪偏移、±15° 旋转、重叠层级和长/短文本。
2. 在同一 iPhone 规格截取阅读预览的页面内容区域；记录页面内实际矩形。
3. 导出 A4/Letter PDF，使用 Poppler 或等价工具按与预览相同逻辑比例栅格化。
4. 归一化页面边缘后生成 alpha/颜色 diff 热图，同时抽取 element 边界与文本行盒。
5. 按 PRD 7.3 阈值判定；任何黑页、透明页、空页、缺图、文字不同、页序不同为 0 容忍失败。
6. 产物保留在 `artifacts/editor-render/<build>/<fixture>/<style>/<paper>/`，并在 PR 描述中链接。

## 7. 性能与稳定性门禁

PRD 尚未冻结具体阈值；在阈值由技术评审签字前，不得以“性能已通过”宣称完成。最低需产出以下测量并由产品/研发确认阈值：

| 场景 | 数据量 | 测量 |
| --- | --- | --- |
| 打开编辑器 | 20 / 100 / 500 可入册资产 | 首屏可交互时间、峰值内存、主线程卡顿 |
| 缩略图浏览 | 100 / 500 页或等价资产 | FPS、缓存命中、内存 |
| 自动排版 | 20 / 100 / 500 | 耗时、是否阻塞手势、事务恢复 |
| PDF 导出 | 20 / 100 / 500，A4/Letter | 总时长、峰值内存、页数进度、失败恢复 |

## 8. 发布门禁与责任人

| Gate | 通过条件 | 责任 |
| --- | --- | --- |
| G-EDITOR-01 页面模型 | GAP-02、GAP-06、SAV-001…005 通过，迁移有自动化证据。 | iOS + QA |
| G-EDITOR-02 编辑能力 | ED/IMG/TXT/LAY P0 全通过，设计逐页核对。 | iOS + 设计 + QA |
| G-EDITOR-03 同源渲染 | RND-001…008 通过，5 模板×2 纸张逐页热图归档。 | iOS + QA |
| G-EDITOR-04 资产与隐私 | AST-001…005 真机通过，无禁用资产泄露。 | iOS + QA |
| G-EDITOR-05 付费 | PAY-001…005 通过；Release Archive 无绕过。 | iOS + QA |
| G-EDITOR-06 性能 | 20/100/500 测量、阈值和失败恢复证据经签字。 | iOS + 产品 + QA |

### 8.1 当前阻断发布的最小清单

1. **GAP-02：页面文档未持久化。** 用户编辑无法跨会话存在。
2. **GAP-01 / 03 / 04 / 05 / 06：正式编辑器与核心操作未实现。** 当前只有预览中两种手势，不能满足产品承诺。
3. **GAP-08：PDF 未读取编辑元素。** 预览与 PDF 不可能一比一，属于直接付费阻断。
4. **GAP-10 / 11：水印样章、冻结导出、进度取消、多版本文件均未落实。** 付费交付边界不成立。
5. **GAP-12 / AST-002：缺失/撤权资产会被静默跳过。** 会生成缺图成品，必须阻断。
6. **GAP-14 / PAY-005：StoreKit 状态不完整且 Debug 默认绕过购买。** 上线配置和用户状态均存在风险。

## 9. 本轮审计与现有测试的边界

已有 `TailorTests` 的 Builder/eligibility/PDF header 测试，以及 `TailorUITests` 的 demo preview/购买/导出页面测试可保留为回归基础；但它们不证明编辑器实现，也不证明真机 PhotoKit、页面持久化或 PDF 视觉一致性。所有上述 P0 用例必须在正式实现合入后补齐，并以真实本地 asset 的真机证据关闭。
