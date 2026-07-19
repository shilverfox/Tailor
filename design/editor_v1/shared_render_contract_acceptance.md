# P0-1 · Shared PageStyle / RenderPlan 签核验收清单

**版本：** 1.0 · 2026-07-16  
**责任：** iOS（实现与自动化）、设计（视觉签核）、QA（资产/设备/PDF 证据）  
**适用范围：** `AlbumEditorFeatureView` 的页面成品区、阅读预览、`LocalPDFExporter`。编辑器的深绿工作区、选择框、控制点、辅助线和操作工具不属于成品页面，禁止进入 Reader 或 PDF。

## A. 签核前置条件

每次验收必须固定以下输入，并把它们写进证据目录的 `manifest.json`：

- Build SHA、设备型号与 iOS 版本、App 的 Dynamic Type 和显示缩放。
- 一份冻结的 `MemoryBookDocument` JSON；其中包含单图、双图、2×2、3×2、注记、章节开场、封面、重叠元素、`cropOffset`、`cropScale`、`rotationDegrees = ±15`、三档文字和单页样式覆写。
- 仅使用本地、已授权的 F-01/F-02/F-04/F-06/F-SAFE 测试素材及每张图的 `localIdentifier`。
- 每一种 `AlbumStyle`（Warm Paper / Quiet Night / Field Notes / Cinema / Film Album）和 A4 / US Letter。
- 免费样章与已解锁完整阅读两种状态。免费状态不生成完整无水印 PDF。

任何一种组合缺少 Editor 成品区截图、Reader 截图、原 PDF、PDF 栅格化 PNG、差异热图或判定 JSON，均为 **未验收**，不是“默认通过”。

## B. 必须存在的唯一渲染输入

| ID | 必须共享的对象 | Editor | Reader | PDF | 通过条件 / 证据 |
|---|---|---|---|---|---|
| RP-01 | `MemoryBookDocument` 冻结快照 | 读取并编辑同一 document | 只读同一 snapshot | 导出开始时冻结该 snapshot | `documentHash`、page ID 列表、元素 ID/asset ID 顺序三端一致；导出中改稿不得改变当前 PDF。 |
| RP-02 | `PageRenderPlan`（或等价纯数据计划） | 每页从 plan 取成品 frame/token/元素 | 同一 plan，只去掉编辑层 | 同一 plan 映射到 PDF points | 不得有 SwiftUI/Quartz 各自按 `kind/layout/photoIDs` 再计算版式的分支；代码审计 + 固定 document 的 plan JSON。 |
| RP-03 | `PageStyle` | 取当前页 `styleOverride ?? book.style` | 同上 | 同上 | 背景、边距、字体、装饰、滤镜、水印都来自同一 serializable token；不得以两个独立 `switch AlbumStyle` 猜测结果。 |
| RP-04 | 图片变换 | 用 `assetID`、normalizedFrame、Fill、cropScale/Offset、rotation、zIndex | 同上 | 同上；只允许提高解码分辨率 | 元素 ID、asset localIdentifier、frame、变换矩阵、z 顺序一致。 |
| RP-05 | 文本变换 | 用 text/frame/style token 绘制 | 同上 | 用同一 PostScript 字体和测量策略绘制 | 文本内容、换行、字号、对齐与可见行必须一致；系统回退字体不接受为容差。 |

## C. PageStyle 视觉契约

### C1. 纸张、背景、安全区与坐标

| ID | 契约 | 可签核的判定 |
|---|---|---|
| GEO-01 | 页面成品坐标系是 `0…1 × 0…1`，映射至 A4 `595×842 pt` 或 US Letter `612×792 pt`；只改变物理尺寸，不改变相对位置。 | 每个元素四边界在 PDF 栅格图与 Reader 中的归一化误差 ≤ 长边 0.5%。 |
| GEO-02 | `PageStyle` 必须显式给出 `trim/background`、`contentInsets`、7% 编辑安全区、圆角/边框/阴影规则。工作区深绿只属于 Editor 外部，不得被误画入 Reader/PDF。 | 同页 Reader 和 PDF 的纸张边缘、留白、边框完全一致；若 PDF 有外层 backdrop/inset，它必须也是 Reader 成品页的一部分并在 token 中声明。 |
| GEO-03 | 用户元素被限制在内容安全区；模板标题、页码、水印装饰层不可选、不可被元素覆盖。 | 边缘、中心、旋转元素、文字拖动的截图 + plan 边界校验；无元素越过安全区。 |
| GEO-04 | Editor 选择框、4 个控制点、对齐线、缩略轨、toolbar 一律不进入 Reader/PDF。 | Reader/PDF 热图中不得出现 clay 选择线、控制点、工作区或任何编辑控件。 |

### C2. 色彩与字体

| ID | 契约 | 可签核的判定 |
|---|---|---|
| COL-01 | 每套 `PageStyle` 定义 sRGB 背景、纸张、主文、次文、accent、line，PDF 以相同 sRGB 值填充。 | 从 plan/PNG/PDF 采样；RGB 差 ≤ 2/255（抗锯齿边缘除外）。 |
| TYP-01 | 标题用 `Iowan Old Style` 的明确 PostScript 名；UI/正文使用明确 SF Pro 字族/字重。不得仅用 SwiftUI `.custom()`、PDF 却 `UIFont.systemFont`。 | 对每页抽取 PDF font metadata；与 plan 中的 font name/weight 对应。文字行盒和换行必须完全一致。 |
| TYP-02 | Small / Default / Large 是 `PageStyle` 定义的三档，不是三端临时倍率；包含行距、字距和段落对齐。 | 三档文字的 Reader/PDF 对比；没有截断/额外换行；超出时产生同一 Book Check 阻断。 |
| TYP-03 | 中文及 Unicode 走事先指定的同一可嵌入 fallback 字体；缺字即失败。 | 中文、emoji、变音符 fixture 的 PDF 字形与 Reader 一致，无豆腐块。 |

### C3. 图片处理、裁剪与层级

| ID | 契约 | 可签核的判定 |
|---|---|---|
| IMG-01 | 所有图片均以 `aspectFill` / Fill 规则绘制；`cropScale` 和 `cropOffset` 是图片容器内变换，不改变容器 frame。 | 每页图片焦点差异 ≤ 容器短边 1%；不能出现空白边。 |
| IMG-02 | 旋转和圆角裁剪顺序固定：clip 到容器 → 变换图像内容（或明确同一等价顺序）→ 恢复 context；Reader/PDF 同步。 | ±15°、横竖图、偏移裁剪的像素热图；无 PDF 旋转方向反转、无泄露到容器外。 |
| IMG-03 | 同一 `assetID` 在三端解析到同一 localIdentifier；高清 PDF 只提高分辨率，不能改图、改焦点或改颜色。 | asset manifest + 图片像素特征/hash；导出请求日志。 |
| IMG-04 | `zIndex` 以稳定次序排序；图片、文本、Film 边框/装饰分别有明确层级。 | 两张重叠图+文字 fixture；Reader/PDF 中遮挡关系一致。 |

### C4. 五套模板

| 模板 | 必须在 Editor 成品区 / Reader / PDF 均一致的 token | 额外验收点 |
|---|---|---|
| Warm Paper | `#F8F3E8` 纸张、深墨绿文字、陶土重点、轻边框 | 纸本留白而非额外 PDF 外框。 |
| Quiet Night | 深墨绿纸张、暖白文字、低对比辅助文、暖陶土重点 | 文本对比达到可读门槛；不能和 Cinema 复用为同一视觉。 |
| Field Notes | sage 基底、ink 文字、卡片/日期标记规则 | 日期/手记装饰必须真实渲染，不能只换背景色。 |
| Cinema | 近黑/深色成品页、暖白文字、低饱和或黑白图片处理、满版规则 | 使用同一 Core Image/RenderPlan filter；无滤镜仅换黑背景判失败。 |
| Film Album | paper + ink、胶片白边、日期框/胶片标记 | 电影胶片边框和日期区域必须由 token 布局，不能仅给图片描边。 |

### C5. 水印与预览范围

| ID | 契约 | 可签核的判定 |
|---|---|---|
| WTR-01 | 免费 Reader 仅展示 6–8 页：封面、目录、至少两个不同时段、至少一张照片页、结尾。 | page ID 清单与截图；不是任意前 N 页。 |
| WTR-02 | 每一张免费样章页都有重复、低对比、对角 `TAILOR · PREVIEW` 水印；水印是 PageStyle/RenderPlan 的装饰层。 | 每页至少 2 个重复水印（或设计签字的明确密度规则）；Reader 截图及 PDF 栅格图。单枚 `PREVIEW` 角标不通过。 |
| WTR-03 | 已解锁 Reader 与正式 PDF 无水印；免费状态不可绕过生成完整无水印 PDF。 | Debug 与 Release 配置审计、UI 测试、PDF 文本/像素检查。 |

## D. 测量与证据执行法

1. 用同一个冻结 document，对五套模板 × A4/Letter × 单图/双图/2×2/3×2/注记页运行。
2. 截取 **Editor 成品区**（裁掉深绿工作区及编辑层）与 Reader 对应页；导出 PDF，按对应页面比例栅格化。
3. 归一化 trim rect 后产出 `editor-reader.png`、`reader-pdf.png`、两张 heatmap、元素边界 JSON、文本行盒 JSON。
4. 自动判定：位置 ≤ 0.5% 长边；裁剪焦点 ≤ 1% 容器短边；颜色 ≤ 2/255；文字/页序/资产/层级/水印为零容忍。
5. 每一组合由 iOS、设计、QA 三方在报告中签 `Pass / Fail / Not run`。`Not run` 不能汇总为通过。

建议归档路径：`artifacts/editor-render/<build>/<fixture>/<style>/<paper>/<state>/`。

## E. 当前实现预复核（2026-07-16）

| 项目 | 当前证据 | 结论 |
|---|---|---|
| RP-01 | `MemoryBookDocument` 已持久化，导出消费其 pages/elements。 | 部分通过；未见 snapshot hash 证据。 |
| RP-02/03 | SwiftUI 使用 `AlbumPalette`，PDF 另有 `palette(for:)` 与固定 `paperRect`；无 `PageRenderPlan`/共享 `PageStyle`。 | **不通过**。 |
| GEO-02 | Editor/Reader 画布为整页 palette.paper；PDF 另画 backdrop + 18pt `paperRect`。 | **不通过**。 |
| TYP-01/02 | SwiftUI 标题 `Iowan Old Style`，PDF 文本为 `UIFont.systemFont`。 | **不通过**。 |
| IMG-01–04 | 两端已消费 normalized frame/crop/rotation/zIndex，但没有固定资产的像素对比证据。 | 未验收。 |
| C4 五模板 | PDF 将 Quiet Night 与 Cinema 复用同 palette；Field/FIlm 的日期/胶片布局并无共享规范。 | **不通过**。 |
| WTR-01 | 代码选择 6–8 页代表样本。 | 部分通过，需 fixture UI 证据。 |
| WTR-02 | Reader 仅绘制单个 `PREVIEW`；PDF 导出无相同水印证据。 | **不通过**。 |

**P0-1 当前签核：不通过。** 研发完成共享 `PageStyle / PageRenderPlan` 与 D 节矩阵证据后，由设计和 QA 复核本清单；任何红项保留即不可宣称“预览即成品”。
