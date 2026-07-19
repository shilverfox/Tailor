# Tailor v1.1 PRD 一致性与发布门禁审计

审计日期：2026-07-15  
审计范围：`Tailor_v1_PRD.md`、规划产物 `01`–`06`、`inputs/source_manifest.md`、任务拆解，以及设计增量/资源清单。  
审计方式：只读逐条对照。本文件不代表任何 P0 已关闭；“已有测试用例”也不等于已经有真机/自动化通过证据。

## 审计结论

当前材料已能支持继续迭代，但**不满足 v1 发布门禁**。规划中已经识别到 ML、正式设计、PDF 性能和 StoreKit 配置等 P0；本审计额外确认了两处 PRD 与角色产物的直接冲突，以及多个没有可执行证据归属的门禁。发布结论必须保持“未通过”。

| 级别 | 编号 | PRD 要求 | 证据路径/发现 | 缺口与建议门禁 |
| --- | --- | --- | --- | --- |
| P0 | AUD-01 | 用户可按**年份或日期范围**隐藏时期；隐藏内容直到显式恢复均不得进入预览/PDF（PRD §5.1.3）。 | `01_requirement_understanding.md` 将 v1 定义为“先按章节/年份隐藏，日期范围后续扩展”；`02_open_questions.md` 亦将日期范围 UI 标为 P1。相反，`design/detailed/v1_1_design_delta.md` §3 已设计 `Custom dates`。 | 产品、设计、研发的范围不一致，且把 PRD 必需能力降级。门禁：冻结 v1 是实现年份+自定义日期范围，还是由产品正式修订 PRD；随后补数据模型、交互稿、TC 和真机证据。未关闭不得发布。 |
| P0 | AUD-02 | 未购买预览为由真实已选照片生成的**6–8 页**带水印样章；素材不足时展示说明页而非虚构内容（PRD §2、§4-09、§5.3.1）。 | `design/detailed/v1_1_design_delta.md` §4 在“所有照片不足”时允许仅 4 页；`04_test_cases.md` TC-10 要求仍为 6–8 页。 | 设计规则与 PRD/测试相冲突，开发无法判定降级页数。门禁：设计把极少素材降级明确改为仍生成 6–8 页（说明/留白页可用），或产品正式修订 PRD 与 TC；提供 normal/one-period/zero-eligible 三组页码和水印截图证据。 |
| P0 | AUD-03 | 同一宠物端侧识别必须具备模型、阈值、耗时/耗电预算及幼年到老年策略（PRD §7.1）。 | `02_open_questions.md` 仅记录“待确认”；`03_technical_plan.md` 仅说明可替换协议；`05_task_breakdown.md` 没有 ML 评审/基准/验收任务。 | 这是 PRD 明列发布 P0，却没有可派工的 owner、输入、基准集、阈值、误识别降级和签收证据。门禁：新增 ML-01，冻结模型/特征、猫狗/多宠/年龄样本、precision/recall 或人工确认兜底指标、单张/10k 相册耗时耗电预算与真机报告。 |
| P0 | AUD-04 | 敏感素材需有本地分类、误判降级策略和 `neverUse` 迁移/删除语义（PRD §5.1、§7.4）。 | `01`、`02` 只声明当前保守降级；`04` 有 TC-05/06，`05` 未拆出分类策略/迁移删除验证的独立任务。 | “人工语义已规划”不能代替敏感分类方案；且 `needsSensitiveReview` 的来源、误判恢复、旧档案迁移和删除/重建场景没有冻结验收。门禁：产品/ML 给出非诊断性允许线索、置信度阈值、不可判断默认流向；研发/QA 给出迁移、恢复、删除档案及重新扫描矩阵。 |
| P0 | AUD-05 | 可用照片必须同时满足 selected、非敏感、非隐藏时期、非 never-use，并被章节、封面、预览、PDF 一致使用（PRD §5.2.3）。 | `01`/`03` 提到统一谓词；`04` 有分散用例；`05` 仅有 IOS-13 的笼统验收。 | 缺少以“单一输出快照/素材清单”为验收对象的跨模块门禁；章节隐藏、日期范围隐藏与照片 `sensitivityState` 的持久化归属也未冻结。门禁：定义 `eligibleAssetIDs`/`ArchiveDocument` 契约与输入输出日志（仅测试环境），以组合矩阵验证 chapter cover、目录、预览每页、PDF 每页都不含禁用 ID。 |
| P0 | AUD-06 | 免费 6–8 页水印预览与购买后无水印完整 PDF 需内容一致、页面容量/大相册性能受控（PRD §7.5）。 | `02` 标为进行中；`03` 说同一快照；`04` 有功能断言，但 `05` IOS-14 未列基准规模、最大照片/页数、耗时、内存、失败阈值或性能产物。 | 缺少可验收性能预算和“同源内容”的定义（preview 的页与完整 PDF 的关系、再编辑后失效、A4/Letter）。门禁：产品冻结最大选片数/完整 PDF 最大页数；iOS 输出渲染快照和性能报告；QA 对 1k/10k 样本、A4/Letter、失败重试、购买前后同素材做真机证据。 |
| P0 | AUD-07 | 12 页及权限、扫描、内购、导出失败态需要正式视觉规格（PRD §7.3）；待确认必须可发现且创建前不得静默跳过（PRD §4-06、§5.2）。 | `02` 标为进行中；`05` DES-11 覆盖失败态但无逐状态交付清单。`design/visual-qa/01-12_acceptance_matrix.md` 含大量 P0 “Required change”，本身说明尚未全部通过；确认页新增设计与当前可点击流程需要逐页复核。 | 当前没有“设计冻结版本 + 原型链接 + 每个状态截图 + 研发实现截图 + 逐项签收”的证据闭环。门禁：建立 12 页 × 正常/空/受限/失败/购买/导出状态追踪表，P0 必须有设计、实现、真机证据与 Design/QA 双签。 |
| P0 | AUD-08 | 不得注册/投递通知、后台自动扫描、周年/相册变化自动唤起；恢复仅能由用户主动触发（PRD §1、§3、§5）。 | `01`/`03`/`04` 有规则和 TC-21–25；`05` IOS-15 仅写“全工程无通知请求/调度”，没有运行时审计、PhotoKit observer、生命周期或回归证据任务。 | 静态搜索不能证明不存在生命周期/后台/相册变化自动执行。门禁：增加无通知二进制/API 扫描、冷启动/前后台/相册变化/系统日期变更的真机录屏和日志证据；恢复入口必须由明确用户按钮触发。 |
| P0 | AUD-09 | App Store Connect 商品、地区定价、审核与隐私标签是发布前 P0（PRD §7.2）；使用 StoreKit 2 非消耗型 `tailor.life_archive.unlock`（PRD §6）。 | `02`/`06` 仅列待产品提供；`05` 没有发布/StoreKit 配置任务、验收证据或 fallback owner。 | 本地 mock/StoreKit Test 不能覆盖上架配置。门禁：新增 REL-01，提供商品状态、地区 $19.99、restore、隐私标签、Sandbox 交易记录与审核材料检查单；未通过只可称开发包，不可称发布包。 |
| P0 | AUD-10 | 原图不上传、不复制、不修改；仅允许不含私密字段的本地匿名漏斗；删除档案需清除本地数据（PRD §2、§6）。 | `04` TC-26–29 覆盖较好；`03` 写了原则；`05` 无隐私数据流审计、网络抓包、持久化检查、删除后文件系统检查任务和证据目录。 | 隐私要求有意图/测试项但没有可审计交付物。门禁：建立 PRIV-01，输出 Info.plist/entitlement/依赖库审计、飞行模式+代理流量证据、SwiftData/沙盒删除前后清单、分析事件字段白名单；由产品/QA 签收。 |
| P1 | AUD-11 | 06 页要求高确定/待确认/已排除/敏感待确认、年份筛选、原图查看、批量排除，以及敏感/永不使用语义（PRD §4-06）。 | `04` TC-04 涵盖；`05` IOS-12 未明确年份筛选、原图查看、批量动作和 never-use 恢复管理；设计稿比任务更细。 | 任务拆解不可直接追踪所有交互。建议 IOS-12/QA-11 分拆为筛选、详情、批量、敏感、永不使用恢复五项，并分别给 accessibility ID 与 UI 测试。 |
| P1 | AUD-12 | 03/04 页要求宠物类型和名称必填、离开年份、3–5 参考照、少于 3 张不可扫、拒绝权限可手动选择（PRD §4-02/03/04）。 | `04` TC-01–03 笼统覆盖；`05` 没有对应开发/设计/测试任务，`01` 页面影响矩阵也只从 05 页开始。 | 基础入门链路未被本轮变更任务显式回归，容易因数据模型改动破坏。建议补 ONB-01 与 UI/真机案例：空值、犬猫限制、2/3/5 张、受限/拒绝/手选、重启恢复。 |
| P1 | AUD-13 | 章节必须有用户 note、封面或等价有序图片、隐藏状态；不生成推断性文案（PRD §5.2.4/5、§6）。 | `01`/`03` 提及；`04` TC-08 覆盖大意；`05` IOS-13/14 没有禁止性文案的验证和章节为空后的处理任务。 | 需把文案来源和空章节规则转为测试：仅日期、允许地点、用户输入；无证据中性标题；never-use 移除后空章节可修复/删除。 |
| P1 | AUD-14 | 任何 scan/purchase/export failure 都保留编辑进度，且确认/时间线/编辑/预览安全退出无催促（PRD §3、§5.1.4、§5.3.3）。 | `04` TC-13–18 覆盖失败；`05` 未按失败态列实现和证据；`design/detailed/v1_1_design_delta.md` 有退出文案，但 `source_manifest` 未记录该设计输入。 | 建议把失败态和安全退出列为 12 页状态矩阵的必测行，并记录每条恢复数据字段与留存证据。 |
| P1 | AUD-15 | 多档案、重新扫描、管理照片权限、二次确认删除及购买权益不受影响（PRD §4-12）。 | `04` TC-12、TC-27 有覆盖；`05` 没有对应开发/回归任务。 | 建议补 archive-management 任务和相互隔离测试（两个档案、一个删除、一个保留、旧 PDF 清理、权益恢复）。 |
| P1 | AUD-16 | 规划输入必须可追溯（PRD 与正式设计/资源为本轮依据）。 | `inputs/source_manifest.md` 只记录旧 chat 方案和 PRD，未记录 `v1_1_design_delta.md`、`prototype_v1_1.html`、资源清单、用户的确认页反馈/验收截图。 | 追溯链不完整，难以证明视觉/反馈如何进入规格。建议更新 manifest：来源、版本/日期、用途、责任人、替代关系；所有新增 P0 证据也登记。 |
| P2 | AUD-17 | 样章模板、图标与真实照片素材的边界需明确，不能以生成宠物图替代用户记忆（PRD §1、§4-09）。 | `design/assets/v1_1_resource_manifest.md` 已正确说明 PHAsset 与纹理界限。 | 资源规划一致；建议补纹理授权/生成记录和印刷级尺寸验收，作为设计资产归档项。 |
| P2 | AUD-18 | 只支持猫狗，其他物种有明确提示（PRD §5）。 | 规划文档未见专门用例/任务。 | 建议补 TC：非猫狗候选、手动选择非猫狗与文案；不阻塞当前确认页修复，但应进入完整 v1 回归。 |

## 建议的统一发布门禁

以下条件必须同时成立，才能把状态从“可继续开发”改为“发布就绪”：

1. **产品冻结**：AUD-01/02 的冲突有正式 PRD 决议；所有 P0 问题都有 owner、截止条件和不可变验收口径。
2. **设计冻结**：12 页和全部 P0 异常/空态都有版本化原型、标注、资源来源；逐页视觉矩阵不再遗留 P0。
3. **研发冻结**：单一可用素材契约、敏感/隐藏/never-use 迁移、PDF 同源渲染、失败状态保留、无通知保护均有代码和自动化测试。
4. **QA 证据**：TC-01–29 中所有 P0 在真机或相应 StoreKit 环境通过；ML、性能、隐私、无通知、6–8 页/水印及跨模块禁用素材有可复查证据。
5. **发布准备**：StoreKit 正式商品、价格、隐私标签、审核材料、删除/恢复购买与离线降级均完成发布候选验证。

## 本轮审计的最低修订顺序

1. 产品先关闭 AUD-01、AUD-02（这两项当前互相冲突，不能由研发猜测）。
2. PM 把 AUD-03–10 纳入 `02_open_questions.md` 与 `05_task_breakdown.md`，明确 owner 和证据输出。
3. 设计按已冻结规则修订 `v1_1_design_delta.md`、原型与视觉矩阵；资源清单同步登记来源。
4. 研发和 QA 以统一素材契约、性能/隐私/无通知证据和 StoreKit 配置为独立门禁任务，而非仅以“构建通过”放行。

## B2–B4 代码与原型复核（2026-07-15）

复核对象：`Tailor/Features/ArchiveFeatureViews.swift`、`AlbumFeatureViews.swift`、`MilestoneRootView.swift`、`Services/ProductionServices.swift`、`design/prototype_v1_1.html` 与 `design/reference/v1_1/README.md`。  
结论：**B2、B3、B4 均不得签收。** `prototype_v1_1.html` 只覆盖 06 的四张静态说明画板，不是 B2–B4 的可点击全流程原型；`README.md` 列出的 B2–B4 参考图大部分尚未交付或批准。

| 批次 | 级别 | 阻断项 | PRD 要求与代码/原型证据 | 必须关闭的门禁 |
| --- | --- | --- | --- | --- |
| B2（05–06） | P0 | **敏感/永不使用流程不完整** | PRD §5.1.1–2 要求敏感待确认、`Never use` 二次确认、原图仍在 Photos、可恢复管理。`ReviewFeatureView` 的普通 `confirmationDialog` 可直接执行 `Never use in this archive`；没有二次确认、影响说明、`Never use (n)` 管理区或 `Allow in this archive` 恢复入口。原型也只覆盖普通待确认 viewer/gate。 | 交付敏感保护卡、Use/Decide later/Never use 二次确认、折叠管理及恢复；对章节/封面/预览/PDF/系统 Photos 做连续 UI+真机回归。 |
| B2（05–06） | P0 | **审核详情与批量/零匹配路径不足** | PRD §4-06 要求查看原图、批量排除和年份筛选；README B2 还定义 viewer、batch、zero-match。当前点图仅弹 `confirmationDialog`，没有 aspect-fit 原图、日期/状态详情或固定操作区；批量模式仅能 Add，不能批量 Exclude/Set aside；空列表只有通用 `No photos in this group`，没有“无清晰匹配”后的手选/更换参考照/保留草稿三条出口。 | 用稳定 FX-10/FX-11 fixture 实现并验证详情、年份筛选、三类批量动作和三条零匹配退出路径；所有动作必须持久化。 |
| B2（05–06） | P1 | **创建时间线提示信息未完整呈现 N/M** | PRD §1 成功标准及 01 的 P0 修正要求清楚呈现“已确认 N、待确认 M”。当前 gate 标题只显示 pending 数；selected 数只出现在次级按钮文本，且 `Continue confirming photos` 没有数量。 | gate 标题/正文同时明确 N 与 M，主操作为带 M 数量的 review，补两条 UI 测试：回到 Needs review、明确继续后仅用 N 张建线。 |
| B2（05） | P0 | **低电量和失败恢复只具 UI demo，非生产状态机** | `MilestoneRootView` 的 `displayState == lowBattery` 只由 `-uiDemoState` 注入；生产扫描从未设置 lowBattery。失败 catch 未保存失败状态/重试语义，只重置显示进度。PRD §3/§4-05 要求暂停/恢复与失败保留。 | 生产扫描接入可测试的低电量/中断/失败状态来源，保存 checkpoint 和人工结果；真机断电/后台/锁屏/权限撤销证据必须通过。 |
| B2（05–06） | P0 | **视觉/原型门禁未满足** | `design/reference/v1_1/README.md` 要求 B2 6 个 scan + 11 个 review PNG/source；`reference_manifest.md` 仍为 missing/candidate，`prototype_v1_1.html` 非可点击且只覆盖四个 06 画板。 | 设计交付所有 B2 状态、可编辑源、PHAssetMask 和产品批准；QA 再做同 fixture 叠图。 |
| B3（07–08） | P0 | **按日期范围隐藏完全未实现** | PRD §5.1.3 要求按年份或日期范围隐藏。当前模型只有 `Chapter.isHidden`；`ArchivePhotoDateRange` 没有 hidden-range 归属，`TimelineFeatureView` 只有章节 context-menu toggle，没有 `Edit periods`、年份/自定义日期、影响摘要或范围恢复。 | 产品先关闭 AUD-01 后，实现持久化日期范围、章节部分隐藏、范围编辑/校验/恢复；预览/PDF 使用同一范围过滤器并有 FX-13 测试。 |
| B3（07–08） | P0 | **隐藏时期不符合“折叠且无代表图”的交互** | PRD §5.1.3、设计 delta §3 要求 `Hidden periods (n)` 折叠区。当前隐藏章节仍在主时间线内以 0.5 opacity card 展示；虽用眼睛图标替代封面，却没有确认 sheet、折叠管理或显式 Restore。 | 隐藏项移入无图的折叠区，提供 Hide confirm/Restore；对 preview/PDF 中资产为零做测试。 |
| B3（07–08） | P1 | **章节编辑韧性与管理动作缺口** | PRD §4-07/08 要求删除、合并、排序、隐藏及章节编辑；当前只有 context-menu hide/edit，未实现 delete/merge/章节排序；编辑页没有 dirty-exit、save-failed、空章 Delete chapter。返回会离开编辑页且未显式保存当前绑定改动。 | 补管理菜单、空章处理、未保存离开确认和保存失败保留；QA 覆盖 never-use 导致唯一封面/唯一照片被移除。 |
| B3（07–08） | P0 | **B3 设计/原型证据不存在** | README 要求 07/08 约 10 张状态图；当前 `design/reference/v1_1/` 没有这些 PNG/source，`prototype_v1_1.html` 不含 07/08。 | B3 全状态设计、可点击路径和 approved reference 未齐之前，不得作高保真或功能签收。 |
| B4（09–12） | P0 | **预览与完整 PDF 非同源，PDF 缺产品结构** | PRD §5.3 要求 6–8 页真实水印样章、购买后以同套内容生成完整无水印 PDF。`AlbumPagesPreview` 是固定 8 页、仅 UI 内 `PREVIEW` 单字水印；`LocalPDFExporter` 没有 `style`/preview snapshot 参数，生成单页封面后按章节流水排版，缺 dedication/contents/closing，不能证明与预览同内容/模板；水印文案也不符合设计的 `TAILOR · PREVIEW` 重复原生水印。 | 定义单一 `ArchiveDocument` 渲染快照，预览与 PDF 共用页面计划、照片 ID、模板和页尺寸；输出 6–8 页/素材不足/购买后无水印 PDF 的可检验页序和截图。 |
| B4（09–12） | P0 | **预览缺加载/失败/明确分页控制** | PRD §3 韧性、design delta §4 要求 preview loading/failed、Try again/Return 和可见 Previous/Next/page count。当前 `TabView` 仅 dots/swipe，没有状态机、页码或失败恢复。 | 实现预览渲染状态、固定可发现分页控制、素材不足页数规则（先关闭 AUD-02），并增加 UI 自动化。 |
| B4（10） | P0 | **购买中/取消/失败/恢复状态不可用** | PRD §4-10、§5.3.3 要求失败/取消/恢复不丢状态。`StoreKitPurchaseService` 能返回 `.pending/.cancelled`，但 `MilestoneRootView.purchase()` 只处理 entitled/restored/failed；`PurchaseFeatureView` 无 `isPurchasing`、禁重复、取消状态或 ErrorCard/retry。 | 把所有 StoreKit 状态绑定到 UI；购买中固定 56pt loading/禁重复，取消中性返回，失败/restore failure 提供 retry/restore/back，保持文档/样式/页尺寸。 |
| B4（11） | P0 | **导出状态与分享 CTA 不符合 PRD** | PRD §4-11 要求渲染进度、保存/分享/返回；设计要求 A4/Letter、rendering、complete、failed。当前导出页一开始就称 `Your archive is ready.`；无 page-size sheet/render progress；失败仅红字；生成后主按钮 `Save and share PDF` 只执行 `done → archive`，真正 `ShareLink` 是另一个次级 `Share PDF`。 | 实现 choosing-paper/rendering(page,total)/complete/failed/file-unavailable 状态；主 CTA 必须打开系统分享或明确命名为保存动作，失败可 Try again/Return 且不丢数据。 |
| B4（12） | P0 | **档案页不是多档案/设置的可操作实现，删除失败被吞掉** | PRD §4-12 要求多个档案、重扫、权限管理、删除二次确认。`ArchivesFeatureView` 只接收一个 `name`；三行设置是静态 HStack；无 empty/access-revoked/rescan 管理；`deleteArchive()` 用 `try?` 忽略仓储/文件删除失败后仍 restart。 | 以 repository `allProfiles()` 构建多档案列表和可点设置行；补 empty/revoked/delete-failed，只有删除成功才离开，失败显示 Try again 并保留数据；验证一个档案删除不影响其他档案/PDF/购买权益。 |
| B4（09–12） | P0 | **B4 原型与像素基准完全缺失** | README 要求约 25 张 09–12 状态图，09 必须逐页 6–8；当前目录无对应 PNG/source，`prototype_v1_1.html` 仅 06。 | 先出 B4 source/PNG、PHAssetMask、fixture，产品批准后才开始像素 PASS/FAIL；此前任何“09–12 UI 已验收”结论无效。 |

### B2–B4 放行条件

1. B2：敏感/never-use 可逆闭环、审核详情/批量/zero-match、真实扫描状态机和全部 05/06 approved 设计与测试证据齐备。
2. B3：产品先裁决日期范围；随后完成范围数据模型、隐藏折叠/恢复、章节管理韧性与 07/08 设计/测试证据。
3. B4：先统一 preview/PDF 渲染模型；再关闭购买、导出和多档案/删除失败状态，补齐 09–12 设计资产、StoreKit/Sandbox 与真机 PDF 证据。

在以上任一条件未满足时，B2–B4 的结论只能是**功能/局部 demo 可运行，不可发布、不可高保真签收**。
