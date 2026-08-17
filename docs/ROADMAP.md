# Roadmap

CameraGeometryKit should grow only where real camera applications need shared semantics.

## Implemented foundation

- iOS 18+ / Swift 6 package boundary
- canonical point/rect types
- source/crop mapping
- aspect-fit / aspect-fill viewport mapping
- mirrored presentation mapping
- UIImage orientation/scale canonicalization
- thin serialized `CameraCaptureSession`
- capability-based `AVCaptureDevice.DiscoverySession` selection
- exact device selection with optional depth capability requirement
- bounded newest-frame VideoDataOutput stream
- typed depth-frame geometry and `CameraSynchronizedFrame`
- optional synchronized video + depth capture with `AVCaptureDataOutputSynchronizer`
- one shared color `CameraFrameStream` in video-only and depth modes
- synchronized color/depth drop and latest-buffer diagnostics
- frame ID and geometry snapshot
- RotationCoordinator wrapper for video/depth capture connections
- explicit preview/analysis mirroring policies
- Swift-native Vision `NormalizedPoint` / `NormalizedRect` conversion
- actor-based `CameraVisionWorker` with latest-frame and stale-delivery guarantees
- diagnostics value model
- English/Japanese documentation
- per-device validation structure

## 0.1.1 validation

Before tagging 0.1.1, validate the video-only path and synchronized depth path on real hardware. Cover available front TrueDepth and rear depth-capable hardware where possible, including rotation, mirroring, RGB/depth dimensions, camera switching failure/rollback behavior, and color/depth drop statistics.

Validation evidence belongs under `docs/validation/<device>/`; it must not become model-specific production branches.

## Near-term: CameraGeometryLab

Build a dedicated verification app rather than a product camera. It should expose device-type switching, preview/capture/depth angles, mirror flags, canonical grid, tap markers, frozen canonical frames, fit/fill switching, frame IDs, depth availability, and dropped/replaced-frame counters.

## Possible additions after repeated real-world need

- a small photo-output geometry helper
- first-class canonical overlay mapping for `AVCaptureVideoPreviewLayer`
- a generalized Accepted Frame token for RGB + depth + mask + Vision derivatives
- MultiCam stream identity and per-camera rotation snapshots
- metadata-output geometry adapters
- custom Metal preview mapping
- `AVAssetWriter` orientation helper
- structured diagnostics export

## Explicit non-goals

- effects library
- editor UI
- generic processing graph
- universal camera product state machine
- ARSession / world-tracking ownership
- backward-compatibility layers
- original Vision request-handler compatibility
- model-specific rotation or camera-selection patches
