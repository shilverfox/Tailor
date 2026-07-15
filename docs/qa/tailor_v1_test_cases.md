# Tailor v1 Test Cases

**Scope.** iPhone, iOS 17+, on-device photos only. Run the P0 set on a physical device with a seeded Photos library (dog, cat, non-pet, duplicate, multiple-pet, old/new, missing-date assets). Unless stated otherwise, start with a clean install and no entitlement. Record screen capture, accessibility audit output, and generated PDF as test evidence.

**Priority:** P0 = release blocker; P1 = required before GA; P2 = regression/desirable. **Automation:** UI = XCUITest; Unit = XCTest; Integration = test-double/service integration; Manual = physical-device or App Store/system UI verification.

## A. Main journey and profile

| ID | Priority / automation | Preconditions | Steps | Expected result |
| --- | --- | --- | --- | --- |
| TC-001 | P0 / UI | Clean install; full Photos permission available; seeded dog assets. | 1. Open Tailor. 2. Tap `Create a life archive`. 3. Allow access. 4. Create valid dog profile. 5. Choose 3 references. 6. Complete/review scan; create timeline; edit chapter; preview; purchase sandbox entitlement; export. | User completes Welcome → Archives. Result is a local, watermark-free PDF; no account/login or network dependency is introduced except StoreKit. |
| TC-002 | P0 / UI + Unit | On Profile; current year known. | Leave name blank, leave departure year blank, then submit. Enter whitespace-only name. Set came-home later than departure. | CTA is disabled before valid input; submitted invalid fields show named inline errors, non-color-only error treatment; invalid year ordering is rejected; valid dog/cat + name + departure enables next step. |
| TC-003 | P1 / UI | Valid profile form populated. | Switch Dog ↔ Cat twice; enter optional came-home year. | Species changes preserve other fields. Year is optional and is used as a boundary only; no inferred story copy appears. |
| TC-004 | P1 / Manual | Future/import entry point capable of unsupported species. | Attempt an unsupported species. | Message says Tailor currently supports dogs and cats and provides a return action; no unsupported archive is created. |
| TC-005 | P1 / UI | At least one editable route. | Navigate back through every route; make chapter edit then back; exit active scan. | Each route has a safe return path. Dirty chapter prompts Keep editing/Discard changes. Active scan offers keep background, pause/return, or cancel; no choice is silently lost. |

## B. Permission and reference selection

| ID | Priority / automation | Preconditions | Steps | Expected result |
| --- | --- | --- | --- | --- |
| TC-010 | P0 / Manual + UI | Clean install; Photo authorization not determined. | Read Privacy screen, tap `Allow photo access`, grant full access. | Scope explanation precedes the system dialog. Full state confirms access and continues to Profile. Copy promises on-device processing/no upload. |
| TC-011 | P0 / Manual | Clean install; choose limited access in system picker. | Select a small set, continue; open Manage selected photos; return. | Persisted Limited banner says results only include selected photos. Manage and Continue actions work; scan never accesses unselected assets. |
| TC-012 | P0 / Manual | Clean install; deny/restrict Photos. | Tap allow and deny; choose manual; repeat and tap Open Settings then grant access. | Denied/restricted state has no dead end: manual picker and Settings actions work. Settings return re-evaluates scope. |
| TC-013 | P0 / UI + Integration | Reference picker test double; valid profile. | Select 0, 1, 2, 3, 5, then attempt 6 references; cancel picker. | Start disabled below 3; enabled at 3–5; sixth selection blocked; cancel retains existing selections; count updates and is announced. |
| TC-014 | P1 / Integration | Three references selected, then remove authorization/deletion for one asset. | Reopen References. | Unavailable tile is identified with replace/remove action; scan cannot begin until three valid references remain. |

## C. Scan, interruption, and matching decisions

| ID | Priority / automation | Preconditions | Steps | Expected result |
| --- | --- | --- | --- |
| TC-020 | P0 / Integration + Manual | 3 valid references; deterministic local matcher fixture. | Start scan and observe batches, counts and thumbnail updates; pause, resume. | Scan runs locally, exposes numeric progress and likely count, and Pause changes to Resume without resetting candidates/checkpoint. |
| TC-021 | P0 / Manual | Scan in progress at nonzero checkpoint. | Background/lock app; relaunch; simulate termination/relaunch. | Scan restores as paused/interrupted with saved checkpoint and resume action. Reviewed decisions/reference photos survive. |
| TC-022 | P0 / Manual | Scan in progress; low-power state simulator/device. | Enter low battery condition. | Warning offers pause/continue later; scan does not silently stop or erase work. |
| TC-023 | P0 / Integration | Matcher returns error with candidates, then without candidates. | Start scan; inject failure; tap Review matches so far; retry. | Error states preserve references and reviewed data. Review-so-far appears only if candidates exist; retry resumes/restarts safely. |
| TC-024 | P0 / Integration + UI | Fixture: high, needs-review, excluded candidates across years. | Open Review. Inspect tabs; create timeline without touching needs-review. | High starts selected; needs-review starts unselected; excluded is absent from archive. Confidence is conveyed by text/state as well as color. |
| TC-025 | P0 / UI | Needs-review item with metadata. | Open viewer; choose This is / Not / Skip; use optional swipe and undo; restore excluded item. | Explicit actions perform correct state changes; swipe is never the only route; undo works; Restore returns asset to review/appropriate pool. |
| TC-026 | P1 / UI | Review has multiple assets and year metadata. | Filter by year, enter multiselect, exclude >1, add selected to archive; inspect original. | Filter applies correctly. Batch exclusion requests confirmation. Viewer displays available date/location only; original is not edited. |
| TC-027 | P0 / Integration + UI | Matcher returns zero candidates; no manually confirmed photo. | Reach Review; attempt timeline creation. | Zero-match explanation offers different references, manual selection, and keep draft. Timeline CTA remains disabled until at least one confirmed asset; no image/story is fabricated. |

## D. Timeline and chapter editing

| ID | Priority / automation | Preconditions | Steps | Expected result |
| --- | --- | --- | --- |
| TC-030 | P0 / Unit + UI | Confirmed assets with weak dates and asset fixture with clear spans. | Generate timeline for both fixtures. | Timeline creates viable 3–6 chapters where possible; weak evidence uses neutral titles (year range/Days together), never claims first home/behavior/emotion. Empty set returns to Review. |
| TC-031 | P0 / UI | Timeline with adjacent chapters. | Rename, change cover, hide, merge with next, reorder. | All actions persist. Merge confirmation retains all photos. Hidden chapter stays recoverable in Hidden chapters and is excluded only from PDF. Reorder supports accessible Move earlier/later. |
| TC-032 | P1 / UI | One viable chapter; then an empty chapter. | Preview single chapter; remove every photo from another chapter. | Preview remains available for one chapter. Empty chapter offers Add photos/Delete; no silently deleted chapter or system asset. |
| TC-033 | P0 / UI + Unit | Existing chapter with >=2 photos. | Edit title/note; set/reorder cover; remove cover; Save. Edit then back and discard. | User wording is preserved; default wording remains date-driven. Removing cover selects next and announces change. Removed photo returns to confirmed pool. Save validates nonempty title. Discard restores prior persisted chapter. |

## E. Preview, purchase, and PDF

| ID | Priority / automation | Preconditions | Steps | Expected result |
| --- | --- | --- | --- |
| TC-040 | P0 / Snapshot + UI | Unentitled archive. | Switch each of 3 templates; browse preview pages. | Warm Paper, Quiet Night, Field Notes update preview. Free preview exposes only cover, contents and two clearly labelled watermarked samples; additional pages remain locked. |
| TC-041 | P0 / Integration + UI | StoreKit test configuration; unentitled archive with edits/style/page size. | Start purchase and cancel; start and inject failure; retry; restore prior entitlement. | Product is `tailor.life_archive.unlock`, one-time $19.99 display. Cancel/failure preserves all archive data and selected style/page size. Restore reports success or no purchase found accurately. |
| TC-042 | P0 / Integration + UI | StoreKit sandbox grants entitlement. | Purchase then return to Preview. | Entitlement gates a full render: watermark is removed in rendered content, primary changes to Generate full PDF, not just hidden visually. |
| TC-043 | P0 / Integration + Manual | Entitled archive; offline mode enabled. | Select US Letter, render; select A4, render; inspect both files. | Each PDF is generated locally, has selected paper dimensions, full chapters/selected photos, and no watermark. No photo/text is sent to a server. |
| TC-044 | P0 / Integration | Entitled archive with source edits. | Start export; inject render failure; relaunch during/after paused render; retry. | Error preserves decisions, chapters, style and selected paper size; retry works. Relaunch presents valid resume/regenerate state. |
| TC-045 | P1 / Manual | Completed local PDF. | Tap Save and share PDF; cancel system Share Sheet; select a destination. | Uses system Share Sheet from sandbox URL. Cancel is not an error. App does not auto-save to Photos or create server copy. Completion includes backup guidance. |

## F. Archives, deletion, privacy, offline

| ID | Priority / automation | Preconditions | Steps | Expected result |
| --- | --- | --- | --- |
| TC-050 | P1 / UI + Integration | Two profiles, one exported; access subsequently revoked. | Open Archives; reopen archive; rescan; manage access. | Cards show local status/template. Rescan preserves prior decisions and references. Revoked access warns per archive; existing local PDF remains available when valid. |
| TC-051 | P0 / Integration + Manual | Profiles, decisions, chapters, PDF and purchase entitlement exist. | Choose Delete all local Tailor data; inspect confirmation; cancel once; confirm deletion; relaunch. | Required second destructive confirmation explicitly says profiles/matches/edits/PDFs are removed, original Photos untouched. Successful delete yields empty state and removes Tailor data/PDFs only; StoreKit entitlement remains. |
| TC-052 | P0 / Manual + static audit | Device proxy/log capture; full journey including scan/export. | Enable flight mode for profile/scan/review/edit/export; inspect network logs, app container, Photos library before/after. | All non-purchase stages work offline. No originals are copied/persisted; only identifiers/allowed metadata and local render exist. No uploads of photos, names, metadata or notes; Photo Library remains unchanged. |
| TC-053 | P1 / Integration | Delete operation test double fails. | Confirm delete; inject storage/delete error; retry. | Archive list/data are retained on failure with error/retry. No partial claim of successful deletion. |

## G. Accessibility and visual regression

| ID | Priority / automation | Preconditions | Steps | Expected result |
| --- | --- | --- | --- |
| TC-060 | P0 / Manual + XCUITest audit | Every route and key error state. | Test VoiceOver traversal/actions, 48-pt targets, default/XL/Accessibility XXL/Bold Text/Increase Contrast at 390 pt and 320 pt. | No essential text clipped; every icon/button has a useful label; focus order is logical; grid reads date/state; controls meet target or documented exception; error/confidence is not color-only. |
| TC-061 | P1 / Manual + Snapshot | Scan and preview screens. | Enable Reduce Motion; operate progress/template/page controls without swipe. | Progress uses static/numeric updates; all carousel/grid workflows have explicit controls; watermarks/decorative imagery are not noisy VO elements. |
| TC-062 | P1 / Snapshot review | All screens and asset fallbacks. | Compare to approved 390-pt design; force missing hero/photo. | Tokens/layout follow detailed spec; fallback is Sage texture + photo symbol, never AI pet avatar; no rainbow bridge, wings, resurrection, pet speech, or fabricated-memory language/visuals. |

## Exit criteria

Release requires all P0 tests passing on at least one supported physical iPhone and current iOS 17.x, with no unresolved privacy/data-loss/accessibility defects. P1 failures require product-owner disposition and a tracked remediation before GA.
