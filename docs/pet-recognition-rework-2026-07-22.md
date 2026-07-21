# Pet Recognition Rework — Design & Plan

Date: 2026-07-22
Owner: engineering
Status: design agreed; implementation staged (Step 1 first)

## Goal

Reliably recognize **this specific** cat or dog (individual re-identification), not
"is there an animal in the photo." The current pipeline has the right *shape*
(cheap species gate → expensive identity gate) but its identity evidence is a
generic image-similarity model applied to whole frames, which is the root cause
of false inclusions (another similar white dog, a child, a monkey) and false
exclusions (same pet, different background).

This is a **rework**, not a tuning pass: it moves recognition from "generic image
similarity" toward "usable pet candidate recall."

## Current architecture (as of cb2c380)

File: `Tailor/Services/PhotoKitVisionScanner.swift`

1. **Species gate (cheap, first).** `VNRecognizeAnimalsRequest` with a species
   keyword filter (dog/cat). Confidence < `animalSpeciesGate` (0.60) → rejected.
   `ScanWorkloadPolicy.shouldGenerateEmbedding` ensures the expensive model runs
   only after this gate — correct cost control for large libraries.
2. **Identity gate (expensive, second).** `VNGenerateImageFeaturePrintRequest`
   on the image; distance to each reference photo via `computeDistance`;
   similarity < `identityCandidateGate` (0.42) → rejected as "right species,
   wrong individual."
3. **Confidence blend.** `animal*0.35 + maxSimilarity*0.65` (identity-weighted).
   Auto-select requires blend ≥ `highAutoConfidenceGate` (0.86) AND ≥ 2 agreeing
   references.

## Root problems (agreed)

1. **Generic features ≠ pet-individual features.** `VNGenerateImageFeaturePrint`
   is a general visual-similarity model. It should be treated as *candidate
   recall* ("visually similar"), never as *confirmation* ("same pet"). It is
   sensitive to background, composition, age, pose, lighting.
2. **No crop to `subjectRegion` before feature extraction.** The animal box is
   already computed by `VNRecognizeAnimalsRequest` but the feature print is taken
   from the **whole image** (`featurePrint(for: cgImage)`), wasting the detection
   and polluting the vector with background. *Highest-value fix.*
3. **256×256 too low for individual comparison.** `.fastFormat` + 256px is fine
   for the species gate, not for distinguishing individuals.
4. **`1 - distance/20` is a magic pseudo-probability.** Vision `computeDistance`
   is only meaningful as a *relative* ordering within one model version; `/20`
   gives the 0.42 / 0.86 thresholds no real statistical meaning.
5. **Thresholds uncalibrated.** All gates are "conservative starting points" per
   their own comments. `PetRecognitionEvaluationReport` exists but has no labelled
   set, so accuracy is currently unquantified.
6. **One best region per photo.** With multiple animals, or a small/occluded
   target, the single best box may not be the user's pet.

## Plan (staged, in priority order)

### Step 1 — Crop to the detected animal region before feature extraction  *(do first)*

- Both **candidate and reference** photos go through the **same** flow:
  `VNRecognizeAnimals → expand box by margin → crop → feature print on the crop`.
  Cropping only candidates would make the two feature spaces inconsistent.
- **Margin: expand the detected box by ~20%** (range 15–25%) on each side,
  clamped to image bounds. Prevents cutting off face/ears/tail and keeps some
  context, while sharply reducing background weight vs. the whole frame.
- **Coordinate system (verified):** `subjectRegion` is stored top-left normalized
  (`FocalCropPolicy.topLeftRegion` already converts Vision's bottom-left box via
  `y: 1 - box.maxY` and clamps to [0,1]). CGImage cropping uses top-left pixel
  coordinates, so `pixelRect = region × (imageWidth, imageHeight)` with **no Y
  flip**. Round to integer pixels and clamp to the image rect.
- If no animal box is available for a reference (detection failed), that
  reference should be dropped from the usable set rather than fall back to a
  whole-frame print (keeps the space consistent). Re-check
  `ScanReferencePolicy.minimumCount` (3) against the post-crop usable count.

### Step 2 — Two-stage resolution

- Stage 1: 256px for the species gate (fast reject of most non-pet photos).
- Stage 2: only for photos that pass the gate, load a 512–768px version and take
  the feature print on the **cropped** animal region. Keeps cost bounded — the
  whole library is never processed at high resolution.

### Step 3 — Remove pseudo-probability; keep raw distance + multi-reference stats

- Stop mapping distance to a fake [0,1] via `/20`.
- Persist the **raw distances**. Decide the bucket from: **min distance, median
  distance, and count of references within a hit threshold** — not a single
  scaled scalar.
- Ensure the model/extractor version is part of the cache key (already
  `featureExtractorVersion` in `FeatureEmbeddingKey`); bumping the version must
  invalidate/rebuild the index. Confirm this on version change.

### Step 4 — Labelled acceptance set (needs user + real consented photos)

- Build a consented, on-device labelled set. Quantify with the existing
  `PetRecognitionEvaluationReport`: candidate recall, candidate precision,
  high-confidence false-positive rate. Set explicit targets before any threshold
  change. Cannot be done without real data.

### Step 5 — Conservative auto-select until calibrated

- Multiple animals in one photo, or a small/occluded target, or a low-agreement
  match → **force `Needs review` (`decision = .pending`), never auto-select.**
- Until targets in Step 4 are met, keep auto-selection to a small minority;
  route the rest through fast batch confirmation.

## Open decisions (confirm before coding Step 1)

- Exact margin value inside the 15–25% band (proposed: 20%).
- Whether "multiple animals detected" is defined as ">1 box above the species
  gate" and how small "too small" is (proposed: target box area < ~5% of image →
  force review). These feed Step 5 but the detection signal is captured in Step 1.
