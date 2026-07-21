# MemoryBook v2 Reader / PDF 三联核验报告

日期：2026-07-21  
范围：`Warm Paper`、Letter/A4、7 个正式页面类型  
结论：**不通过 P-002/P-003，当前不能签署“预览与导出一比一”。**

## 1. 核验对象与证据

- Reader：通过正式 `PreviewFeatureView → AlbumPagesPreview → ReaderPageSpread → EditorBookPageCanvas` 路径运行，以 `visual-fixture` 启动参数逐页采集 `Reader single page`。
- PDF：同一 `MemoryBookVisualQAFixture.make(style:paper:)` 配方经 `LocalPDFExporter` 生成 Letter/A4 PDF，再将每页栅格化。
- 页面族：cover、dedication、contents、chapterOpener、photoSelection、milestone、closing，共 7 页。
- 持久证据：
  - [Letter Reader/PDF contact sheet（左 Reader，右 PDF）](contact_sheets/reader-left_pdf-right-letter.jpg)
  - [A4 Reader/PDF contact sheet（左 Reader，右 PDF）](contact_sheets/reader-left_pdf-right-a4.jpg)
  - [逐页及逐元素 metric](comparison_metrics.json)
  - [Letter PDF](pdf/warmPaper/letter/00000000-0000-0000-0000-000000000101-life-archive-20260720-235855-99DCBC2F.pdf)
  - [A4 PDF](pdf/warmPaper/a4/00000000-0000-0000-0000-000000000101-life-archive-20260720-235858-93DDADB3.pdf)
  - [Letter render-plan manifest](pdf/warmPaper/letter/manifest.json)
  - [A4 render-plan manifest](pdf/warmPaper/a4/manifest.json)
  - Reader 原始截图位于 `reader/warmPaper/{letter,a4}/reader-page-01...07.png`。
- UI 自动化结果：`testCaptureWarmPaperReaderPagesForLetterAndA4Evidence` 1/1 通过；xcresult 为 `/tmp/TailorV2TripleUIQADerivedData/Logs/Test/Test-Tailor-2026.07.21_00-42-14-+0800.xcresult`。

注意：两端由**同一确定性 fixture 配方**分别构造，页面 ID、照片 ID、内容与页面参数一致；本轮没有跨测试进程共享一份序列化 `MemoryBookDocument` revision，因此只能证明同配方、同语义文档，不能声称验证了同一内存实例或同一持久化 revision。Final Preview 与上述 Reader 使用相同页面组件，且 fixture 路径设置为 purchased；但 `visual-fixture` 只接入 `.preview` 路由，本轮没有对 `.finalPreview` 路由做独立 fixture 截图。

## 2. 坐标归一化与比较方法

Reader 元素截图包含页面容器上下留白，因此不能直接与整页 PDF 做像素比较。脚本按以下步骤处理：

1. 读取 Reader RGB 截图，以左上背景色为容器背景；行/列中超过 45% 像素与背景差值大于 4 时判为纸张有效区域。
2. 得到实际纸张矩形：A4 为 `[0,100,774,1198]`，Letter 为 `[0,160,846,1258]`；两者实际纸张高度均为 1098 px。
3. 将 PDF 页使用 Lanczos 缩放至 Reader 纸张像素尺寸。
4. 再按物理纸张点数归一：A4 `595×842 pt`，Letter `612×792 pt`。元素候选区域来自 PDF render-plan manifest 的 `paperRect + normalizedFrame`。
5. 照片使用确定性 fixture 的三种专用色块检测；文字使用深墨绿前景色检测；比较两侧实际栅格 bounding box 的 `x0/y0/x1/y1`，最大坐标差作为几何误差。
6. 全页另记录 MAE、RMSE 和 1pt 膨胀后的双向边缘覆盖率。这些全页指标会受到字体抗锯齿和 Reader-only 浮层影响，只用于定位，不替代元素几何判定。

实现脚本：[compare_triple_render.py](compare_triple_render.py)。

## 3. 逐页结果

| 纸张 | 页 | 页面类型 | MAE | RMSE | 已检测元素最大框偏差 | 判定 |
| --- | ---: | --- | ---: | ---: | ---: | --- |
| A4 | 1 | cover | 1.388 | 8.817 | 23.005 pt | 失败：标题文字下移 |
| A4 | 2 | dedication | 4.266 | 23.030 | 40.643 pt | 失败：多行文字下移 |
| A4 | 3 | contents | 6.356 | 24.872 | 85.887 pt | 失败：文字下移且有 Reader-only 浮层 |
| A4 | 4 | chapterOpener | 1.601 | 11.106 | 23.005 pt | 失败：标题文字下移 |
| A4 | 5 | photoSelection | 2.193 | 13.214 | 23.005 pt | 失败：图片几何通过，标题文字失败 |
| A4 | 6 | milestone | 1.596 | 9.914 | 23.005 pt | 失败：标题文字下移 |
| A4 | 7 | closing | 2.295 | 12.838 | 23.005 pt | 失败：文字下移 |
| Letter | 1 | cover | 1.418 | 9.159 | 20.197 pt | 失败：标题文字下移 |
| Letter | 2 | dedication | 4.420 | 23.639 | 33.180 pt | 失败：多行文字下移 |
| Letter | 3 | contents | 6.029 | 24.375 | 75.016 pt | 失败：文字下移且有 Reader-only 浮层 |
| Letter | 4 | chapterOpener | 1.668 | 11.612 | 20.197 pt | 失败：标题文字下移 |
| Letter | 5 | photoSelection | 2.291 | 13.896 | 19.475 pt | 失败：图片几何近似通过，标题文字失败 |
| Letter | 6 | milestone | 1.615 | 10.184 | 20.197 pt | 失败：标题文字下移 |
| Letter | 7 | closing | 2.408 | 13.490 | 20.197 pt | 失败：文字下移 |

拆分元素后的结果：

- A4 照片实际框最大偏差 `0.769 pt`，满足 `≤1 pt`。
- Letter 照片实际框最大偏差 `1.447 pt`，其余为 `0.723 pt`；最大值相当于 Reader 两个低分辨率像素，仍应在更高分辨率、同一 revision 复验后才能签字。
- A4 文字实际框偏差范围 `15.337–85.887 pt`，平均约 `30.759 pt`。
- Letter 文字实际框偏差范围 `11.541–75.016 pt`，平均约 `26.208 pt`。
- Fit 与 Fill 均被实际覆盖：第 5 页四图为 Fit，封面/章节/milestone 为 Fill。
- 当前生产 `MemoryBookVisualQAFixture` 的元素 `rotationDegrees` 均为 0，且没有有意义的元素重叠，所以本轮不能为 rotation 与 zIndex 栅格一致性签字；manifest 顺序测试不等同于视觉合成验证。

## 4. 缺陷判定

### QA-V2-005 — P0：Reader 与 PDF 文字布局系统性不一致

Reader 与 PDF 虽然共享 attributed-string 工厂和 render-plan frame，但 Reader 最终由 `UIViewRepresentable/UILabel` 排版，PDF 由 Quartz `NSAttributedString.draw(in:)` 排版。实际栅格显示 Reader 文字相对 PDF 系统性下移；多行内容页误差最高达到 A4 `85.887 pt`、Letter `75.016 pt`。这直接违反 P-002 `≤1 pt` 与 P-003 文字换行/分页一致要求。

### QA-V2-006 — P0：目录页存在 Reader-only 页面内浮层

`AlbumPagesPreview` 在包含 `.contents` 的页面组上，以与 `ReaderPageSpread` 同一 `ZStack` 的 sibling 叠加 `ReaderContentsOverlay`。该浮层位于页面可见区域内，XCUITest 的元素截图采集到的是用户实际看到的合成像素；它不是纸张边界裁剪产生的伪影。PDF render plan 没有该元素，因此预览第 3 页与导出必然不同。

## 5. GF-01～GF-04 与 20 本质量证据审计

仓库未发现规定的 GF-01～GF-04 完整 artifact，也未发现 20 本逐本评分表。现有 deterministic visual fixture、manifest 和单元测试不能替代以下证据。

| 项目 | 当前状态 | 可自动完成 | 真实依赖 |
| --- | --- | --- | --- |
| GF-01：12 张、3 章、近重复 | 缺正式 fixture/全模板成品 | 可自动生成非个人素材、JSON、5×2 Preview/PDF、去重与结构断言 | 设计对真实观感签字 |
| GF-02：112 张、4 章、复杂比例/低清 | 缺正式 fixture、性能证据 | 可自动化文档构建、分页、导出耗时基线 | 真机 PhotoKit、热状态、内存峰值、取消/恢复手感 |
| GF-03：3 张最小成册 | 缺正式 fixture | 可完整自动化不复制、不虚构章节、Preview/PDF | 仅最终审美签字 |
| GF-04：缺失/敏感/排除/隐藏/长文本 | 缺正式 fixture/四层零泄漏包 | 可自动化模型过滤、Book Check、PDF 对象/缩略图/页面零泄漏 | 真机权限变化、iCloud/缺失 asset 恢复 |
| 20 本自动成册 ≥70% 无需结构重做 | 无逐本证据 | 可自动检查重复、泄漏、页数、结构、溢出、导出成功 | 产品/设计/QA 对真实或合法授权样本进行盲评；“感人、精美、无需结构重做”不能由代码替代 |

## 6. 门禁结论与下一步

1. 当前 **P-002/P-003 不通过**，QA-V2-005、QA-V2-006 均为阻断“预览=导出”的 P0。
2. 修复后必须使用同一份已序列化 document/revision，同时驱动 Preview/FinalPreview 和 Letter/A4 PDF；不得只用两次独立 fixture 构建推断同 revision。
3. 视觉 fixture 必须增加非零 rotation、相互遮挡的不同 zIndex 元素、连续字号、长文本、RTL/emoji，以及 Fit/Fill；逐元素框误差目标 `≤1 pt`。
4. GF-01～GF-04 可先由自动 fixture 补齐；GF-02 真机性能、GF-04 权限/缺图、20 本审美评分保留为真实依赖。

## 7. 2026-07-21 第二轮 canonical paper typography 复测

研发将 11pt 打印下限改为按 canonical paper size 计算，再缩放到 Reader。本轮使用以下全新证据，未复用第 1～6 节的旧截图/PDF：

- Reader/FinalPreview UI：`/tmp/TailorP0005UI.xcresult`，2/2 通过；14 张附件来自 `/tmp/TailorP0005UIAttachments`。
- 隔离 PDF：`/tmp/TailorP0005PDF/Logs/Test/Test-Tailor-2026.07.21_02-55-24-+0800.xcresult`，1/1；对应 Warm Paper PDF/raster/manifest 已固化到 `rerun_canonical/pdf/`。
- 同一序列化 revision：`testVisualQAFixtureUsesOneSerializedRevisionAndCoversHardRenderGeometry` 独立复跑 1/1，通过两次相同 bytes 解码后的 document、render manifest 和 export snapshot fingerprint 相等；xcresult：`/tmp/TailorV2QARecheckDerivedData/Logs/Test/Test-Tailor-2026.07.21_02-59-38-+0800.xcresult`。
- FinalPreview 独立路径：`testVisualFixtureAlsoFeedsFinalPreviewAndKeepsNavigationOffPaper` 1/1；xcresult：`/tmp/TailorV2QARecheckDerivedData/Logs/Test/Test-Tailor-2026.07.21_02-53-41-+0800.xcresult`。
- 运行边界：重型 PDF 测试与全套同进程执行时曾被 SIGKILL；拆成隔离 PDF 1/1 与其他 117/117 后通过。因此不能把 SIGKILL 隐去，也不能将隔离通过描述为“全套同跑通过”。

### 7.1 冻结证据

- [未配准原始 metric](rerun_canonical/comparison_metrics_raw.json)
- [仅全页刚性原点配准后的 metric](rerun_canonical/comparison_metrics_registered.json)
- [A4 contact sheet，左 Reader / 右 PDF](rerun_canonical/contact_sheets_registered/reader-left_pdf-right-a4.jpg)
- [Letter contact sheet，左 Reader / 右 PDF](rerun_canonical/contact_sheets_registered/reader-left_pdf-right-letter.jpg)
- [PDF 直接栅格到 Reader 像素尺寸的交叉检查](rerun_canonical/comparison_metrics_exact_registered.json)
- 原始 Reader、PDF、7 页 raster 和 manifest 均位于 `rerun_canonical/`。

比较仍保持 `≤1 pt`，未降低阈值。唯一配准是每页统一的 x/y 刚性平移，用于消除 XCUI accessibility element screenshot 将容器边距及像素取整带入页面原点的问题；没有非等比缩放、局部变形或逐元素对齐。

| 纸张 | 原始图片最大误差 | 原始文字最大误差 | 刚性配准后图片残差 | 刚性配准后文字残差 | 结论 |
| --- | ---: | ---: | ---: | ---: | --- |
| A4 | 0.769 pt | 1.538 pt | 0.769 pt | **2.307 pt** | 文字失败 |
| Letter | 0.723 pt | 2.170 pt | 0.723 pt | **1.447 pt** | 文字失败 |

刚性 registration（像素）：

- A4 第 1～7 页：`(0,0) (1,-1) (1,0) (0,0) (0,1) (0,1) (0,-2)`；单轴最大 `1.538 pt`，属于截图页面原点不确定性。
- Letter 第 1～7 页：`(1,0) (1,1) (1,-1) (1,0) (1,0) (1,0) (1,-2)`；单轴最大 `1.447 pt`。

配准后图片仍通过、文字反而保留 1.447～2.307pt 残差，说明这不是整页原点误差，而是文字相对图片的实际栅格边界/基线漂移。典型失败元素：

- A4 dedication 正文 `...0721`：2.307pt；包含 RTL Arabic、ZWJ family emoji、CJK、combining grapheme 和显式换行。
- A4 photoSelection 标题 `...0780`：2.307pt。
- A4 milestone 标题 `...0800`：2.307pt。
- Letter 多个标题/正文边界稳定为 1.447pt。

直接将 PDF 栅格到 Reader 像素尺寸的交叉检查也没有把文字残差压到 1pt 内（A4 2.307pt、Letter 2.170pt），因此不能归因于先生成 2160px PDF raster 再缩小这一条路径。

### 7.2 覆盖项结论

| 项目 | 结果 |
| --- | --- |
| 同 serialized revision | 通过：相同 bytes、document、manifest、snapshot fingerprint 的独立测试 1/1。证据文件自身仍未增加 fingerprint 字段，链路由测试及固定 ID/updatedAt 证明。 |
| Preview / FinalPreview | 通过路由测试；两者消费相同页面组件。 |
| 目录 overlay | **通过并关闭 QA-V2-006**：第 3 页截图无纸内浮层；FinalPreview 断言 `Reader contents` 不存在于页面，外部 `Contents` 按钮仍存在。 |
| Fit / Fill | 第 5 页同时覆盖；图片框残差 A4 ≤0.769pt、Letter ≤0.723pt。 |
| rotation / zIndex | 封面 6°；第 5 页 -8°/+12° 且有重叠 z-order；contact sheet 合成顺序一致，图片几何通过。 |
| 连续字号 | dedication `textFontScale = 1.137` 实际进入两端；整体字号比例问题已修复，但文字边界仍超过 1pt。 |
| RTL / emoji / CJK / combining / wrap | 第 2 页真实覆盖；字符、显式换行及行序一致，A4 该正文边界残差 2.307pt，故不能签文字像素门禁。 |
| 五模板回归 | 五模板×双纸张×7 页 PDF 隔离生成通过；仅 Warm Paper 有 Reader/PDF 三联，不能外推为五模板 Reader 三联通过。 |

### 7.3 缺陷状态

- **QA-V2-005：保持 P0 开放。** 第一轮 11～86pt 系统偏移已消失，canonical 字号修复有效；但严格栅格门禁仍剩 A4 2.307pt、Letter 1.447pt 文字残差，超过 `≤1pt`。
- **QA-V2-006：关闭。** Preview 和 FinalPreview 均证明 Contents 导航移出纸内，PDF/Reader 页面内容一致。

当前最终结论仍为：**P-002/P-003 不通过，不能签署 FinalPreview 与 A4/Letter PDF 一比一。**

## 8. 2026-07-21 第三轮 canonical CoreText shaping 复测

Reader 改为在规范 A4/Letter page spec 上使用与 PDF 相同的 CoreText shaping/hinting，再由 `CGContext` 对整页做一次等比缩放；PDF 保持 `scale = 1`。本轮严格复用第 7 节冻结的脚本、元素框检测和 `≤1 pt` 阈值，没有修改比较方法。

### 8.1 证据与运行边界

- Reader UI：`/tmp/TailorP0005CanonicalUI.xcresult`；14 张附件来自 `/tmp/TailorP0005CanonicalUIAttachments`。
- 同 revision PDF：沿用固定 fixture revisionDate/ID 且 PDF renderer canonical scale 为 1 的第 7 节 PDF 证据；第三轮只改变 Reader 的 canonical CoreText 缩放路径，PDF 输出内容未改变。
- [未配准原始 metric](rerun_canonical_v3/comparison_metrics_raw.json)
- [仅全页刚性原点配准后的 metric](rerun_canonical_v3/comparison_metrics_registered.json)
- [A4 contact sheet，左 Reader / 右 PDF](rerun_canonical_v3/contact_sheets_registered/reader-left_pdf-right-a4.jpg)
- [Letter contact sheet，左 Reader / 右 PDF](rerun_canonical_v3/contact_sheets_registered/reader-left_pdf-right-letter.jpg)
- 原始 Reader、配对 PDF、raster 和 manifest 位于 `rerun_canonical_v3/`。
- 第三轮完整回归由研发报告为 build、117/117、隔离 PDF 1/1 通过；重型 PDF 与全套同进程曾 SIGKILL 的历史运行边界继续保留，不能表述成单次全套通过。

### 8.2 冻结数值

| 纸张 | 原始图片最大误差 | 原始文字最大误差 | 刚性配准后图片残差 | 刚性配准后文字残差 | 结论 |
| --- | ---: | ---: | ---: | ---: | --- |
| A4 | 0.769 pt | 1.534 pt | 0.769 pt | **1.537 pt** | 文字失败 |
| Letter | 0.723 pt | 2.170 pt | 0.723 pt | **1.447 pt** | 文字失败 |

刚性 registration（像素）：

- A4 第 1～7 页：`(1,0) (1,0) (1,0) (0,0) (0,0) (0,0) (0,0)`。
- Letter 第 1～7 页：`(1,0) (1,1) (1,0) (1,0) (1,0) (1,0) (1,0)`。

第二轮的多处 1.447～2.307pt 文字残差已收敛为两个孤立边缘：

- A4 第 3 页标题 `...0740`：`1.537 pt`。Reader/PDF 四边分别只差约 `1/1/2/1` 个 Reader 像素，换行、基线和整体位置没有出现结构性分歧。
- Letter 第 1 页副标题 `...0701`：`1.447 pt`。x/y/高度一致，仅右侧 glyph raster bbox 相差 2 个 Reader 像素。

这两项表现为低分辨率 Reader 截图中的单个 glyph 边缘两像素 bbox 量化/hinting 残差，而不是上一轮那种相对图片的整体基线、字号或换行布局漂移。但冻结门禁按实际检测框最大误差判定，不能因推断为栅格量化而豁免，因此仍按失败处理。

### 8.3 缺陷状态

- **QA-V2-005：保持 P0 开放。** 第三轮 canonical CoreText shaping 显著收敛差异，但 A4 `1.537 pt`、Letter `1.447 pt` 仍超过严格 `≤1 pt` 门禁。
- **QA-V2-006：保持关闭。** 本轮没有重新引入 Reader-only contents 页面内浮层，第二轮 FinalPreview 独立回归结论继续有效。

当前最终结论仍为：**P-002/P-003 不通过；不能在 `≤1 pt` 的既定门禁下关闭 QA-V2-005。**

## 9. 2026-07-21 第四轮高分辨率 canonical text raster 复测

Reader 将 canonical 文字先在约 2160px 长边的离屏 raster 中绘制并缓存，再统一缩放到页面。QA 使用 `/tmp/TailorP0005RasterUI.xcresult` 与 `/tmp/TailorP0005RasterUIAttachments` 的 14 张新 Reader 截图，配对固定 fixture/revision 的既有 PDF；严格复用冻结 `compare_triple_render.py` 和 `≤1 pt` 阈值，没有调整检测、registration 或容差。

### 9.1 证据

- [未配准 raw metric](rerun_canonical_v4/comparison_metrics_raw.json)
- [仅全页刚性 registration metric](rerun_canonical_v4/comparison_metrics_registered.json)
- [逐元素 registered bbox](rerun_canonical_v4/element_bbox_registered.md)
- [A4 contact sheet，左 Reader / 右 PDF](rerun_canonical_v4/contact_sheets_registered/reader-left_pdf-right-a4.jpg)
- [Letter contact sheet，左 Reader / 右 PDF](rerun_canonical_v4/contact_sheets_registered/reader-left_pdf-right-letter.jpg)
- Reader、PDF、raster 和 manifest 均固化在 `rerun_canonical_v4/`。

### 9.2 冻结数值

| 纸张 | Raw image max | Raw text max | Registered image max | Registered text max | 判定 |
| --- | ---: | ---: | ---: | ---: | --- |
| A4 | 0.769 pt | 1.534 pt | 0.769 pt | **1.538 pt** | 文字失败 |
| Letter | 0.723 pt | 2.170 pt | 0.723 pt | **1.447 pt** | 文字失败 |

Registered 逐元素统计：

- A4：6/6 个可检测图片元素通过；10 个可检测文字元素中 9 个通过、1 个失败；另 4 个低对比辅助文字元素在冻结颜色检测器下为 N/D，未计为通过。
- Letter：6/6 个可检测图片元素通过；10 个可检测文字元素中 6 个通过、4 个失败；另 4 个低对比辅助文字元素为 N/D。
- A4 失败：第 3 页 contents 标题 `...0740 = 1.537900 pt`。
- Letter 失败：第 1 页 `...0701 = 1.446809 pt`、`...0700 = 1.446809 pt`；第 2 页 `...0720 = 1.446575 pt`；第 7 页 `...0820 = 1.446809 pt`。

全页刚性 registration 像素：

- A4：`(1,0) (1,0) (1,1) (0,0) (0,0) (0,0) (0,0)`。
- Letter：`(1,0) (1,1) (1,0) (1,0) (1,0) (1,0) (1,0)`。

第四轮仍主要剩余单边 2 个 Reader 像素的 glyph bbox/hinting 残差，没有重新出现早期的字号、换行或整体基线系统偏移。但冻结门禁以实际逐元素框最大误差判定，不因肉眼接近或推断为量化而豁免。

### 9.3 锐度与资源风险观察

- Contact sheet 在当前 UI 截图尺度下文字可读，未观察到明显整行模糊、重影、裁断或换行变化；这一观察不替代原尺寸设计签字。
- Reader XCUI 证据本身为 `786×1296`，无法仅靠截图证明 2160px 离屏 raster 在不同真机 scale 下始终优于直接 CoreText，也不能替代印刷尺度检查。
- A4 约 `1524×2160` 的 32-bit RGBA 单页缓冲理论占用约 12.6 MiB；如果多页 raster、缩放中间层和解码缓存同时常驻，峰值会按页数和副本数增加。当前未提供真机峰值内存、cache eviction、后台/thermal、长书快速翻页证据，因此记录为性能风险，不作为本轮几何门禁的替代结论。

### 9.4 缺陷状态

- **QA-V2-005：保持 P0 开放。** A4 `1.538 pt`、Letter `1.447 pt` 仍超过 `≤1 pt`。
- **QA-V2-006：保持关闭。** 第四轮未涉及或重新引入 contents 页面内浮层。

当前结论：**第四轮仍不能签署 P-002/P-003，也不能关闭 QA-V2-005。**

### 9.5 回滚与当前最佳证据

第四轮相对第三轮没有降低最大误差：A4 仍约为两个 Reader 像素；Letter 的超限可检测文字从第三轮 1 个增加到第四轮 4 个，同时引入约 2160px 离屏 raster 缓存的内存风险。因此研发已撤回第四轮离屏缓存实现，恢复第三轮共享 CoreText canonical draw。

- `rerun_canonical_v4/` 继续作为失败方案的不可变回归证据，不代表当前代码实现。
- 当前代码最佳证据恢复为 `rerun_canonical_v3/`：A4 仅第 3 页标题 `1.537 pt`，Letter 仅第 1 页副标题 `1.447 pt`，各为一个单边约 2 Reader pixel 残差。
- 回滚不等于门禁通过：**QA-V2-005 继续保持 P0 开放，阈值和冻结脚本均不变。**
