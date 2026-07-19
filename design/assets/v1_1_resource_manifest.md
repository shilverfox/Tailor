# Tailor v1.1 · 资源输出清单

依据最新版 PRD，06–09 页的核心图像不是品牌素材，而是用户授权范围内的 `PHAsset`。为避免用生成宠物图冒充用户记忆，本次资源输出不新增任何狗/猫位图。

| 资源/素材 | 输出方式 | 落地位置 | 验收 |
| --- | --- | --- | --- |
| 确认页缩略图 | PhotoKit 运行时请求，1:1 aspect-fill | 内存缩略图缓存 | 仅授权 asset；不写入磁盘原图副本 |
| 时间线封面 | PhotoKit 运行时请求，72×72 pt | `TailorChapterCard` | 隐藏时期无代表图 |
| 章节九宫格 | PhotoKit 运行时请求，3 列 1:1 | Chapter editor | 敏感/永不使用/隐藏时期素材不进入 |
| 6–8 页样章照片 | 本地 PDF/SwiftUI renderer 运行时请求 | Preview/PDF renderer | 当前 selected 素材；每页都有水印 |
| 样章水印 | 原生文字，`TAILOR · PREVIEW` | Preview/PDF renderer | 不能为可关闭的位图遮罩 |
| 敏感/隐藏状态图标 | SF Symbols | 所有安全状态 | `hand.raised`、`eye.slash` 等有文字标签 |
| 三套模板纸张纹理 | 复用现有 `02_Warm_Paper.png`、`03_Quiet_Night.png`、`04_Field_Notes.png` | Style swatch / PDF 背景 | 不含宠物或示例文案；材质不拉伸 |

## 不应生成或打包的图片

- 任何用于确认结果、章节封面、样章或 PDF 的狗/猫照片。
- 医院、病重、临终、遗体等敏感情境插图。
- “永不使用”“隐藏时期”专用情绪化插图。
- 写有 `TAILOR · PREVIEW` 的图片水印。

## 如需补齐纹理源文件

已有 PNG 只用于 UI 预览；印刷级 PDF 背景如需更高分辨率，按原 `asset_requirements.md` 的三份无文字、无宠物纸张纹理提示词补交 3000×4200 px sRGB 源图。生成前须记录来源和人工检查结论，不能把生成结果用于用户照片位置。

