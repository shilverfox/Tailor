# P0-2 剩余工作计划：Crop、Text、Reader/PDF 同源与保存

> 前提：E06 Layout（含照片页 → Note、锁定元素说明）已定向签收；本计划不触及 P0-3/P0-4，也不将最终真机或 P0-1 栅格发布门禁误标为已通过。
>
> 依据：`18_p0_2_editing_interactions_qa_acceptance_2026-07-16.md` §3/§4/§6/§8，`design/editor_v1/p0_2_product_design_recheck_2026-07-16.md` 的 B-3/B-4/B-5。

## 交付组 A：Crop 事务、Fill 约束与退出状态

### 功能缺口

- 普通 Editor / Reader / PDF 仍可能接受 `cropScale < 1`，无法从源码证明图片容器不露白。
- Crop 的 Cancel / Done / Reset / Undo、替换后裁剪及返回未提交三选项没有完整事务与回读证据。
- 当前 Crop 画面未证实原元素固定框、72% 遮罩、横竖图焦点一致。

### 最小实现

1. 定义唯一的 `CropTransform` / `FillCropConstraint`：以 source aspect、容器 aspect、旋转、scale、offset 计算最小 Fill scale 与四边合法 offset；Editor、Crop、Reader、PDF 都调用它，彻底移除 `0.5` 的独立下限。
2. Crop session 持有 `entryElement`、`draftTransform`、`historyBaseline`。Cancel/Discard 不写 document/history；Done 仅写一条 history；Reset 只更新 draft；Replace 继承 frame/rotation/z-index 后重新求新图合法 Fill transform。
3. 当用户离开未提交 Crop 时显示 `Keep editing / Save and leave / Discard this edit`；切页、返回和退后台均走同一 session 状态机。
4. 以设计规格重构 Crop stage：原元素比例固定窗口、遮罩 72%、明确 `Cancel / Crop photo / Done / Reset`，并提供稳定 accessibility ID。

### 固定 fixture

`F-P02-CROP`：6 张稳定本地 CGImage（横、竖、正方、极宽、极高、中心定位标记），覆盖横框竖图、竖框横图、初始旋转 ±15°、替换图片。

### 自动化 / UI / 渲染证据

- `MemoryBookCropTests`：四边 offset clamp、最小/最大 zoom、无白边数学断言、Cancel Codable 等值/无 history、Done→Undo→Redo、Reset→Done→Undo、Replace 保留 frame/rotation/z-index。
- `EditorP02CropUITests`：Crop 入口、Cancel、Done、Reset、未提交离开三选项；归档每个状态截图。
- `P02RenderManifestTests`：同一 committed crop 在 Reader/A4/Letter plan 中 assetID/frame/transform/rotation/z-index 完全相同。
- 后续最终门禁才追加 PDF raster / 真机 Photos 录屏；本组不替代该门禁。

### 验收条件与依赖

- CRP-001…007 的 P0 项通过，尤其 CRP-002/003/004/006；Crop 永不产生空白且取消不保存。
- 依赖 P0-1 的 `MemoryBookPageRenderPlan`；不依赖真实设备。

## 交付组 B：Text 草稿测量、Fit text、字段/Unicode 与导出阻断

### 功能缺口

- 需要将“实际溢出”从近似模型升级为同一 typography token（字号、行距、字距、字体回退）下的可复核测量；输入过程、三字号、Unicode 和 120/240 边界需全覆盖。
- Fit text 必须只变字号而不改 frame/内容；无法容纳时继续红色阻断。
- Book Check 定位与导出拒绝/无新 PDF、Undo/Redo/重启回读尚未形成闭环。

### 最小实现

1. 定义 `TextLayoutSpec` / `TextMeasurement`：PageStyle 字体映射、字号档、lineHeight、letterSpacing、alignment 与可用 text rect；Reader/PDF 从同一 spec 读取。
2. TextEditor 维护 draft value/style，实时量测并在 canvas 画红框、面板显示 `Fit text`；按字段白名单与页面语义限制编辑对象。
3. 按字段实行 120/240 的 `Character`（grapheme cluster）限制与剩余提示，保留中文、Arabic/RTL、emoji、组合 emoji、换行的原始值。
4. Fit text 依次尝试允许字号档，不改 frame/对齐/文本；失败保留错误。Book Check 的 `Go` 定位到元素，导出在 blocking 时不创建文件。
5. Done/Fit 均形成单一 undo 事务，并通过 repository 持久化。

### 固定 fixture

`F-P02-TEXT`：标题、日期、120 字符照片注记、240 字符献词、刚好适配/加一字溢出、中文、Arabic/RTL、emoji/组合 emoji/换行，三字号分别布置在照片页与献词页。

### 自动化 / UI / 渲染证据

- `MemoryBookTextLayoutTests`：三个字号 token、Unicode Codable round trip、120/240 边界、draft overflow/fit 成功与失败、Fit frame 不变、Book Check/export blocker、undo/redo/repository 回读。
- `EditorP02TextUITests`：实时红框、Fit text、失败提示、Book Check → Go、阻断导出且 Documents 无新 PDF；附件截图。
- `P02RenderManifestTests`：F-P02-TEXT 的 Preview/A4/Letter 对比 text/value/style/line boxes；最终 raster/PDF font metadata 归最终发布门禁。

### 验收条件与依赖

- TXT-001…007 的 P0 项通过，Fit text 不截断、不扩框、无法适配继续阻断。
- 依赖 P0-1 shared typography/render-plan；依赖保存组提供 repository 回读。

## 交付组 C：P02 持久化与 Reader/PDF 冻结计划证据

### 功能缺口

- 现有局部模型/UI 测试未证明 crop/text/layout 的提交结果冷启动后不变，也未输出 P02 固定 fixture 的 Preview/A4/Letter manifest 与实际 PDF。
- 没有将 export 开始瞬间的 document/plan hash 与后续编辑隔离的 P02 专项证据。

### 最小实现

1. 建立 `F-P02-PERSIST`：在同一 document 中包含已提交 crop、三字号文本、Fit text、6→Note 迁页、锁定图片与用户元素。
2. 注入测试 repository / deterministic asset provider / temporary export directory；保存后重建 root，再回读 document。
3. Export 开始冻结 `MemoryBookRenderManifest` 与 document hash；Preview/A4/Letter/PDF adapter 读取同一 manifest，不重新按 layout 或 crop 推导。
4. 输出可归档 manifest JSON（pageID、assetID、frame、crop、rotation、z-index、text value/style/measurement、layout/page order、watermark）。

### 固定 fixture

`F-P02-PERSIST` 组合 A/B 的 committed document；资产来自 F-P02-CROP 的确定性图像，不使用个人 Photos。

### 自动化 / UI / 渲染证据

- `P02PersistenceTests`：repository encode/decode、冷启动回读、crop/text/layout/locked element 字段完全一致。
- `P02RenderManifestTests`：Preview/A4/Letter/PDF 的 manifest 等值；导出中编辑不影响当前 PDF、下一次导出才改变 hash。
- `P02PDFStructureTests`：有效 PDF、页序/asset/text/layout 与 manifest 对应；真实 raster / heatmap 与真机留在 G-EDITOR-03。

### 验收条件与依赖

- 满足验收文档 C 层的可复现部分：保存回读、Reader/A4/Letter/PDF manifest、导出快照；P0-1/P0-2 栅格和真机发布门禁仍单列 `Not run`，不得用本组替代。
- 依赖组 A/B 的稳定数据模型，以及 P0-1 `MemoryBookRenderManifest`。

## 实施与验收顺序

1. 组 A（Crop）完成 → 产品/设计、QA 独立验收 CRP。
2. 组 B（Text）完成 → 产品/设计、QA 独立验收 TXT。
3. 组 C（P02 保存/RenderPlan）完成 → QA 验收 C 层；随后才评估 P0-2 是否可签收。

每组未通过即仅返工本组；不启动 P0-3/P0-4。最终 G-EDITOR-03 仍要求真实图片 A4/Letter raster 和真机验证。
