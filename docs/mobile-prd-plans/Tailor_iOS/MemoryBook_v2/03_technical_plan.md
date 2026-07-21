# iOS 技术方案草案

## 1. 架构

```text
Confirmed Archive Photos
        ↓
Editorial Analyzer (event / quality / role / duplicate)
        ↓
Book Planner (chapters / page recipes / pacing)
        ↓
MemoryBookDocument
        ├── SwiftUI Page Renderer → Preview / Editor
        ├── PDF Renderer          → A4 / Letter
        └── Book Check            → issues / navigation
```

## 2. 唯一文档模型

```swift
struct MemoryBookDocument: Codable, Identifiable {
    var id: UUID
    var schemaVersion: Int
    var petProfileID: UUID
    var templateID: TemplateID
    var pages: [MemoryBookPage]
    var generationRevision: Int
    var updatedAt: Date
}

struct MemoryBookPage: Codable, Identifiable {
    var id: UUID
    var kind: PageKind
    var chapterID: UUID?
    var recipeID: String
    var elements: [MemoryBookElement]
    var isLayoutLocked: Bool
    var userEditRevision: Int
}

struct MemoryBookElement: Codable, Identifiable {
    var id: UUID
    var kind: ElementKind
    var normalizedFrame: CGRectCodable
    var rotationRadians: Double
    var zIndex: Int
    var isLocked: Bool
    var payload: ElementPayload
    var styleOverride: ElementStyleOverride?
}
```

图片 payload 至少包含 `assetLocalIdentifier / contentMode / cropScale / cropOffset / focalPoint`；文字 payload 至少包含 `text / source / fontToken / fontSize / color / alignment`。

## 3. 渲染契约

- 页面使用归一化 0…1 坐标；根据输出纸张映射到目标 rect。
- 图片统一使用一个 `ImagePlacementResolver` 计算等比 Fit/Fill、裁切、旋转后的有效区域。
- SwiftUI 和 PDF 共用 `ResolvedPage` 中间模型，不允许分别解释 cropScale/cropOffset。
- 字体通过 `FontCatalog` 映射；PDF 缺少字体时属于阻断错误，不静默替换。
- 选择框、控制点、安全线只属于 editor overlay，不进入 `ResolvedPage`。

## 4. 自动编排

### 4.1 EditorialProfile

对每张用户已选照片记录：时间、宽高比、像素、主体/宠物安全框、质量分、近重复组、事件组和角色分。不得把未确认照片自动加入。

### 4.2 PageRecipe

每个配方声明：支持照片数量、期望宽高比、最小 PPI、可用文本、模板权重和布局求解器。评分建议：

`score = cropSafety + roleFit + chronology + quality + templateAffinity + rhythm - duplicatePenalty`

首轮只实现确定性规则和可测试评分，不引入云端模型。

### 4.3 整书节奏

Book Planner 先生成章节骨架，再按 `opener → hero → sequence → quiet → transition` 分配页面。连续两页避免完全相同的配方；单章节照片不足时减少页数，不复制照片填充。

## 5. 编辑事务与锁定

- 每次拖动、缩放、旋转在手势结束时合并成一个 Undo transaction。
- 只有当前选中元素注册编辑手势；未选中元素只接受点击选中。
- 首次用户修改页面后设置 `isLayoutLocked`；用户可显式解除锁定。
- 模板“重排未锁页”只生成候选 diff，用户确认后原子提交，Undo 一次恢复整个操作。

## 6. 保存与迁移

- SwiftData 保存文档元数据和 Codable 页面树；大缩略图进入 Cache，原图不落库。
- 每次事务后 debounce 保存；切后台立即 flush。
- 保留 `schemaVersion` 和迁移器；迁移失败打开只读恢复副本，不覆盖原草稿。
- 自动生成的 revision 与用户 edit revision 分开，防止重新生成覆盖编辑。

## 7. Book Check

阻断：缺失资产、无可导出照片、文字溢出、不可满足裁切、字体不可用。建议：疑似重复、低 PPI、主体靠近裁切边、节奏重复。每项必须携带 pageID/elementID 和可导航修复动作。

## 8. 性能与诊断

- 页面缩略图异步缓存，当前页使用所需尺寸，禁止一次解码整册原图。
- 自动编排可取消；中断后保留上一个成功文档。
- 日志字段：documentID（本地脱敏）、generationRevision、pageID、recipeID、templateID、renderTarget、duration、issueCode；不得记录照片、宠物名或用户文字。
- 降级：智能规划失败时使用确定性按时间分章 + Safe Single/Two-up 配方，仍允许编辑和导出。

