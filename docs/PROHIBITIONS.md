# Prohibited Patterns

These patterns repeatedly produce camera bugs that look device-specific even when the root cause is a coordinate, rotation, or scheduling mistake.

Treat this document as part of the package contract.

## 1. Device-model rotation hacks

```swift
if model == "iPhone17,1" {
    angle += 90
}
```

Do not do this. Record the failure under device validation, inspect `RotationCoordinator` angles and connection state, and fix the generic assumption.

## 2. Front/back fixed-angle tables

```swift
angle = device.position == .front ? 270 : 90
```

Do not do this. Camera module native orientation is not a stable front/back rule.

## 3. UI orientation as camera orientation

Do not derive capture angle from `windowScene.interfaceOrientation`. UI orientation and physical camera orientation are different domains.

## 4. `UIDeviceOrientation` as the primary camera resolver

Do not derive camera rotation from the phone's posture. `RotationCoordinator` exists specifically to resolve camera-specific rotation.

## 5. Preview angle used for capture

Preview and capture angles are separate properties. Do not substitute one for the other.

## 6. Capture angle used to rotate camera chrome

Camera chrome is product UI. Do not rotate/reflow it because the capture angle changed.

## 7. Width/height orientation guessing

Do not infer rotation from pixel-buffer dimensions. Native sensor orientation and connection-applied rotation vary.

## 8. Double rotation

If the `AVCaptureVideoDataOutput` connection physically rotated the frame, do not apply the same correction in Core Image, the viewer, or export again.

## 9. Writer resolves orientation itself

`AVAssetWriter` code must not inspect `UIDevice`, `UIWindowScene`, front/back camera, or device model to guess orientation. It consumes a resolved capture orientation.

## 10. Physically rotating every writer frame without need

For `AVCaptureVideoDataOutput + AVAssetWriter`, prefer a track transform over per-frame rotation when orientation metadata is sufficient.

## 11. Mirroring embedded in rotation logic

Mirror policy is independent. Do not “fix” a mirrored front preview by adding rotation transforms.

## 12. Front camera always saved mirrored

A mirrored selfie preview does not imply mirrored media identity. Decide preview and storage policies separately.

## 13. Untyped point soup

Do not let one untyped `CGPoint` mean Vision normalized, screen points, crop-relative points, and image normalized values at different times. Use semantic types and explicit mappings.

## 14. Raw Vision coordinates in UI state

Vision's origin differs from canonical image space. Convert at the Vision boundary.

## 15. Capture-device focus point stored as canonical

`AVCaptureVideoPreviewLayer.captureDevicePointConverted` returns unrotated capture-device point-of-interest space. Keep it as `CaptureDevicePoint`.

## 16. Implicit clamping during coordinate transforms

Clamping a point outside a crop to the crop edge changes its meaning. Preserve out-of-range normalized values until a boundary explicitly requires clipping.

## 17. Unlimited frame queues

Never queue every camera frame for Vision/image processing. Real-time processors drop obsolete work.

## 18. Heavy processing in capture callback

The sample-buffer callback should package and hand off the frame quickly. Do not run Vision, Core Image rendering, contour extraction, mask scanning, or file I/O there.

## 19. Heavy processing on MainActor

MainActor owns UI state, not image processing.

## 20. Cancellation without stale-result protection

A cancelled operation can race to completion. Compare generation/configuration identity immediately before publication.

## 21. Old result after camera switch

A camera switch changes device, rotation coordinator, mirroring policy, and processing generation. Old-camera results must not overwrite new-camera UI.

## 22. Reusing the old RotationCoordinator

A coordinator belongs to an `AVCaptureDevice`. Recreate it after the active camera changes.

## 23. Mixing derivatives from different frames

Do not combine RGB, mask, depth, and Vision results from different accepted frame IDs when geometric alignment matters.

## 24. Silent fallback when required synchronized data is missing

If a feature requires depth/mask/other synchronized data, do not silently substitute unrelated current RGB data. Keep the last valid synchronized state or expose an explicit unavailable state.

## 25. Simulator-only completion claims

Do not mark front-camera, TrueDepth, device rotation, mirroring, or model-specific behavior verified based only on Simulator. Record real-device evidence under `docs/validation/<device>/`.

## 26. Mutating `CameraCaptureSession.captureSession` from product code

The session is exposed so apps can attach an `AVCaptureVideoPreviewLayer` and inspect it. Do not independently add/remove inputs or outputs, switch devices, or call start/stop on it. Capture-graph mutations must remain serialized by `CameraCaptureSession`.

## 27. Publishing low-level Vision results without a delivery-time generation gate

For ordinary live analysis, use `CameraVisionWorker`. If product code uses `CameraVisionPipeline` directly, it must provide equivalent generation validation at the actual UI-delivery boundary. Checking only when Vision finishes leaves a race with already-enqueued MainActor delivery.
