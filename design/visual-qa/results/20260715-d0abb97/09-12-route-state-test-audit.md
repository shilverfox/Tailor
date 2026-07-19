# 09–12 路由与异常态测试审计（2026-07-15）

## 已验证的可执行状态

- 09：默认未购买预览、三种风格入口、US Letter 选择器、已购后 `Generate full PDF`、一期素材的保守预览入口。
- 10：默认购买页与本地 `purchase-failed` fixture；失败后仍显示解锁和恢复购买入口。
- 11：完成态显示 `Save and share PDF`；失败 fixture 不再提供 PDF URL，显示错误并保留 `Generate PDF` 与返回时间线。
- 12：已导出档案 card 与设置行可点击；删除确认标题与 destructive action 可访问。

## 2026-07-15 执行证据

- `xcodebuild build-for-testing`：通过。
- 定向 UI 运行：`/tmp/Tailor-09-12-ui-rerun.xcresult`，iPhone 17 Pro（iOS 26.5），4 条中 2 通过、2 失败。
- 失败 1：系统 `confirmationDialog` 的 `Cancel` 未出现在 XCTest 的应用可访问性树；删除 title 和 `Delete local data` 可访问。该项保留为 12 页验收缺口，不能以测试绕过。
- 失败 2：当时 `export-failed` fixture 仍持有 `exportURL`，导致继续显示完成态 CTA；fixture 已改为失败时 URL 为 `nil`，并新增本地错误文案断言，需在后续串行测试中复验。

## 尚未实现，不能伪造为通过

- 09：preview loading / retry。
- 10：purchasing 防重复、取消、恢复成功确认。
- 11：页尺寸 sheet、逐页渲染进度、文件不可用恢复。
- 12：空档案、权限撤销、删除失败重试、多个档案。

这些状态已有 candidate 设计稿，但尚无相应生产 View 状态或可验证的 UI fixture；它们是开发与视觉验收阻塞项，而非测试数据问题。
