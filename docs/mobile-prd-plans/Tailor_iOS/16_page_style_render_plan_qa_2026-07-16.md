# Tailor PageStyle / RenderPlan P0-1 测试方案

> 角色：测试验收负责人  
> 状态：**待研发接入共享 PageStyle / RenderPlan 后执行；当前为不通过（渲染消费方与测试基线尚未接通）**  
> 依据：编辑器 PRD §6–§8、§12.2；设计规格 `design/editor_v1/design_spec.md` §1、§3.6、§5；编辑器测试计划 RND-001…008。

## 1. 验收对象与不可降级的前提

P0-1 的对象不是“PDF 能生成”，而是同一份冻结的 `MemoryBookDocument` 在 SwiftUI 阅读预览和 PDF 中产生相同的页面语义与布局。研发提交必须提供下列可测试边界：

```text
MemoryBookDocument + PageStyle + AssetImageProvider
              ↓
          PageRenderPlan[]       // 不可变、按页、可序列化的渲染指令
            ↙              ↘
 SwiftUI PageRenderer      PDF/Quartz PageRenderer
```

`PageRenderPlan` 至少可供测试读取：页面尺寸/安全区、页面背景/水印、元素按 z-index 排序后的 frame、文本样式与已测量行布局、图片 assetID、Fill 裁剪变换、旋转、模板装饰与滤镜指令。不得由 PDF renderer 再次按章节选片或再次计算版式。

测试入口必须支持注入：

- `AssetImageProvider`：由测试提供确定性的本地 `CGImage`，不能依赖 Simulator demo 空 `localIdentifier` 或真实用户照片。
- PDF 输出目录：测试专用临时目录。
- `PageStyle` / `PageRenderPlan`：可直接构造，避免仅透过 UI 点击间接验证。
- SwiftUI 阅读页的无编辑 chrome 渲染入口，返回同一目标页面比例的图像。

没有这些注入点，以下测试只能标记为 **BLOCKED**，不能以人工截图、PDF 文件头或模拟数据文案替代。

## 2. 固定 Fixture

`RenderPlanFixtureBook` 以六类页组成 6 页文档；图片均为测试内生成的彩色象限/编号图（含横图、竖图、近边缘焦点），并记录 SHA-256：

| 页 | 类型 | 必须覆盖的渲染条件 |
| --- | --- | --- |
| 1 | cover | 背景、标题/副标题/年份、单图 Fill |
| 2 | contents | 目录文本、无图片、安全区与页码 |
| 3 | chapter opener | 标题、日期、备注、局部 style override |
| 4 | photo single | 非整数 frame、cropScale/cropOffset、+15° 旋转 |
| 5 | photo diptych | 两张横竖图、重叠 z-index、-15°、Small/Default/Large 文本 |
| 6 | photo mosaic/note/closing | 2×2 或 3×2、用户注记、Film 日期区、结尾文本 |

另建 `RenderPlanWatermarkFixtureBook`（至少 10 页、2 个日期时期）验证免费样章的 6–8 页选择；`MissingAssetFixtureBook` 验证在生成 render plan 前阻断。

## 3. 最小自动化集

### A. 结构与同源契约（每次 PR 必跑）

| ID | 断言 | 通过条件 |
| --- | --- | --- |
| RP-001 | 单一 document → preview/PDF 获取同一 `PageRenderPlan` 序列 | 页数、pageID、assetID、元素数、zIndex 次序、styleID、watermark 标志完全相同 |
| RP-002 | 归一化坐标在 A4/Letter 映射 | element 边界的相对坐标不变；只发生目标纸张物理缩放 |
| RP-003 | 图片 Fill 变换 | 容器内不露白；assetID、cropScale/offset、rotation、zIndex 与 plan 相同 |
| RP-004 | 文本排版 | 3 档字号、对齐、line breaks 与 `RenderPlan` 的已测量行完全一致；超长文本产生 blocking issue |
| RP-005 | 模板 | Warm Paper / Quiet Night / Field Notes / Cinema / Film Album 均有完整 `PageStyle`；全册切换不改变用户元素，单页 override/restore 只影响目标页 |
| RP-006 | 安全与水印 | 7% 安全区、模板装饰不可成为 element；免费样章为 6–8 页、每页重复 `TAILOR · PREVIEW`；已购全册无水印 |
| RP-007 | 出错 | missing/unauthorized asset 在 plan 或导出准备阶段 blocking；PDF renderer 不可 `continue` 后成功出缺图页 |
| RP-008 | 冻结快照 | PDF 开始后修改 document 不影响当前 PDF；下一次导出才使用新 plan |

建议测试文件：`TailorTests/PageStyleRenderPlanTests.swift`、`TailorTests/PDFRenderContractTests.swift`。A 组不依赖真机；应在 iOS 17 simulator 与当前 simulator 都跑。

### B. 像素一致性（5 模板 × 2 纸张 × 6 页 = 60 页对）

对每一个 `style ∈ {warm, quiet, field, cinema, film}`、`paper ∈ {A4, US Letter}`：

1. 由同一冻结 fixture 建 plan；渲染无编辑 chrome 的 SwiftUI 预览图。
2. 导出 PDF；使用 `CGPDFPage` / Quartz（或固定版本 Poppler）栅格化到与预览相同的页面像素尺寸。
3. 归一化外部阴影、设备 status bar 与无关背景；页面内容区以同一纸张矩形对齐。
4. 输出 preview PNG、PDF、PDF PNG、overlay、heatmap、`metrics.json` 到：
   `artifacts/editor-render/<git-sha>/<fixture>/<style>/<paper>/`。

`metrics.json` 必含 pageID、assetID、frame、crop transform、rotation、text line boxes、z-index order、background alpha、像素差统计与判定。

### C. 免费样章边界（额外 10 页 PDF/预览）

`RP-009`：免费状态只渲染 6–8 页，包含封面、目录、至少两个时期、照片页、结尾；每页有重复水印。`RP-010`：已购状态全册无水印。两者仍必须以同源 plan 检查页序/assetID。

## 4. PRD §7.3 判定阈值

| 指标 | 测法 | Pass |
| --- | --- | --- |
| 页面完整性 | alpha/背景扫描 + page ID | 0 张透明、黑、空白、重复、缺图、错序页 |
| 元素几何 | plan/preview/PDF 提取元素边界 | 与 preview 的边界误差 ≤ 页面长边 0.5% |
| 图片焦点 | fixture 标记点经过 crop/rotate 后的位置 | 与 preview 的差异 ≤ 图片容器短边 1% |
| 文本 | font token、line box、行字符串、对齐 | 完全一致；任何换行、可见字符或字号档不同即 FAIL |
| 层级 | 重叠 fixture 的像素采样 + zIndex 序列 | 前景/背景次序完全一致 |
| 视觉 diff | 在文本/照片算法的抗锯齿边界作 1 px mask 后 | 非抗锯齿区域不得存在可解释外差异；先以上述语义指标为准，不能只用“平均像素差低”放行 |

Cinema/Film 的风格测试除比对一致性外，必须验证 Cinema 本地低饱和/黑白指令、Film 边框和日期区实际出现；不能只比较两张同样错误的渲染图。

## 5. 当前可直接执行性与判定

| 检查 | 当前状态 | 判定 |
| --- | --- | --- |
| 完整现有 XCTest/UI test | 可跑；最近证据为 Simulator 48/48 | 仅基础回归 PASS |
| `PageStyleRenderPlanTests` | 当前仅有 `MemoryBookPageStyle` / `MemoryBookPageRenderPlan` 的基础类型；尚无 preview/PDF 的共同消费、测试 `AssetImageProvider` 或专项测试 target | BLOCKED（不是 PASS） |
| 60 页 preview/PDF raster diff | 当前没有共享可测 plan、无固定图片 fixture、无结果目录/metrics harness | BLOCKED |
| PDF 可读性 | 现有 `testLocalPDFExporterWritesValidPDF` 只验证 `%PDF`、且传入空 photos | 不构成 P0-1 证据 |
| 真机最终验收 | 真机当前 unavailable，且没有真实 Photos fixture | BLOCKED |

### 5.1 本轮执行记录（2026-07-16）

- 研发已增加 `MemoryBookPageStyle` 与 `MemoryBookPageRenderPlan(page:document:pageSize:)`，并让编辑画布和 `LocalPDFExporter` 消费基础纸张、边距、风格和 `orderedElements` 合同。
- 独立执行 `testSharedPageRenderPlanKeepsPaperGeometryAndTemplateRulesPlatformIndependent`：**1/1 通过**。结果包：`/tmp/tailor-p01-contract-tests/Logs/Test/Test-Tailor-2026.07.16_13-20-32-+0800.xcresult`。
- 这只关闭“基础共享几何/样式/元素排序合同”的回归检查，**不关闭** PRD §7.3 或 G-EDITOR-03。

因此正式 P0-1 的视觉验收结论仍为：**不通过 / 未具备可复现的视觉自动化前置条件**。缺少确定性 `AssetImageProvider`、冻结 `PageRenderPlan[]`、预览/PDF 栅格化与 metrics 产物；免费样章水印也尚未进入共享合同。研发完成这些前置后，先执行 A 组；A 组全绿后执行 B/C。任一组合失败即 P0-1 不通过，不能以其余模板通过抵消。

## 6. 执行命令（研发接入后）

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project Tailor.xcodeproj -scheme Tailor \
  -destination 'platform=iOS Simulator,id=41F93DB0-C75A-4044-BD9D-C7D90D00FE9B' \
  -derivedDataPath /tmp/tailor-renderplan-tests \
  test -only-testing:TailorTests/PageStyleRenderPlanTests \
  -only-testing:TailorTests/PDFRenderContractTests
```

在同一 Git SHA 下再执行全量 48+ 测试；生成的 artifact 路径、XCTest result、PDF hash 和 metrics 必须一起归档。真机仅在这些自动化通过后进行 5 模板 × A4/Letter 的真实 Photos 抽检；真机不能替代可复现 fixture 的基线测试。
