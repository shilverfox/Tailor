# P0-1 · 产品/设计复验记录（2026-07-16）

**依据：** [P0-1 签核单](p0_1_shared_render_signoff.md)  
**复验对象：** 当前工作区的 PageStyle、PageRenderPlan、编辑画布、阅读预览、PDF 导出器与 F-RP-01。  
**定向测试：** 3/3 XCTest 通过；结果包：/tmp/tailor-p01-qa-retest/Logs/Test/Test-Tailor-2026.07.16_13-49-51-+0800.xcresult。

## 结论

- **A. 共享渲染代码合同：条件通过。** Editor、Reader 与 PDF 已消费同一 PageRenderPlan / PageStyle；免费水印和 PDF 分支进入共同 plan；F-RP-01 对五模板 × A4/Letter × 7 页的字段合同通过。
- **B. 可运行语义：部分通过，尚未签收。** 断言是同一模型重复生成 manifest 后相等，尚未证明真实 Reader 与 PDF adapter 的逐字段记录/比对，也未导出 F-RP-01 PDF。
- **C. 栅格化和真机视觉：未执行，发布门禁不通过。** 没有 artifacts/editor-render、PDF raster、heatmap、metrics，实体机仍不可用。

因此，**P0-1 可作为“共享 RenderPlan 基线”进入下一项开发；不得标记为产品/设计完整通过，也不得解除“预览即成品”的发布门禁。**

## 签核项逐条复验

| 签核项 | 当前源码证据 | 结论 |
| --- | --- | --- |
| S-01 页面、背景、纸张 | PageStyle 提供 paper/backdrop；编辑画布和 PDF 都从 plan 绘制 pageRect/paperRect；Reader 复用画布。 | **代码通过；视觉待验证** |
| S-02 7% 安全区与保护层 | 交互拖动硬编码夹在 0.07…0.93，但 RenderPlan 未声明 safeRect / 保护层，也无 plan 断言。 | **不通过** |
| S-03 文字映射与行盒 | display 使用 Iowan Old Style token；正文仍是 SwiftUI / UIKit system font，plan 未携带正文 PostScript 映射、tracking、lineHeight 或 measured line boxes。 | **不通过** |
| S-04 图片变换与层级 | plan 固化 assetID/frame/crop/rotation/zIndex，按 (zIndex, UUID) 稳定排序；编辑器/PDF 均消费。 | **代码通过；真实图片/PDF待验证** |
| S-05 五模板 | 五套背景 token 都有；Cinema mono、Film 页面及图片框几何同源。Field Notes 日期标记与 Film 日期区域未成为 plan 装饰。 | **部分通过** |
| S-06 样章水印 | preview 水印固定两处重复对角 TAILOR · PREVIEW；Editor、Reader、PDF 均从 plan 绘制；付费 plan 无水印。 | **代码通过；样章范围/视觉待验证** |
| S-07 导出快照 | 导出开始时建立 renderManifest 并循环其 plans，后续编辑不会改已取出的值。没有导出中编辑自动化回归，也没有可归档 hash。 | **部分通过** |

## 已核对的测试覆盖

- F-RP-01：五模板 × A4/Letter × 7 页，断言页数、页 ID、元素排序和付费/免费水印字段。
- 共享 paper 几何、字体 token、排序。
- 五模板的 Cinema / Film 规则和两种纸张。

以上证明**模型合同**，但不证明 PDF 像素、字体嵌入、真实 PhotoKit 裁剪、Cinema 滤镜输出或阅读页视觉。

## 下一次产品/设计放行前的最小补证

1. 将 safeRect、保护层与正文可嵌入字体/行距/字距加入 PageStyle/RenderPlan；将 Field Notes 日期标记和 Film 日期区加入装饰 plan。
2. 用确定性图片 fixture 真正导出 PDF，产出 Reader/PDF 栅格化比对和 metrics；不可用“重复构造 manifest 相等”替代。
3. 连接真机后执行 Cinema、Film、免费/已购样章的 A4/Letter 抽检，并归档真实页截图与 PDF。
