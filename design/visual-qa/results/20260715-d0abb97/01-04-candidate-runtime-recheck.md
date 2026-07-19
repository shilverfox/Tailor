# 01–04 candidate 设计与 iOS runtime 复核

审计时间：2026-07-15  
Git revision：`d0abb97`（工作树包含未提交产品与设计变更）  
最终状态：**全部 BLOCKED — no approved pixel reference**。

## 可复核基线事实

[`reference_manifest.md`](../../reference_manifest.md) 的文件头明确说明：当前仓库**没有**满足 `approved` 定义的 390×844 视觉参考。`ui_scope_contract.md` 规定只有 manifest 标记为 `approved` 的 PNG 才能做 1:1 叠图；candidate 只能记录方向性差异，不能用于 PASS 或 FAIL 签收。

| 页面/状态 | 参考 PNG 是否存在 | manifest 状态 | 运行时证据 | 本轮结论 |
| --- | --- | --- | --- | --- |
| 01 `welcome-default` | 是，390×844 | candidate | `runtime/2026-07-15/01-welcome-runtime-390x844.png`，14:09 | BLOCKED；截图早于当前 Welcome 未提交改动 |
| 01 `welcome-privacy-sheet` | 是，390×844 | candidate | 无同状态 runtime 截图 | BLOCKED |
| 02 `privacy-not-determined` | 是，390×844 | candidate | `02 privacy--runtime-390x844.png`，14:10，但没有 fixture/授权状态记录 | BLOCKED |
| 02 `privacy-limited` | 是，390×844 | candidate | 无 | BLOCKED |
| 02 `privacy-denied` | 是，390×844 | candidate | 无 | BLOCKED |
| 03 `profile-valid` | 是，390×844 | candidate | `03 profile--runtime-390x844.png`，14:10；另见第一轮人工差异审计 | BLOCKED |
| 03 `profile-validation-error` | 是，390×844 | candidate | 无 | BLOCKED |
| 03 `profile-unsupported-species` | **否** | blocked | 无 | BLOCKED — DESIGN_REFERENCE_MISSING |
| 04 `references-ready` | 是，390×844 | candidate | `04 references--runtime-390x844.png`，14:10；无受控 PHAsset fixture 记录 | BLOCKED |
| 04 `references-under-minimum` | 是，390×844 | candidate | 无 | BLOCKED |
| 04 `references-asset-unavailable` | **否** | blocked | 无 | BLOCKED — DESIGN_REFERENCE_MISSING |

## 系统状态栏 / safe-area 缺口

候选 PNG 为 390×844，但现有运行截图含 iPhone 状态栏/Dynamic Island；候选图没有批准的状态栏、Home Indicator 或 app-safe-area 定义。合同只允许在报告中声明后裁至 app safe area 对照，不能自行裁去系统区域后声称全页 1:1。

因此，以下项目本轮均不可判通过：顶部返回/wordmark/eyebrow 的 y 坐标、标题首行 y 坐标、固定 CTA 对 Home Indicator 的底部间距、系统状态栏颜色与图标样式。设计需在 approved PNG 或 companion safe-area 规范中固定这些规则。

## 当前 Welcome 改动后的证据失效

现有 01 runtime 截图时间为 14:09；当前未提交的 `Tailor/Features/OnboardingFeatureViews.swift` 已改变 Welcome 的标题拆行（`Keep a life` + `close.`）、hero 高度（286→297）、顶部 wordmark/help 布局与底部 action inset。因此旧截图不再对应当前实现，不能用于本轮比较、叠图或回归通过结论。

建议重新捕获的命令（先冻结 QA iPhone 13 UDID）：

```bash
cd /Users/lijian15/iosWork/Tailor
SIMULATOR_UDID=<Tailor-QA-iPhone13-UDID>
/usr/bin/xcodebuild build -project Tailor.xcodeproj -scheme Tailor \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID"
/usr/bin/xcrun simctl boot "$SIMULATOR_UDID" || true
/usr/bin/xcrun simctl bootstatus "$SIMULATOR_UDID" -b
/usr/bin/xcrun simctl install "$SIMULATOR_UDID" \
  "$HOME/Library/Developer/Xcode/DerivedData/Tailor-atyczrlhkknoriamyexrsjxildgn/Build/Products/Debug-iphonesimulator/Tailor.app"
/usr/bin/xcrun simctl launch --terminate-running-process "$SIMULATOR_UDID" \
  com.tailor.prototype -uiTesting -uiDemoRoute welcome
# 等待 XCUITest 的明确元素断言完成后，再执行：
/usr/bin/xcrun simctl io "$SIMULATOR_UDID" screenshot \
  "artifacts/visual-qa/<build>/01-welcome-default-runtime@3x.png"
```

配套 UI 命令仅能证明 demo 页面可达，不构成像素通过：

```bash
/usr/bin/xcodebuild test -project Tailor.xcodeproj -scheme Tailor \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  -only-testing:TailorUITests/TailorOnboardingUITests/testDemoRoutes01Through04RenderAndCaptureEvidence
```

重新截图后仍须等待产品将对应 candidate PNG 升为 `approved`，才能生成 overlay、diff 和 PASS/FAIL 结论。

## 不得宣称通过的项目

1. 01–04 的任何默认态或异常态均不得称“像素级通过”。
2. 01 Welcome 的最新代码没有新 runtime 截图；不得以 14:09 历史图证明它通过。
3. 02 limited/denied、03 validation/unsupported、04 under-minimum/asset-unavailable 没有完整同 fixture runtime 与 approved 基线；不得因默认态可达而覆盖这些状态。
4. 旧 `design/screens/01.png`–`04.png`、任何 prototype 与历史截图不得作为替代对照。
