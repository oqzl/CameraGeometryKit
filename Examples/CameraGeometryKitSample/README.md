# CameraGeometryKit Sample

This is a small iOS 18+ Swift 6 app that demonstrates the package's camera
session wrapper, preview rotation, canonical non-mirrored analysis stream, and
latest-frame statistics.

The sample uses `AVLayerVideoGravity.resizeAspect` (fit). For geometry and rotation validation, fit is recommended over fill because fill introduces cropping. The library itself does not force a `videoGravity` policy.

## Preview rotation

Normal apps do not need to combine `CameraRotation.observe()` with repeated `applyPreviewAngle(to:)` calls.

```swift
previewRotationBinding = camera.bindPreviewRotation(to: previewLayer)
```

`CameraPreviewRotationBinding` applies the initial preview angle from `AVCaptureDevice.RotationCoordinator` and automatically reapplies later angle changes to the PreviewLayer connection. Create a new binding after switching to a different physical camera.

## Orientation diagnostics HUD

Use the chevron at the right edge of the top status card to expand the diagnostics HUD downward.

The HUD separates values by where they cross the library/app boundary:

- `LIBRARY → APP / SESSION`: public `CameraCaptureSession` state plus actual analysis/photo connection values
- `LIBRARY → APP / FRAME`: pixel size, rotation, and mirroring actually delivered to the app in `CameraFrameGeometry`
- `LIBRARY → APP / PREVIEW`: preview/capture angles used by `CameraPreviewRotationBinding`
- `APP / PREVIEW + UI`: `UIDeviceOrientation`, `UIInterfaceOrientation`, PreviewLayer bounds/gravity, and the PreviewLayer connection's actual rotation/mirroring/transform

In the normal state, `requested preview` and `preview actual` should match. A mismatch points to the binding / PreviewLayer connection boundary. If `requested preview` itself is unexpected, investigate the library-side RotationCoordinator source.

The HUD adds no independent `rotationEffect` or compensating transform. `CameraPreviewRotationBinding` owns preview rotation application; the HUD only observes requested versus actual values. When device orientation changes, the same key values are logged once to the console with the `[OrientationDebug]` prefix.

## Build

From the repository root:

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

Open the generated project in Xcode to run it on an iOS 18+ device. Camera
behavior, rotation, mirroring, and camera switching require a real device;
the simulator is suitable only for checking that the app builds and launches.

The target uses the repository root as a local Swift package dependency. The
generated `.xcodeproj` is intentionally kept next to `project.yml` so the
sample can be opened directly after checkout; regenerate it when the project
definition changes. If you run `xcodebuild` from the repository root instead,
prefix the project path with `Examples/CameraGeometryKitSample/`.
