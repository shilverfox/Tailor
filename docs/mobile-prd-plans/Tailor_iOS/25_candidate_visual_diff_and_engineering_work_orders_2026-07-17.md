# 三模板高保真视觉回归：候选对照与研发修改单

状态：进行中。设计候选用于发现差异和指导返工，**不是 approved 基线**；任何“通过”仅表示相对候选方向的工程复审通过，不能替代设计批准。

## 1. 本轮优先矩阵与判定

优先覆盖 Warm Paper、Quiet Night、Field Notes × A4/US Letter × `cover`、`dedication`、`contents`、`chapterOpener`、`photoSelection`、`milestone`、`closing`（42 格）。

每一格的最低可执行检查：

| 维度 | Editor | Reader | PDF raster |
|---|---|---|---|
| 布局/间距 | paper/safe 区、元素 frame、无编辑控件入成品 | 同一 page index 与纸张比例 | 同一 paper/safe 区和 page media box |
| 色彩/材质 | 模板 backdrop/paper/texture token | 同 token | 同 token；不能静默退化为另一套纯色 |
| 字型/文字 | display/body、行距、对齐、无截断 | 可见文字/换行相同 | 同一文字 layout snapshot |
| 图片 | frame、crop、rotation、焦点 | 无手柄/选中态 | 同 asset/crop/rotation/z-index |
| 控件 | 编辑态仅作可编辑性证据 | 顶/底部浏览控件不覆盖纸张 | 无 UI chrome；免费态水印、已购态无水印 |

相对同一 frozen `MemoryBookDocument` 的阈值：元素边界 ≤ 页面长边 0.5%；图片焦点 ≤ 容器短边 1%；可见文字、换行、字号等级和对齐一致。

## 2. 候选对照来源（均未批准）

| 候选 | 临时用途 | 状态 |
|---|---|---|
| `design/assets/02_Warm_Paper.png` | Warm Paper 材质/色调方向 | candidate |
| `design/assets/03_Quiet_Night.png` | Quiet Night 材质/色调方向 | candidate |
| `design/assets/04_Field_Notes.png` | Field Notes 材质/色调方向 | candidate |
| `design/reference/v1_1/09-preview-unpurchased-page-{1…8}.png`、`09-preview-purchased.png` | iPhone Reader 的候选信息层级/水印方向 | candidate |
| `design/reference/v1_1/10-purchase-*.png`、`11-export-*.png` | 购买与完成页的候选信息层级 | candidate |

现有 `design/visual-qa/reference_manifest.md` 明确以上为 candidate。它们在批准并注册 42 个页级 `memory-book/<template>/<paper>/<page-kind>.png` 前，不得用作像素级签收。

## 3. 已观察的可复现差异与修改单

### P0-VIS-01：三模板成品页仅有纯色，缺少模板材质合同

**证据：** 当前 PDF raster 的 Warm/Quiet/Field 页面均为纯色 paper/backdrop。`MemoryBookPageStyle` 仅保存 RGB 色值；没有 texture asset、opacity 或 mapping token。资源清单却要求三个 `02/03/04` 材质用于 Style swatch/PDF 背景。

**研发修改：** 在共享 `MemoryBookPageStyle` / `MemoryBookPageRenderPlan` 增加 texture descriptor（asset ID、opacity、scale/content mode、fallback）。Editor、Reader、PDF 都仅消费此 descriptor；加载失败时使用显式纯色 fallback 并在 manifest 记录，禁止某一端独自铺纹理。

**复审：** 每个模板 A4/Letter 两页均有同质感的 Editor、Reader、PDF raster；文字对比保持可读；manifest 含相同 texture token。

### P0-VIS-02：当前 F-RP-01 不能代表七类页面的视觉语义

**证据：** 现有 `pdf-raster-01…07.png` 都是 `Fixture <kind>` + 单张色块图。dedication/contents/closing 仍包含图片；photoSelection 没有多图层级；无法验证目录页码、长正文、叠图裁剪或结尾留白。

**研发修改：** 新增测试/QA 专用视觉 fixture（不改变生产业务）并固定图片：cover 大图；dedication/closing 多行无图；contents 目录+页码；chapterOpener 竖图+日期+note；photoSelection 两/四图、不同 crop/rotation/z；milestone 图+日期/注记。所有三端读取同一 `MemoryBookDocument`。

**复审：** 42 格的每页内容对应自身 page kind；不再以“同一单图”冒充逐页视觉验证。

### P0-VIS-03：缺少 Editor / Reader / PDF 三端截图与差异产物

**证据：** 当前有 PDF、manifest、metrics、70 个 raster，但无 `editor-display.png`、`reader.png`、归一化图和热图。历史 `design/visual-qa/runtime/2026-07-15/09/10/11` 为黑色系统启动帧，不可用作运行时视觉证据。

**研发修改：** 用 UI demo fixture 重新采集：

```text
artifacts/visual-qa/memory-book/<build>/F-RP-VIS-01/<template>/<paper>/<index>-<kind>/
  editor-display.png
  reader.png
  exported.pdf
  pdf-raster.png
  normalized-editor.png
  normalized-reader.png
  diff-editor-reader.png
  diff-reader-pdf.png
  manifest.json
  metrics.json
  result.md
```

编辑选中框/手柄只进入单独 `editor-editing.png`，不进入像素差异。

**复审：** 每格齐全且误差阈值通过；失败图保留，不可用“截图异常”覆盖。

### P1-VIS-04：文字层级和留白无法由当前 fixture 签收

**证据：** 当前 raster 大面积留白且标题一律为 `Fixture …`，无法验证 display/body 字型、contents 页码、dedication 行距和 closing 留白。

**研发修改：** 随 P0-VIS-02 fixture 一并提供行盒/文本 token 到 metrics；截图应包含符合 page kind 的短/长文本。

### P1-VIS-05：购买与完成页缺少有效当前运行截图

**证据：** 现有 390×844 runtime PNG 是黑色启动过渡帧；候选图只在 `design/reference/v1_1`，且尚未批准。

**研发修改：** 用 UI demo fixture 采集 purchase default/purchasing/cancelled/failed/restored，以及 export ready/rendering/complete/failed。维持：$19.99 + one-time、四项权益、Apple Account 法律文案、恢复购买；完成页本地书封面、页数/纸张、Save and share PDF、失败 retry/返回时间线。

## 4. 首轮签收边界

- **可暂时通过：** shared manifest、PDF page size/非空、当前五模板的 deterministic PDF 导出通路。
- **不可高保真签收：** 全部 42 个三模板页面；原因是 P0-VIS-01/02/03 未关闭，且没有 approved 页级设计基线。
- **不可高保真签收：** 购买/完成页视觉；原因是没有有效当前运行截图、没有 approved 页面基线。
- **复审顺序：** 研发完成 P0-VIS-01 → 设计复审两种纸张的三模板背景 → 完成 P0-VIS-02/03 → 设计逐格复审 42 格 → 再处理 P1 文字与购买/完成页。
