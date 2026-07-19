# Confirmation grid scroll stability

The confirmation grid now gives each asynchronous `PHAsset` tile a stable
square measurement before and after the thumbnail callback. This prevents
degraded/full-quality PhotoKit updates from changing LazyVGrid row heights and
causing scroll-position oscillation. The pending-review gate is presented as a
stable sheet so the fixed bottom CTA does not compete with a changing grid
layout.

Runtime evidence: `/tmp/tailor-confirm-jitter-fixed2.png` (390×844 simulator).

Build verification: `xcodebuild ... build CODE_SIGNING_ALLOWED=NO` passed.
