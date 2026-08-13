# CameraGeometryKit Development Rules

## Platform
- iOS 18+ only.
- Swift 6 only.
- No compatibility code for older iOS, older Swift, or older Vision APIs.
- Prefer current Apple APIs and supported replacements.

## Geometry
- Use `CanonicalPoint` / `CanonicalRect` for app-semantic image locations.
- Canonical space is uncropped, upright, non-mirrored, normalized 0...1, top-left origin.
- Coordinate domains cross explicit mappings.
- Do not clamp canonical values implicitly.

## Capture
- `CameraCaptureSession` owns capture-graph mutation.
- Keep camera switching and session start/stop serialized through the wrapper.
- The exposed session is for preview attachment and inspection.

## Rotation and mirroring
- `AVCaptureDevice.RotationCoordinator` is the camera rotation source.
- Preview and capture angles are distinct.
- Do not infer rotation from UI/device orientation, camera position, device model, or pixel dimensions.
- Recreate the coordinator after camera switch.
- Use `videoRotationAngle` APIs, not older orientation-enum APIs.
- Rotation and mirroring are separate policies.

## Vision
- Use the iOS 18+ Swift-native Vision API.
- Use `ImageProcessingRequest.perform(...)` with `async` / `await`.
- Do not add a request-handler compatibility path.
- Keep `NormalizedPoint` / `NormalizedRect` typed as Vision geometry until converting through `VisionGeometry`.
- Use `CameraVisionWorker` for normal live analysis.

## Real-time processing
- One expensive operation in flight; newest pending frame only.
- Preserve `CameraFrameID` and timestamp when alignment matters.
- Invalidate old work after camera/configuration/screen changes.
- Cancellation saves resources; generation identity prevents stale publication.
- Heavy work stays off MainActor and capture callbacks.

## Validation
- Simulator-only verification is insufficient for rotation, mirroring, TrueDepth/depth, or device-specific camera behavior.
- Record device results under `docs/validation/<device>/` and `docs-ja/validation/<device>/`.
- Device evidence must not become device-model production branches.

## Documentation
- `README.md` and `docs/*.md` are English.
- `README-ja.md` and `docs-ja/*.md` are Japanese mirrors.
