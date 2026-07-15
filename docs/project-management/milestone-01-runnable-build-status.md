# Tailor 首个里程碑：可运行 App（已验收）

更新时间：2026-07-14

## 目标

交付一版可在 iPhone Simulator 运行的 Tailor App：完成 12 屏 SwiftUI UI、首版固定视觉资源、本地 Mock 主流程，以及基础自动化测试。

## 已交付

| 工作流 | 负责人 | 状态 | 证据 |
| --- | --- | --- | --- |
| 产品与交互规格 | 产品/设计 | 完成 | `docs/mobile-prd-plans/Tailor_iOS/Tailor_v1_PRD.md`、`design/detailed/` |
| 12 屏 SwiftUI 原型 | iOS 研发 | 完成 | `Tailor/Features/MilestoneRootView.swift` 及同目录页面组件 |
| 本地 Mock 服务与路由 | iOS 研发 | 完成 | `Tailor/App/AppRouter.swift`、`Tailor/Services/DemoServices.swift` |
| 固定编辑型视觉资源 | 设计/资源 | 完成 | `Tailor/Resources/Editorial/`；right.codes 任务、来源 URL 和 SHA-256 见 `design/assets/generation_manifest.json`；PhotoKit 用户照片仍以动态内容呈现 |
| XCTest 测试 | 测试 | 已完成 | `TailorTests/TailorFeatureTests.swift`，6 个核心状态测试 |

## 构建门禁

以下命令已在本机成功构建：

```bash
xcodebuild -project Tailor.xcodeproj -scheme Tailor -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Tailor.xcodeproj -target TailorTests -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

结果均为 `BUILD SUCCEEDED`；最终构建也确认 6 张 Editorial PNG 已作为 Bundle resources 复制进 App。

## 运行验证（已通过）

本机已升级至 Xcode 26.6 并安装 iOS 26.5 Simulator runtime。已创建并启动 `Tailor iPhone 16` Simulator，成功安装并启动 `com.tailor.prototype`。

- 运行截图：[tailor-welcome-hero-aligned-ios26.png](evidence/tailor-welcome-hero-aligned-ios26.png)
- XCTest 结果：`** TEST SUCCEEDED **`，6/6 通过。
- 测试产物：`~/Library/Developer/Xcode/DerivedData/Tailor-atyczrlhkknoriamyexrsjxildgn/Logs/Test/Test-Tailor-2026.07.14_23-15-51-+0800.xcresult`

运行中发现并修复了两个 iOS 26 环境问题：缺少 Launch Screen 导致旧尺寸信箱式显示，以及欢迎页原始 PNG 撑开 ScrollView 宽度导致文本裁切和右侧溢出。修复后已重新构建、安装、启动并检查截图。

## 验收结论

首个里程碑完成：12 屏 SwiftUI 原型、首版固定视觉资源、本地 Mock 主流程和基础自动化测试均已交付，并已在 iPhone Simulator 实际启动验证。

## 范围边界

这一可运行版本使用本地演示数据；真实 PhotoKit 识别、Core ML、StoreKit 真实购买和 PDF 最终渲染属于后续功能实现，不会伪装成已完成能力。
