# iPhone 17 Validation

This directory collects real-device CameraGeometryKit validation runs for the iPhone 17 family / devices being referred to as “iPhone 17” during development.

Do not infer the hardware identifier from the marketing name. Each run must record the actual identifier reported by the device.

## Status

No CameraGeometryKit validation run has been recorded yet.

## Expected run files

Create one file per meaningful OS/package validation run, for example:

```text
2026-08-14-ios-26.6.md
```

Start from [`../TEMPLATE.md`](../TEMPLATE.md).

## Why this folder exists

Previous camera work showed that front-camera sensor-native orientation can differ from assumptions made for rear cameras or earlier hardware generations. The response is to record RotationCoordinator values, connection-applied rotation, mirroring, frame dimensions, and visible output on the real device.

This folder must not become a source of hard-coded `if iPhone17 { rotate90() }` behavior.
