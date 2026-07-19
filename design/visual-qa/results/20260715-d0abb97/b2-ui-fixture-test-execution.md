# B2 UI Fixture 与 XCTest 执行报告

执行时间：2026-07-15  
范围：05 scan 六态；06 review viewer / pending gate / batch / sensitive。  
结论：**测试夹具与用例已接入；执行结果 BLOCKED — Scheme 测试计划未按命令 destination 收敛，不能声明测试通过。**

## 本轮可执行变更

| 位置 | 变更 | 目的 |
| --- | --- | --- |
| `Tailor/Features/MilestoneRootView.swift` | `-uiTesting -uiDemoRoute <route> -uiDemoState <state>` | 只在 UI 测试启动路径创建受控 fixture，不改变正常生产启动 |
| 05 demo states | `running`、`paused`、`interrupted`、`lowBattery`、`failed`、`complete` | 使状态文案/CTA 可由测试稳定启动；未实现状态不由 fixture 伪造为通过 |
| 06 demo states | `review-viewer`、`review-pending-gate`、`review-batch`、`review-sensitive` | viewer/gate 由真实点击路径展开；batch 注入 3 张 needs-review；sensitive 注入 1 张保护候选 |
| `TailorUITests/TailorOnboardingUITests.swift` | 新增 scan、review viewer/gate/batch/sensitive UI 断言 | 验证可发现性与明确操作路径 |

## 测试状态分类

| 用例 | 结果类型 | 状态 |
| --- | --- | --- |
| `testScanDemoStatesExposeRunningPausedAndCompleteActions` | 正向回归 | 待有效 test run |
| `testScanUnimplementedB2StatesRemainVisibleExpectedFailures` | `XCTExpectFailure` | 被设计为留下 interrupted / lowBattery / failed 的明确缺口，不跳过 |
| `testReviewCanQuicklyApproveSelectedCandidatesWithoutOpeningEachDecisionSheet` | 正向回归 | 已升级为 3 个 needs-review batch fixture；待有效 test run |
| `testReviewViewerAndPendingGateAreDiscoverableWithDedicatedFixtures` | 正向回归 | 待有效 test run |
| `testReviewSensitiveFixtureKeepsProtectiveGroupDiscoverable` | 正向回归 | 待有效 test run |

## 执行证据与阻断

已发起以下定向命令（目标指定为 `1168B641-8055-4706-A068-480704EC75F5`）：

```bash
/usr/bin/xcodebuild test -quiet -project Tailor.xcodeproj -scheme Tailor \
  -destination 'platform=iOS Simulator,id=1168B641-8055-4706-A068-480704EC75F5' \
  -resultBundlePath /tmp/Tailor-B2-Serial-20260715.xcresult \
  -only-testing:TailorUITests/TailorOnboardingUITests/testScanDemoStatesExposeRunningPausedAndCompleteActions \
  -only-testing:TailorUITests/TailorOnboardingUITests/testScanUnimplementedB2StatesRemainVisibleExpectedFailures \
  -only-testing:TailorUITests/TailorOnboardingUITests/testReviewCanQuicklyApproveSelectedCandidatesWithoutOpeningEachDecisionSheet \
  -only-testing:TailorUITests/TailorOnboardingUITests/testReviewViewerAndPendingGateAreDiscoverableWithDedicatedFixtures \
  -only-testing:TailorUITests/TailorOnboardingUITests/testReviewSensitiveFixtureKeepsProtectiveGroupDiscoverable
```

观察到 Scheme 的测试计划实际启动到 `41F93DB0-C75A-4044-BD9D-C7D90D00FE9B`（iPhone 17 Pro），而非命令指定设备；Runner 退出后 `xcodebuild` 未生成可读取的完成结果并保持挂起。为避免持续占用共享模拟器，已停止这轮由 QA 启动的挂起进程。

因此：

- 构建阶段已进入 app/UITest runner 启动，未发现 Swift 编译诊断；这不是测试通过证据。
- `/tmp/Tailor-B2-Serial-20260715.xcresult` 未完成，不能读取为有效 xcresult。
- 本报告不把任何正向 B2 用例记为 PASS。

## 复跑前置条件

1. 在 Scheme/Test Plan 中固定或移除覆盖命令行 destination 的测试设备配置。
2. 确保同一时间仅有一条 `xcodebuild test` 使用该模拟器。
3. 运行完成后使用下列命令读取结果；只有 `failedTests: 0` 且 expected failures 与三项已知 05 缺口一致时，才可记录为有效执行。

```bash
/usr/bin/xcrun xcresulttool get test-results summary \
  --path /tmp/Tailor-B2-Serial-20260715.xcresult
```

4. `XCTExpectFailure` 的三项若变为 unexpectedly passed，说明产品状态已补齐；应删除 expected-failure 包装并改为普通 PASS 断言。
