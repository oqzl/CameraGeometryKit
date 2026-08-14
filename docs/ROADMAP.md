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
- ordered device-type preference and front/back switching
- bounded newest-frame VideoDataOutput stream
- optional synchronized RGB + depth delivery
- depth-frame dimensions / rotation / mirroring metadata
- frame ID and geometry snapshot
- RotationCoordinator wrapper
- explicit preview/analysis mirroring policies
- Swift-native Vision geometry conversion
- actor-based `CameraVisionWorker` with latest-frame and stale-delivery guarantees
- narrow ARKit captured-image / canonical geometry adapter
- diagnostics value model
- English/Japanese documentation
- per-device validation structure

## 0.1.1 validation focus

Validate capability selection and synchronized depth on real hardware before tagging 0.1.1. At minimum cover a normal wide-angle path plus available TrueDepth / LiDAR or other depth-capable hardware. Record device evidence; do not turn it into model-specific production branches.

## Near-term: CameraGeometryLab

Build a dedicated verification app rather than a product camera. It should expose front/back and device-type switching, preview/capture/analysis angles, mirror flags, a canonical grid, depth availability, frame IDs, dropped/replaced-frame counters, and saved-photo replay.

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
