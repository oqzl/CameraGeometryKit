# Architecture

CameraGeometryKit keeps one canonical image space and explicit adapters at framework boundaries.

The package owns geometry, frame metadata, capability-based camera discovery, rotation/mirroring policy, a thin serialized `CameraCaptureSession`, optional synchronized depth delivery, bounded Swift-native Vision execution, stale-result suppression, narrow ARKit image/depth adapters, and diagnostics.

`CameraCaptureSession` owns authorization, one video input, video-only or synchronized video/depth frame outputs, photo output, start/stop, camera switching, capture rotation, and canonical non-mirroring. Depth capture is opt-in and uses `AVCaptureDataOutputSynchronizer`; it does not make the package a universal camera manager.

The video-only path retains the existing `CameraFrameStream`. The depth path emits `CameraSynchronizedFrame`, whose color `CameraFrame` supplies the identity used for time-matched depth and downstream derivatives.

Camera selection is based on AVFoundation device types/capabilities rather than iPhone model identifiers. Depth format selection is restricted to the selected device's current active video format; the library does not silently choose a different color capture policy.

`ARKitFrameAdapter` converts ARKit camera/depth geometry at the framework boundary. It does not own `ARSession`, anchors, world tracking, or scene reconstruction.

`CameraVisionWorker` is the live-analysis boundary. It is an actor that accepts an `ImageProcessingRequest` factory or an async operation, keeps one expensive operation in flight, retains only the newest pending frame, and performs generation-safe MainActor delivery.

Product UI, recording policy, effects, storage, semantic model choices, and workflows remain in the app. There is no compatibility wrapper for pre-iOS-18 Vision APIs.
