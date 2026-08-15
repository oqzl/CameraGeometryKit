# CameraGeometryKit

CameraGeometryKit is an iOS 18+ / Swift 6 foundation for camera apps that need photos, touch input, Vision, live video frames, front/back cameras, mirroring, rotation, cropping, and previews to agree on what “the same point in the image” means.

AVFoundation, Vision, UIKit/SwiftUI, Core Image, photos, and video frames each have valid but different coordinate and orientation conventions. CameraGeometryKit establishes one canonical image space and makes every boundary explicit.

```text
Photo / Camera Frame / Vision / Touch / Crop / Preview
                         │
                         ▼
              Canonical Image Space

origin      top-left
x           left → right
y           top → bottom
range       normalized 0...1
orientation upright
mirroring   none
```

[日本語](README-ja.md)

## Requirements

- iOS 18+
- Swift 6
- Xcode with an iOS 18+ SDK
- No third-party dependencies
- No backward-compatibility layer for pre-iOS-18 Vision APIs

## What this package owns

- typed canonical points and rectangles
- crop and output-image coordinate mapping
- aspect-fit / aspect-fill preview mapping
- photo canonicalization (`UIImage` orientation `.up`, scale 1)
- a thin serialized `CameraCaptureSession` foundation
- bounded latest-frame `AVCaptureVideoDataOutput` streaming
- per-frame identity, timestamp, rotation, mirroring, and dimensions
- `AVCaptureDevice.RotationCoordinator` wrappers
- explicit preview and analysis mirroring policies
- Swift-native Vision normalized geometry conversion
- Swift Concurrency-based live Vision scheduling
- generation-safe result delivery
- diagnostics primitives
- device-by-device validation records

## What it deliberately does not own

- effects and filters
- app-specific camera chrome
- a universal `CameraManager`
- concrete Vision model/product semantics
- best-shot selection, tracking behavior, or product workflows
- storage and sharing policy
- a generic runtime pipeline graph

The package is infrastructure. Product code remains the composition root.

## Installation

Add the repository as a Swift Package dependency and import:

```swift
import CameraGeometryKit
```

The package manifest is iOS 18+ and Swift 6 only.

## Sample App

A separate SwiftUI camera app is maintained in the
[CameraGeometryKitExamples](https://github.com/oqzl/CameraGeometryKitExamples)
repository. Check it out next to this repository as `~/git/CameraGeometryKitExamples`
and follow its build instructions.

## Canonical coordinates

Do not put screen points, Vision points, crop-relative points, and image points into the same untyped `CGPoint` variable.

```swift
let subject = CanonicalPoint(x: 0.42, y: 0.61)
```

Canonical values are intentionally not clamped. A point can lie outside the current crop while still being a valid position in the source image.

```swift
let space = ImageCoordinateSpace(
    sourceSize: CGSize(width: 4032, height: 3024),
    cropRect: CGRect(x: 504, y: 0, width: 3024, height: 3024)
)
let outputPoint = space.outputNormalizedPoint(for: subject)
```

For a rendered preview:

```swift
let mapping = ViewportMapping(
    imageSize: image.size,
    viewportSize: viewSize,
    contentMode: .aspectFit,
    isMirrored: false
)
let canonical = mapping.canonicalPoint(fromViewport: touchLocation)
```

Aspect-fit letterbox touches return `nil`. Aspect-fill crop offsets are preserved instead of silently clamped.

## Photos

Normalize imported images at the boundary before deriving geometry:

```swift
let canonicalImage = image.cameraGeometryCanonicalized()
let preview = canonicalImage.cameraGeometryDownsampled(maxPixelDimension: 1600)
```

The canonical image is orientation `.up`, scale `1`, so image-processing geometry can use one unit per pixel.

## Capture session

`CameraCaptureSession` is the standard thin starting point. It owns camera authorization, one active video input, `CameraFrameStream`, `AVCapturePhotoOutput`, serialized start/stop and camera switching, capture rotation, and canonical non-mirroring.

```swift
let camera = CameraCaptureSession()
try await camera.start(position: .back)
```

Its `captureSession` is exposed so an app can attach a preview layer, not so the app can mutate the capture graph independently:

```swift
let previewLayer = AVCaptureVideoPreviewLayer(session: camera.captureSession)
let previewRotation = camera.makePreviewRotation(previewLayer: previewLayer)
```

Recreate preview rotation after a successful camera switch. Before issuing a photo request, resynchronize the photo connection:

```swift
try await camera.preparePhotoCapture()
camera.photoOutput.capturePhoto(with: settings, delegate: delegate)
```

Photo settings/delegate policy, preview UI, recording, effects, and product workflow remain app responsibilities.

See [Capture Session](docs/CAPTURE_SESSION.md).

## Camera frames

`CameraFrameStream` provides an `AVCaptureVideoDataOutput` and an `AsyncStream<CameraFrame>` with a newest-one buffer. The standard session wrapper configures its capture angle and canonical non-mirroring.

Apple physically rotates frames delivered by `AVCaptureVideoDataOutput` when `videoRotationAngle` is set. `CameraFrame.geometry.appliedVideoRotationAngle` is diagnostic metadata. Do not apply it again.

```text
capture 60 fps
    │
    ├─ frame 100 ── analysis running
    ├─ frame 101 ── replaced
    ├─ frame 102 ── replaced
    └─ frame 103 ── newest pending
```

There is no growing queue to catch up later.

## Rotation

Preview and capture angles are different responsibilities. Use `CameraRotation` / `AVCaptureDevice.RotationCoordinator`; do not calculate camera angles from interface orientation, `UIDeviceOrientation`, front/back position, pixel dimensions, or an iPhone model table.

See [Camera Rotation](docs/CAMERA_ROTATION.md).

## Mirroring

Preview mirroring and media identity are independent. The usual policy is mirrored front preview, non-mirrored analysis/saved media.

```swift
CameraConnectionConfiguration.configurePreviewMirroring(
    on: previewConnection,
    cameraPosition: device.position
)
CameraConnectionConfiguration.configureCanonicalAnalysisMirroring(on: analysisConnection)
```

## Vision

CameraGeometryKit uses the Swift-native Vision API available on iOS 18+. There is no legacy Vision request-handler compatibility layer.

Vision observations expose normalized geometry with types such as `NormalizedRect`. Convert to canonical geometry at the Vision boundary:

```swift
let canonicalBox = VisionGeometry.canonicalRect(from: observation.boundingBox)
```

For live work, use `CameraVisionWorker<Value>`. It is an actor that keeps one expensive operation in flight, retains only the newest pending frame, uses Task cancellation for obsolete work, preserves frame identity, and blocks stale delivery with a generation gate.

```swift
let faces = CameraVisionWorker<[CanonicalRect]>(
    makeRequest: { DetectFaceRectanglesRequest() },
    map: { observations in
        observations.map {
            VisionGeometry.canonicalRect(from: $0.boundingBox)
        }
    },
    delivery: { output in
        faceBoxes = output.value
    }
)

for await frame in camera.frameStream.frames {
    await faces.submit(frame)
}
```

When camera identity, analyzer settings, or the consuming screen changes:

```swift
await faces.invalidate()
```

Concrete request choice and semantic result mapping stay in the app. See [Vision Pipeline](docs/VISION_PIPELINE.md).

## Touch and `AVCaptureVideoPreviewLayer`

A live preview layer's focus/exposure coordinate is not canonical image space. Keep it typed separately and let AVFoundation account for `videoGravity`:

```swift
let point: CaptureDevicePoint = previewLayer.captureDevicePoint(
    fromLayerPoint: touchLocation
)
device.focusPointOfInterest = point.cgPoint
```

Do not store that value as a `CanonicalPoint`. For app-semantic points on a custom preview of canonical images/frames, use `ViewportMapping`.

## Diagnostics

During development record at least camera position, preview/capture/analysis rotation angles, mirror flags, frame dimensions, delivered frames, AVFoundation drops, and newest-buffer replacements.

See [Validation](docs/VALIDATION.md).

## The rules that matter most

See [Prohibited Patterns](docs/PROHIBITIONS.md). The short version:

- no per-device angle tables
- no UI-orientation-to-camera-angle conversion
- no deprecated `videoOrientation` path
- no double rotation
- no “front means mirrored media” assumption
- no legacy Vision request-handler path
- no raw Vision geometry in UI state
- no unbounded frame queues
- no heavy processing on MainActor or capture callbacks
- no stale result publication after a generation changes
- no width/height-based orientation guessing
- no external mutation of `CameraCaptureSession`'s capture graph

## Documentation

[API Reference (Swift-DocC)](https://oqzl.github.io/CameraGeometryKit/documentation/camerageometrykit/)

- [Documentation build and GitHub Pages publishing](docs/DOCUMENTATION.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Coordinate Spaces](docs/COORDINATE_SPACES.md)
- [Capture Session](docs/CAPTURE_SESSION.md)
- [Camera Rotation](docs/CAMERA_ROTATION.md)
- [Vision Pipeline](docs/VISION_PIPELINE.md)
- [Prohibited Patterns](docs/PROHIBITIONS.md)
- [Validation](docs/VALIDATION.md)
- [Roadmap](docs/ROADMAP.md)

Japanese documentation mirrors these under `docs-ja/`.

## License

MIT
