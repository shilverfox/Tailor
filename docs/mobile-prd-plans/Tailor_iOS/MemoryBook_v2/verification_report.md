# Tailor MemoryBook v2 验证报告

Status: conditional

## Reopened P0 (2026-07-21)

- `QA-V2-005`: Reader 与 PDF 的文本绘制实现/坐标不一致。实测 A4 文本包围框最大偏移 85.887pt，Letter 最大偏移 75.016pt，超过 `<= 1pt` 门禁。
- `QA-V2-006`: Contents 页纸张内部存在 `ReaderContentsOverlay`，PDF 无对应内容，违反同 revision 所见即所得。
- 证据：`verification/memorybook_v2/triple_render_2026-07-21/REPORT.md` 与同目录 contact sheets。
- 结论：在两项 P0 修复并由测试、设计复验前，代码门禁保持打开，不能标记发布就绪。

### Development repair status

- Reader 与 PDF 已统一为共享 CoreText 绘制器；纸张内容中的 `ReaderContentsOverlay` 已移除，目录导航保留在纸张外部。
- 自动化回归：App build 通过；unit 117/117；五模板 × Letter/A4 × 7 页 PDF 证据通过；Reader Letter/A4 共 14 页采集通过。
- 以上不关闭 `QA-V2-005/006`；必须由 QA 对新证据重新计算 `<=1pt` 指标，并由设计复验后才能关闭。

### First rerun result

- `QA-V2-006`: 关闭。目录导航已移出纸张内容，新 Reader 证据不存在仅预览覆盖层。
- 图片几何：通过。A4 最大偏移 0.769pt，Letter 最大偏移 0.723pt；旋转、zIndex、fit/fill 均有证据。
- `QA-V2-005`: 仍失败。文字 A4 最大偏移 3.845pt、Letter 最大偏移 2.170pt。真实根因是 Reader 约 258pt 画布触发 11pt 最小字号，而 PDF 595/612pt 不触发；共享 CoreText 尚未共享相同的归一字号。
- 设计门禁维持 fail/pending；研发第二轮需把“编辑可读性下限”与“渲染字号计算”分离，再由 QA 重测，阈值不变。

## 自动化验证

| 层级 | 结果 | 证据 |
| --- | --- | --- |
| Build | 通过 | 研发冻结快照 Xcode build |
| Unit | 115/115 通过 | QA 账本第 11 节 |
| 专项模型 | 6/6 通过 | 字体、grapheme、Book Check、Story Plan |
| 重点 UI | 8/8 通过 | Text×2、Book Check、Preview×2、Purchase×2、Story Plan |
| Diff hygiene | 通过 | `git diff --check` |

## 设计验证

- Text `photoCaption` unexpected exit：关闭。
- Story Plan 合并确认、影响摘要、`Pages need review`：通过。
- Preview logical page → Editor → Preview：通过。
- Book Check 精确定位：通过。
- Purchase transaction failure 保留购买/恢复入口：通过。
- Book Check Ignore 运行截图、Price unavailable fixture、Quiet Night 真机材质：条件门禁。

## 尚未执行

- 真机 PhotoKit/热降速/后台/重启/大相册。
- 真实 StoreKit 商品、地区、离线、pending、取消、恢复。
- 五模板完整页面族盲测。
- Final Preview / A4 / Letter PDF 三联像素签字。
- GF-01～GF-04 与 20 本内容质量 KPI。

在上述项目完成前，`Status` 不得改为 `passed`。
