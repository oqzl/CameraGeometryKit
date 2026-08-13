# Prohibited Patterns

Treat these as package invariants.

1. **No device-model rotation hacks.** Device-specific failures belong in validation records, not production angle branches.
2. **No front/back fixed-angle tables.** Camera position does not define a stable native rotation.
3. **No UI-orientation camera resolver.** Do not derive capture rotation from `UIDeviceOrientation` or interface orientation.
4. **No deprecated orientation API.** Do not use `AVCaptureVideoOrientation`, `AVCaptureConnection.videoOrientation`, or `isVideoOrientationSupported`. Use `AVCaptureDevice.RotationCoordinator`, `videoRotationAngle`, and `isVideoRotationAngleSupported(_:)`.
5. **Keep preview and capture rotation separate.** Do not substitute one angle for the other.
6. **No double rotation.** A frame already rotated by an `AVCaptureVideoDataOutput` connection must not be rotated again downstream.
7. **Keep rotation and mirroring separate.** A mirrored front preview does not imply mirrored analysis or saved media.
8. **No untyped coordinate soup.** Screen, Vision, crop, capture-device, and canonical coordinates must cross explicit typed boundaries.
9. **No implicit clamping.** An out-of-crop source point remains out of crop until clipping is explicitly required.
10. **No unbounded frame queues.** Live processing retains obsolete work only long enough to replace it with the newest pending frame.
11. **No heavy work in capture callbacks or on MainActor.** Capture callbacks package and hand off frames; MainActor owns UI state.
12. **Cancellation is not stale-result protection.** Generation identity must prevent obsolete results from publishing after camera/configuration changes.
13. **Do not mix derivatives from different frame IDs** when RGB/mask/depth/Vision alignment matters.
14. **Do not reuse a rotation coordinator after camera switch.** A coordinator belongs to one `AVCaptureDevice`.
15. **Do not mutate `CameraCaptureSession.captureSession` from product code.** Capture-graph mutation remains serialized inside the wrapper.
16. **No pre-iOS-18 Vision compatibility layer.** Use Swift-native Vision request/observation types and `async` / `await`; do not reintroduce request-handler-based execution.
17. **Use Swift-native Vision geometry.** Keep `NormalizedPoint` / `NormalizedRect` typed as Vision geometry until converting through `VisionGeometry`.
18. **Live Vision must preserve freshness.** `CameraVisionWorker` or an equivalent implementation must keep bounded work, source frame identity, invalidation cancellation, and stale-delivery suppression.
19. **Simulator-only verification is insufficient** for camera rotation, front-camera mirroring, TrueDepth/depth, or device-specific behavior. Record real-device evidence under `docs/validation/<device>/`.
