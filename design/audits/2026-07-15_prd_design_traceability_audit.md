# Tailor v1 · PRD 到设计交付物可追溯性审计

审计日期：2026-07-15  
审计范围：`Tailor_v1_PRD.md` 与 `design/` 内 v1.1 原型、设计增量、详细规格、交接包、资源清单、视觉验收矩阵。  
审计方式：只读文档/原型结构核对；未将“文案写入规格”误判为“页面已高保真设计或可点击验证”。

## 结论

设计规则层面对新版 PRD 的覆盖是**部分合格**：`ui_spec.md` 与 `v1_1_design_delta.md` 已明确敏感素材、永不使用、时期隐藏、6–8 页真实水印样章与无通知原则。

但设计交付层**不具备签收条件**，也不足以称为“12 页及异常态已完成高保真、可点击原型”。仓库没有 Figma/Relay 源文件；`prototype_v1_1.html` 只有 06 照片确认的四张静态画板，且没有点击事件；旧 `prototype.html` 虽有 12 张画板，也没有交互，并保留与新版 PRD 冲突的内容。PRD 第 7 节第 3 条要求的正式视觉规格仍为未关闭 P0。

状态定义：

| 状态 | 含义 |
| --- | --- |
| 已规则化 | 有文字规格/验收描述，但没有相应高保真画面或可点击证据。 |
| 已画板化 | 有静态画面；并不表示交互、异常态或真实素材逻辑已经设计。 |
| 可签收 | 有来源可编辑设计稿、主态/异常态、可点击路径、标注与验收截图。当前无页面达到该状态。 |

## P0：阻断设计签收与研发门禁

| ID | PRD 要求 | 现有证据 | 缺口与影响 | 必须补齐 |
| --- | --- | --- | --- | --- |
| D-P0-01 | 12 页、权限/扫描/内购/导出失败的正式视觉规格（PRD 85–91，尤其第 89 行） | `DESIGN_HANDOFF.md:30–43` 仅列为“应完成”；仓库无 `.fig`、Relay 导出或等价可编辑源文件。 | 没有可签收的设计源，研发只能依据文本猜测尺寸/状态；PRD 自己列出的发布前 P0 未关闭。 | 交付并链接 Figma/Relay（或版本化等价设计源），每页含主态与规定异常态、组件标注和版本号。 |
| D-P0-02 | 原型应覆盖完整流程且主按钮/返回可走通（PRD 25–27、33–46） | `prototype_v1_1.html:7–10` 仅有 4 个 06 静态 `<section>`；文件无 JS、`onclick`、链接或实际 `<button>` 交互。`prototype.html` 虽有 12 个画板，却同样无导航实现。 | 无法验证欢迎到导出、返回、取消、重试、保存进度路径；“可点击原型”宣称不成立。 | 将原型改为状态化可交互流程，并至少录制/自动化验证主闭环和每个失败返回路径。 |
| D-P0-03 | 照片确认须有 High/Needs review/Excluded/**Sensitive**、原图查看、批量与永不使用（PRD 40、60–63） | 文字规则在 `v1_1_design_delta.md:12–55` 与 `ui_spec.md:79–87`；v1.1 原型只展示 High、Needs review、候选查看器、待确认拦截。 | 未提供 Sensitive 分组、保护卡、`Use/Decide later/Never use` 二次确认、Never use 折叠管理、Excluded 恢复、年筛选 sheet、批量操作、零匹配画面。敏感素材安全路径不能被设计/测试验证。 | 为上述每个状态增加画板及交互连接；Never use 影响章节封面/预览/PDF 的反馈需有页面证据。 |
| D-P0-04 | 可按年份/日期范围隐藏；隐藏期不展示代表图且不进预览/PDF（PRD 41、62、69） | 规则在 `v1_1_design_delta.md:57–73`，`ui_spec.md:89–97`。 | 没有 07 的 `Edit periods`、年份/日期范围 sheet、影响摘要、`Hidden periods (n)` 折叠/恢复、章节部分隐藏状态的 v1.1 画板或交互。 | 补齐 07 的可点击设计与边界态；包含无图隐藏态、恢复后加载封面及与预览页码重算关系。 |
| D-P0-05 | 未购买预览是真实 6–8 页、封面/目录/至少两时期章节与结尾，逐页水印，素材不足降级说明（PRD 19、43、75–77） | 规则完整地在 `v1_1_design_delta.md:75–101` 与 `ui_spec.md:109–117`；旧 `prototype.html:14` 仍写“Cover, contents, and two sample pages”，仅一个书封画面，并使用 `TAILOR · SAMPLE`。 | 当前唯一 09 画板与新版 6–8 页、逐页水印、分页操作和真实素材/降级规则冲突；没有 6–8 页实体设计/页面状态，无法验证预览与 PDF 内容一致性。 | 产出 6–8 页页面序列、分页按钮/页码、加载/失败/购买后无水印态，以及一章/无合格照片降级画面；废弃或明确标记旧 09 画板。 |
| D-P0-06 | 失败不丢进度；权限拒绝、扫描中断、购买失败、PDF 失败均可重试（PRD 20、27、36、39、44–45） | `ui_spec.md` 对这些状态有文字描述；`design/design_spec.md:49` 明言失败/受限“仍须补齐为单独可交互状态”。 | 没有足够画面或路径可验证：02 limited/denied，05 paused/interrupted/low-battery/failed/complete，09 loading/failed，10 purchasing/cancel/failure/restore，11 page-size/rendering/failed/file unavailable，12 empty/access-revoked/delete-failure。 | 将这些状态列为每页必交付画板与原型节点；每个失败节点都必须连到“重试/返回且保留状态”。 |
| D-P0-07 | 不虚构宠物经历；章节无证据时用中性标题（PRD 51、70–71） | `prototype.html:12` 仍显示 `The beginning` 与 `A life remembered`。 | 这两个标题暗示未经用户确认的叙事，与新版 PRD 直接冲突；旧原型仍在交接输入中，极易误导研发/测试。 | 从旧原型/PNG/交接引用中删除或显著标为“已废弃，不可实现”；用 `2018–2020` / `Days together` 等中性例子替代。 |

## P1：设计冻结前必须补齐

| ID | PRD 要求 | 当前状态 | 缺口 |
| --- | --- | --- | --- |
| D-P1-01 | 01–04 的全部可用/错误态（PRD 35–38、50） | 已规则化/旧静态画板化 | 01 Help/隐私 sheet；02 完整/受限/拒绝返回；03 表单错误、年份关系、其他动物；04 少于 3、失效资源、查看/替换/移除均无交互画面。 |
| D-P1-02 | 05 显式启动、暂停/恢复、前后台仅用户主动恢复、无通知（PRD 7、29、39、54） | 已规则化/旧画板化 | 无 paused、interrupted、low-battery、failed、complete 画面；也没有在档案页主动恢复入口的可见设计。应增加“无通知”检查说明而非只写文档。 |
| D-P1-03 | 08 可编辑标题/说明/选片/封面/排序（PRD 42、70–71） | 已规则化/旧画板化 | 无 add/remove、cover 替换、空章节、排序、保存失败/离开未保存提示的高保真或交互。 |
| D-P1-04 | 10 只陈述交付/价格/隐私；取消/失败/恢复状态（PRD 44、55、77） | 已规则化/旧画板化 | 主态没有显示设计规格要求的法律细则；购买中/取消/失败/恢复无画板。注意避免在失败状态加入情绪催促。 |
| D-P1-05 | 11 A4/US Letter、本地生成、系统分享、错误保留内容（PRD 45、81） | 已规则化/旧画板化 | 只有完成态；缺少页尺寸选择、渲染进度、失败、再次生成、系统分享前后说明。 |
| D-P1-06 | 12 多档案、重扫、权限管理、删除二次确认（PRD 46、81） | 已规则化/旧画板化 | 空档案、访问撤销、重扫选择、删除 sheet/失败没有设计。 |
| D-P1-07 | 真实照片与资源边界（PRD 5、16、81） | 资源策略正确，但审计证据不完整 | `v1_1_resource_manifest.md` 正确规定 06–09 不生成宠物图；但旧原型普遍使用色块/剪影，尚无“真实 PHAsset / 无权限占位”对照画面。资源 manifest 也未包含品牌图标/欢迎图的最终来源、license/provenance、1x/2x/3x/打印纹理验收。 |
| D-P1-08 | 390pt、动态字体、无障碍、可达性（PRD 规格隐含 iPhone-only 交付；设计验收第 123 行） | 仅文字要求 | 没有 320pt、AX3/XXL、Increase Contrast、VoiceOver 截图或焦点顺序证据；`prototype_v1_1.html` 的四标签是溢出裁切样式，未证明横向滚动或键盘焦点可达。 |

## P2：一致性与交付卫生

| ID | 发现 | 证据 | 修正 |
| --- | --- | --- |
| D-P2-01 | 设计权威来源不唯一。 | `DESIGN_HANDOFF.md:21` 把 `prototype.html` 称为输入；第 82 行说 v1.1 优先，但旧 12 屏/PNG 仍可被误用。 | 建立 `design/README.md` 的权威顺序：PRD → v1.1 Figma/Relay → token/components → prototype；把旧画板移入 `archive/` 并加 deprecated 标识。 |
| D-P2-02 | “所有页面和异常态均可覆盖”的交接声明与实际文件不一致。 | `DESIGN_HANDOFF.md:30–43,73–78` 与静态/缺失节点矛盾。 | 将交付状态改成逐页矩阵：`spec / static / clickable / runtime verified`，禁止用“完成”代替证据。 |
| D-P2-03 | 视觉验收矩阵是“待改清单”，不是通过证据。 | `visual-qa/01-12_acceptance_matrix.md:3,113–119` 自称 Required SwiftUI change，要求截图/叠图，但只存 01 before/after。 | 矩阵增加 Owner、实现提交、截图路径、差异结论、关闭日期；未有截图不可标为通过。 |
| D-P2-04 | 资源输出清单正确限制了宠物图，但纹理交付状态不清。 | `v1_1_resource_manifest.md:22–24` 说如需高分辨率才补交；`asset_requirements.md:19–21` 要 3000×4200。 | 明确 v1 是否需要印刷级 PDF；需要则将三张带 provenance 的 print asset 作为上线门禁，不需要则更新 PDF 分辨率策略。 |

## 逐页设计覆盖判定

| 页面 | PRD 设计规则 | 静态主画板 | 可点击/异常态证据 | 判定 |
| --- | --- | --- | --- | --- |
| 01 欢迎 | 有 | 旧原型 | 无 | 已规则化，未可签收 |
| 02 权限 | 有 | 旧标准态 | limited/denied 无画板/路径 | 未完成 |
| 03 建档 | 有 | 旧标准态 | 校验/年份关系/其他动物无 | 未完成 |
| 04 参考照 | 有 | 旧标准态 | 0–2、失效、替换/查看无 | 未完成 |
| 05 扫描 | 有 | 旧 running 态 | pause/interrupted/low battery/failed/complete 无 | 未完成 |
| 06 确认 | 有，v1.1 详细 | 仅 High/Needs review/viewer/gate | Sensitive/Never use/Excluded/zero/batch/filter 无；无可点击 | 部分完成，不可签收 |
| 07 时间线 | 有 | 旧标准态 | hide period/range/restore/empty/menu 无 | 未完成 |
| 08 章节编辑 | 有 | 旧标准态 | add/remove/reorder/empty/dirty/failure 无 | 未完成 |
| 09 预览 | 有，v1.1 详细 | 旧单封面，且与新版冲突 | 6–8 页/加载/失败/已购无 | 未完成 |
| 10 购买 | 有 | 旧标准态 | purchasing/cancel/failed/restored 无 | 未完成 |
| 11 导出 | 有 | 旧完成态 | page size/rendering/failed/file unavailable 无 | 未完成 |
| 12 档案 | 有 | 旧标准态 | empty/access revoked/delete sheet/failure 无 | 未完成 |

## 重新建立设计门禁（建议作为本轮统一门禁）

1. **PRD traceability gate**：产品为 PRD 第 35–46、58–77、85–92 每项分配唯一设计节点；没有节点不得排入开发完成。
2. **Design-source gate**：设计师提供可编辑 Figma/Relay 链接/导出与版本号；HTML/PNG 只作为评审快照，不能替代源设计。
3. **Prototype gate**：每一条主流程和每个异常节点具有可点进/回退/取消/重试路径；06 必测 High → pending → 原图决策 → pending gate，07 必测 Hide/Restore，09 必测分页/水印/降级。
4. **Safety-data gate**：用同一组受控样本验证 sensitive、neverUse、date-range-hidden 在 confirmation、timeline、chapter、preview、PDF 的可见性均为零；保留系统 Photos 原图。
5. **Visual gate**：390×844 主态和指定异常态逐页截图，与权威设计叠图；P0 零差异或有批准的偏差记录。没有证据即未通过。
6. **Accessibility and resilience gate**：320pt、AX3/XXL、Increase Contrast、VoiceOver；权限拒绝、扫描/购买/PDF 失败均验证编辑状态保留。无通知/无自动回忆用启动、回前台、相册变化、周年日期四种事件回归。

## 本轮签收结论

**不通过设计签收；不得把“设计完成”作为研发/测试全量通过的前置结论。**

可继续开发已文字化的规则，但以下项目必须作为发布阻断项跟踪：D-P0-01 至 D-P0-07。设计师应先补齐 06 敏感分支、07 隐藏期、09 6–8 页样章和全流程异常态，再组织产品、研发、测试进行同一份追溯矩阵上的联合复核。
