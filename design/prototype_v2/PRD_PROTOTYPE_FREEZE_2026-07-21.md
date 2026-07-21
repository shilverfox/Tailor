# Tailor v2 PRD 与原型冻结确认单

- 冻结版本：`Tailor-v2.2-docfreeze-2026-07-21`
- 冻结日期：2026-07-21
- 适用范围：iPhone / iOS 17+ / Tailor v2 主流程 01–20
- 当前结论：产品与原型输入完整，无 P0 需求歧义；允许继续既定实现与验收，不允许扩大范围。
- 独立签字：设计 PASS；测试可测试性 PASS；文档 P0=0、P1=0；8 个冻结 SHA 全部匹配。

## 唯一基线

1. 产品：`docs/mobile-prd-plans/Tailor_iOS/Tailor_v2_PRD.md`
2. 原型入口：`design/prototype_v2/prototype_map.html`
3. 页面跳转：`design/prototype_v2/flow_and_screen_contract.md`
4. 全局状态：`design/prototype_v2/state_matrix.md`
5. 01–06 独立合同：`design/prototype_v2/v2_pages_01_06_contract.md`
6. 补充视觉合同：`design/prototype_v2/v2_visual_contract_01_06_18_20.md`
7. PRD 追踪：`design/prototype_v2/prd_prototype_traceability.md`
8. 关键状态：`design/prototype_v2/detailed_state_specs.md` 与 `detailed_states.html`
9. v2.2 新增裁决状态：`design/prototype_v2/v22_adjudication_state_specs.md` 与 `v22_adjudication_states.html`

## 冻结文件 SHA-256

| 文件 | SHA-256 |
|---|---|
| `Tailor_v2_PRD.md` | `289ba9d154b24218900af3c9415768fdfc3d41cb5881c167f3cadf39c304840c` |
| `prototype_map.html` | `7fee9cfd409e70333485293331ffcba079cebbb92044a05ade26b74a44aa83ab` |
| `flow_and_screen_contract.md` | `0f865e8deba628705944d101f98134cb3893cd16efae928a3846132b7a164b3c` |
| `state_matrix.md` | `5338477d954a81d83fe040dfe907c9491bc67e60488709eed15bc3010396803e` |
| `v2_pages_01_06_contract.md` | `3f736d013d0da30ed2cc797ce84ea5ab7a0e0c633624369188c70c7932ec3ffd` |
| `v2_visual_contract_01_06_18_20.md` | `3c655182a4895c5e4185879d80850731b8f84d6792a240f0314a73e320755a8d` |
| `prd_prototype_traceability.md` | `9aaca8fab5e8352f82aff7a83276de5cc8de034ef62188b97b3d54930fd65897` |
| `detailed_state_specs.md` | `caa58f0e6414d218f537c96792f50e351c32b1eee4e95d7d6d85c37e1f7e3d72` |
| `v22_adjudication_state_specs.md` | `ff0045e3aedb12f0e52bcbad2c2110d2a1a355cd1ab4c52503003d3f774b2a20` |
| `v22_adjudication_states.html` | `c2c2fb59db9b40c2557d7d123a10d3522e0fcefe6253a60b69107d5763f7b8e9` |

## 冲突裁决

- 完整文档创建时点：07 只创建 `StoryPlanDraft`；08 编辑并确认；09 首次选择模板后原子创建 `MemoryBookDocument`。
- 01–06：v2 合同为产品/状态基线，v1 截图仅是视觉参考。
- 纸型：09 默认 US Letter、可选 A4；纸型属于 revision，Book Check 绑定 revision+纸型+规则版本，19 切换必须重新检查。
- 恢复：03–09 均写入 Archive checkpoint；20 按八类状态精确恢复。
- denied：04 Manual Import 选择 3–500 张最终候选，保存明确选择的 App 私有副本并跳过全库扫描。
- 识别代际：matchGenerationID 明确包含 profileID+species+reference fingerprint+matcherVersion；embedding 可复用，代际变化重算 match，旧人工 decision 变 stale 并须复核。
- sensitive：normal selected 或 sensitive selected+sensitiveApprovedAt 可入册；neverUse 永不可覆盖。
- 导航：使用 ReturnContextStack；16 从11进入时只返回11；11保存后自动重跑Book Check，按稳定issue locator、former index、logicalPageID或最近页fallback；blocking进入17，通过才回19。19导出成功停留本页，用户明确进入20。
- 样章：min(8,total)，正常8/最少6；多时期优先两个章节，单时期不得虚构拆段，使用真实献词/注记页组成结构。
- 编辑器：Smart Draft 不替代 Page Editor；图片、文字、页面、层级、锁定、撤销/重做能力全部保留。
- 预览/付费：未购买可完整编辑，只查看 6–8 页水印样章；Book Check 后进入购买或已解锁最终预览。
- Purchase 只允许从当前 revision 的 Book Check 通过态进入；10 不可直达 18，购买成功才进入 19，后续编辑/切纸型必须重检。
- 渲染：Reader、Final Preview、PDF 使用同一 document revision、页面模型和排版语义。
- 排除项：视频、音乐、云端 AI、生成式情感文案、订阅、实体印刷不进入 v2。

## 开工与变更规则

- 研发、设计、测试只能处理本冻结范围及已记录缺陷。
- 任何改变 20 页主流程、付费边界、文档创建时点、编辑器能力或渲染门禁的修改，必须同时更新 PRD、原型合同、追踪表并重新评审。
- 工作区文件当前可作为冻结内容基线；Git commit/标签属于版本固化动作，未经用户明确要求不自动提交或打标签。

## 尚未关闭但不构成需求歧义的实施门禁

- `QA-V2-005` Reader/PDF 文字像素一致性。
- Quiet Night 真机 Material 表现、StoreKit 沙盒、真实设备全流程。
- GF-01～GF-04 与 20 本真实内容质量样本。

这些是实现/验证问题，不再反向阻塞产品与原型冻结。
