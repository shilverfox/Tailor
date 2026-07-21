# Tailor v2｜01–06、18、20 视觉与状态合同

> 本文件把旧稿提升为 v2 可验收视觉合同。旧 PNG/HTML 只用于摄影构图和品牌气质参考；组件层级、文案、状态和按钮位置以本文件为准。

## 固定画布与 token

- 基准设备：iPhone 13，390×844pt，Light，标准 Display Zoom，Dynamic Type `.large`；内容遵守系统 safe area。
- 背景 `#F7F1E5`，深绿 `#123F35`，陶土 `#C65B3D`，浅鼠尾草 `#DCE5D2`，正文灰绿 `#687A72`。
- 页面左右边距 24pt；顶部内容从 safe-area 下 20pt 开始；底部主按钮距 safe-area 16pt，高 60pt，圆角 18pt。
- 页面主标题使用品牌 serif 44pt/0.98；正文 17pt/1.35；eyebrow 12pt uppercase/0.16 tracking；系统交互文字使用 SF Pro。
- Loading 必须保持完整页面骨架，不得出现持续白屏；错误不展示内部 error code。

## 01–06

| 页面 | 固定层级 | 关键状态视觉 |
|---|---|---|
| 01 Welcome | 全屏真实宠物图；底部暖白渐变区；标题、价值说明、深绿主按钮、隐私链接 | 无自动弹窗；照片缺失时用品牌纸纹，不用空白屏 |
| 02 Privacy | 顶部返回+eyebrow；三张隐私承诺卡；底部 Allow Photos；Manual Import 次按钮 | full/limited/denied 分别有状态条；denied 明示“只复制你手动选择的照片到本 App” |
| 03 Pet Profile | 狗/猫 segmented；名称输入；到家年份 optional；离开年份 required；头像位 | 校验信息位于字段下方，不用弹窗；保存稍后继续是文字按钮 |
| 04 References | 3–5 个等宽槽位，首行 3 个；缩略图为 aspectFill 但可点开原图；底部 Start finding | denied 时标题切为 Manual Import，显示 3–500 多选摘要和私有副本说明，不显示扫描承诺 |
| 05 Scan | 深绿全屏；标题、环形真实进度、processed/total、4个候选缩略图、状态说明、底部 Pause/Resume | paused/thermal/failure/recovery 都保留当前数字；thermal 文案可换行且操作始终可恢复 |
| 06 Review | 暖白；大标题+四状态横向 tabs；年份筛选；批量操作卡；3列网格；底部 Create memory book | selected/needs review/sensitive/never use/stale 使用不同图标且不只靠颜色；sensitive approval 用详情 sheet；长网格底部不抖动 |

## 18 Purchase

- 顶部返回并保持 source context；标题 `Keep the complete book.`。
- 交付清单四项：完整无水印、A4/Letter、持久本地、可重复导出。
- 商品加载中只显示骨架和 `Loading price…`；成功只使用 StoreKit `displayPrice`；失败时购买按钮 disabled，并显示 Retry、Restore、Back。
- Cancel/Back 精确返回进入来源及 logicalPageID/issueIndex；页面不得写死 `$19.99` 作为实际购买按钮价格。

## 20 Archive

- 每个档案卡包含封面、宠物名、当前阶段、保存时间和最近 PDF。
- pre-document 阶段用进度 chip 与动态主按钮：Continue profile / Choose photos / Resume scan / Review photos / Continue draft / Review story / Choose style。
- documentReady 使用 Continue editing；有导出时显示 Open last PDF；文件丢失显示解释和 Re-export，不显示失效按钮。
- Refresh new photos、Manage access、Delete archive 位于 More；删除二次确认并说明不影响系统照片。

## 验收要求

1. 设计输出必须覆盖本文件每个页面的 default、loading/empty、failure、recovery 和权限/付费相关状态。
2. 01–06、18、20 的逐像素签字以基准设备的新 v2 输出为准；旧 v1 图只做并排参考，不能作为 expected screenshot。
3. Dynamic Type、VoiceOver、键盘、真机状态栏另走运行态验收，不改变上述信息层级。
