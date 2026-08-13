# Vision Pipeline

Vision integration has two independent correctness requirements: coordinate semantics and real-time freshness.

## Geometry

Vision normalized rectangles use a lower-left origin. Convert them to `CanonicalRect` at the Vision boundary with `VisionGeometry`. Do not keep raw Vision rectangles in general UI state and remember to flip them later.

## Frame semantics

When the VideoDataOutput connection has already applied the resolved capture rotation and canonical non-mirroring policy, `CameraFrame.pixelBuffer` is treated as upright canonical analysis data. `CameraFrame.geometry.appliedVideoRotationAngle` records what was already applied; it is not a request for another rotation.

## Bounded scheduling

`CameraFrameStream.frames` buffers only the newest pending frame. A sequential analyzer therefore sees fresh work instead of an ever-growing FIFO backlog.

Do not run expensive analysis on MainActor or inside the capture callback.

## Stale-result protection

Use `WorkGeneration` to snapshot semantic configuration before analysis and check it again immediately before publication. Advance the generation when camera/analyzer configuration changes or the consuming screen disappears.

Cancellation and generation checks have different roles: cancellation saves resources; generation identity guarantees that obsolete work cannot overwrite current state.

## Frame identity

When a result must align with another derivative, carry the source `CameraFrameID` and timestamp. Recent RGB, mask, depth, and Vision results are not interchangeable with results from the same accepted frame.

## Result boundary

Map Vision results to small Sendable app values containing canonical geometry and only the fields the UI needs. Keep Vision coordinate conventions out of SwiftUI state.
