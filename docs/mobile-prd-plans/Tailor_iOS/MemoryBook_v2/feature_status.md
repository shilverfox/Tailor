# Tailor MemoryBook v2 功能状态

- 当前流程：流程4（Review / Verification / Release Gates）
- 产品基线：`../Tailor_v2_PRD.md`
- 原型基线：`../../../../../design/prototype_v2/prototype_map.html`
- 当前结论：代码级 QA 通过；发布验收未完成
- 最近更新：2026-07-21

## 已通过

- PRD、原型、状态矩阵与实现合同无 P0 产品歧义。
- App 构建通过。
- 全量单元测试 115/115 通过。
- 最终独立重点 UI 测试 8/8 通过。
- QA-V2-001～004 已关闭。
- Text `photoCaption` 异常退出、字体 round-trip、CoreText grapheme 边界、Book Check 精确返回、Story Plan 确认摘要、Preview logical page、StoreKit 本地化价格契约均已验证。

## 条件门禁

- 连接 iPhone 当前由 CoreDevice 报告为 `unavailable`，真机验证未执行。
- Quiet Night 的 Material 合成只允许真机判定。
- StoreKit 真实商品、离线、地区价格、pending、取消与恢复购买待验证。
- 五模板完整页面族盲测完成：5 个隔离 AI-agent、100 次判断、总体识别率 98%，内部视觉辨识门禁通过；这不替代真实用户研究。
- SwiftUI Reader 与 Letter/A4 PDF 三联复验：`QA-V2-006` 目录页纸内覆盖层已关闭；图片几何通过（A4 0.769pt、Letter 0.723pt）；早期字号比例问题已修复。
- `QA-V2-005` 当前最佳 v3：共享 CoreText canonical layout 后仅剩低分辨率 glyph bbox 的 2 Reader px 离散差异（A4 1.537pt、Letter 1.447pt）；换行、基线、向量布局一致。v4 高分辨率离屏方案未降低最大值且约 12.6MiB/页，已撤回。原 `<=1pt` glyph bbox 门禁仍 OPEN，等待产品裁决验收口径，不做逐元素特例。
- GF-01～GF-04 与 20 本真实内容质量 KPI 待完成。

## 下一动作

1. 由产品裁决 `QA-V2-005`：继续保留严格 glyph bbox `<=1pt` 并阻断，或改为“向量布局 `<=1pt` + glyph 边缘 `<=2 Reader pixels` 的明确栅格离散上限”。
2. iPhone 重新可用后执行真机 Quiet Night、PhotoKit、大相册热降速、后台/重启恢复。
3. 使用真实 StoreKit 商品完成地区价、离线、取消、恢复测试。
4. 只在所有发布门禁通过或存在用户明确接受风险记录后给出上线结论。
