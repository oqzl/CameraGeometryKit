# Video Frames

## Default pixel format

`CameraFrameStream` requests device-native output by default (`videoSettings = [:]`). It does not force BGRA.

Apple explicitly recommends avoiding BGRA as a default because camera capture usually has to convert into BGRA and BGRA consumes substantially more memory bandwidth than common native bi-planar YCbCr formats.

If a downstream consumer genuinely requires a concrete format, request it explicitly:

```swift
let frames = CameraFrameStream(pixelFormat: kCVPixelFormatType_32BGRA)
```

The package should not choose a conversion cost on behalf of every app.

## Latest-frame semantics

The stream uses `alwaysDiscardsLateVideoFrames = true` and an `AsyncStream` newest-one buffer. Camera input is treated as a real-time signal, not a FIFO batch workload.

When analysis is slower than capture, old pending work is replaced. The expected failure mode under load is lower analysis FPS, not increasing latency and memory usage.

## Capture callback

The sample-buffer delegate packages frame identity, timestamp, dimensions, camera position, connection rotation, and mirroring, then yields the frame. Heavy work belongs downstream.

Do not run Vision, rendering, mask scans, contour extraction, or file I/O in the callback.

## Rotation cost

A rotation angle on an `AVCaptureVideoDataOutput` connection physically rotates delivered buffers. This is useful for a canonical upright analysis stream, but it has a per-frame cost.

For an `AVAssetWriter` path, prefer an unrotated data-output connection plus `AVAssetWriterInput.transform` when track metadata is sufficient. Do not pay for physical frame rotation only to encode playback orientation.

## Frame identity

`CameraFrameID` is monotonically increasing within a `CameraFrameStream`. Keep it on derived results when geometric synchronization matters.

Two results that are both “latest” are not necessarily from the same frame.

## Diagnostics

`CameraFrameStream.statistics()` exposes delivered frames, frames dropped by AVFoundation, and pending frames replaced by newest-one buffering. Record these during real-device validation.

## Apple references

- [TN3121: Selecting a pixel format for an AVCaptureVideoDataOutput](https://developer.apple.com/documentation/technotes/tn3121-selecting-a-pixel-format-for-an-avcapturevideodataoutput)
- [AVCaptureVideoDataOutput](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput)
- [AVCaptureConnection.videoRotationAngle](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/videorotationangle)
