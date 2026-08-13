# Video Frames

## Default pixel format

`CameraFrameStream` は device-native output (`videoSettings = [:]`) を default にし、BGRA を固定要求しません。

Apple は BGRA を安易な default にしないよう案内しています。一般的な native YCbCr からの変換が必要になり、memory bandwidth も大きくなるためです。

特定 format が必要な場合だけ明示します。

```swift
let frames = CameraFrameStream(pixelFormat: kCVPixelFormatType_32BGRA)
```

## Latest-frame semantics

`alwaysDiscardsLateVideoFrames = true` と `AsyncStream` newest-one buffer を使います。Camera input を FIFO backlog にしません。

解析が capture より遅い場合は old pending frame を置換します。負荷時に期待するのは analysis FPS 低下であり、latency / memory の増加ではありません。

## Capture callback

sample-buffer delegate は frame identity、timestamp、dimensions、camera position、connection rotation、mirroring を package して yield するだけです。重い画像解析・rendering は下流へ渡します。

## Rotation cost

`AVCaptureVideoDataOutput` connection の rotation angle は配信 buffer を物理回転します。canonical upright analysis stream には有用ですが、毎frame costがあります。

`AVAssetWriter` path では metadata で十分なら unrotated data-output connection + `AVAssetWriterInput.transform` を優先します。

## Frame identity

`CameraFrameID` は `CameraFrameStream` 内で単調増加します。geometry synchronization が必要な派生結果には source frame ID を保持します。

両方が「latest」であることと「same frame」であることは同義ではありません。

## Diagnostics

`CameraFrameStream.statistics()` から delivered frames、AVFoundation dropped frames、newest-one buffering で置換された pending frames を取得できます。実機 validation で記録します。

## Apple references

- [TN3121: Selecting a pixel format for an AVCaptureVideoDataOutput](https://developer.apple.com/documentation/technotes/tn3121-selecting-a-pixel-format-for-an-avcapturevideodataoutput)
- [AVCaptureVideoDataOutput](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput)
- [AVCaptureConnection.videoRotationAngle](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/videorotationangle)
