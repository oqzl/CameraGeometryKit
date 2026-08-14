# CameraGeometryKit Sample

An iOS 18+ / Swift 6 lab app for exercising CameraGeometryKit features on real hardware.

## Tabs

- `Capture`: camera session, preview rotation, frame statistics, orientation diagnostics HUD
- `Geometry`: `CanonicalPoint` / `CanonicalRect` / `ViewportMapping` fit/fill, mirroring, and tap mapping
- `Vision`: `CameraVisionWorker` + Swift-native `DetectFaceRectanglesRequest`, Vision → canonical → preview overlay
- `Depth`: depth-capable device discovery, exact physical-device selection, synchronized RGB/depth, rotation, pixel dimensions, center depth
- `Image`: PhotosPicker input with `UIImage.cameraGeometryCanonicalized()` / `cameraGeometryDownsampled()` comparison

The sample uses `AVLayerVideoGravity.resizeAspect` (fit). Fit is recommended for geometry/rotation validation because fill adds cropping. The library itself does not force a `videoGravity` policy.

## Preview rotation

Normal apps do not need to combine `CameraRotation.observe()` with repeated `applyPreviewAngle(to:)` calls.

```swift
previewRotationBinding = camera.bindPreviewRotation(to: previewLayer)
```

`CameraPreviewRotationBinding` applies the initial preview angle from `AVCaptureDevice.RotationCoordinator` and automatically reapplies later angle changes to the PreviewLayer connection. Create a new binding after switching to a different physical camera.

## Orientation diagnostics HUD

Use the chevron on the Capture tab to expand the diagnostics HUD.

- `LIBRARY → APP / SESSION`: public `CameraCaptureSession` state plus actual analysis/photo connection values
- `LIBRARY → APP / FRAME`: pixel size, rotation, and mirroring delivered in `CameraFrameGeometry`
- `LIBRARY → APP / PREVIEW`: preview/capture angles used by `CameraPreviewRotationBinding`
- `APP / PREVIEW + UI`: device/interface orientation, PreviewLayer bounds/gravity/connection rotation/mirroring/transform

Normally `requested preview` and `preview actual` should match. The HUD adds no independent `rotationEffect` or compensating transform. Diagnostics JSON can be copied or shared.

## Feature matrix

| Library feature | Sample surface |
|---|---|
| `CameraCaptureSession` / `CameraFrameStream` | Capture |
| `CameraPreviewRotationBinding` / `CameraRotation` | Capture / Vision / Depth |
| `CameraDeviceDiscovery` / exact `CameraDeviceRequest` | Depth |
| `CanonicalPoint` / `CanonicalRect` / `ViewportMapping` | Geometry / Vision |
| `CameraVisionWorker` / `VisionGeometry` | Vision |
| synchronized RGB + depth / `CameraDepthFrame` | Depth |
| UIImage canonicalization / downsampling | Image |
| orientation diagnostics JSON | Capture |

`ImageCoordinateSpace`, `CaptureDevicePoint`, `ARKitFrameAdapter`, and photo capture remain additional verification surfaces to expose from the sample; the goal is to close the matrix completely rather than leave library-only features.

## Build

```bash
cd Examples/CameraGeometryKitSample
xcodegen generate --spec project.yml
xcodebuild -project CameraGeometryKitSample.xcodeproj \
  -scheme CameraGeometryKitSample \
  -sdk iphoneos \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

Run on iOS 18+ hardware for camera behavior, rotation/mirroring, TrueDepth/LiDAR, and camera-switch validation.
