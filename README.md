# CameraGeometryKit

CameraGeometryKit is an iOS 18+ / Swift 6 foundation for camera apps that need photos, touch input, Vision, live video frames, front/back cameras, mirroring, rotation, cropping, and previews to agree on what “the same point in the image” means.

The package exists because AVFoundation, Vision, UIKit/SwiftUI, Core Image, photos, and video frames each have valid but different coordinate and orientation conventions. A small camera app can get away with converting ad hoc. A real camera app eventually cannot.

CameraGeometryKit establishes one canonical image space and makes every boundary explicit.

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

## What this package owns

- typed canonical points and rectangles
- crop and output-image coordinate mapping
- aspect-fit / aspect-fill preview mapping
- photo canonicalization (`UIImage` orientation `.up`, scale 1)
- bounded latest-frame `AVCaptureVideoDataOutput` streaming
- per-frame identity, timestamp, rotation, mirroring, and dimensions
- `AVCaptureDevice.RotationCoordinator` wrappers
- explicit preview and analysis mirroring policies
- Vision normalized-coordinate conversion
- bounded frame delivery plus generation tokens for stale-result suppression
- diagnostics primitives
- device-by-device validation records

## What it deliberately does not own

- effects and filters
- app-specific camera chrome
- a universal `CameraManager`
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

## Canonical coordinates

Do not put screen points, Vision points, crop-relative points, and image points into the same untyped `CGPoint` variable.

```swift
let subject = CanonicalPoint(x: 0.42, y: 0.61)
```

Canonical values are intentionally not clamped. A point can lie outside the current crop while still being a perfectly valid position in the source image.

For a cropped output:

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
```

This makes the image orientation `.up` and the scale `1`, so image-processing geometry can use one unit per pixel. Downsampling for interactive preview preserves normalized coordinates:

```swift
let preview = canonicalImage.cameraGeometryDownsampled(maxPixelDimension: 1600)
```

## Capture-session integration

CameraGeometryKit deliberately does not own the entire `AVCaptureSession`. The app remains responsible for permission UX, device selection, session lifecycle, photo/movie outputs, and camera chrome. The package supplies the pieces whose semantics must stay consistent across those paths.

For live analysis, add `CameraFrameStream.output` to the app's session and update the stream whenever the active camera changes:

```swift
let frameStream = CameraFrameStream()

session.beginConfiguration()
session.addOutput(frameStream.output)
frameStream.setCameraPosition(device.position)
session.commitConfiguration()
```

When switching cameras, create a new `CameraRotation` for the new `AVCaptureDevice`, reapply connection policies, and invalidate the old processing generation.

## Camera frames

`CameraFrameStream` provides an `AVCaptureVideoDataOutput` and an `AsyncStream<CameraFrame>` with a newest-one buffer.

After adding the output, configure its connection with the camera-specific capture angle and non-mirrored analysis policy:

```swift
@MainActor
func configureAnalysisConnection(
    frameStream: CameraFrameStream,
    rotation: CameraRotation
) {
    guard let connection = frameStream.output.connection(with: .video) else { return }
    rotation.applyCaptureAngle(to: connection)
    CameraConnectionConfiguration.configureCanonicalAnalysisMirroring(on: connection)
}
```

Apple physically rotates frames delivered by `AVCaptureVideoDataOutput` when `videoRotationAngle` is set. `CameraFrame.geometry.appliedVideoRotationAngle` is therefore diagnostic metadata. Do not apply it again.

The frame stream is deliberately bounded:

```text
capture 60 fps
    │
    ├─ frame 100 ── analysis running
    ├─ frame 101 ── replaced
    ├─ frame 102 ── replaced
    └─ frame 103 ── newest pending
```

There is no growing queue to “catch up” later.

## Rotation

Create a new `CameraRotation` for each active `AVCaptureDevice`:

```swift
@MainActor
let rotation = CameraRotation(device: device, previewLayer: previewLayer)
```

Use the preview angle for preview and capture angle for captured media / canonical analysis frames:

```swift
rotation.applyPreviewAngle(to: previewConnection)
rotation.applyCaptureAngle(to: analysisConnection)
```

Do not calculate these angles from interface orientation, `UIDeviceOrientation`, front/back position, pixel dimensions, or an iPhone model table.

See [Camera Rotation](docs/CAMERA_ROTATION.md).

## Mirroring

Preview mirroring and media identity are independent.

```swift
CameraConnectionConfiguration.configurePreviewMirroring(
    on: previewConnection,
    cameraPosition: device.position
)
CameraConnectionConfiguration.configureCanonicalAnalysisMirroring(on: analysisConnection)
```

The usual policy is mirrored front preview, non-mirrored analysis/saved media.

## Vision

Vision is part of the foundation because its coordinate convention is one of the major camera-geometry boundaries. Vision uses normalized coordinates with a lower-left origin; convert immediately at the boundary:

```swift
let canonicalBox = VisionGeometry.canonicalRect(
    fromVisionNormalized: observation.boundingBox
)
```

Live Vision work should consume `CameraFrameStream.frames` sequentially. The stream already buffers only the newest pending frame, so a slow analyzer does not create an ever-growing FIFO backlog.

Use `WorkGeneration` to reject results produced under obsolete camera/analyzer configuration:

```swift
let generation = WorkGeneration()
let workGeneration = generation.current

// Perform Vision away from MainActor.
// Before publishing:
guard generation.isCurrent(workGeneration) else { return }
```

On a camera switch, analyzer settings change, or screen departure:

```swift
generation.invalidate()
request.cancel() // when a VNRequest is currently in flight
```

Cancellation controls resources; generation comparison is the correctness guarantee. See [Vision Pipeline](docs/VISION_PIPELINE.md).

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

Camera coordinate bugs should be observable, not guessed at. During development record at least:

```text
camera position
preview rotation angle
capture rotation angle
analysis connection angle
preview mirrored
analysis mirrored
frame dimensions
frames delivered
frames dropped by AVFoundation
pending frames replaced by latest-frame buffering
```

See [Validation](docs/VALIDATION.md).

## The rules that matter most

The project keeps explicit prohibited patterns in [PROHIBITIONS.md](docs/PROHIBITIONS.md). The short version:

- no per-device angle tables
- no UI-orientation-to-camera-angle conversion
- no double rotation
- no “front means mirrored media” assumption
- no raw Vision coordinates in UI state
- no unbounded frame queues
- no heavy processing on MainActor or capture callbacks
- no stale result publication after a configuration generation changes
- no width/height-based orientation guessing

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Coordinate Spaces](docs/COORDINATE_SPACES.md)
- [Camera Rotation](docs/CAMERA_ROTATION.md)
- [Vision Pipeline](docs/VISION_PIPELINE.md)
- [Prohibited Patterns](docs/PROHIBITIONS.md)
- [Validation](docs/VALIDATION.md)
- [Roadmap](docs/ROADMAP.md)

Japanese documentation mirrors these under `docs-ja/`.

## License

MIT
