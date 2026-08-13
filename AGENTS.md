# CameraGeometryKit Development Rules

These rules are architectural constraints, not suggestions.

## Platform

- iOS 18 or later only.
- Swift 6 language mode only.
- Prefer Apple frameworks. Add no third-party dependency without a concrete reduction in total complexity.
- Do not add compatibility paths for iOS 17 or earlier or Swift 5.

## Canonical image space

- App-semantic image locations use `CanonicalPoint` / `CanonicalRect`.
- Canonical space is the uncropped, upright, non-mirrored image normalized to 0...1, top-left origin, x right, y down.
- Do not pass an untyped `CGPoint` / `CGRect` between coordinate domains when the domain matters.
- Do not clamp canonical values implicitly. Crops and aspect-fill mappings may legitimately produce values outside 0...1.
- Imported `UIImage` values must be canonicalized to orientation `.up` and scale 1 before image-space geometry is derived from them.

## Rotation

- `AVCaptureDevice.RotationCoordinator` is the authoritative source of camera rotation.
- Preview angle and capture angle are different values with different responsibilities.
- Never infer camera rotation from `UIDeviceOrientation`, `UIWindowScene`, interface orientation, front/back position, device model, or pixel-buffer width/height.
- Recreate the rotation coordinator when the active camera device changes.
- Never add model-specific 90-degree fixes. A device-specific failure belongs in validation evidence first, not production branching.
- If `AVCaptureVideoDataOutput` has a nonzero `videoRotationAngle`, AVFoundation physically rotates the delivered pixel buffer. Do not rotate it again downstream.
- For `AVCaptureVideoDataOutput + AVAssetWriter`, prefer sensor-native/unrotated buffers and `AVAssetWriterInput.transform` instead of rotating every frame.

## Mirroring

- Rotation and mirroring are separate policies.
- Canonical analysis and saved media are non-mirrored unless a product explicitly requires otherwise.
- A front-camera preview may be mirrored, but that does not change canonical image identity.
- Never assume "front camera" means "stored media is mirrored".

## Vision

- Vision normalized geometry uses a different origin. Convert through `VisionGeometry` before it enters app state or UI.
- Vision consumes canonical frame buffers with the orientation metadata carried by `CameraFrameGeometry`.
- Do not run Vision or other heavy image analysis on MainActor or in the capture delegate callback.
- Do not expose raw `VNObservation` objects as cross-thread app state when a small Sendable canonical result will do.

## Real-time frame pipeline

- Frame processing is bounded. Never accumulate an unbounded frame queue.
- One expensive analysis is in flight at a time; retain at most the newest pending frame.
- `CameraFrameID` and timestamps identify the accepted source frame. Derived results must keep that identity when synchronization matters.
- Configuration changes, camera switches, and screen departure invalidate old processing generations.
- Old-generation results must never overwrite new state.
- Cancellation should cancel the active Vision request when possible and always suppress stale publication.
- High-rate diagnostics are aggregated off-main and published as small value snapshots.

## Preview and touch

- For custom previews of canonical images/frames, map touch through `ViewportMapping`.
- For `AVCaptureVideoPreviewLayer` focus/exposure, use AVFoundation conversion APIs and the distinct `CaptureDevicePoint` type.
- Do not pretend capture-device point-of-interest coordinates are canonical image coordinates.
- Respect aspect-fit letterboxing and aspect-fill cropping explicitly.

## Validation

- Simulator success is not sufficient for camera orientation, front-camera mirroring, TrueDepth, depth, or device-specific behavior.
- Record real-device results under `docs/validation/<device>/` and `docs-ja/validation/<device>/`.
- A device folder records evidence; it must not become a reason to add device-model branches.
- At minimum validate front/back, portrait/landscape left/landscape right, rotation lock on/off, camera switch, background/foreground recovery, preview, frame, Vision overlay, and photo output where applicable.
- Keep diagnostics visible during validation: preview angle, capture angle, analysis connection angle, mirror flags, frame dimensions, dropped/replaced frames.

## Documentation

- `README.md` and `docs/*.md` are English.
- `README-ja.md` and `docs-ja/*.md` are Japanese mirrors.
- When behavior changes, update both languages in the same change.
- Keep prohibited patterns in `docs/PROHIBITIONS.md` and `docs-ja/PROHIBITIONS.md` synchronized with this file.

## Change discipline

- Keep the package a camera-geometry and frame-boundary foundation, not a universal CameraManager.
- Do not add effects, app-specific UI, or feature switches to the package core.
- Add the smallest complete API that preserves the invariants above.
- Update tests and validation documentation with behavior changes.
