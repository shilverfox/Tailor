# Tailor iOS · 主流程设计与测试回归记录

**日期：** 2026-07-17  
**范围：** 照片确认 → 时间线 → 相册编辑 → 阅读预览 → 解锁 → PDF 生成/导出 → 档案。  
**边界：** 本轮仅回归和记录问题，未修改任何产品代码、测试代码或设计资源。

## 结论

- **功能主链路：通过。** 确认照片到 PDF 完成页的端到端 UI 用例通过。
- **设计高保真签署：不通过。** 存在 4 个 P0 问题，主要集中在导出完成、分享和档案入口。
- **全量 UI 回归：未签署。** 运行环境两次未生成可读取的完整结果包；不将此视为产品功能失败，但不能宣称全量 UI 已回归通过。

## P0 设计/交互问题（阻断）

| ID | 问题 | 预期 | 实际 | 影响与定位 |
| --- | --- | --- | --- | --- |
| D-P0-01 | 导出完成主按钮没有执行分享 | `Save and share PDF` 打开系统分享；次操作进入档案 | 主按钮仅跳转档案，真正的 `ShareLink` 被放在次级操作 | 导出后“保存/分享”主链路中断。`Tailor/Features/AlbumFeatureViews.swift:1390` |
| D-P0-02 | 档案主卡无法打开 | 最近档案卡打开阅读/编辑或 PDF | `Open Milo’s Life Archive` 是空动作 | 用户重新进入 App 后不能从主卡访问成品。`Tailor/Features/AlbumFeatureViews.swift:1397` |
| D-P0-03 | 导出完成页不是实际成品信息 | 展示真实封面、生成时间、纸张规格和页数 | 固定的通用 `Milo / Life Archive` 卡片 | 交付页缺少纪念成品感和文件可识别性。`Tailor/Features/AlbumFeatureViews.swift:1379` |
| D-P0-04 | 缺失照片没有前置反馈 | 编辑/预览显示缺失占位与 Replace，Book Check 可定位并阻断 | 画布静默省略；直到导出阶段才报 `photoUnavailable` | 用户无法及时修复，导出失败发生过晚。`AlbumFeatureViews.swift:362`、`ArchiveModels.swift:1504` |

## P1 设计问题（不阻断功能闭环）

| ID | 问题 | 定位 |
| --- | --- | --- |
| D-P1-01 | 阅读预览仍混入样式/纸张表单，没有沉浸式逐页阅读、顶部页码和翻页语义。 | `AlbumFeatureViews.swift:1273` |
| D-P1-02 | 五个模板卡视觉不一致，Cinema 与 Film Album 在运行态退化为普通文字。 | `AlbumFeatureViews.swift:1274,1281` |
| D-P1-03 | 编辑器选中图片只有描边，缺少控制点、拖动柄与对齐辅助线。 | `AlbumFeatureViews.swift:369` |
| D-P1-04 | 页面管理器为系统 List/色块，未满足两列缩略图、当前页和已修改状态可视化。 | `AlbumFeatureViews.swift:552` |
| D-P1-05 | 购买中没有 loading/禁用重复点击状态。 | `AlbumFeatureViews.swift:1341` |
| D-P1-06 | 时间线、章节和档案仍使用 `.white.opacity`，不满足纸张/卡片 token 的像素级设计基线。 | `ArchiveFeatureViews.swift:397,419`；`AlbumFeatureViews.swift:1399` |

## 测试回归结果

| 项目 | 结果 | 证据/说明 |
| --- | --- | --- |
| 主流程端到端 UI | PASS | `/tmp/tailor-regression-mainflow-20260717.xcresult`：确认 → 时间线 → 编辑 → 预览 → 解锁模拟 → PDF 完成。 |
| 领域、导出、持久化单元测试 | PASS，62/62 | `/tmp/tailor-regression-unit-20260717.xcresult` |
| 归档删除确认 | PASS | 已覆盖；系统照片不受影响。 |
| 导出成功/失败本地操作 | PASS | 已覆盖。 |
| 全量 UI 套件 | 未签署 | 两次运行未形成可读取 xcresult：首次模拟器并发占用；串行重跑异常退出。日志含 LLDB DebuggerVersionStore/no debugger version 及 iOS 26.5 UIAccessibility 重复类警告。 |

## 尚未完成的测试覆盖

- 扫描恢复/中断完整路径；
- 长照片列表到底后回滚的完整复跑；
- 样式 × 纸张 × 已购导出；
- 购买失败与恢复；
- 其余编辑器文字、裁剪、页面管理 UI 用例；
- 真机 PDF 栅格/像素比对。

## 后续门禁

1. 研发修复 D-P0-01…04 后，设计与测试仅复测受影响页面和主链路。
2. 在独占模拟器或真机上串行执行全量 UI 套件并保留 `.xcresult`。
3. P0 清零且全量 UI 结果包可读取后，才可进入高保真设计签署。

## 2026-07-17 扫描可靠性回归补充

**范围：** 参考照片校验、扫描恢复、低电量/热状态暂停、重扫合并与本地索引清理。  
**执行原则：** 本补充轮仅执行回归与问题记录；未修改产品实现或测试实现。

| ID | 级别 | 问题 | 复现/证据 | 影响 |
| --- | --- | --- | --- | --- |
| R-P0-01 | 已修复 | 当前工程不能编译，扫描可靠性单元测试及运行态回归均被阻断。 | `.onChange(of: pickerItems)` 已移至 `ReferencesFeatureView` 的外层 `TailorScreen`；修复后 `TailorTests` 69/69 通过。结果包：`/tmp/tailor-scan-reliability-unit-r3.xcresult`。 | 构建门禁已恢复。 |
| R-P1-01 | P1（设计决策待确认） | 未实现自动的 `PHPhotoLibraryChangeObserver` 触发重扫。 | 采用更克制的策略：已完成档案的 **Rescan for new photos** 会启动基于 asset identifier catalog fingerprint 的增量扫描，避免未获用户同意时后台扫描相册。 | 新增/删除照片不会静默自动扫描；用户可显式触发重扫。 |
| R-P1-02 | 已验证（单元） | 参考图硬校验、checkpoint 指纹、人工决定/章节/相册导出记录保留、低电量/热暂停。 | `TailorTests` 69/69 通过，包含 `testScanResumePolicyRejectsSameCountLibraryWhenIdentifiersChanged`、`testScanReferenceAndRuntimePoliciesHaveDeterministicSafetyGates`、`testScanArchiveMergePreservesUserDecisionsChaptersBookAndExports`、`testIncrementalRescanCheckpointSeedsExistingCandidatesWithoutAssumingCatalogCount`。 | 仍需真机 PhotoKit/Vision 测试覆盖真实相册和资源状态。 |

### 本轮验证命令

```text
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project Tailor.xcodeproj -scheme Tailor \
  -destination 'platform=iOS Simulator,id=1168B641-8055-4706-A068-480704EC75F5' \
  -only-testing:TailorTests CODE_SIGNING_ALLOWED=NO \
  -resultBundlePath /tmp/tailor-regression-20260717.xcresult
```

### 回归准入条件

1. 在真机上覆盖：不足三张/失效参考图、相册同数量换图后的恢复、低电量与严重热状态暂停恢复、重扫后人工排除/章节/相册/PDF 记录保留、删除档案后索引不可恢复。
2. 产品确认“显式重扫”是否为 v1 的最终策略；若要求自动提示，再补 `PHPhotoLibraryChangeObserver` 及用户可控的提醒入口。
