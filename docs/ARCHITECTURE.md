# Architecture

CameraGeometryKit keeps one canonical image coordinate space and explicit adapters at framework boundaries.

The package stays intentionally narrow. It owns geometry, frame metadata, rotation/mirroring policy, a thin serialized `CameraCaptureSession`, bounded Vision execution, stale-result generation tracking, and diagnostics.

`CameraCaptureSession` owns only the shared mutable AVFoundation graph needed by the foundation: authorization, one video input, frame output, photo output, start/stop, camera switching, capture rotation, and canonical non-mirroring. Product UI, recording policy, photo settings/results, effects, and workflows remain in the app.

`CameraVisionPipeline` is the low-level bounded request executor. `CameraVisionWorker` is the preferred high-level live-analysis boundary and adds generation-safe MainActor delivery. Concrete Vision request choice and result semantics remain in the app.

The package must not grow into a universal `CameraManager`, generic runtime pipeline graph, or product feature container.

See `COORDINATE_SPACES.md`, `CAPTURE_SESSION.md`, `CAMERA_ROTATION.md`, `VISION_PIPELINE.md`, and `PROHIBITIONS.md` for detailed rules.
