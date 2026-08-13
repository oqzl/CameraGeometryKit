# Vision Pipeline

CameraGeometryKit targets iOS 18+ and Swift 6 only. Vision integration therefore uses the Swift-native Vision API introduced in iOS 18. The original prefixed Objective-C/Swift request API is intentionally outside the package surface, examples, and tests.

Apple's migration guidance is straightforward: adopt the new request and observation types, replace completion-handler request execution with `async` / `await`, and consume observations returned directly by `perform()`.

## Request execution

A Swift-native image request conforms to `ImageProcessingRequest` and performs directly on a `CVPixelBuffer`:

```swift
let request = DetectFaceRectanglesRequest()
let observations = try await request.perform(
    on: frame.pixelBuffer,
    orientation: frame.geometry.visionOrientation
)
```

The normal single-request path needs no compatibility request handler.

## `CameraVisionWorker`

`CameraVisionWorker<Value>` is an actor that owns real-time scheduling policy, not model semantics.

It guarantees:

- one expensive operation in flight at a time
- at most one pending frame, always the newest
- Swift Task-based execution
- cooperative Task cancellation on invalidation
- source `CameraFrameID` and timestamp propagation
- generation-based stale-result rejection
- final delivery through a MainActor gate

For one `ImageProcessingRequest`:

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
```

Feed frames from the bounded frame stream:

```swift
for await frame in camera.frameStream.frames {
    await faces.submit(frame)
}
```

## Invalidation

Camera identity, analyzer configuration, or screen ownership changes invalidate old work:

```swift
await faces.invalidate()
```

Invalidation clears the pending frame, advances the semantic generation, and requests cancellation of the active Task. Cancellation is a resource optimization; generation identity is the correctness guarantee if an underlying operation doesn't stop immediately.

The MainActor delivery gate is part of the guarantee. An old result cannot arrive after a completed invalidation simply because it had already been queued for UI publication.

## Arbitrary async Vision work

The operation initializer supports multi-request analysis or other Swift-native Vision workflows without reintroducing legacy request abstractions:

```swift
let worker = CameraVisionWorker<MyResult>(
    operation: { frame in
        // Compose modern async Vision requests here.
    },
    delivery: { output in
        // MainActor
    }
)
```

Keep concurrency bounded. Vision requests can be memory-intensive, and Apple recommends limiting concurrent Vision work. Live camera analysis defaults to one in-flight operation because freshness is more valuable than throughput.

## Geometry

Swift-native Vision observations expose image locations with types such as `NormalizedPoint`, `NormalizedRect`, and protocols such as `BoundingBoxProviding`. Vision uses a normalized lower-left origin. CameraGeometryKit canonical space is normalized with a top-left origin.

Convert at the Vision boundary:

```swift
let canonical = VisionGeometry.canonicalRect(from: observation.boundingBox)
```

Do not persist raw Vision geometry in general UI state when canonical geometry is the semantic value the app needs.

## Frame semantics

`CameraFrameStream` delivers frames using the resolved capture rotation and canonical non-mirroring policy. `CameraFrame.geometry.visionOrientation` describes the orientation passed to Swift-native Vision requests. `appliedVideoRotationAngle` records what AVFoundation already applied and is not a request for another rotation.

## References

- Apple Vision documentation
- WWDC24: Discover Swift enhancements in the Vision framework
- `ImageProcessingRequest`
- `DetectFaceRectanglesRequest`
- `NormalizedRect`
