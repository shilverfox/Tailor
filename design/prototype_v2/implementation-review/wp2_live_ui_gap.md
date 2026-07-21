# Tailor v2.2｜WP-2 Live UI 设计实现差距

> 核对基线：`v22_acceptance_matrix.md`、`v22_adjudication_state_specs.md`、`v22_adjudication_states.html` 与冻结 `Tailor_v2_PRD.md`。  
> 核对范围：当前 SwiftUI 的 03–09 / 20，并追踪 12 个 v2.2 状态的实际承载面。  
> 核对方式：只读代码；未修改业务代码。代码仍在并行落盘时，以本文“最终复核”小节记录的文件状态为准。  
> 判定：`MATCH` = 当前代码已表达冻结状态；`PARTIAL` = 有入口/数据但视觉或交互合同不完整；`MISSING` = 当前 UI 没有该状态或行为相反。

## 1. 结论摘要

当前 WP-2 已从“只有模型”推进到可识别的页面骨架：Manual Import、八类 checkpoint label、StoryPlanDraft 流程、09 纸型选择和原子建册 loading 均已进入 SwiftUI。但按设计验收矩阵仍不能签署 UI PASS，主要不是颜色或间距问题，而是若干用户可见行为仍会破坏冻结流程。

### P0 交互 / 状态差距

1. **Manual Import 从 06 返回会落入 05 Scan**：`ReviewFeatureView.back` 使用通用 raw-value `back()`；手动路径 04→06 后返回会进入 05，违反“手动模式绝不进入全库扫描”。
2. **06 Sensitive 没有显式批准状态**：Sensitive 照片仍使用通用 confirmation dialog；`This is {name}` 会把 sensitivity 改成 normal，没有风险确认，也没有 `selected + sensitiveApprovedAt` 的同一事务。
3. **06 stale decision UI 完全缺失**：没有 stale 数量、只读旧选择、`REVIEW AGAIN`、新 generation 说明或批量/逐张复核入口。
4. **03/04/06/08/09 缺统一“稍后继续”可见入口**：数据层虽有 checkpoint，页面不能按冻结流程主动回 20；授权参考照在未满 3 张时也没有把槽位变化实时写回 Archive。
5. **06→07 的 CTA 门槛不一致**：06 的 `Create timeline` 只要求 `eligibleCount > 0`，而 `beginSmartDraft` 要求至少 3 张；1–2 张时按钮看似可用，点击后又回 06，形成无解释的假可用状态。
6. **07 的完成文案违反产物边界**：页面写着 “The draft becomes a shared MemoryBook document”，但冻结行为是 07 只生成 `StoryPlanDraft`，09 才创建 `MemoryBookDocument`。
7. **09 创建失败没有页面内反馈/重试**：repository 保存失败只写全局 `operationError`，`BookStyleFeatureView` 不接收或展示；用户看到按钮恢复但不知道失败原因。
8. **20 没有动态主 CTA**：checkpoint label 只嵌在可点击档案卡内，底部唯一大按钮仍为 `Create another archive`；这与 S09 的“一个 checkpoint、一个主 CTA”相反，并且早期 checkpoint 仍显示 `Rescan for new photos` 竞争操作。

### P1 视觉 / 可理解性差距

1. 02 denied 已把 `Import photos manually` 改为主 CTA，并会在从 Settings 返回时刷新权限；但页面仍沿用通用标题和四张授权卡，保留与 denied 无关的 `Limited access is okay`，没有 S01 的三段专属私有副本/删除承诺层级。
2. 04 Manual Import 缺“授权后按指纹映射并清理副本”的可见说明，也没有明确写出下一步全部以 Needs review/pending 进入 06。
3. 04 单项读取失败会被 store 静默跳过；页面只看到数量减少，没有指出哪些失败，也没有针对失败项的可见重选反馈。
4. 09 纸型是系统 segmented picker，已满足选择功能，但没有状态稿中的纸张形状、尺寸并列卡、默认推荐层级及“模板+纸型共同创建 revision”的解释。
5. 20 档案摘要是通用 `Saved locally · Ready to continue`，没有按 profile/reference/scan/review/draft/story/style/document 显示状态摘要。
6. 03 的 `CAME HOME` 仍是静态 `2017`，不是可编辑可选年份；这不是 12 状态新增点，但与冻结 03 页面合同不一致。

## 2. 03–09 / 20 页面逐页核对

| 页面 | 当前代码入口 | 已对齐 | 具体差距：元素 / 状态 / CTA / 返回 | 判定 |
|---|---|---|---|---|
| **03 Pet Profile** | `OnboardingFeatureViews.swift` `ProfileFeatureView`；`MilestoneRootView.completeProfile()` | 名称、species、离世年份校验；完成后写 `.references` checkpoint | **元素**：到家年份是假静态文本。**状态**：输入未完成时没有可见保存/恢复反馈。**CTA**：只有 `Choose reference photos`，缺 Save for later。**返回**：回 02 正常，但手动模式来源没有提示下一步是 Manual Import。输入过程不提交，进程终止无法恢复未提交字段。 | `PARTIAL / P0恢复，P1视觉` |
| **04 Reference Photos** | `ArchiveFeatureViews.swift` `ReferencesFeatureView` | 3–5 张、少于 3 禁用、冷启动可按 PHAsset ID 重载缩略图；完成后 `.scan` | **状态**：只有点击 Continue 才写入档案；1–2 个已选槽位只在 Root state，冷启动不保证恢复。**CTA**：缺 Save for later。**错误**：资源失效有文案但没有明确修复计数/失效槽位标识。 | `PARTIAL / P0恢复` |
| **04 Manual Import** | `ArchiveFeatureViews.swift` `ManualImportFeatureView`；`MilestoneRootView.importManualItems/removeManualAsset/completeManualImport` | 3–500；N/500；3 张前 CTA 禁用；500 时 Add 禁用；真实缩略图和删除；私有复制；保存后直接 06；导入过程中 CTA 禁用 | **元素**：缺授权后指纹映射/清理说明；缺“下一步全部 Needs review，不扫描全库”独立状态卡。**错误**：unreadable item 被静默跳过，无法看到失败项；批次硬错误只有通用字符串。**返回**：04→03 正常；但进入 06 后返回错误地到 05。**恢复**：已导入项持久化，但页面没有显式 Continue later。 | `PARTIAL / P0返回，P1反馈` |
| **05 On-device Scan** | `ArchiveFeatureViews.swift` `ScanFeatureView`；`MilestoneRootView.startScan/completeScanReview` | 扫描/暂停/恢复/失败/thermal/low power；进度与 checkpoint；完成后写 `.review`；恢复不自动启动 | **CTA**：失败态额外允许 `Review matches so far`，需由 QA 确认不会用不足素材绕过后续 3 张门槛。**返回**：授权扫描回 04 正常；manual 不应能进入本页，但当前 06 Back 会把 manual 用户带到此页。 | `PARTIAL / P0由 manual 返回触发` |
| **06 Photo Review** | `ArchiveFeatureViews.swift` `ReviewFeatureView` | 四分组、年份、批量选择、逐张确认、pending gate、manual 追加、主按钮随内容滚动 | **状态**：无 stale generation；Sensitive 不记录批准时间；neverUse 虽可标记，但普通详情仍共用一套动作。**CTA**：`eligibleCount == 1/2` 仍启用 Create，下一层却拒绝；Create 文案仍是 timeline 而非 memory book（可接受旧视觉但需统一）。**返回**：manual 路径错误回 05；缺 Save for later→20。**错误**：manual 追加失败保留页面，但无失败项级反馈。 | `MISSING S03/S04；其余 PARTIAL / P0` |
| **07 Smart Draft** | `ArchiveFeatureViews.swift` `SmartDraftFeatureView`；`MilestoneRootView.beginSmartDraft` | 真实 summary、loading、失败操作位置、Continue later；保存 `StoryPlanDraft`，不创建页面 | **元素**：完成态说明错误宣称 draft 是 `MemoryBook document`。**错误**：首次持久化失败发生在进入 07 之前，错误写入 `smartDraftError` 但仍留 06，07 的失败卡无法呈现该失败。**CTA**：loading disable 正确；simple fallback 有入口。 | `PARTIAL / P0语义与错误可见性` |
| **08 Story Plan** | `ArchiveFeatureViews.swift` `TimelineFeatureView/ChapterEditorFeatureView`；`MilestoneRootView.confirmStoryPlan` | 编辑 StoryPlanDraft；章节标题/说明/代表图；相邻合并、明确拆分点、排序、隐藏；影响摘要；确认后 `.stylePending` | **CTA**：只有 `Choose book style`，缺 Save for later→20。**状态**：没有明确的“StoryPlanDraft 待确认/已保存”持久状态提示。**返回**：回 07；章节编辑回 08正常。 | `PARTIAL / P0恢复入口` |
| **09 Book Style** | `ArchiveFeatureViews.swift` `BookStyleFeatureView`；`MilestoneRootView.applySelectedBookStyle` | 五模板；Letter 默认/A4；创建中 CTA 禁用；09 首次按 draft+style+paper 建唯一文档；成功 `.documentReady`→10 | **元素**：纸型视觉层级比 S05 弱；缺共同创建 revision 说明。**CTA**：缺 Save for later；没有显式无效输入态（当前依赖入口 guard）。**错误**：创建失败不传入页面，无错误卡/Retry；选择可保留但用户无法判断事务失败。**返回**：回 08正确。 | `PARTIAL / P0失败与恢复，P1视觉` |
| **20 Archive** | `AlbumFeatureViews.swift` `ArchivesFeatureView`；`MilestoneRootView.resumeArchive` | 持久 checkpoint→唯一 route 映射；卡片显示动态 actionLabel；点击卡片可恢复；最近 PDF、删除二次确认 | **元素**：缺阶段摘要和 active checkpoint 视觉；档案卡可点击但不像明确主 CTA。**CTA**：底部主 CTA 错为 `Create another archive`；`Rescan for new photos` 对所有 checkpoint 恒显，形成竞争操作。**返回/恢复**：route 映射已存在，fallback 在模型层；但 UI 无法证明 profile/references 等恢复了哪些字段。 | `PARTIAL / P0 CTA` |

## 3. 12 个 v2.2 状态逐项映射

| 状态 | 当前承载代码 | 当前可见实现 | 与状态稿差距 | 判定 |
|---|---|---|---|---|
| **S01 / 02 denied** | `PrivacyFeatureView` + `enterProfile(manual:)` | denied 卡、Open Settings、Manual Import 主 CTA、Settings 回前台权限刷新与 02→03→04 路由均存在 | 仍显示通用标题和四张授权卡；`Limited access is okay` 在 denied 状态无关；缺 “library stays closed / private copy / delete with archive” 的专属信息层级。 | `PARTIAL / P1视觉` |
| **S02 / 04 Manual Import** | `ManualImportFeatureView` + `ManualAssetStore` | 数量边界、缩略图、删除、私有复制、CTA 门槛、直达 06 已有 | 缺 mapping 清理与 pending-next 信息；读取失败无逐项反馈；06 Back 错入 05。 | `PARTIAL / P0` |
| **S03 / 06 Sensitive approval** | `ReviewFeatureView` | Sensitive tab 与说明卡存在 | 无风险详情 sheet、显式确认、Pending→Approved 状态；Include 会清除 sensitivity，未写 `sensitiveApprovedAt`。 | `MISSING / P0` |
| **S04 / 06 stale choices** | 无独立 UI；模型已有 stale 字段 | 无 | 缺变化原因、generation、数量、只读旧选择、Review Again、逐张/批量复核及恢复。 | `MISSING / P0` |
| **S05 / 09 template + paper** | `BookStyleFeatureView` | 五模板、Letter/A4、Letter 默认、创建中 disable | 缺 paper card 视觉、revision 说明、失败态和 Save later。 | `PARTIAL / P0错误，P1视觉` |
| **S06 / 17 paper recheck** | 不属 WP-2 UI；现有 Preview 直接绑定 paper change | 本轮未发现 S06 专属 running screen | 需要 WP-4；不能计入 WP-2 完成。当前 19/10 的 pageSize onChange 仍可能直接改 book，不能以 S05 代替 S06。 | `MISSING / 后续 WP-4` |
| **S07 / 17 stable fallback** | 模型有 ReturnContextStack 类型；Root 仍主要使用 `editorReturnRoute` | 无 S07 完成态 | 新 revision 自动复检、stable locator/fallback 与“不闪旧结果”未形成该 UI。 | `MISSING / 后续 WP-4` |
| **S08 / 18 passed-only purchase** | `PurchaseFeatureView`/Root 基础路由 | Book Check→Purchase 顺序与动态价格基础存在 | 是否绑定 persisted pass context、取消/失败回同一 17、纸型/revision proof 仍不在该状态稿层级；不能计入 WP-2。 | `PARTIAL / 后续 WP-4` |
| **S09 / 20 eight checkpoints** | `ArchiveCheckpoint` + `ArchivesFeatureView` | 八类 actionLabel 与 resume route 已进入模型和档案卡 | 动态动作不是底部主 CTA；无阶段摘要；Create another archive 和全局 Rescan 抢占主操作。 | `PARTIAL / P0` |
| **S10 / 11→16→11 stack** | 模型已有 stack；Root 仍保留 `editorReturnRoute` | 无来源条/临时 Style 帧反馈 | 16 Apply/Cancel 先回 11、底层 10/17/19 上下文保留尚不可由当前 UI 验收。 | `MISSING / 后续 WP-4` |
| **S11 / automatic recheck** | 无专属中间态 | 无 | 缺新 revision 进度、return target、blocking/pass 自动分流及禁止旧预览。 | `MISSING / 后续 WP-4` |
| **S12 / single-period six-page sample** | `PreviewFeatureView` 与 SamplePlan/Builder | 本轮 WP-2 没有新增专属可见状态证据 | 需固定 fixture 验证 6 页真实结构、单章节、不重复、不虚构；不能由“预览能打开”替代。 | `NOT VERIFIED / 后续 WP-5` |

## 4. 建议研发按现有冻结范围修复的最小顺序

这不是新需求，只是按已冻结依赖排序：

1. 先修 manual 06 Back，保证 02→03→04→06 全程不触达 05。
2. 统一 03–09 的 `Continue later` 与 checkpoint 提交；Reference 选择变化实时保存。
3. 让 20 的动态 resume label 成为唯一底部主 CTA；早期 checkpoint 隐藏无意义 Rescan。
4. 统一 06 与 07 的三张门槛；修正 07 的 StoryPlanDraft 文案和 persistence failure 可见状态。
5. 给 09 传入创建错误与 Retry/Save later；保留模板和纸型选择。
6. S03/S04 由后续识别/eligibility 工作包实现，但 UI 必须按既有 S03/S04 状态稿落地，不得继续复用通用 confirmation dialog。

## 5. 最终复核记录

- 初次只读核对：2026-07-21，已观察到 WP-2 并行落盘中的 Manual Import 缩略图/删除、纸型 binding、创建中 disabled 与动态 checkpoint label。
- 最终代码复核：2026-07-21 08:00（Asia/Shanghai）。已复核 `MilestoneRootView.swift`、`ArchiveFeatureViews.swift`、`OnboardingFeatureViews.swift` 和 `AlbumFeatureViews.swift` 的整包落盘版本；S01 主 CTA、S02 缩略图/删除/500 上限、S05 创建中禁用均按最终代码更新了本文判定。
- 运行截图：本报告未宣称任何状态已获得真机/Simulator 截图；截图证据仍按 `v22_acceptance_matrix.md` 命名补齐。
- 代码改动：无。本文件仅为设计实现核对记录。
