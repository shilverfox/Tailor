# Tailor v1.1 · 安全选片与真实样章设计变更

状态：开发、原型和测试的补充设计基线。本文只补充 2026-07-15 版 PRD 的新增/收紧项；若与旧版设计描述冲突，以本文和 `Tailor_v1_PRD.md` 为准。

## 1. 设计原则与全局退出规则

- Tailor 由用户显式打开、显式继续。不得以扫描完成、照片库变化、离开年份周年或后台回前台为由自动弹出旧照片、推送或提醒。
- 确认、时间线、章节编辑、样章预览四页的左上角均为 `Back to archive`（SF Symbol `chevron.left`，最小 48×48 pt）。返回只保存当前已落盘编辑；有未保存的章节修改时显示 `Keep editing / Save and return / Discard changes`，不出现未完成催促语。
- 无论是敏感、隐藏还是永不使用，系统照片均不被修改、移动、隐藏或删除；界面必须写清其影响范围仅为“this archive”。
- 所有状态均以文本 + 图标表达，不能只依赖陶土橙、灰度或眼睛图标。

## 2. 06 — 照片确认：敏感待确认与永不使用

### 信息架构

确认页的筛选顺序固定为：`High`、`Needs review`、`Sensitive`、`Excluded`。数字是各状态当前数量；`Sensitive` 使用 `hand.raised` 图标，`Excluded` 使用 `minus.circle` 图标。四个标签超过一行时使用横向滚动标签栏，不能缩小到不可读。

| 状态 | 默认是否已选 | 网格标识与动作 | 进入后续时间线/PDF |
| --- | --- | --- | --- |
| High | 是 | `checkmark.circle`，可取消选择/排除/标为敏感 | 仅保持 selected 时进入 |
| Needs review | 否 | `questionmark.circle`，可确认/排除/标为敏感 | 用户确认后才进入 |
| Sensitive | 否 | `hand.raised` + “Sensitive — decide when ready” | 绝不进入，直至用户明确 `Use in this archive` |
| Excluded | 否 | `minus.circle`，可恢复为 Needs review | 不进入 |
| Never use | 否 | 不在常规网格显示；在 Sensitive 页的 `Never use (n)` 折叠区管理 | 永不进入当前档案的章节、封面、样章或 PDF |

### 待确认照片：可发现性和进入时间线门槛（P0）

`Needs review` 不是一个可忽略的统计标签，而是确认页的主要人工决策任务。不得把“选入档案”只放在长按、滑动或隐藏菜单中。

1. 四个分组标签始终可见，并同时显示文字、图标和数量：`High · n`（`checkmark.circle`）、`Needs review · n`（`questionmark.circle`）、`Sensitive · n`（`hand.raised`）、`Excluded · n`（`minus.circle`）。选中标签有 2 pt Ink 下划线和 `Selected` 的 VoiceOver 状态；不可只用颜色区分。
2. `Needs review` 为空以外的任何状态下，页首都显示一张可点击的进度卡：`n photos still need your confirmation`，主操作 `Review photos`。用户在 High 页不会错过待确认入口。
3. 在 Needs review 网格中，点按任一照片（不需要长按）打开原图查看器。查看器底部固定三枚可见按钮：`This is [name]`（主按钮）、`Not [name]`（次按钮）、`Set aside as sensitive`（文字按钮）。每个按钮最小 48 pt；完成任一决定后显示可撤销 toast 并前进到下一张待确认照片。
4. `Create timeline` 前若仍有待确认照片，必须弹出拦截 sheet，而不是静默只用已选照片：
   - 标题：`[selected] photos are ready. [pending] still need your confirmation.`
   - 正文：`Only confirmed photos will be added to your timeline. You can review the rest now or continue with the photos already chosen.`
   - 操作顺序：主按钮 `Review [pending] photos`；次按钮 `Create timeline with [selected] photos`；`Cancel`。
   - 当 selected 为 0 时，禁用“Create timeline with 0 photos”，主按钮保持 `Review photos`。这不是强制用户处理全部候选，而是让“跳过”成为清楚、可逆的知情选择。

原图查看器的日期、状态和三个决定动作都必须在首屏可见；长按和左右滑只能作为快捷方式，不得是唯一入口。

### 待确认的快速批量选入

- 待确认网格顶部提供可见 `Select`。进入后照片点按只切换勾选状态，不打开逐张 action sheet；每张已勾选照片都有文字/勾选标记，不能只用边框颜色。
- 批量工具栏包含 `Select all shown`、`Add N to archive` 与 `Done`。`Add N` 在 N=0 时禁用；仅用户勾选的当前筛选结果可被一次性设为 selected，绝不因扫描完成自动选入。
- 用户需要排除或查看细节时退出选择模式后点图，使用既有 `Not [name]`。批量模式不取消单图排除路径。
- 候选扫描的视觉说明不得将通用动物检测说成身份识别；弱参考照相似度、非目标物种和纯人像不应进入此网格。宁可漏检并提供手动补充，也不得把猴子、小熊猫或小朋友呈现为“可能是 [name]”。

### 敏感页布局和交互

1. 在年筛选下方显示 16 pt 内边距的保护卡：标题 `Some photos are set aside.`，正文 `They will not be added unless you choose to use them.`，辅助链接 `Why am I seeing this?` 仅说明“Tailor may set aside difficult or low-quality images. It does not diagnose what happened in a photo.”
2. 敏感照片网格使用本地 `PHAsset` 缩略图；未打开前不应全屏自动放大。每张卡片有 12 pt 圆角、`hand.raised` 徽章和日期，不能使用“临终/病重/遗体”等诊断性标签。
3. 点开原图后使用底部 action sheet：
   - `Use in this archive`（先显示一次明确确认：`This photo can appear in your timeline and PDF.`）
   - `Decide later`（默认状态，无二次确认）
   - `Never use in this archive`（破坏性样式；二次确认文案：`It will be removed from chapters, covers, previews, and future PDFs. Your original photo stays in Photos.`）
   - `Back to archive`
4. 选择 `Never use` 后立即从当前所有章节和封面移除；若影响封面，使用下一张合格照片并显示非阻塞提示 `Cover updated. The original photo is unchanged.`。若其为章节唯一照片，章节转为空章节，显示 `Add photos` 和 `Delete chapter`。
5. `Never use (n)` 为可展开的管理区，默认折叠。每行仅显示日期、模糊化 40% 缩略图和 `Allow in this archive`；恢复后进入 `Needs review`，不会自动选中。

### 高/待确认的原图查看器

点按照片打开查看器；底部动作固定为 `This is [name]`、`Not [name]`、`Set aside as sensitive`。左/右滑仅为快捷操作，必须提供以上按钮和可撤销 toast。批量操作仅允许 `Exclude`、`Add to archive`、`Set aside`; 批量 `Never use` 必须二次确认并展示数量。

## 3. 07 — 生命时间线：时期隐藏

### 卡片与筛选

- 章节菜单增加 `Hide from album`（`eye.slash`）。确认 sheet：标题 `Hide this period?`；正文 `Its photos and cover will stay in this archive, but will not appear in your preview or PDF until you restore it.`；操作 `Hide period` / `Cancel`。
- 已隐藏章节移入时间线底部 `Hidden periods (n)` 折叠区，不能只显示一个眼睛图标。折叠标题须朗读数量，且默认不展示任何代表图，以避免无意触发回忆。
- 展开后每张隐藏卡只显示日期范围、标题、照片数量、`Hidden from album` 状态和 `Restore to album`。用户点击恢复后才加载封面缩略图；恢复不会自动打开或轮播照片。
- 在可见章节中，标题、照片数和封面都只来源于 `selected`、非敏感、非永不使用、非隐藏时期的照片。章节被隐藏后，预览页的页数/目录实时重算。

### 按年份或日期范围隐藏

时间线顶端 `Edit periods` 进入范围选择 sheet：

- 选项 `A year` / `Custom dates`，默认不预填敏感年份。
- 年份行有计数和 `Hide year`；日期范围使用开始/结束日期、校验开始不晚于结束。
- 提交前显示影响摘要：`This will hide 14 selected photos from 2020.`，不得展示缩略图预览。
- 范围与已有章节交叠时，不拆分或虚构章节；直接将范围内符合条件的照片排除在预览/PDF 外，并在相应章节显示 `Some photos hidden` 的文字状态。

## 4. 09 — 样式与真实 6–8 页水印样章

### 样章的固定内容策略

未解锁时，预览根据用户**当前**已选、非敏感、非永不使用、非隐藏时期的真实照片生成 6–8 页。模板、封面、章节标题、用户说明和纸张尺寸更改后重新渲染；水印不可通过 UI 隐藏。

| 页序 | 页面 | 内容来源 | 最低/降级规则 |
| --- | --- | --- | --- |
| 1 | Cover | 宠物名、用户所选封面或第一张合格照片 | 无照片时为纸张+标题，说明 `Add selected photos to build a preview.` |
| 2 | Contents | 可见章节的日期、标题和页码 | 一章时仍显示一个目录条目 |
| 3 | Chapter opener A | 最早可见时期的真实封面、日期、标题、用户 note | 无可见章节时用说明页，不能编造 |
| 4 | Photo selection A | 同一章节 1–4 张真实照片 | 不足时留白并写 `More photos can be added in Edit timeline.` |
| 5 | Chapter opener B | 与 A 不同的可见时期；优先时间跨度最远者 | 没有第二时期则显示 `One period is ready so far.` 说明页 |
| 6 | Photo selection B | 第二时期的 1–4 张真实照片 | 同上 |
| 7 | Optional note / selection | 若素材允许，来自用户 note 或另一时期真实照片 | 素材不足时不强制生成 |
| 8 | Closing page | 用户宠物名 + 中性文案 `Made from the photos you chose.` | 始终生成 |

最多 8 页；当第 7 页缺少真实素材时为 7 页，仍以结尾页收束。首 6 页为最低目标；如所有照片不足，至少显示封面、目录、说明、结尾四页，并明确这不是完整样章。不得为了凑页数复制同一照片或生成虚构素材。

### 预览 UI

- 三个 96×78 pt 样式按钮保留：Warm Paper、Quiet Night、Field Notes。选中态为 2 pt Ink 边框 + `checkmark.circle.fill`，纹理仅用于材质预览。
- 中央使用 5:7 纸张比例的水平分页预览。提供可见按钮 `Previous page` / `Next page`、`Page 3 of 7` 文本和 swipe；不可仅依赖 swipe。
- 每一页以 18–24% Ink 不透明度、斜向重复 `TAILOR · PREVIEW` 水印覆盖实际页面内容。水印仍保证正文与照片可判断，不可用“模糊图”冒充水印。
- 目录和样章每页均显示真实日期/用户标题，不显示在可见时间线之外的章节；隐藏、敏感和永不使用照片的 `localIdentifier` 不得传入预览渲染器。
- 预览加载中显示纸张 skeleton 和 `Preparing your preview…`；失败卡为 `We couldn’t prepare this preview.` + `Try again` / `Return to timeline`，不清空选择或样式。
- 未购买的底部卡文案改为：`Every page in this preview is watermarked.` / `It is built from the photos currently included in your album.` CTA 为 `Unlock complete album · $19.99`。购买后同样内容重新渲染完整无水印 PDF，而非隐藏一个视觉覆盖层。

## 5. 资源与实现边界

### 新增资源清单

| 分类 | 名称 | 是否需导出位图 | 规格/来源 |
| --- | --- | --- | --- |
| 系统图标 | `hand.raised`, `eye.slash`, `eye`, `checkmark.circle`, `minus.circle`, `arrow.uturn.backward` | 否 | SF Symbols，随 Dynamic Type 和高对比度适配 |
| 照片缩略图 | `archive-photo-{localIdentifier}` | 否 | 每次从用户授权 `PHAsset` 动态请求；绝不进入 Assets.xcassets |
| 水印 | `TAILOR · PREVIEW` | 否 | PDF/SwiftUI 原生文字绘制，重复斜排；不可做可删除图片层 |
| 样章模板 | `warm-paper`, `quiet-night`, `field-notes` | 复用已有纹理 | 仅背景材质，不含宠物、人物、文案或照片 |
| 安全状态图 | 无 | 否 | 使用上述 SF Symbols + 原生文本，避免为敏感场景绘制情绪化插图 |

因此本次没有新增“宠物图片”资源。样章、确认页、时间线和章节页必须由真实用户授权照片填充；生成一张狗/猫图片会违反“真实素材”的产品承诺。

## 6. 设计验收要点

1. 将敏感照片标为 `Never use` 后，在确认、所有章节、封面、样章和新导出的 PDF 中均不可见；系统 Photos 中原图仍存在。
2. 隐藏一个年份/日期范围后，时间线只在 `Hidden periods` 中以文本出现；预览/PDF 不含该范围内照片或封面。
3. 未购买预览在正常素材下显示 6–8 页，含封面、目录、两个不同时段章节与结尾；每页均带水印且使用真实已选照片。
4. 四个主页面均可在不触发任何提醒的情况下返回档案；退出文字不施压、不暗示错过或遗憾。
5. 390 pt、320 pt、Accessibility XXL、Increase Contrast 与 VoiceOver 下，状态、页码、恢复/永不使用等关键控制均可到达和辨识。
6. 有待确认照片时，用户从 High、Sensitive 或 Excluded 分组都能在首屏找到 `Review photos`；点击任何 Needs review 照片后，无需长按即可看到 `This is [name]` / `Not [name]` / `Set aside as sensitive`。
7. 点击 `Create timeline` 且仍有待确认照片时，必须先显示数量明确的拦截 sheet；用户能选择继续确认、带已确认照片继续，或取消，且不会无提示丢弃待确认素材。
