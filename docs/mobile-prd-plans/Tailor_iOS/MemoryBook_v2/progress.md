# Tailor MemoryBook v2 交付进度

## 2026-07-20

- 冻结 v2 PRD、01–20 页面合同、状态矩阵和详细状态稿。
- 完成共享 `MemoryBookDocument → Page → Element` 主流程、五模板、完整 Page Editor、Book Check、Final Preview 和 PDF 路由。
- 三轮研发返修关闭 Preview/Edit、8 字体、Story Plan、Book Check、动态价格、视频入口、主体焦点裁切、字体回退、文字溢出和 Text sheet 生命周期问题。
- 最终独立 QA：115/115 单测、6 条专项模型、8 条重点 UI 全部通过。
- 第三轮设计验收：核心阻断项关闭；Book Check Ignore、Price unavailable、Quiet Night 等保留条件证据。

## 2026-07-21

- 进入流程4发布前验收。
- CoreDevice 可识别 `Jian 的 iPhone / iPhone 13`，但状态为 `unavailable`，真机门禁等待设备重新连接、解锁和信任。
- 2026-07-21 三联渲染发现 `QA-V2-005`（Reader/PDF 文字位置不一致）与 `QA-V2-006`（目录页 Reader-only overlay），代码门禁重新打开；研发修复后由测试和设计复验。
- 研发已统一 Reader/PDF 的 CoreText 绘制路径并移除纸内目录浮层；全量构建、117/117 单测、5 模板 × 2 纸型 × 7 页 PDF 证据及 Reader 14 页采集通过。当前仅表示代码回归通过，`<=1pt` 三联像素门禁仍待 QA 新证据关闭。
- 并行推进缺失 UI fixture、五模板盲测和 Preview/PDF 三联验收。
- 新增正式验证、发布、回滚和监控文档入口。
