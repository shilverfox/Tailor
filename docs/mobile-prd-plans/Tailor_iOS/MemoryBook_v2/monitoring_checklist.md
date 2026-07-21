# Tailor MemoryBook v2 发布监控清单

## 本地诊断事件

- [ ] photo_permission_scope / denied / limited。
- [ ] scan_start / pause / thermal_pause / resume / complete / failure。
- [ ] smart_draft_start / fallback / complete / cancel。
- [ ] editor_autosave / save_failure / restore_revision。
- [ ] book_check_blocking_count / suggestion_count / ignore。
- [ ] purchase_load / success / cancel / pending / failure / restore。
- [ ] pdf_start / cancel / failure / complete / reopen。

事件不得包含照片、宠物名、EXIF、地点、章节文字或文件内容。若 v2 保持完全不上传分析数据，则这些事件只写入用户可导出的本地诊断包。

## 发布观察

- Crash-free sessions、扫描失败率、热暂停率、PDF 失败率。
- 购买商品加载失败率、恢复购买失败率、退款与支持请求。
- 首次扫描耗时 P50/P95、每千张照片耗时、峰值内存。
- Preview→Editor→Book Check→Purchase→Export 漏斗完成率（仅获得用户明确分析授权后）。

## 告警与处理

- P0 隐私/错误收费：立即停止发布并执行回滚。
- Crash-free sessions 低于发布基线或 PDF 失败率异常：暂停分阶段发布。
- 热暂停后无法恢复、档案无法重开：升级为 P0 数据可靠性问题。
