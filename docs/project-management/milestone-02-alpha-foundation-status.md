# Tailor 本地 Alpha：照片入口与档案持久化

更新时间：2026-07-14

## 已交付

- `PhotoLibraryAccess`：读取并请求 PhotoKit `readWrite` 授权，映射完整、受限、拒绝与受限制状态。
- `ReferencesFeatureView`：使用系统 `PhotosPicker`，限制 3–5 张图片，并在界面中展示所选图片缩略图。
- `SwiftDataArchiveRepository`：本地保存、更新、读取和删除 `PetProfile`，参考照片 asset identifier 一并持久化。
- App 启动时恢复最近档案的姓名、类型、离开年份、参考照片标识和相册风格。
- 在资料页与参考照片页前进时等待档案写入完成，避免页面跳转后异步写入丢失。

## 验证证据

- iOS 26.5 Simulator 实际启动 App 成功。
- App 容器实际生成 SwiftData `Library/Application Support/default.store`、`-wal` 与 `-shm` 文件。
- `xcodebuild test`：7/7 XCTest 通过，其中 `testSwiftDataArchiveRepositoryPersistsAndUpdatesProfile` 覆盖保存、覆盖、读取、删除。

## 本阶段边界

系统 PhotosPicker 负责用户显式挑选参考照片；尚未实施以照片内容进行的宠物识别。下一阶段应在已保存的 asset identifier 上接入 PhotoKit 获取、日期分组和端侧识别候选集。
