# P0-1 共享 PageStyle / PageRenderPlan 验收用例与证据模板

> 状态：待研发交付后执行；本文件不以现有测试通过替代视觉发布门禁。  
> 对应：[P0-1 最小实施计划](16_p0_shared_page_style_render_plan_2026-07-16.md)、[编辑器 PRD §7.1、§7.3](14_life_album_page_editor_v1_PRD_2026-07-15.md)。  
> 范围：共享背景、纸张/安全区、字体 token、Cinema/Film 装饰、归一化元素映射；不签收裁剪交互、页面管理或资产异常等后续 P0。

## 1. P0-1 签收结论规则

P0-1 只有同时满足下列三层证据时才能标记为“通过”。任一层失败即退回研发；不得因模拟器截图看起来相近而豁免。

| 层级 | 通过条件 | 证据责任 | 结论性质 |
| --- | --- | --- | --- |
| A. 共享契约 | `MemoryBookPageStyle.resolve` 与 `MemoryBookPageRenderPlan` 是五模板、A4/Letter、元素几何/排序、字体及装饰的唯一解析入口。Editor、Reader Preview、PDF 均从该计划消费。 | 研发源码审计 + 单元测试 | 可自动化、阻断 |
| B. 可运行语义 | 同一固定文档在编辑画布、阅读预览与 PDF 具有相同页序、paper rect、元素 frame/z-index、文字 token、模板装饰；未购页有水印，已购 PDF 无水印。 | QA 自动化 + Simulator | 可自动化、阻断 |
| C. 视觉保真 | 5 模板 × A4/Letter × 页面类型，PDF 与阅读预览按 PRD §7.3 栅格化比对达标；Cinema/Film 用真实本地图片在实体机核验。 | QA + 设计 + 真机/PDF 热图 | 发布门禁；本次 P0-1 可先记录为“待真机视觉关闭”，不可声称全量发布通过 |

### 1.1 不可接受的替代证据

- 仅断言 `%PDF` 文件头、页数或某个按钮存在。
- 仅证明 `MemoryBookDocument.pages` 被传入，而未证明三端读取同一 `PageRenderPlan`。
- 使用空 `localIdentifier`、占位色块或模拟器 demo 替代 Cinema/Film 的真实照片证据。
- 用“系统字体不同”解释标题/正文换行、字号等级或可见内容不一致。

## 2. 固定验收夹具

`F-RP-01` 必须在测试 target 可稳定构造，不依赖用户 Photos；它用于契约和 PDF 结构测试。真机视觉用 `F-RP-REAL`（QA 本地导入、不提交个人照片）。

| 页面类型 | F-RP-01 页面内容 | P0-1 验收点 |
| --- | --- | --- |
| cover | 标题、宠物名、单张横图 | backdrop / paper、display font、单图裁剪 |
| dedication | 多行短文本、无图 | body font、行距、纸张安全区 |
| contents | 目录文字与页码 | text token、对齐、可见页码 |
| chapterOpener | 日期、标题、单张竖图 | 标题/正文层级、归一化 frame |
| photoSelection | 两张互相覆盖图片，非整数 frame、不同 crop、`-15°/+15°`、不同 z-index | frame/crop/rotation/z-index 排序 |
| milestone | 一张图 + 注记 + 日期 | Film 日期/注记区；Cinema 图像处理 |
| closing | 多行结尾文字 | body font、边距、无额外图片框 |

所有夹具页面的元素 ID、asset ID、文本和数值必须固定，并在测试失败日志中输出 `RenderPlan` 摘要（style、paper、paperRect、safeRect、font token、decoration、ordered element IDs）。

## 3. 自动化验收用例

### 3.1 模型与源码共享契约

| ID | 前置/操作 | 通过条件 | 自动化证据 |
| --- | --- | --- | --- |
| RP-UNIT-001 | 对 `Warm Paper`、`Quiet Night`、`Field Notes`、`Cinema`、`Film Album` 分别 `resolve`。 | 每套生成非空、确定性的 RGB、paper inset/safe rect、标题/正文 token；五套 token 不以 PDF/SwiftUI 分支另行定义。 | `PageStyleTests`，快照/等值断言 |
| RP-UNIT-002 | A4 和 Letter 分别生成 `RenderPlan`。 | page size 正确；paperRect/safeRect 在页面内；归一化元素映射只随纸张物理比例变化；没有分散的 18pt/inset 常量。 | `PageRenderPlanTests` + 源码 grep 审计 |
| RP-UNIT-003 | 用 F-RP-01 的 photoSelection 页面解析 plan。 | ordered elements 严格按 `(zIndex, stable tie-breaker)`；frame/crop/rotation/textStyle 完整保留。 | 纯模型单测 |
| RP-UNIT-004 | 将同一 `RenderPlan` 交给 Editor、Reader Preview、PDF adapter。 | 三端 adapter 接收同一个计划类型/字段；不得分别重新调用 `palette(for:)`、字体选择或 paper inset。 | 编译期接口测试 + 源码审计 |
| RP-UNIT-005 | Cinema / Film plan。 | Cinema 有唯一确定的本地 monochrome 指令；Film 有页面边框与图片框/日期区指令；二者不改变原 asset ID 或 crop 数据。 | 纯模型单测 |
| RP-UNIT-006 | `watermarked = true/false`。 | 同一 base plan 仅增加/去除水印层；内容元素、paperRect、字体、装饰、页序保持不变。 | 纯模型单测 |

**源码审计固定命令（研发交付后执行）：**

```bash
rg -n "MemoryBookPageStyle|MemoryBookPageRenderPlan|PageRenderPlan" Tailor
rg -n "palette\\(for:|paperInset|18(\\.0)?" Tailor
```

第二条命令命中并不自动失败；QA 必须逐个判定是否位于唯一共享解析器。若命中 Editor、Preview 或 PDF 的独立 style/geometry 分支，则 `RP-UNIT-004` 失败。

### 3.2 运行时三端语义矩阵

每个格均必须运行；总计 **5 模板 × 2 纸张 × 7 页面类型 = 70 页**。Editor 的选中边框仅在编辑态存在，不纳入 PDF 差异。

| ID | 覆盖维度 | 操作 | 通过条件 | 自动化方式 |
| --- | --- | --- | --- | --- |
| RP-RUN-001 | 5 templates × A4/Letter × 7 types | 注入 F-RP-01，打开 Editor 画布、Reader Preview，导出 PDF。 | 三端 page index/type/ordered element IDs 相同；Editor 与 Reader 读取同一 plan。 | UI/集成测试 + render manifest |
| RP-RUN-002 | 同上 | 从 manifest 比较 `paperRect`、`safeRect`、每元素 physical rect、rotation、crop、font token。 | Editor/Reader/PDF 的记录逐字段等值（浮点允许 `1e-6`）。 | 集成测试 |
| RP-RUN-003 | 5 templates × 2 papers | 以 `watermarked=true` 生成未购样章；以 false 生成已购输出。 | 未购每页包含 `TAILOR · PREVIEW` 重复低对比水印层；已购 PDF/全册预览完全无水印；base content 不变。 | PDF text/graphics manifest + UI accessibility |
| RP-RUN-004 | Cinema × A4/Letter；Film × A4/Letter | 使用 F-RP-REAL 的高/低亮度图。 | Cinema 在 Editor/Reader/PDF 均为同一单色/低饱和视觉规则；Film 三端均有相同页面边框、图片框、日期区。 | 真机截图 + PDF 栅格化；不得用仅模型断言代替 |
| RP-RUN-005 | 5 templates × 2 papers | 同一文档切换 paper size 和模板。 | 只改变 plan 中允许变化的 token/物理映射；asset ID、normalized frame、crop、rotation、z-index、文本和页序不变。 | 文档 diff + 集成测试 |

## 4. PDF 栅格化与设计签核

### 4.1 必须产出

对 `RP-RUN-001` 的每一个组合，保留下列目录：

```text
artifacts/editor-render/<build>/<fixture>/<template>/<paper>/<page-kind>/
  editor.png
  reader-preview.png
  exported.pdf
  pdf-raster.png
  normalized-preview.png
  diff-heatmap.png
  manifest.json
  result.md
```

`result.md` 至少记录 page number、实际纸张尺寸、paper/safe rect、比较分辨率、元素边界最大误差、图片焦点最大误差、文本行盒对比、水印状态和判定人。

### 4.2 判定阈值（直接引用 PRD §7.3）

| 项目 | 通过标准 | 失败示例 |
| --- | --- | --- |
| 元素位置 | 边界误差 ≤ 页面长边 0.5% | 不同 paper inset、frame 偏移、错层 |
| 图片焦点 | 差异 ≤ 图片容器短边 1% | crop offset、scale 或 rotation 不同 |
| 文字 | 换行、字号等级、对齐、可见文本完全一致 | 系统字体替换、字距/行距不同、截断 |
| 视觉结构 | 背景、边框、Film 日期区、Cinema 效果、水印、页序一致 | 黑/透明/空白/重复页，装饰缺失或多出 |

设计师签核只针对 `normalized-preview.png` 与 `pdf-raster.png`，不得仅查看 iPhone 整屏截图；QA 负责数值阈值，设计负责 token 与视觉规则是否正确。

## 5. 真机 / 手工验证清单

| ID | 环境 | 操作 | 预期 | 证据 |
| --- | --- | --- | --- | --- |
| RP-MAN-001 | 实体 iPhone，F-RP-REAL | 每套模板分别在 A4/Letter 打开 Editor、进入阅读预览、导出。 | 纸张比例、背景、边距、字体和装饰无跳变；页面翻动后仍一致。 | 每组合录屏 + PDF |
| RP-MAN-002 | 实体 iPhone，Cinema | 高亮、暗部、彩色背景宠物图分别检查三端。 | 同一图像视觉处理一致，原图未被写回/修改。 | Photos 原图截图 + Editor/Preview/PDF |
| RP-MAN-003 | 实体 iPhone，Film | 含长日期、短日期、无日期页。 | 边框和日期/注记区一致，不遮挡图片/文字。 | 页面截图 + PDF |
| RP-MAN-004 | 真实未购与已购/Debug 明确绕过 | 查看样章并导出对应文件。 | 免费仅水印样章；完整 PDF 无水印；不存在“免费 PDF 无水印”或“已购 PDF 残留水印”。 | 录屏 + 两份 PDF |

## 6. P0-1 交付证据模板

研发交付后先填 A，QA/设计分别填 B/C。未填项按未通过处理。

```markdown
# P0-1 验收记录

- Build SHA / 版本：
- 执行日期：
- 研发交付 PR / 变更范围：
- Fixture：F-RP-01 / F-RP-REAL
- 设备与 iOS：
- 是否 Debug purchase bypass（若是，配置/启动参数）：

## A. 共享契约（研发 + QA）
- `MemoryBookPageStyle.resolve` 定义位置：
- `MemoryBookPageRenderPlan` 定义位置：
- Editor 调用点：
- Reader Preview 调用点：
- PDF 调用点：
- 独立 palette / inset grep 命中及处置：
- RP-UNIT-001…006：通过 / 失败（附 xcresult 路径）

## B. 运行时语义（QA）
| template | paper | page kind | Editor plan | Preview plan | PDF plan | watermark | 判定 |
| --- | --- | --- | --- | --- | --- | --- | --- |

- RP-RUN-001…005：通过 / 失败（附 manifest 与测试路径）

## C. 栅格化与真机（QA + 设计）
| template | paper | page kind | edge error | focal error | text match | visual rule | artifact path | QA | 设计 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |

- Cinema / Film 真机结果：
- 未购/已购水印结果：
- 未关闭原因（如有）：

## 最终结论
- A 共享契约：通过 / 不通过
- B 自动化语义：通过 / 不通过
- C 发布视觉门禁：通过 / 待真机 / 不通过
- P0-1 可进入下一项：是 / 否
- 签名：研发 / QA / 产品-设计
```

## 7. 本轮退出条件

研发完成 P0-1 后，QA 的最小“可进入下一项”结论为：A 与 B 全绿、5×2×7 的产物目录齐全、设计已审阅至少每模板 A4/Letter 各一组代表页；C 的真实照片真机矩阵可标注“待设备可用后关闭”，但此状态不得解除最终发布门禁，也不得描述为“PDF 已一比一验证完成”。

## 8. 本轮执行记录（2026-07-16）

### 8.1 已独立验证的内容

- 源码调用链：`EditorBookPageCanvas`（编辑）与 `AlbumPagesPreview`（阅读）均走 `MemoryBookPageRenderPlan(page:document:pageSize:)`；`LocalPDFExporter` 亦以该 plan 绘制 page/paper、元素排序、字体及 Film 几何。
- 定向 XCTest 命令：

  ```bash
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
    -project Tailor.xcodeproj -scheme Tailor \
    -destination 'platform=iOS Simulator,id=41F93DB0-C75A-4044-BD9D-C7D90D00FE9B' \
    -derivedDataPath /tmp/tailor-p01-qa-final test \
    -only-testing:TailorTests/TailorFeatureTests/testSharedPageRenderPlanKeepsPaperGeometryAndTemplateRulesPlatformIndependent \
    -only-testing:TailorTests/TailorFeatureTests/testSharedPageRenderPlanResolvesEveryTemplateForBothPaperSizes \
    CODE_SIGNING_ALLOWED=NO
  ```

- 结果：**2/2 通过**；结果包为 `/tmp/tailor-p01-qa-final/Logs/Test/Test-Tailor-2026.07.16_13-41-31-+0800.xcresult`。该组覆盖五模板 × A4/Letter 的基础 token、paper geometry、Cinema 指令和 Film 几何，不能替代页类型或视觉用例。
- `git diff --check` 对本轮相关源码与文档通过。

### 8.2 未通过 / 未具备证据的项目

| 验收项 | 当前观察 | 结论 |
| --- | --- | --- |
| RP-UNIT-006 / RP-RUN-003 水印同源 | `AlbumPagesPreview` 仍在 plan 外硬编码单枚 `Text("PREVIEW")`；`LocalPDFExporter` 无 `watermarked` 输入或 PDF 水印层。 | **不通过** |
| 70 页运行时语义矩阵 | 没有 F-RP-01、render manifest 或 Editor/Reader/PDF 三端字段比较测试。 | **未执行 / 不通过** |
| 5 模板 × A4/Letter 栅格 diff | 没有 `artifacts/editor-render`、PDF raster、热图或 metrics。 | **未执行 / 发布门禁未关闭** |
| Cinema / Film 真机 | 没有 F-RP-REAL、真实 Photos 资产或可用实体设备证据。 | **待真机** |

### 8.3 QA 结论

**P0-1 基础共享几何/模板合同：条件通过（仅 A 的已实现子集）。**  
**P0-1 完整验收：不通过。** 研发需先把免费水印作为共享 render-plan 层，随后补 F-RP-01、70 页的 manifest 对照与 PDF 栅格化产物；完成后由 QA 复验。没有这些证据，不得将本轮描述为“预览/PDF 已一比一验证完成”，也不得解除 G-EDITOR-03 发布门禁。

### 8.4 返工复验（2026-07-16）

研发已补入 `MemoryBookWatermarkStyle.preview`、`MemoryBookRenderManifest`、F-RP-01（七种页面类型）及 PDF 的 `watermarked` 输入。独立执行三项定向测试：

```text
testSharedPageRenderPlanKeepsPaperGeometryAndTemplateRulesPlatformIndependent
testSharedPageRenderPlanResolvesEveryTemplateForBothPaperSizes
testRenderPlanFixtureKeepsEditorReaderAndPDFContractsEqualAcross70Pages
```

结果：**3/3 通过**；独立结果包：`/tmp/tailor-p01-qa-retest/Logs/Test/Test-Tailor-2026.07.16_13-49-51-+0800.xcresult`。源码也确认 Editor/Preview/PDF 都读取 watermark plan，PDF 在导出前冻结 manifest。

但复验发现一个不能以“待 raster”掩盖的源码偏差：SwiftUI watermark 使用 `.tracking(fontSize * 0.23)`，而 PDF 的 attributed string 未设置对应 `.kern`；字距既不在 `MemoryBookWatermarkStyle` 中，也未由 PDF 读取。其结果会直接改变水印文本宽度和居中位置。因此：

- RP-UNIT-006 / RP-RUN-003：**仍不通过**（须将 letter-spacing 纳入共享 watermark token，并在 PDF 使用 `NSAttributedString.Key.kern`）。
- 70 页 manifest 语义检查：**通过**（不等价于视觉像素验证）。
- 栅格 diff、真实 Photos 的 Cinema/Film 与真机门禁：**仍未执行，不通过发布门禁**。

截至本记录，P0-1 最终结论维持：**不通过；不得进入下一 P0 项或解除 G-EDITOR-03。**

### 8.5 字距返工复验（2026-07-16）

研发将 `letterSpacingRatio` 加入 `MemoryBookWatermarkStyle`；`MemoryBookPageRenderPlan.watermarkLetterSpacing()` 为两个端提供同一物理字距；SwiftUI 使用 `.tracking(letterSpacing)`，PDF 使用 `.kern: letterSpacing`。QA 已核对三处调用，未发现其他 watermark-specific 常量分支。

独立重跑 §8.4 的三项定向测试，结果：**3/3 通过**；结果包：`/tmp/tailor-p01-qa-kern/Logs/Test/Test-Tailor-2026.07.16_13-52-59-+0800.xcresult`。

**QA 分层结论：**

| 门禁层 | 结论 | 说明 |
| --- | --- | --- |
| A. 共享契约 | 通过 | 共享 PageStyle / RenderPlan、两纸张五模板、Film/Cinema 指令、共享水印/字距、冻结 manifest 均有源码及 3 项定向测试证据。 |
| B. 可运行语义 | 通过（合同级） | F-RP-01 覆盖 5 × 2 × 7 = 70 个 page-plan，验证排序、页面类型、水印/无水印、manifest Codable 与 paid/free 内容不变。 |
| C. 视觉保真与发布 | **不通过 / 未执行** | 尚无 PDF raster、热图、metrics 或真实 Photos 的 Cinema/Film 真机证据；它们不能由 manifest 相等或 unit tests 代替。 |

因此，研发可将 **P0-1 的共享渲染实现子任务** 标记为“代码与合同测试通过”，但产品/设计/QA 不签署“预览即成品”或 G-EDITOR-03；最终视觉门禁继续挂在 P0-C 的栅格化和真机验收项上。
