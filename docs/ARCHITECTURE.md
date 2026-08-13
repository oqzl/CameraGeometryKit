# Architecture

CameraGeometryKit keeps one canonical image space and explicit adapters at framework boundaries.

The package owns geometry, frame metadata, rotation/mirroring policy, a thin serialized `CameraCaptureSession`, bounded Swift-native Vision execution, stale-result suppression, and diagnostics.

`CameraCaptureSession` owns authorization, one video input, frame/photo outputs, start/stop, camera switching, capture rotation, and canonical non-mirroring. Product UI, recording policy, effects, and workflows remain in the app.

`CameraVisionWorker` is the live-analysis boundary. It is an actor that accepts an `ImageProcessingRequest` factory or an async operation, keeps one expensive operation in flight, retains only the newest pending frame, and performs generation-safe MainActor delivery.

There is no compatibility wrapper for pre-iOS-18 Vision APIs.

The package must not grow into a universal `CameraManager` or product-feature container.
