# CameraGeometryKit Sample

This is a small iOS 18+ Swift 6 app that demonstrates the package's camera
session wrapper, preview rotation, canonical non-mirrored analysis stream, and
latest-frame statistics.

## Build

From the repository root:

```bash
cd Examples/CameraGeometryKitSample
xcodegen generate --spec project.yml
xcodebuild -project CameraGeometryKitSample.xcodeproj \
  -scheme CameraGeometryKitSample \
  -sdk iphoneos \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

Open the generated project in Xcode to run it on an iOS 18+ device. Camera
behavior, rotation, mirroring, and camera switching require a real device;
the simulator is suitable only for checking that the app builds and launches.

The target uses the repository root as a local Swift package dependency. The
generated `.xcodeproj` is intentionally kept next to `project.yml` so the
sample can be opened directly after checkout; regenerate it when the project
definition changes. If you run `xcodebuild` from the repository root instead,
prefix the project path with `Examples/CameraGeometryKitSample/`.
