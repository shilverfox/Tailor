# Tailor v2.2 代码差距审计

> 审计基线：`Tailor-v2.2-docfreeze-2026-07-21`  
> 审计日期：2026-07-21  
> 审计方式：只读 PRD、原型合同、现有业务代码与测试；本轮未修改业务代码。

## 1. 门禁结论

### 1.1 PRD 与原型是否已经确认清楚

**通过。** 以下六份权威输入对主流程、页面职责、状态恢复、付费边界和新增 v2.2 裁决的描述一致，未发现 P0 产品冲突：

1. `Tailor_v2_PRD.md`
2. `flow_and_screen_contract.md`
3. `state_matrix.md`
4. `v2_pages_01_06_contract.md`
5. `v2_visual_contract_01_06_18_20.md`
6. `prd_prototype_traceability.md`

已经冻结且可直接作为研发/测试输入的关键结论是：

- 07 只生成并持久化 `StoryPlanDraft`，08 只确认/编辑它，09 才以故事规划、模板和纸型原子创建 `MemoryBookDocument`。
- 09 选择模板和纸型；纸型属于 document revision；Book Check 结果绑定 revision、纸型和规则版本。
- 03–09 均有唯一 Archive checkpoint 与动态 `resumeRoute`。
- Photos denied 进入 3–500 张 Manual Import，不进入全库扫描。
- 识别结果按 `matchGenerationID` 隔离；识别条件改变后旧人工决定变为只读 stale decision，并须复核。
- sensitive 只有 `selected + sensitiveApprovedAt` 才可入册；`neverUse` 永不可覆盖。
- 编辑器返回使用 `ReturnContextStack`，17/19 来源编辑保存后必须先自动复检。
- 购买只能经由 10→17→18→19；当前 revision 未通过检查时不能进入购买或最终预览。
- 免费样章真实、通常 8 页、最少 6 页；单时期不得虚构第二时期。
- Debug bypass 必须为 DEBUG 编译下的显式测试入口，Release/TestFlight/App Store 不可达。

现有 `08_prd_prototype_alignment_report.md` 的“无 P0 产品歧义”结论与本次复核一致。文档门禁已经通过，**不需要再次讨论产品方向；下一阶段应修代码差距，而不是继续改 PRD。**

### 1.2 当前代码是否达到冻结方案

**未达到，不能把 v2.2 视为功能完成或进入发布验收。** 十项重点裁决中：0 项完整、6 项部分实现、4 项缺失。Manual Import、识别代际、StoryPlanDraft 持久化、pre-document checkpoint 是主流程 P0 缺口。

## 2. 状态定义

| 状态 | 定义 |
| --- | --- |
| Complete | 模型、持久化、路由、界面与关键测试均符合冻结合同 |
| Partial | 已有可复用能力，但数据语义、异常路径或验收证据不完整 |
| Missing | 冻结合同的核心模型/流程不存在，或现有行为与合同相反 |

## 3. 逐项差距总表

| # | 冻结裁决 | 状态 | 主要代码位置 | 风险 | 实现任务 | 当前测试证据 / 必补证据 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `StoryPlanDraft → 09 创建文档` | **Partial** | `ArchiveModels.swift:3253-3275,3390-3415,3483-3520`；`MilestoneRootView.swift:819-873`；`SwiftDataArchiveRepository.swift:14-22,68-93` | **P0**：07 的结果不可恢复；08 实际编辑 `ArchiveDocument.chapters`；产物边界无法证明 | 新增 Codable `StoryPlanDraft`、事件组/章节候选/照片角色/去重/建议页数；持久化到 Archive；07 原子保存 plan；08 编辑 plan；09 一次事务创建 document；已有 document 返回 08 只更新语义并标 `needsReflow` | 已有：Story Plan merge/split、locked page reflow（`TailorFeatureTests:2693-2723`）。缺：07 不创建 document、草稿冷启动恢复、09 原子成功/失败回滚、已有文档不重建 |
| 2 | paper / revision / Book Check cache | **Partial** | `ArchiveModels.swift:38,1183-1215,2221-2240,2833-2939`；`MilestoneRootView.swift:26-31,987-993`；`AlbumFeatureViews.swift:3338-3429` | **P0**：纸型不在 09 选择；没有稳定 revision/check key；检查阈值与冻结值不一致，编辑后可能继续使用未复检页面 | 新增 `documentRevisionID`、revision transaction、`BookCheckResult` 与键 `(revisionID,paper,rulesVersion=1)`；09 同时选 style/paper；纸型变化新建 revision 并失效检查；PPI 改为 `<100` blocking、`100..<200` suggestion；补 rhythm、nearDuplicateGroup、主体保留率与 focal 边距冻结规则 | 已有：纸型渲染、Book Check 图片/文字/重复项测试。缺：cache key 失效、规则版本失效、冻结阈值边界 99/100/199/200、09 纸型创建事务 |
| 3 | 03–09 checkpoints / 动态 Archive 恢复 | **Missing** | `ArchiveModels.swift:7,1619-1663,3543-3575`；`MilestoneRootView.swift:488-525`；`SwiftDataArchiveRepository.swift:14-23` | **P0**：除扫描外，重启不能精确恢复；`saveDraft` 会重建轻量 ArchiveDocument，可能丢失后续字段；Archive 主按钮无法真实反映阶段 | 新增八类 `ArchiveCheckpoint` 与唯一 `resumeRoute`；每一页面成功事务写 checkpoint；Archive 动态标签；恢复数据失效时回退最早修复页；迁移旧 lifecycle/scanCheckpoint | 已有：scan checkpoint 持久化/目录变化测试（`TailorFeatureTests:254-290`）。缺：03、04、06、07、08、09 各 checkpoint round-trip 和失效 fallback；Archive 动态按钮 UI 测试 |
| 4 | denied Manual Import | **Missing** | `OnboardingFeatureViews.swift:91-102`；`ArchiveFeatureViews.swift:5-107`；`PhotoKitVisionScanner.swift:343-361` | **P0**：按钮只是把本地状态伪装成 `.limited`；仍只选 3–5 张参考照并进入扫描；真实 denied 最终触发 `insufficientAccess` | 新建 denied/manual 模式；PHPicker 3–500 最终候选；显式复制到 App 私有目录并持久化文件引用/指纹；直接进入 06 pending；06 支持继续添加；授权后指纹映射 PHAsset 并删除匹配副本；删档清理副本；不得建全库索引 | 已有 UI 测试只证明按钮到 03（`TailorOnboardingUITests:26-35`），不能证明导入闭环。缺：3/500 边界、私有副本、冷启动、映射清理、删除清理、denied 不调用 scanner |
| 5 | `matchGenerationID / species / staleDecision` | **Missing** | `PhotoKitVisionScanner.swift:352-470,585-633`；`ArchiveModels.swift:1069-1157,3586-3605` | **P0**：embedding 按 profile 文件保存且无 extractorVersion；species/参考照变化不会隔离匹配代；增量 merge 会无条件保留旧 decision，可能把另一只宠物的确认结果静默带入 | 建立与宠物无关的 `(assetID,featureExtractorVersion)` embedding store；新增 generation 元数据/结果表；生成冻结 hash；区分自动结果与人工 decision；代际变化生成 `staleDecision` 且 eligibility=false；姓名/年份变化不失效 | 已有：识别策略、扫描恢复、增量合并测试。缺：四个 hash 输入、姓名/年份不失效、species/reference/matcher 失效、embedding 复用、stale decision 禁止入册与重新确认 |
| 6 | `sensitiveApprovedAt` eligibility | **Partial** | `ArchiveModels.swift:9-16,1069-1157`；`ArchiveFeatureViews.swift:229-240,314-329,397-437`；`MilestoneRootView.swift:530-545` | **P0**：没有批准时间；当前 sensitive 永远不可入册，`Include` 会改回 normal，丢失敏感语义；无法审计风险确认 | 将 sensitivity 收敛为 normal/sensitive/neverUse；新增 `sensitiveApprovedAt`；详情 sheet 风险确认后才能 selected；实现唯一 eligibility 函数并用于 generator/candidate/preview/PDF；加入 hidden period 条件；迁移旧状态 | 已有：normal/needsReview/neverUse eligibility 与 round-trip（`TailorFeatureTests:43-86`）。缺：approved sensitive 正例、未批准反例、neverUse 不可覆盖、四层一致、迁移测试 |
| 7 | `ReturnContextStack` / 编辑后复检 | **Missing** | `MilestoneRootView.swift:9-14,564-585`；`ArchiveModels.swift:2307-2310` | **P0**：只有单一 `editorReturnRoute`，无法表达 10/17/19→11→16 嵌套；Book Check locator 缺 ruleID；从 19 编辑后可直接回 19，绕过复检 | 新增 Codable stack frame 与 push/pop 规则；保存 source、logicalPageID/index、paper、完整 issue locator；16 只弹临时帧；11 保存生成 revision 后自动检查；实现 issue/page 消失 fallback | 已有：Final Preview 返回同 logical page、Book Check 定位 UI 测试。缺：嵌套 16、17 修复后同问题/附近问题 fallback、19 编辑 blocking→17/pass→19、冷启动 stack 恢复 |
| 8 | `10→17→18→19` 门禁 | **Partial** | `MilestoneRootView.swift:28-31,572-585,887-927,987-993`；`AlbumFeatureViews.swift:3418-3420` | **P0**：正常 10→17 与 pass 分支存在，但购买取消/失败停留 18 而非返回同一 17 pass；19 编辑返回不复检；19 切纸型不复检 | 把 gate 建模为“已检查的当前 revision”；18 仅接收 pass token/context；取消/失败/offline 回 17 同一通过态；购买成功→19；19 任一编辑/纸型变化创建 revision 并先回 17 | 已有：购买状态保持、价格重试、Book Check blocker UI。缺：10 不可直达 18 的路由测试、18 各失败返回 17、旧 pass 对新 revision 无效、19 编辑/纸型复检 |
| 9 | 样章单时期 fallback | **Partial** | `AlbumFeatureViews.swift:3731-3753`；`TailorFeatureTests.swift:2738-2747`；`TailorOnboardingUITests.swift:401-419` | **P1**：选择是真实页且保持 6–8 页，但大书常只得到 7 页；测试只断言范围，未验证“通常 8”；无单时期不虚构的专门证据 | 提取 SamplePlan；目标 `min(8,total)`；固定 cover/contents/真实 opener/真实 photo/closing；两时期优先两章节；单时期用真实 dedication/note 补到 6；不足 8 的整书全部展示且不复制 | 已有：6–8 范围、隐藏章节说明。缺：单时期、双时期、整书<8、整书>8 正好8页、无重复/无虚构、固定页面族测试 |
| 10 | Debug 隔离 | **Partial** | `TailorApp.swift:7-17`；`MilestoneRootView.swift:37-45,71-81,139-165` | **P1**：Release 编译隔离已实现；但付费 bypass 使用 `-uiBypassPurchase && !-uiTesting`，与冻结的“显式 UI-test 参数”口径相反，测试 fixture 与开发 bypass 是两套语义 | 冻结唯一测试参数/launch configuration；所有 fixture 与 bypass 置于 `#if DEBUG` 且要求显式 UI-test session；Release 构建测试断言参数无效；避免普通 Debug 手工启动误绕付费 | 已有：源码 `#if DEBUG` 隔离。缺：Release archive/构建下 bypass 不可达自动测试、无参数 Debug 不旁路、唯一显式参数正例 |

## 4. 关键事实与代码证据

### 4.1 07–09 产物边界尚未实现

- 当前只有非 Codable 的 `MemoryBookDraftSummary`，不是可持久化的 `StoryPlanDraft`（`ArchiveModels.swift:3269-3275`）。
- `beginSmartDraft()` 立即调用 `createTimeline()`；后者直接改写 `ArchiveDocument.chapters`（`MilestoneRootView.swift:823-860`）。
- 09 应有的“模板 + 纸型”原子创建，当前只在 `applySelectedBookStyle()` 内按模板创建文档，Book Style 页面没有纸型 binding（`MilestoneRootView.swift:26,863-873`）。

### 4.2 恢复模型只覆盖扫描

- `ArchiveDocument` 只有粗粒度 `ProfileLifecycle` 和 `ScanCheckpoint`，没有 pre-document checkpoint/resume route（`ArchiveModels.swift:1619-1663`）。
- 冷启动恢复只对 lifecycle `.scanning` 跳转 05；其他阶段停在 Welcome（`MilestoneRootView.swift:503-525`）。
- `saveDraft()` 创建新 `ArchiveDocument` 时只带照片与章节（`MilestoneRootView.swift:488-500`），实现 checkpoint 时必须同时修复这一聚合保存边界。

### 4.3 Book Check 有能力，但不是冻结版 revision gate

- 当前 Book Check 每次从 `MemoryBookDocument` 即时计算，有 blocker/suggestion 和 issue 定位，这是可复用基础。
- `MemoryBookDocument` 只有 `updatedAt`，没有 `documentRevisionID`；没有持久化 `BookCheckResult` 或 `bookCheckRulesVersion`（`ArchiveModels.swift:2221-2240`）。
- 当前 PPI 常量为 150/300（`ArchiveModels.swift:1183-1186`），冻结合同为 100/200。
- 当前重复检查按同一 photo ID 多页，不是冻结的 `nearDuplicateGroup` 规则（`ArchiveModels.swift:2928-2934`）。

### 4.4 Manual Import 当前不是一个真实模式

- `Choose photos manually instead` 只执行 `scope = .limited; next()`（`OnboardingFeatureViews.swift:102`）。
- 后续 References 仍是 3–5 张、必须解析成 PHAsset localIdentifier（`ArchiveFeatureViews.swift:13-20,61-73`）。
- scanner 再读取系统授权；denied/restricted 会直接失败（`PhotoKitVisionScanner.swift:343-344`）。

### 4.5 识别代际和敏感审批是数据正确性缺口

- `PetFeaturePrintIndex` 文件按 profileID 隔离，字典键只是 asset identifier，未含 extractorVersion（`PhotoKitVisionScanner.swift:585-625`）。
- 增量 merge 明确保留旧 decision/sensitivity，未判断 generation 是否变化（`ArchiveModels.swift:3591-3602`）。
- 当前 eligibility 仅允许 `selected && normal`（`ArchiveModels.swift:1100-1104`）；没有 `sensitiveApprovedAt`，也没有 stale generation 条件。

### 4.6 付费路径“页面顺序正确”，但“revision 门禁不完整”

- 10 的主操作进入 17，17 无 blocker 后进入 18/19，基础顺序存在（`MilestoneRootView.swift:28-30`）。
- 18 的 cancelled/pending/failed 只留在 Purchase 页面显示提示（`MilestoneRootView.swift:895-908`），与冻结的返回 17 同一 pass state 不同。
- Final Preview 编辑结束使用单一 route 直接返回 19（`MilestoneRootView.swift:564-585`），没有自动 Book Check。
- 纸型变化只改 `pageSize/updatedAt` 并持久化（`MilestoneRootView.swift:987-993`），没有新 revision 和检查失效。

## 5. 建议实现工作包与依赖顺序

在用户确认本审计后再实施；本轮不实施。

1. **WP-1 数据契约与迁移（P0）**  
   `StoryPlanDraft`、八类 checkpoint、revision/check result、recognition generation/stale decision、sensitive approval、manual asset、ReturnContextStack。先完成 Codable/SwiftData migration 与纯模型测试。
2. **WP-2 03–09 主流程事务（P0）**  
   Manual Import、checkpoint 恢复、07/08/09 产物边界与原子创建。没有 WP-1 不开始页面拼接。
3. **WP-3 识别与 eligibility（P0）**  
   版本化 embedding、generation rematch、stale 复核、敏感审批、四层统一过滤。
4. **WP-4 revision gate 与返回栈（P0）**  
   09 paper、Book Check cache/rules、10→17→18→19、17/19 编辑后复检、稳定 locator fallback。
5. **WP-5 样章与 Debug 契约（P1）**  
   SamplePlan 规则完整化、单时期 fixture、唯一 DEBUG 测试入口和 Release 反向证明。
6. **WP-6 产品/设计/测试联合验收**  
   先做状态和功能验收，再做逐页视觉与真机/StoreKit；不得用已有 v1 截图替代 v2 01–06/18/20 expected。

## 6. 进入研发前的验收清单

本审计完成后，可以进入“实现计划评审”，但只有以下条件满足后才能开始编码：

- [ ] 产品确认六份冻结文档仍为唯一权威输入，不新增口头分支。
- [ ] 研发确认 WP-1 的 schema 与 migration 先行，不继续在单一 RootView state 上追加补丁。
- [ ] 测试先补十项裁决的失败用例，确保旧实现先红、新实现后绿。
- [ ] 设计为 Manual Import、stale decision、sensitive approval、checkpoint Archive、编辑后复检补齐可验收状态稿。
- [ ] 每个工作包有独立提交、回滚点和验收证据目录。

## 7. 最终判断

- **需求是否确定：是。** PRD 与原型合同已经对齐，可以停止产品方案反复。
- **当前实现是否与方案对齐：否。** 关键缺口集中在数据模型、恢复事务、识别代际和 revision gate，不是单纯 UI 补丁。
- **是否可以立即继续堆界面：否。** 应先评审并落地 WP-1 数据契约，否则 Manual Import、恢复、复检和识别代际会继续互相覆盖。
- **是否可以开始下一步：在产品确认本审计结论后，可以进入“数据契约/TRD + 测试先行”的研发阶段。**
