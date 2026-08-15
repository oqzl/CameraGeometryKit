# Capture and analysis

## Capture session

Create one ``CameraCaptureSession`` per capture pipeline. The session owns
authorization, the active input, frame outputs, photo output, serialized
start/stop, camera switching, and the camera rotation policy.

The exposed `captureSession` is intended for attaching an
`AVCaptureVideoPreviewLayer` and inspection. The application must not mutate
the capture graph through that property.

Camera selection uses AVFoundation-reported device types and capabilities.
Do not branch on an iPhone model identifier.

## Rotation and mirroring

``CameraRotation`` uses `AVCaptureDevice.RotationCoordinator`. Preview and
capture angles are separate. Recreate rotation state after a camera switch,
and keep rotation and mirroring as independent policies.

## Depth

Depth is opt-in through ``CameraDepthCaptureConfiguration``. When enabled,
``CameraSynchronizedFrameStream`` pairs the valid color frame with an optional
depth frame. A missing depth sample does not discard the color frame, and the
color ``CameraFrameID`` remains the identity for downstream derivatives.

RGB and depth buffers can have different pixel dimensions; use their metadata
instead of assuming equal sizes.

## Live Vision

``CameraVisionWorker`` is an actor boundary for live analysis. It runs one
expensive operation at a time, keeps only the newest pending frame, requests
cooperative cancellation on invalidation, and uses generation identity to
prevent stale publication.
