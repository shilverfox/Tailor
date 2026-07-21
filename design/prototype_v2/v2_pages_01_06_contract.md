# Tailor v2｜01–06 独立页面合同

> 本文件是 01–06 的 v2 产品与交互基线。`design/reference/v1_1` 只提供色彩、字体、间距和构图参考；发生冲突时，以本文件和 `Tailor_v2_PRD.md` 为准。

| ID | 页面 | 进入条件 | 主操作与成功结果 | 必备异常/恢复状态 | 持久化边界 |
|---|---|---|---|---|---|
| 01 | Welcome | 首次启动或无档案 | Create life archive → 02 | 隐私详情可返回；不得自动请求相册 | 不创建空档案 |
| 02 | Privacy & Permission | 01 或设置 | 完整/受限授权后 → 03；denied 可选 Manual Import | denied、limited、系统设置返回、授权范围变化 | 只保存授权状态；手动导入副本在04由用户明确选择后保存 |
| 03 | Pet Profile | 02 或新建档案 | 名称+狗/猫+离开年份有效后 → 04 | 名称/类型/离开年份缺失；年份不在1900…当前年；到家>离开 | 原子保存 profile；到家年份可选 |
| 04 | Reference Photos / Manual Import | 03 或档案继续 | 授权：3–5张后→05；denied：PHPicker选3–500张最终候选→06 | 0–2张禁用；asset/文件缺失可替换 | 授权保存localIdentifier；手动模式仅保存明确选择的App私有副本 |
| 05 | On-device Scan | 用户显式开始或恢复未完成扫描 | 完成 → 06；Pause/Resume/Continue later | 热状态降并发、失败可重试、权限变化、App 重启恢复；不得不可恢复中断 | 保存已检查 ID、索引/结果、游标和状态；成功后只增量处理新增照片 |
| 06 | Photo Review | 扫描完成或档案继续 | 至少 3 张可入册后 Create memory book → 07 | 高确定/待确认/敏感/排除/空结果；批量通过与逐张纠正 | 保存 decision+sensitivity；normal selected 或已显式批准的 sensitive selected 可入册，neverUse/hidden/excluded 不可入册 |

## 共同交互规则

1. 01–06 任一失败都不得清空 profile、参考照 ID、扫描索引或人工照片决策。
2. App 重开优先恢复最近成功状态；成功全量扫描后不自动重新全扫。
3. 扫描页进度必须由真实 processed/total 更新；暂停、热降速和失败均显示可恢复动作。
4. 参考照和确认页缩略图从 PhotoKit ID 重新加载；内存 UIImage 不得作为唯一来源。
5. 低置信候选不自动入册；待确认支持批量通过。敏感素材须在详情页确认风险并选择入册，记录 sensitiveApprovedAt；neverUse 永不可覆盖。
6. 原系统照片永不被修改或删除。
7. embedding 索引与宠物身份分离；参考照集合或狗猫类型变化只重算匹配，旧人工 decision 标记 stale 并须重新确认。
8. 03–06 的 Save/Continue later 均创建 Archive checkpoint，恢复路由分别回当前最早未完成页面。

## 视觉来源约束

- 可复用 v1 的暖白、深绿、陶土橙、标题层级、卡片形态和图标语言。
- 不复用 v1 中与本合同冲突的按钮文案、自动重扫、错误裸码、不可恢复暂停或单张强制确认交互。
- 01–06 的视觉验收必须同时读取本合同与 `state_matrix.md`，不能只对照旧截图。
