# B2 验收准备：05 扫描六态与 06 确认十一态覆盖审计

审计时间：2026-07-15  
依据：`design/reference/v1_1/README.md`、`Tailor_v1_PRD.md`、`ArchiveFeatureViews.swift`、`MilestoneRootView.swift`、`TailorOnboardingUITests.swift`。  
结论：**B2 不能签收。05 缺 4 个产品状态；06 仅部分覆盖 11 个状态；当前没有 `approved` 的 B2 像素参考 PNG。**

## 05 — On-device scan（六态）

| README 状态 | 当前实现证据 | 当前 UI/XCTest 覆盖 | 判定 | 阻断/缺口 |
| --- | --- | --- | --- | --- |
| running | `isScanning == true` 时 CTA 是 `Pause scan`；进度、计数、缩略条存在 | 没有能注入 `isScanning=true` 的 demo fixture；05 路由固定为 `paused=true,isScanning=false` | PARTIAL | 需 `-uiDemoState scan-running` 或等价 fixture；缩略图当前为色块，不是 `PHAssetMask` / 本地缩略图 |
| paused | `paused == true` 显示 `Scan paused at n%. Your progress is saved.` | demo route `scan` 可达到；现有 route smoke test 只检查标题 | FAIL | 底部动作在 `isScanning=false` 时显示 `Start on-device scan`，不是 README 要求的 `Resume scan` |
| interrupted | 无独立渲染状态；恢复草稿也仅把 `paused=true` | 无 | FAIL | 缺 `Ready to continue where you left off.`、明确 Resume 和“用户主动打开后”状态 fixture |
| low-battery | 无电量检测、state 或 warning card | 无 | FAIL | PRD/README 的低电量卡和 Pause now/Continue later 完全缺失 |
| failed | `operationError` 只替换正文；CTA 会回到 Start，未提供 ErrorCard / Review matches so far | 无错误注入 | FAIL | 缺 Try again、Review matches so far、已确认内容保留的可见状态和 fixture |
| complete | `progress >= 1` 显示 `Matches ready for your review.` 和 `Review photos` | 没有注入 100% 完成态；route smoke test 不断言 | PARTIAL | 需完成功能 fixture，验证不会自动前进且 Review photos 可达 |

### 05 必须新增的自动化入口与 XCTest

产品侧应提供仅 UI 测试可用、不会进入生产路径的受控状态：

```text
-uiTesting -uiDemoRoute scan -uiDemoState running|paused|interrupted|lowBattery|failed|complete
```

每一态的 XCTest 最小断言：标题、指定状态文案、主/次按钮、进度/计数、固定隐私文案；`complete` 断言停留当前页直到点击 `Review photos`；`interrupted` 断言没有通知/倒计时文案。示例命令：

```bash
/usr/bin/xcodebuild test -project Tailor.xcodeproj -scheme Tailor \
  -destination 'platform=iOS Simulator,id=<QA-iPhone13-UDID>' \
  -only-testing:TailorUITests/TailorB2ScanUITests
```

在这些 fixture 出现前，不能新增可稳定运行的六态 XCTest；以当前 `scan` demo 冒充六态会漏检 4 个状态。

## 06 — Photo confirmation（十一态）

| README 状态 | 当前实现/证据 | 当前 UI/XCTest 覆盖 | 判定 | 阻断/缺口 |
| --- | --- | --- | --- | --- |
| high-with-pending | 四 tab、All years、可见 `Review n photos waiting for your choice`、Create timeline 存在 | `testReviewMakesPendingChoicesDiscoverableBeforeTimeline` | PARTIAL | 候选 fixture 仅 3 张，非 FX-10 规定数量；没有 approved 参考 PNG |
| needs-review | 点击 tile 进入 confirmation dialog；有 Select/quick approve | discoverable + quick approve 两个测试 | PARTIAL | 设计要求的 `Tap a photo to decide` 方向可用；无 approved 像素图/受控 FX-10 |
| viewer | 以 `confirmationDialog` 展示 This/Not/Set aside/Never use | 间接覆盖 This/Not | FAIL | 没有 aspect-fit 原图、日期/状态信息、48pt viewer 动作布局；不能视为 README viewer |
| pending-gate | Create timeline 有 pending dialog，含 Continue、Create with selected、Cancel | 现有测试只检查提示标题，未断言两条明确路径 | PARTIAL | 补两条 UI 用例：继续确认进入 needs-review；明确继续后进入 timeline 且只含 selected |
| sensitive | Sensitive tab + 保护 InfoCard；可由 action dialog `Set aside as sensitive` 进入 | 无 | PARTIAL | 无受控敏感 fixture、无 approved 图、未验证不会进入后续页面 |
| never-use-confirm | Action dialog 中直接有 Never use | 无 | FAIL | 缺破坏性**二次确认**、缺“原图留在 Photos”影响说明 |
| never-use-manager | 无 | 无 | FAIL | 缺折叠管理、40% 模糊 mask、`Allow in this archive` 恢复入口 |
| excluded | Excluded tab 存在 | 无 | PARTIAL | 缺 README 要求的明确 `Restore` 交互和 fixture 断言 |
| year-filter | Menu 可筛年份 | 无 | PARTIAL | 不是要求的 year-filter sheet；缺 filter fixture 与返回 All years 自动化 |
| zero-match | 空组仅显示通用 `No photos in this group` | 无 | FAIL | 缺 `No clear matches yet` 与 Choose different refs / Select manually / Keep draft 三条退出路径 |
| batch | Needs-review quick select 支持批量 Add | quick approve 测试 | PARTIAL | 缺批量 Exclude / Set aside，且没有 FX-10 多候选状态 |

### 06 可立即运行的现有测试命令

```bash
/usr/bin/xcodebuild test -project Tailor.xcodeproj -scheme Tailor \
  -destination 'platform=iOS Simulator,id=<QA-iPhone13-UDID>' \
  -only-testing:TailorUITests/TailorOnboardingUITests/testReviewMakesPendingChoicesDiscoverableBeforeTimeline \
  -only-testing:TailorUITests/TailorOnboardingUITests/testReviewCanQuicklyApproveSelectedCandidatesWithoutOpeningEachDecisionSheet
```

这些命令只证明当前 demo 的“待确认可发现/批量选入”路径，不证明 B2 11 态、敏感链或像素规格通过。

### 06 应补的 XCTest 用例（产品 fixture 就绪后）

| 用例名 | fixture / 启动参数 | 最低断言 |
| --- | --- | --- |
| `testReviewPendingGateRequiresExplicitChoiceBeforeTimeline` | FX-10, `review-high-with-pending` | 点击 Create 后存在 Continue / Create with selected / Cancel；两条路径均按 PRD 行为执行 |
| `testReviewSensitiveDeferralNeverAddsPhotoToTimeline` | FX-10, `review-sensitive` | 标记 decide later 后，photo ID 不在 timeline/cover/preview/PDF 输入 |
| `testReviewNeverUseRequiresImpactConfirmationAndKeepsSystemPhoto` | FX-10, `review-never-use-confirm` | 二次确认含 Photos 原图说明；确认后 asset 不在后续页面，PhotoKit 原图仍存在 |
| `testReviewNeverUseManagerCanRestoreOnlyAfterExplicitAction` | FX-10, `review-never-use-manager` | manager 可见；Allow 恢复后才变为 eligible |
| `testReviewExcludedCanRestoreAndYearFilterReturnsToAllYears` | FX-10, excluded/year-filter | Restore 正确回到 needs review；All years 恢复完整集合 |
| `testReviewZeroMatchOffersThreeSafeExitPaths` | FX-11, zero-match | 三条路径均可达，不造假照片 |
| `testReviewBatchActionsCoverIncludeExcludeAndSetAside` | FX-10, batch | 三个批量动作均影响正确 asset 集合 |

## 设计/像素门禁

`reference_manifest.md` 当前将 05 全部列为 `MISSING` / blocked，06 全部仍为 `MISSING` 或 static candidate only。即使上述功能补齐，也必须等待 `README.md` 所列 PNG 与 source 被交付、产品升为 `approved` 后，才能对 `PHAssetMask` 外区域叠图签收。

## 立即阻断项

1. **05 P0：** paused CTA 文案/动作错误，interrupted/low-battery/failed 状态缺失。
2. **06 P0：** never-use 缺二次确认与管理恢复；zero-match 路径缺失；viewer 不是需求规定的详情查看器。
3. **B2 视觉 P0：** 没有 approved 05/06 参考 PNG，因此不能宣称像素验证通过。
4. **测试可观测性：** `-uiDemoRoute` 只覆盖默认 route，不支持 05 六态或 06 FX-10/FX-11 的稳定注入，阻止全状态 UI 自动化。
