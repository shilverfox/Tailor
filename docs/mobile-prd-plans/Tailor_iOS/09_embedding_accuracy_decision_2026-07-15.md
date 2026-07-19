# Embedding 识别准确性方案决策

## 已落地

- 继续使用端侧 Vision `VNRecognizeAnimalsRequest` + `VNGenerateImageFeaturePrintRequest`。
- 保留 `0.52` 的动物类别初筛和 `0.42` 的相似度初筛，避免姿态、年龄、光照变化导致真实照片被静默丢弃。
- 初筛结果仍按置信度分层；只有高置信结果自动选中，其他结果必须进入人工确认。
- 不能把 Vision 通用 Feature Print 当作宠物身份模型；猴子、小熊猫或其他宠物的排除需要专用 Re-ID 模型或人工确认门禁。

## 评估结论

SQLite/增量索引主要解决重复扫描、耗电和启动速度，不直接解决身份误识别；Accelerate/vDSP 当前不能直接读取 `VNFeaturePrintObservation` 的公开原始 Float 向量，因此暂不接入。

## 后续门禁

1. 用真实验收集校准 `0.52 / 0.42` 阈值，并记录 precision/recall。
2. 增加宠物主体裁剪后再提取特征，降低背景相似度影响。
3. 将当前本地特征缓存迁移到 SQLite/系统 SQLite，并按 `PHAsset.localIdentifier` 做增量索引。
4. 如果误识别仍高，再评估专用宠物 Re-ID Core ML 模型；不能把通用 Vision Feature Print 宣称为身份识别模型。
