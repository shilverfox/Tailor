# v1.1 iOS 技术方案

## 架构原则

保持 SwiftUI + SwiftData + PhotoKit + Vision/Core ML 可替换扫描协议 + UIKit 本地 PDF + StoreKit 2。所有照片只通过 `PHAsset.localIdentifier` 延迟读取；缩略图和渲染图不持久化为原图副本。

## 数据流

```text
PhotoKit/Vision 候选 → ArchivePhoto(decision + sensitivityState)
      → usablePhotos 统一过滤 → Chapter.photoIDs/cover → 预览页 → PDF
```

`usablePhotos` 必须是单一可复用谓词，供章节生成、章节可添加素材、代表图、样章、PDF 共用。修改为 `neverUse` 时，事务内删除其在所有章节的 ID；隐藏章节/时期则在输出层过滤且不显示代表图。

## 敏感策略

扫描层不声称诊断。只有本地规则或用户确认可把候选送至 `needsSensitiveReview`；不能可靠判断时保持普通低置信 `needsReview`。确认页执行四类操作：确认选入、排除、敏感稍后决定、永不使用。后两类都不能进入素材池。

## 预览/PDF

预览渲染器产出固定页序：封面、给它的一句话、目录、至少两个不同时段章节、选片页、结尾；素材不足时补说明页，页数限定 6–8。预览加水印，完整 PDF 不加水印。两者都使用相同 `ArchiveDocument` 快照、风格、页面尺寸和可用素材过滤器。

## 可靠性与隐私

- 仅用户点击“开始扫描”后创建 scan task；取消/后台保存 checkpoint；恢复必须由用户主动进入档案后点击。
- 不引入通知框架或任何按日期触发逻辑。
- 诊断只允许本地匿名事件：流程阶段、失败类别、候选数量分桶；禁记宠物名、照片标识、日期、说明、敏感/排除具体内容。
- PhotoKit 受限/拒绝、扫描/PDF 失败、购买失败均保留 SwiftData 文档。

## 发布与回滚

新增 Codable 字段以 `decodeIfPresent` 默认值实现旧档案迁移。发布前对含旧 JSON 档案升级、删除和重新导出进行回归；回滚不得破坏本地文档读取。
