# Device Validation

## Why validation lives in the repository

Camera behavior depends on real hardware: sensor orientation, available cameras, mirroring defaults, supported rotation angles, depth capabilities, and performance differ by device.

The response is not device-model branching. The response is device-model evidence.

Validation records live under:

```text
docs/validation/<device>/
docs-ja/validation/<device>/
```

Example:

```text
docs/validation/iPhone17/
```

A device directory can contain multiple runs as OS versions change:

```text
iPhone17/
├── README.md
├── 2026-08-14-ios-26.6.md
└── 2026-09-xx-ios-26.x.md
```

Do not overwrite evidence from older OS builds when behavior changes.

## Required device metadata

Record marketing device name, hardware identifier, iOS version/build, package/app commit SHA, Xcode version, rotation-lock state, camera device type/position, and active format/FPS when relevant.

## Minimum rotation matrix

For each relevant camera test portrait, landscape left, landscape right, upside down where needed, rotation lock off, and rotation lock on.

For each posture record preview angle, capture angle, VideoDataOutput connection angle, preview/analysis mirror flags, delivered dimensions, preview uprightness, canonical frozen-frame uprightness, saved-photo uprightness, and Vision-overlay alignment.

## Camera matrix

Where supported: back wide, ultra wide, telephoto, front, TrueDepth, virtual camera, and MultiCam combinations used by the app. Missing capabilities are recorded as unavailable, not failures.

## Timing / lifecycle matrix

Test immediately after launch, posture change, front/back switch, rapid repeated switches, background → foreground, session interruption/recovery, analyzer-setting changes while Vision runs, and screen departure while Vision runs.

Verify that old-generation results never appear after a switch/change.

## Preview and touch

For canonical custom preview mapping:

- center tap maps to `(0.5, 0.5)`
- four near-corner markers map consistently
- aspect-fit letterbox touches are rejected
- aspect-fill crop mapping remains stable
- mirrored preview reverses display x without changing canonical x

For `AVCaptureVideoPreviewLayer` focus/exposure, use AVFoundation conversion and do not reinterpret `CaptureDevicePoint` as canonical.

## Vision

Record source `CameraFrameID`, result frame ID, canonical bounding box/point, visual alignment in every posture, alignment after camera switch, alignment under front-preview mirroring, and stale-result behavior after invalidation.

## Performance

Record capture FPS, analyzer latency, AVFoundation dropped frames, newest-buffer replacements, UI responsiveness, and sustained thermal behavior where relevant. Under load the expected behavior is frame dropping, not queue growth.

## Failure evidence

```text
Device: iPhone 17 Pro / iPhone18,3
OS: iOS 26.6
Camera: front
Posture: landscape left
Rotation lock: on

Preview angle: ...
Capture angle: ...
Analysis connection angle: ...
Preview mirrored: ...
Analysis mirrored: ...
Frame dimensions: ...
Frame ID: ...
Vision result frame ID: ...

Observed:
Expected:
Screenshot/video:
```

Do not summarize a failure as only “front camera is 90° wrong.”

## Promotion rule

A device-specific observation can change generic code only when the generic invariant is wrong or an Apple API requires a capability-specific branch. Do not add branches merely because a device validation folder exists.
