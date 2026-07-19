# 03–04 Candidate Alignment — Engineering Round 2

Date: 2026-07-15  
Target: `Tailor` simulator `41F93DB0-C75A-4044-BD9D-C7D90D00FE9B`, normalized 390 × 844 capture  
Revision: current working tree (uncommitted)

## Verified implementation changes

| State | Change | Directional result |
| --- | --- | --- |
| 03 profile-valid | Converted title to a single multiline accessibility/rendering node; adjusted selector/form rhythm; preserved the reference CTA vertical rhythm. | The title is now stable in a runtime screenshot. Under the candidate's implicit content-area comparison, selector, input, year fields, information card and CTA are within roughly 1–8 px of the candidate geometry. |
| 04 references-ready | Converted the title to one multiline node; compacted the helper card into the candidate's one-line detail; adjusted second grid-row rhythm. | Candidate content positions are directionally aligned after excluding status chrome: title/body/grid/count/helper card are within roughly 0–6 px. |

## Deliberate 04 exception

The candidate has no declared status-bar/safe-area policy. Moving the `Start looking` CTA to its candidate y-coordinate caused the real runtime safe-area inset to cover the helper card. The implementation retains the actual iOS safe-area placement so every required element remains visible and tappable. This leaves the CTA approximately 31 px below the candidate PNG and is **not a pixel PASS**.

## Remaining gate

`docs/mobile-prd-plans/Tailor_iOS/08_reference_01_04_promotion_adjudication_2026-07-15.md` remains controlling. 03 still lacks unsupported-species and validation-error approved states; 04 still lacks an approved PHAsset fixture/asset-unavailable state and an approved chrome mask. The current candidate images therefore cannot support formal overlay/diff acceptance.
