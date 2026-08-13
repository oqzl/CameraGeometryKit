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
- bounded newest-frame VideoDataOutput stream
- frame ID and geometry snapshot
- RotationCoordinator wrapper
- explicit preview/analysis mirror policies
- Swift-native Vision `NormalizedPoint` / `NormalizedRect` conversion
- actor-based `CameraVisionWorker` with latest-frame and stale-delivery guarantees
- diagnostics value model
- English/Japanese documentation
- per-device validation structure

## Near-term: CameraGeometryLab

Build a dedicated verification app rather than a product camera. It should expose front/back switching, preview/capture/analysis angles, mirror flags, a canonical grid, tap markers, a visible Vision rectangle sample, frozen canonical frames, fit/fill switching, frame IDs, dropped/replaced-frame counters, and saved-photo replay.

The purpose is to make geometry failures obvious in screenshots and device validation records.

## Real-device matrix

Populate `docs/validation/iPhone17/` first, then add hardware folders as devices become available. Evidence should accumulate across OS versions without turning into model-specific production branches.

## Possible additions after repeated real-world need

- a small photo-output geometry helper
- first-class canonical overlay mapping for `AVCaptureVideoPreviewLayer`
- an Accepted Frame / synchronization token for RGB + depth + mask + Vision
- depth-frame geometry
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
- backward-compatibility layers
- original Vision request-handler compatibility
- model-specific rotation patches
