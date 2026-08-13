# Architecture

CameraGeometryKit keeps one canonical image coordinate space and explicit adapters at framework boundaries.

The package stays intentionally narrow: geometry, frame metadata, rotation/mirroring policy, Vision coordinate conversion, stale-result generation tracking, and diagnostics belong here; product effects, persistence, and app UI do not.

See `COORDINATE_SPACES.md`, `CAMERA_ROTATION.md`, `VISION_PIPELINE.md`, and `PROHIBITIONS.md` for the detailed rules.
