# Warm Paper baseline 交付后研发实现单

状态：研发 contract 门禁已完成；设备截图热图证据待单独采集  
日期：2026-07-22  
前置任务：`28_warm_paper_approved_baseline_design_request_2026-07-22.md`

## 1. 触发条件

设计交付已确认以下内容，研发已开始并完成 source/render contract 门禁：

- 14 张 approved baseline PNG 已存在；
- 每张图有可编辑源文件；
- 设计交付说明明确标记 `approved`；
- 输出路径符合：

```text
design/reference/v1_1/memory-book/warmPaper/{letter,a4}/{cover,dedication,contents,chapterOpener,photoSelection,milestone,closing}.png
```

如果设计标记 `design-change-required`，研发先修改生产默认合同和代码，再重新进入本单；不能直接拿冲突图做像素比对。

当前登记：

- approved 说明：`design/reference/v1_1/memory-book/warmPaper/APPROVED.md`
- SVG 可编辑源：`design/reference/v1_1/memory-book/warmPaper/{letter,a4}/*.svg`
- PNG 导出脚本：`design/reference/v1_1/memory-book/warmPaper/export-approved-baseline-pngs.swift`
- source contract 脚本：`verification/memorybook_v2/verify_warm_paper_approved_baseline_contract.py`

## 2. 研发目标

让 Warm Paper 生产默认生成结果与 14 张 approved baseline 完成可重复验证：

```text
approved baseline x Editor x Reader x PDF raster
```

本单的 source/render contract 部分完成后，`verification/default-template-acceptance-round-2026-07-22.md` 可更新为“contract PASS”。设备 UI 像素热图仍应作为独立证据补充，不与本轮代码门禁混淆。

## 3. 研发实现步骤

1. 注册设计基准图
   - 新增或更新 memory-book reference manifest；
   - 明确 14 张图状态为 `approved`；
   - 记录可编辑源路径、设计确认日期和设计负责人。
   - 先运行 approved baseline preflight：

```text
/usr/bin/python3 verification/memorybook_v2/check_warm_paper_approved_baselines.py
/usr/bin/python3 verification/memorybook_v2/verify_warm_paper_approved_baseline_contract.py
```

2. 新增生产默认 fixture
   - 已新增 `MemoryBookProductionDefaultFixture`；
   - 通过 `-uiDemoState production-default-fixture` 进入 Editor / Reader / Final Preview；
   - fixture 从 Story Plan + Warm Paper + paper size 创建；
   - 禁止手工修改 frame、crop、rotation、zIndex、Fit/Fill；
   - 使用设计单第 3 节固定内容；
   - Letter 和 A4 各输出 7 类页面。
   - 已新增/扩展 `testProductionDefaultFixtureUsesBuilderDefaultsForWarmPaperBaseline`，覆盖 Letter/A4、7 页、固定文案、style token、paperRect、title/subtitle frame、结构页 Fill、photoSelection Fit 实际 frame、照片顺序和 rotation。

3. 输出运行时证据
   - Editor 成品区截图；
   - Reader 截图；
   - PDF 文件；
   - PDF raster PNG；
   - render manifest；
   - normalized 图；
   - baseline/runtime 叠图；
   - diff heatmap；
   - metrics JSON；
   - result.md。

建议路径：

```text
verification/memorybook_v2/approved_baseline_warm_paper_YYYYMMDD/
  letter/
    cover/
      baseline.png
      editor.png
      reader.png
      pdf-raster.png
      overlay-editor-baseline.png
      overlay-reader-baseline.png
      overlay-pdf-baseline.png
      diff-editor-baseline.png
      diff-reader-baseline.png
      diff-pdf-baseline.png
      manifest.json
      metrics.json
      result.md
  a4/
    ...
```

4. 实现差异判定
   - 复用现有 `verification/memorybook_v2/triple_render_2026-07-21/compare_triple_render.py` 的纸张归一化思路；
   - 不把旧 deterministic raster 当 approved baseline；
   - 指标必须区分布局、图片、文字、颜色/材质；
   - 失败时保留失败图和 JSON，不允许覆盖为通过。

5. 根据差异修改代码
   - 若 frame/布局不一致，优先修改 `MemoryBookTemplatePolicy` 或 `MemoryBookBuilder.elements`；
   - 若 Fit/Fill/裁切不一致，优先修改 `applyAutomaticTemplateAccents` 或 focal crop 策略；
   - 若材质/颜色不一致，修改 `MemoryBookPageStyle` / texture descriptor / renderer；
   - 若 Editor/Reader/PDF 彼此不一致，修改共享 render plan 或对应 renderer，不能只修截图表面。

6. 更新验收结论
   - 14 格全部通过后，更新默认模板验收报告；
   - 若任一格失败，保持 `FAIL/PENDING`，并写明失败页面、失败维度和下一步 owner。

## 4. 验收阈值

| 指标 | 门禁 |
|---|---|
| 元素边界 | 不超过页面长边 `0.5%` |
| 图片焦点 | 不超过容器短边 `1%` |
| 文字几何 | `<= 1 pt` |
| 文字内容 | 不丢字、不截断、不改变换行语义 |
| 图片模式 | Warm Paper 照片选择页默认 Fit；结构页 Fill |
| rotation | Warm Paper automatic 图片默认 `0°` |
| 纸张/纹理 | 与 approved baseline 视觉一致，不能退化为错误纯色 |
| 三端一致性 | Editor、Reader、PDF 消费同一 render contract |

## 5. 最低测试要求

至少运行：

```text
/usr/bin/xcodebuild test -project Tailor.xcodeproj -scheme Tailor -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:TailorTests/TailorFeatureTests
```

如新增 UI 截图自动化，还需运行对应 `TailorUITests` 用例，并把 `.xcresult` 路径写入 result.md。

每次研发修改后必须运行：

```text
/usr/bin/git diff --check
```

## 6. 完成定义

设备截图级完成需要同时满足：

- 14 张 approved baseline 已注册；
- 14 格 Editor / Reader / PDF 证据齐全；
- 每格 result.md 明确 PASS；
- metrics JSON 达到阈值；
- 相关单测和截图自动化通过；
- `verification/default-template-acceptance-round-2026-07-22.md` 更新为 PASS；
- 没有使用 candidate、旧 prototype 图或人工修改过的 QA fixture 作为通过依据。

## 7. 交接备注

当前研发已完成的前置修复：

- Warm Paper 多图默认收敛为单图/双图；
- Warm Paper 照片选择页默认 Fit；
- Warm Paper automatic 图片默认 rotation `0°`；
- 新增 `MemoryBookProductionDefaultFixture` 和 `production-default-fixture` UI demo state；
- 新增 `verification/memorybook_v2/check_warm_paper_approved_baselines.py`；
- 新增 `verification/memorybook_v2/verify_warm_paper_approved_baseline_contract.py`；
- 新增 approved baseline SVG/PNG/source-assets 和导出脚本；
- 扩展 `TailorFeatureTests/testProductionDefaultFixtureUsesBuilderDefaultsForWarmPaperBaseline` 为 approved baseline contract 回归门禁；
- 相关 `TailorFeatureTests` 120 个用例通过。

剩余工作不是继续猜设计，而是如需更高证据级别，使用同一生产默认 fixture 采集设备 Editor/Reader/PDF raster，并生成 overlay/diff/heatmap。
