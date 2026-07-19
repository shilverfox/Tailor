# Tailor v1 · Asset requirements

All dimensions are pixels at 3× unless stated otherwise. Product UI uses local user-authorized `PHAsset` thumbnails for pet photos; AI-generated assets are decorative/editorial only and must not imply they depict the user’s pet or a recovered memory. SF Symbols require no exported raster file.

## Delivery convention

- Asset catalog namespace: `Tailor/Assets.xcassets/Brand/` and `Tailor/Assets.xcassets/Editorial/`.
- Provide PNG (sRGB) with no embedded text/watermark; retain source prompt and provenance beside delivery.
- Use `@1x/@2x/@3x` if raster is used in UI. PDF previews are rendered locally, so template textures should also have a vector or high-resolution print source.
- Do not package generated dogs/cats inside PhotoKit result grids, timeline covers, or real archive page examples.

## Required visual assets

| Resource name | Size / crop | Use | Direction / prompt |
| --- | --- | --- | --- |
| `editorial_welcome_companion` | 3600×2400, 3:2 landscape; keep animal in central 70%, safe 390×286-pt crop | Welcome screen hero only; can be replaced by licensed editorial photography. | `A quiet documentary-style photograph of one adult mixed-breed dog resting beside a sunlit window on a simple woven rug, warm natural morning light, muted cream, deep forest green and clay-orange environment accents, authentic candid composition, low saturation, subtle paper-like grain, no person visible, no text, no collar tag readable, no rainbow, no angel wings, no fantasy, no memorial props, no watermark, photographic realism` |
| `brand_app_icon_master` | 3072×3072 square, no transparent corners; design also delivered as editable vector | App-icon exploration. **[Assumption]** final logo direction: a simple folded-paper “T” / archive-tab abstract mark, no pet silhouette. | `Minimal premium app icon, abstract folded paper bookmark forming a subtle letter T, deep ink green on warm ivory paper, one restrained clay-orange seam, flat vector-like geometric form, no words, no animal, no gradient, no shadow, centered, iOS app icon composition` |
| `brand_wordmark_reference` | 2400×800 transparent PNG + vector | Design reference/export only; use native text in app. **[Assumption]** wordmark is temporary until brand freeze. | `Editorial wordmark reading TAILOR, refined warm editorial serif typography, deep ink green on transparent background, generous letterspacing, no icon, no effects, no watermark` |
| `template_warm_paper_texture` | 3000×4200, 5:7 portrait seamless/light texture | PDF background at low opacity; preview swatch. | `Subtle uncoated warm ivory archival paper texture, barely visible natural fibers and soft grain, evenly lit, no stains, no writing, no border, no shadows, seamless-feeling, print-ready` |
| `template_quiet_night_texture` | 3000×4200, 5:7 portrait | Quiet Night PDF background / swatch. | `Very subtle deep ink green matte paper texture, minimal warm paper fibers, low contrast, no words, no stars, no rainbow, no vignette, print-ready flat background` |
| `template_field_notes_texture` | 3000×4200, 5:7 portrait | Field Notes PDF background / swatch. | `Subtle pale sage archival notebook paper texture with faint understated warm-gray rule lines, low contrast, no writing, no borders, no shadows, print-ready` |
| `empty_archive_still_life` | 1800×1200, 3:2 | Optional empty-state illustration for archive list. Must be used only if no real archive exists. | `A quiet still life of a closed blank warm-ivory photo album and a small simple leaf on a wood table, soft natural side light, muted cream, ink green and clay-orange palette, restrained editorial photographic style, no pet, no person, no text, no rainbow, no sentimental props, no watermark` |

## Image-generation protocol

Use right.codes `gpt-image-2` only after brand/legal review. Submit asynchronously, retain `task_id`, prompt, timestamp and source URL in an internal asset manifest; download and manually inspect output before adding it to the asset catalog. Required negative constraints are included in each prompt. A generated image that resembles a specific user pet must not be used as its stand-in.

## Local-photo rendering requirements (not generated assets)

| UI region | Source and crop behavior | Privacy/empty rule |
| --- | --- | --- |
| Reference slots | User-selected `PHAsset`; 3:4, aspect-fill; focus central subject but preserve original. | Empty slots show neutral `photo.badge.plus` + label. |
| Scan strip | Small local thumbnails, 1:1, 38 pt. | Show only assets within current authorization scope. |
| Confirmation grid | `PHAsset` thumbnails, 1:1; tap opens original aspect-fit viewer. | Never write thumbnail data as a permanent copy. |
| Timeline/chapters | User-confirmed thumbnail, 1:1 cover; original retained as source. | Neutral placeholder if selected cover removed. |
| PDF pages | User-confirmed original rendered at appropriate print resolution. | Generated editorial assets never substitute for a photo. |

### v1.1 selection safety additions

- Sensitive, `neverUse`, and date-range-hidden assets have no asset-catalog equivalent and must not be copied into a preview/PDF cache. They are runtime eligibility states on the user-authorized `PHAsset` only.
- Free previews use the same real, currently eligible photos as the archive. The repeated `TAILOR · PREVIEW` watermark is native drawn text, not a supplied raster and not a blur substitute.
- See `v1_1_resource_manifest.md` for the authoritative v1.1 resource output/non-output list.

## No-export list

Do not create custom illustrations for standard UI icons, photo permission, scanning, purchase, errors, sharing, or delete confirmation. Those surfaces use SF Symbols and semantic color so they work with Dynamic Type, contrast modes, and localization.
