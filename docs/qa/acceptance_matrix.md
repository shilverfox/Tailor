# Tailor v1 Acceptance Matrix

This matrix connects the authoritative PRD requirements to detailed design and the evidence that must be attached to a release candidate. `TC-*` refers to [tailor_v1_test_cases.md](tailor_v1_test_cases.md). Screens refer to `design/detailed/ui_spec.md`; implementation boundaries refer to `design/detailed/developer_handoff.md`.

| Requirement / release gate | Source requirement | Design / implementation reference | Verification evidence | Tests | Gate |
| --- | --- | --- | --- | --- | --- |
| End-to-end archive completion | PRD §§1–3 | Screens 01–12; handoff §1 | Physical-device recording, produced PDF, archive card | TC-001, 005 | P0 |
| iOS 17+, iPhone-only, no account/sync | PRD §1 | Handoff §1/§4 | Supported-device matrix; routing/config review | TC-001, 052 | P0 |
| Explain privacy before access | PRD §4 page 02; §6 | Screen 02; handoff §4 PhotoKit | System-dialog recording and copy screenshot | TC-010 | P0 |
| Full, limited, denied, restricted paths | PRD §§2–3 | Screen 02 states; handoff §5 | Per-state screenshots/video and authorization test logs | TC-010–012 | P0 |
| 3–5 valid reference photos | PRD §4 page 04 | Screen 04; handoff §1 ReferenceFeature | Picker state screenshots/test results | TC-013–014 | P0 |
| On-device scan, pause/recovery | PRD §§2–3, §6 | Screen 05; handoff §2 ScanState | Checkpoint persistence log, relaunch recording | TC-020–023 | P0 |
| Low confidence is never auto-included | PRD §§2,5 | Screen 06; handoff §4 matcher | Candidate fixture state assertions and generated-PDF asset list | TC-024–027 | P0 |
| Manual confirmation and correction | PRD §4 page 06 | Screen 06 interactions | Screen capture of This is/Not/Skip/Undo/Restore | TC-025–026 | P0 |
| Evidence-based neutral storytelling | PRD §5 | Screens 07–08; handoff §5 visual | Fixture output review and copy scan | TC-030, 033, 062 | P0 |
| Chapters are editable/recoverable | PRD §§2,4 | Screens 07–08 | Persistence/reopen recording; source-photo state audit | TC-031–033 | P0 |
| Three local preview templates | PRD §4 page 09 | Screen 09; handoff §3 TemplateSwatch | Snapshot set for all styles | TC-040 | P1 |
| Free sample limits and watermark | PRD §4 page 09; handoff §5 | Screen 09 state | Preview page screenshots/content inspection | TC-040 | P0 |
| Correct one-time IAP | PRD §6 | Screen 10; handoff §4 StoreKit | StoreKit test transaction report | TC-041–042 | P0 |
| Purchase failure/cancel/restore preserves work | PRD §§2–3 | Screen 10 states; handoff §2 | State persistence assertions/video | TC-041 | P0 |
| Local, watermark-free paid PDF | PRD §§1,6 | Screens 09/11; handoff §4 PDF | A4 and Letter PDF artifacts, metadata/traffic audit | TC-042–043 | P0 |
| Export failure/relaunch retains edits | PRD §§2–3 | Screen 11 states; handoff §2 | Failure/retry and relaunch recording | TC-044 | P0 |
| System-directed sharing only | PRD §4 page 11 | Screen 11; handoff §4 ShareLink | Share Sheet recording; destination/cancel verification | TC-045 | P1 |
| Multiple archives/rescan/access warning | PRD §4 page 12 | Screen 12; handoff §1 ArchiveFeature | Archive/rescan test recording | TC-050 | P1 |
| Delete all Tailor data, not originals/entitlement | PRD §§2,4,6 | Screen 12 delete sheet; handoff §2 | Before/after app-container and Photos audit; entitlement check | TC-051, 053 | P0 |
| Offline except StoreKit | PRD §2; Test Plan | Handoff §5 | Airplane-mode recording; network capture | TC-043, 052 | P0 |
| No photo upload/copy/modify/delete | PRD §§2,6; Test Plan | Global/screen privacy copy; handoff §4 | Proxy logs, container inspection, Photos before/after inventory | TC-052 | P0 |
| Accessibility / Dynamic Type / motion | Handoff §5 | Global a11y + screens 01–12 | Accessibility Inspector/XCUITest audit, device screenshots | TC-060–061 | P0 |
| Restrained memorial visual/content policy | PRD §5 | Screens 01, 07–09; asset guidance | Design/copy review and screenshot pack | TC-030, 062 | P1 |
| P0 ML validation: accuracy, threshold, runtime/battery | PRD §7(1) | Handoff §6(2) | Separate ML benchmark report: dataset definition, precision/recall by age/multi-pet, latency, energy; approved threshold | TC-020–027 plus ML report | P0 external gate |
| P0 App Store product/privacy readiness | PRD §7(2) | Screen 10; handoff §6(1) | App Store Connect screenshot/configuration, privacy nutrition label, legal copy approval | TC-041, 052 | P0 external gate |
| P0 formal visual source and redlines | PRD §7(3) | Handoff §6(3) | Editable Figma/Relay, 12 screen + failure-state redlines, physical-device sign-off | TC-060, 062 | P0 external gate |

## Evidence package for sign-off

1. P0 execution report with device/OS/build, timestamps, tester, result, defect links, and attached screenshots/video.
2. StoreKit sandbox transaction/restore evidence and an unwatermarked A4 + US Letter PDF produced from the same approved archive.
3. Privacy evidence: proxy/network capture, app-container inventory, and before/after Photos-library audit.
4. Accessibility evidence at 320 pt and 390 pt for default and Accessibility XXL, plus VoiceOver traversal recording.
5. ML, App Store, and editable-design external-gate artifacts listed above. A green UI suite alone does not close these gates.
