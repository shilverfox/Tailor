# Tailor Mantis adapter spike

This is an isolated M7 feasibility package, not a dependency of the Tailor app target.

It pins Mantis 3.1.0 and proves a narrow persistence rule: Tailor may store a versioned, opaque `CropInfo` JSON payload, but it must render that payload by replaying it against the original PhotoKit image. The envelope never stores a cropped bitmap.

Passing this package does not approve production adoption. Remaining gates are the real SwiftUI crop session, Cancel/Done and Tailor Undo integration, perspective payload capture from the UI, app-size/accessibility measurement, physical-device large-image behavior, and Editor/Reader/A4/Letter pixel equality.
