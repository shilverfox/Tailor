# Tailor App Preview Capture Shotlist

Status: draft for capture
Target output: clean app footage for the 30s App Store Preview and short social cuts

## Capture principles

- Use only fictional/demo pet content.
- Use dog/cat photos that look real, ordinary, and respectful.
- Do not use fantasy imagery, angel wings, halos, rainbow bridge imagery, or visibly distressed humans.
- Keep all visible names and years fictional.
- Prefer `Milo`, dog, Came Home `2017`, Left Us `2024`.
- Use English UI.
- Capture with clean status bar if possible.
- Do not show debug overlays, simulator controls, or local file paths.

## Required shots

| ID | Shot | Source | Capture length | Must show | Notes |
|---|---|---|---:|---|---|
| S01 | Welcome | Running app or `design/reference/v1_1/01-welcome-default.png` after current copy update | 3s | `Create a memory book` and value copy | Prefer running app because current local design reference has older copy. |
| S02 | Pet profile | Running app | 3s | Dog/Cat, name, Came Home, Left Us | Use gentle tap/typing. |
| S03 | Reference photos | Running app | 3s | 3–5 chosen photos and `Start looking` | If permission flow is noisy, use fixture route. |
| S04 | On-device scan | Running app or design reference | 3s | progress ring / checking moments | Overlay caption handles core message. |
| S05 | Photo review | Running app | 3s | grid, Include / Not this pet / create book | Demonstrates user control. |
| S06 | Privacy proof | Running app privacy screen or welcome privacy sheet | 2s | on-device / not uploaded | Should be a clean, readable hold. |
| S07 | Smart Draft | Running app or `design/auto-book-v2/screens/01-smart-first-draft.png` | 3s | arranging approved photos | Must avoid invented memory claims. |
| S08 | Story Plan | Running app or `design/auto-book-v2/screens/02-story-plan.png` | 3s | chapters, dates, selected moments | Establishes book structure. |
| S09 | Book Style | Running app or `design/auto-book-v2/screens/03-book-style.png` | 4s | Warm Paper / Quiet Night / Field Notes | This is a key quality shot. |
| S10 | Page Preview | Running app | 4s | page turn / preview pages | Show actual book pages, not only thumbnails. |
| S11 | Page Editor | Running app | 3s | Customize/edit, text or crop adjustment | Use one simple edit only. |
| S12 | Book Check | Running app or `design/auto-book-v2/screens/07-book-check.png` | 2s | print-ready / no blocking issues | If current UI is less polished than prototype, use real app for App Store and prototype only for internal brief. |
| S13 | Final Preview | Running app | 4s | full unlocked preview, no watermark | Show current toolbar with `Share page`. |
| S14 | Share page | Running app | 3s | tap `Share page`, preparing state or system share sheet | Avoid showing personal contacts in the system sheet. Crop if needed. |
| S15 | PDF export | Running app | 4s | `Your PDF is ready.`, `Save and share PDF` | This is the final paid-value shot. |
| S16 | End card | Designed graphic | 1s | app icon, Tailor, `Private Pet Memory Books` | Can be created in video editor. |

## App Store Preview compliance notes

For App Store Preview, use real app UI footage wherever possible. Prototype screens are acceptable for internal planning but should not be used as if they are shipped functionality. If prototype-quality visuals are materially different from the shipping app, capture the shipping app.

Do not show:

- simulator frame or desktop UI;
- app source code;
- PRD/prototype documents;
- non-shipping future features;
- fake App Store purchase success screens;
- price unless StoreKit returns it in the app UI;
- social media / Messages recipient names.

## Suggested capture routes

If UI test fixtures are used, prefer deterministic states:

| Purpose | Suggested route/state |
|---|---|
| Photo review ready | `confirm / review-ready` |
| Preview purchased | `preview / preview-purchased` |
| Final preview | `finalPreview` |
| Purchase | `purchase` |
| Export complete | `export` |
| Export rendering | `export / exporting` |
| Archive | `archive` |

Final exact launch arguments should be taken from `TailorUITests/TailorOnboardingUITests.swift` and current app routing before recording.

## Capture checklist

- [ ] Confirm legal/support URLs are not shown unless updated online.
- [ ] Confirm no old copy appears: `life archive`, `complete album`, `Your archive is ready`.
- [ ] Confirm no debug fixture labels are visible in captured app UI.
- [ ] Confirm no system photo permission alert is visible in final footage.
- [ ] Confirm share sheet does not reveal personal contacts.
- [ ] Confirm all captions remain readable on a muted autoplay preview.
- [ ] Confirm app footage matches current shipping UI.

## Raw asset naming

Use this structure:

```text
artifacts/marketing/app-preview/raw/
  01_welcome.mov
  02_profile.mov
  03_reference_photos.mov
  04_scan.mov
  05_review.mov
  06_privacy.mov
  07_smart_draft.mov
  08_story_plan.mov
  09_book_style.mov
  10_preview.mov
  11_editor.mov
  12_book_check.mov
  13_final_preview.mov
  14_share_page.mov
  15_export_pdf.mov
  16_end_card.png
```

## Still assets that can support the edit

Current local sources:

- `Tailor/Assets.xcassets/Editorial/WelcomeHero.imageset/WelcomeHero.png`
- `Tailor/Assets.xcassets/Editorial/WarmPaper.imageset/WarmPaper.png`
- `Tailor/Assets.xcassets/Editorial/QuietNight.imageset/QuietNight.png`
- `Tailor/Assets.xcassets/Editorial/FieldNotes.imageset/FieldNotes.png`
- `Tailor/Assets.xcassets/Editorial/ExportCompletionCompanion.imageset/ExportCompletionCompanion.png`
- `design/prototype_v2/page-share/page-share-final-preview-approved.png`
- `design/auto-book-v2/screens/03-book-style.png`
- `design/auto-book-v2/screens/08-final-export.png`

Use these as design references or non-App-Store social background material only when they do not misrepresent shipped UI.

