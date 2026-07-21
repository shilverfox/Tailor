# Tailor v2.2 独立 QA 验收报告

- 验收日期：2026-07-21
- 验收基线：`Tailor-v2.2-docfreeze-2026-07-21`
- 唯一增量用例：`docs/mobile-prd-plans/Tailor_iOS/MemoryBook_v2/v2_2_test_delta.md`
- 环境：Tailor iPhone 16，iOS Simulator 26.5 (23F77)，arm64；Xcode 26.5
- 原则：本轮未修改生产代码。只补充/校正 QA 测试与证据；Mock、Simulator、Release 模拟器证据不冒充 DEVICE、STOREKIT 或 TestFlight 证据。

## 1. 结论

**当前不能签署 v2.2 发布验收。**

- 完整单元回归：`154/154 PASS`。
- WP2 事务专项：`17/17 PASS`，测试已直接调用正式 `ManualImportPolicy`、`StoryPlanWorkflow`、`ArchiveWorkflowTransaction`，没有使用测试内复制算法。
- 关键 UI：最终 `7 PASS / 2 FAIL`。失败的两条均为 P0 验收入口阻塞：完整主链 fixture 只有 2 张已选照片；Purchase fixture 没有当前 revision 的 Book Check pass。
- Release：构建成功；Release 二进制未发现 `-uiTesting`、`-uiDemoRoute`、`-uiBypassPurchase` 等字符串；带这些参数安装启动仍停留普通 Welcome 页，Debug fixture/bypass 未触发。
- 50 条冻结用例按“所需证据全部满足才 PASS”的严格口径统计：`PASS 7 / FAIL 2 / NOT RUN 41`。
- DEVICE、STOREKIT、完整 SNAPSHOT 门禁尚未执行，不能由单元测试或 demo fixture 代替。

## 2. P0 / P1 问题

### P0

| ID | 问题 | 独立证据 | 影响 |
| --- | --- | --- | --- |
| QA-V22-P0-01 | `review-ready` 完整主流程 fixture 只构造 2 张 selected，而正式 Smart Draft 最低要求 3 张。`Create memory book` 实际禁用，主链停在 06。 | `TailorV22AcceptanceKeyUI.xcresult`；失败 `testMainArchiveFlowReachesACompletedPDFAfterReviewAndUnlock`；失败层级显示 `We found 2 moments`、CTA Disabled。 | 无法提供 PAPER-01、PAY-01～05 及完整 06→19→PDF 的 AUTO-UI 证据。 |
| QA-V22-P0-02 | `purchase-failed` fixture 未持久化当前 `(revision,paper,rulesVersion)` 的 Book Check pass，进入 18 后立即被正式门禁重定向到 17，页面显示 3 blocking，Purchase 状态不可达。 | `TailorV22AcceptanceKeyUI.xcresult`；失败 `testPurchaseFailurePreservesTheUnlockScreenAndRestorePath`；失败层级为 `BOOK CHECK / 3 blocking`。 | PAY-03、PAY-04 当前 FAIL；购买失败/取消/恢复及价格状态无法独立验收。 |

### P1 / 外部门禁

| ID | 问题 | 后续证据 |
| --- | --- | --- |
| QA-V22-P1-01 | 8 个 checkpoint 的模型/持久化均通过，但尚无从 Archive 动态 CTA 恢复每一页的完整 AUTO-UI 组。 | 补 CP-01～08 参数化 XCUITest，并保存关键截图。 |
| QA-V22-P1-02 | ReturnContext 仅完成 LIFO 数据契约和“19 编辑后产生 blocking→17”的 UI；同 locator、issue 消失、无 blocking 页面 fallback 未跑通。 | 补 RETURN-01～04、06 定向 UI。 |
| QA-V22-P1-03 | 真机权限变化、PHPicker 3/500/501、私有副本、增量扫描未执行。 | DEVICE 日志、录屏、文件目录/哈希。 |
| QA-V22-P1-04 | StoreKit 沙盒购买/取消/失败/恢复未执行。 | StoreKit Configuration 或沙盒 Apple ID 日志。 |
| QA-V22-P1-05 | Sample Planner 的局部 UI/单元通过，但冻结的 3 张单时段与双时段完整 snapshot 组合未执行。 | 两套固定 fixture、页面结构清单和截图/PDF diff。 |

## 3. 50 条冻结用例逐项状态

状态口径：`PASS` = 文档要求的本地可执行证据已齐；`FAIL` = 已执行且不满足；`NOT RUN` = 必需证据层未执行或未覆盖完整 Given/When/Then。

| ID | P | 状态 | 已取得证据 / 缺口 |
| --- | --- | --- | --- |
| V22-PAPER-01 | P0 | NOT RUN | Letter 原子建册 UNIT PASS；主流程 UI 被 QA-V22-P0-01 阻塞。 |
| V22-PAPER-02 | P0 | NOT RUN | A4 首次原子建册 UNIT PASS；09 A4 UI 未执行。 |
| V22-PAPER-03 | P0 | PASS | `testBookCheckCacheKeyIsExactlyRevisionPaperAndRulesVersion`、exact cache hit。 |
| V22-PAPER-04 | P0 | PASS | revision/paper/rules 三个单变量变化均 cache miss。 |
| V22-PAPER-05 | P0 | NOT RUN | reflow UNIT 与 blocking→17 UI 有证据；19 切纸型 A4 的完整自动检查分支未执行。 |
| V22-CP-01 | P0 | NOT RUN | 8 checkpoint 持久化 UNIT PASS；Archive CTA→03 UI 未执行。 |
| V22-CP-02 | P0 | NOT RUN | references route UNIT PASS；UI/DEVICE 未执行。 |
| V22-CP-03 | P0 | NOT RUN | scan checkpoint 既有 UNIT PASS；UI/DEVICE 进程恢复未执行。 |
| V22-CP-04 | P0 | NOT RUN | review decision 保留 UNIT PASS；Archive CTA UI 未执行。 |
| V22-CP-05 | P0 | NOT RUN | Smart Draft cursor UNIT PASS；Archive CTA UI 未执行。 |
| V22-CP-06 | P0 | NOT RUN | StoryPlanDraft round-trip UNIT PASS；Archive CTA UI 未执行。 |
| V22-CP-07 | P0 | NOT RUN | confirmed draft/stylePending UNIT PASS；Archive CTA UI 未执行。 |
| V22-CP-08 | P0 | NOT RUN | documentReady route UNIT PASS；logicalPage UI 恢复未执行。 |
| V22-CP-09 | P0 | NOT RUN | 失效 checkpoint 回退且保留 snapshots UNIT PASS；UI/DEVICE 未执行。 |
| V22-MANUAL-01 | P0 | NOT RUN | 0/2 边界 UI/UNIT PASS；DEVICE 未执行。 |
| V22-MANUAL-02 | P0 | NOT RUN | 3/500、pending、直达 review、不建 scan checkpoint UNIT PASS；500 UI/DEVICE 未执行。 |
| V22-MANUAL-03 | P0 | NOT RUN | 第 501 项拒绝且前 500 保留 UNIT PASS；UI/DEVICE 未执行。 |
| V22-MANUAL-04 | P0 | NOT RUN | 未执行“3 选 1 读取失败，只产生 2 份副本”的 AUTO-FILE/DEVICE。 |
| V22-MANUAL-05 | P0 | NOT RUN | 指纹映射、decision 保留、只删匹配副本 UNIT+FILE PASS；DEVICE 未执行。 |
| V22-MANUAL-06 | P0 | NOT RUN | 档案私有目录隔离删除 FILE PASS；完整删除流程及 DEVICE 未执行。 |
| V22-MATCH-01 | P0 | NOT RUN | embedding key UNIT PASS；持久库提取次数 AUTO-FILE 未执行。 |
| V22-MATCH-02 | P0 | PASS | 姓名/年份不进入 generation hash，generation ID 稳定。 |
| V22-MATCH-03 | P0 | NOT RUN | generation ID 变化 UNIT PASS；授权范围全量重匹配与 FILE 未执行。 |
| V22-MATCH-04 | P0 | NOT RUN | stale/ineligible UNIT PASS；stale UI 明示未执行。 |
| V22-MATCH-05 | P1 | NOT RUN | 既有增量策略测试通过；真实新增照片 DEVICE 未执行。 |
| V22-SAFE-01 | P0 | PASS | normal+selected eligibility UNIT PASS。 |
| V22-SAFE-02 | P0 | NOT RUN | 未批准 sensitive 不 eligible UNIT PASS；批量旁路 UI 未完整执行。 |
| V22-SAFE-03 | P0 | NOT RUN | 审计时间 UNIT PASS；详情确认/取消 UI 未执行。 |
| V22-SAFE-04 | P0 | NOT RUN | neverUse 不可覆盖 UNIT PASS；逐张/批量 UI 未执行。 |
| V22-SAFE-05 | P0 | NOT RUN | builder/export 局部过滤测试存在；四层同一混合 fixture 的 UI+FILE 未执行。 |
| V22-RETURN-01 | P0 | NOT RUN | ReturnContextStack LIFO UNIT PASS；10→11→16 UI 未执行。 |
| V22-RETURN-02 | P0 | NOT RUN | 嵌套 frame/locator round-trip UNIT PASS；17→11→16 UI 未执行。 |
| V22-RETURN-03 | P0 | NOT RUN | 同 locator 在新检查的定位 UI 未执行。 |
| V22-RETURN-04 | P0 | NOT RUN | issue/page 删除后的 `min(I,lastIndex)` UI 未执行。 |
| V22-RETURN-05 | P0 | PASS | `testFinalPreviewEditWithBlockingResultReturnsThroughBookCheck`：19/P3→11/P3→17，且未短暂暴露旧 Reader。 |
| V22-RETURN-06 | P0 | NOT RUN | 默认 fixture 产生 blocking；无 blocking 与 page fallback 分支未执行。 |
| V22-PAY-01 | P0 | NOT RUN | 正式代码含 Book Check 门禁；主流程 UI 在 06 阻塞，未完成 10→17 证据。 |
| V22-PAY-02 | P0 | NOT RUN | blocking Book Check UI 可见，但缺少明确“无 18 入口/旁路”的完整 UI 断言。 |
| V22-PAY-03 | P0 | FAIL | Purchase fixture 无 current pass，被重定向至 17，无法验证 17 Continue→18。 |
| V22-PAY-04 | P0 | FAIL | purchase-failed 用例未进入 18；STOREKIT 亦未执行。 |
| V22-PAY-05 | P0 | NOT RUN | entitlement UNIT 局部通过；成功购买/恢复的 UI+STOREKIT 未执行。 |
| V22-PAY-06 | P0 | NOT RUN | 权益与 revision 局部 UNIT 存在；购买后修改 UI+STOREKIT 未执行。 |
| V22-SAMPLE-01 | P0 | NOT RUN | Sample Planner 6–8 局部 UNIT PASS；3 张单时段完整结构与 SNAPSHOT 未执行。 |
| V22-SAMPLE-02 | P1 | NOT RUN | 8 页截断与“样章外章节”UI PASS；双真实时期优先选择的 UNIT+SNAPSHOT 未执行。 |
| V22-DEBUG-01 | P0 | NOT RUN | 源码要求显式双参数；普通 Debug 的 10→17→18 UI 未执行。 |
| V22-DEBUG-02 | P1 | NOT RUN | 显式 Debug bypass 且 Book Check 仍阻断的完整 UI 未执行。 |
| V22-DEBUG-03 | P0 | PASS | Release build PASS；二进制无测试参数字符串；带参数安装启动仍为普通 Welcome。 |
| V22-RULES-01 | P0 | PASS | `BookCheckCacheKey.currentRulesVersion == 1` 且持久化 key 使用 1。 |
| V22-RULES-02 | P0 | NOT RUN | rulesVersion 变化 cache miss PASS；新结果保存 v2 且 document 不变未完整断言。 |
| V22-RULES-03 | P0 | NOT RUN | 未执行冻结的 PPI/retention/focal/重复/连续页面全部边界矩阵。 |

## 4. 测试断言审计

- 未发现 `XCTAssertTrue(true)`、`XCTAssertFalse(false)`、全局 `continueAfterFailure=true` 或为通过而新增 skip。
- `needsReview → pending`、敏感枚举迁移属于冻结模型命名迁移，原有相等性/eligibility 断言仍保留。
- Core Text 边界测试由固定字符数改为搜索真实布局边界，但仍严格断言 fit→overflow、UTF-16 消耗和完整 grapheme，不属于放宽。
- QA 新增 WP2 测试最初含测试内辅助算法；验收前已移除，改为直接调用生产 `ManualImportPolicy`、`ManualImportFlowPolicy`、`StoryPlanWorkflow`、`ArchiveWorkflowTransaction`。
- 两个过时 UI 预期按冻结文档校正：样章总页数由旧 7 改为 `min(8,total)=8`；19 编辑后产生 blocking 应回 17，而不是展示旧 19。两项均增加/保持门禁断言，不是弱化。

## 5. 证据清单

| 产物 | 结果 |
| --- | --- |
| `/private/tmp/TailorWP2MainFlowTestsR2.xcresult` | WP2 事务专项 17/17 PASS |
| `/private/tmp/TailorV22AcceptanceUnitR3.xcresult` | 全量 TailorTests 154/154 PASS |
| `/private/tmp/TailorV22AcceptanceKeyUI.xcresult` | 初轮关键 UI 9 条：4 PASS / 5 FAIL；保留原始失败证据 |
| `/private/tmp/TailorV22AcceptanceCorrectedUI.xcresult` | 冻结预期校正复测：RETURN-05、SAMPLE UI PASS；manual 文案断言仍旧，随后单测复核 |
| `/private/tmp/TailorV22UIManualR3.xcresult` | denied manual 入口与 0/3 禁用门禁 PASS |
| `/private/tmp/TailorV22ReleaseDerived/Build/Products/Release-iphonesimulator/Tailor.app` | Release build/install/launch PASS |
| `verification/v22_acceptance/runtime/release-bypass-attempt.png` | Release 带测试/bypass 参数仍显示普通 Welcome |

说明：首次两次完整单元启动曾分别遇到 test runner bootstrap kill 与 CoreSimulator Mach -308；重启专用模拟器后同一代码完整 154/154 通过，判定为测试基础设施故障，不计产品失败，失败 xcresult仍保留为审计轨迹。

## 6. 建议的下一门禁顺序

1. 研发只修 QA-V22-P0-01/02 的 deterministic fixtures，不绕过正式业务门禁。
2. QA 立即重跑完整 06→10→17→18→19→PDF 与 Purchase 失败/取消/恢复 UI。
3. 补齐 Paper、Checkpoint、Return fallback、Rules 边界自动测试。
4. 再进入真机 PhotoKit/Manual 生命周期、StoreKit 沙盒和最终 Snapshot/PDF 验收。

