# Warm Paper approved baseline 研发验收结果

- 日期：2026-07-23
- 范围：Warm Paper × Letter/A4 × 7 类页面
- 结论：**contract PASS**

## 已完成

- 14 张 approved baseline PNG 已存在：
  - `design/reference/v1_1/memory-book/warmPaper/letter/*.png`
  - `design/reference/v1_1/memory-book/warmPaper/a4/*.png`
- SVG 可编辑源已存在：
  - `design/reference/v1_1/memory-book/warmPaper/letter/*.svg`
  - `design/reference/v1_1/memory-book/warmPaper/a4/*.svg`
- approved 说明已登记：
  - `design/reference/v1_1/memory-book/warmPaper/APPROVED.md`
- 生产默认 fixture 已接入：
  - `MemoryBookProductionDefaultFixture`
  - `-uiDemoState production-default-fixture`
- source contract 脚本通过：
  - `verification/memorybook_v2/verify_warm_paper_approved_baseline_contract.py`
- render contract 单测通过：
  - `TailorFeatureTests/testProductionDefaultFixtureUsesBuilderDefaultsForWarmPaperBaseline`
- 完整 `TailorFeatureTests` 通过：
  - 120 tests, 0 failures

## 已对齐的合同点

- 页序：cover、dedication、contents、chapterOpener、photoSelection、milestone、closing。
- 文案：与设计任务单固定 fixture 一致。
- 纸张：Warm Paper `#F8F3E8`，backdrop `#EFE4D1`。
- 字体比例：title `paperRect.width × 0.045`，subtitle/body `paperRect.width × 0.026`。
- 结构页图片：Fill，rotation `0°`。
- photoSelection：Diptych + Fit，rotation `0°`。
- Fit 实际 frame：按 `normalizeFitImageFramesToAssetAspect()` 收缩到真实可见照片边界。
- 图片顺序：landscape 第一张，portrait 第二张。

## 证据边界

本轮完成的是 source/render contract 级研发门禁。尚未采集真实设备 Editor/Reader 截图，也未生成设备截图级 overlay/diff/heatmap。

如后续需要对外声称“像素级一致”，继续按 `docs/mobile-prd-plans/Tailor_iOS/29_warm_paper_baseline_implementation_work_order_2026-07-22.md` 的设备截图流程补证据。

