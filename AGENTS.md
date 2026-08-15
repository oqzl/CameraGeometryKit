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
- Select cameras from AVFoundation-reported device types and capabilities, never from iPhone model identifiers.
- Preserve the requested `sessionPreset` policy; depth support must not silently choose an unrelated color video format.

## Depth
- Depth capture is opt-in.
- Use `AVCaptureDataOutputSynchronizer` for live RGB/depth pairing.
- A dropped depth sample becomes `CameraSynchronizedFrame.depth == nil`; do not discard the valid color frame.
- Preserve the color `CameraFrameID` as the identity for downstream depth/mask/Vision derivatives.
- RGB and depth may have different pixel dimensions; never align them by assuming equal width/height.
- Choose `activeDepthDataFormat` only from the current `activeFormat.supportedDepthDataFormats`.
- If requested depth is unavailable for the active video format, fail explicitly rather than silently selecting a different capture policy.

## Rotation and mirroring
- `AVCaptureDevice.RotationCoordinator` is the AVFoundation camera rotation source.
- Preview and capture angles are distinct.
- Do not infer AVFoundation rotation from UI/device orientation, camera position, device model, or pixel dimensions.
- Recreate the coordinator after camera switch.
- Use `videoRotationAngle` APIs, not older orientation-enum APIs.
- Apply the capture rotation/mirroring policy consistently to video and depth connections.
- Rotation and mirroring are separate policies.

## Vision
- Use the iOS 18+ Swift-native Vision API.
- Use `ImageProcessingRequest.perform(...)` with `async` / `await`.
- Do not add a request-handler compatibility path.
- Keep `NormalizedPoint` / `NormalizedRect` typed as Vision geometry until converting through `VisionGeometry`.
- Use `CameraVisionWorker` for normal live analysis.

## ARKit
- ARKit integration belongs in an app or integration target such as ARLab, not in the CameraGeometryKit package.
- CameraGeometryKit must not import ARKit or own `ARSession`, anchors, world tracking, raycasts, or scene reconstruction.
- When an integration target uses ARKit's `displayTransform` contract, `UIInterfaceOrientation` may be used there; do not feed it into AVFoundation rotation logic.

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
