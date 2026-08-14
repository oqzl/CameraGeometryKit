import SwiftUI

@main
struct CameraGeometryKitSampleApp: App {
    var body: some Scene {
        WindowGroup {
            SampleRootView()
        }
    }
}

private enum SampleTab: Hashable {
    case capture
    case geometry
    case vision
    case depth
    case image
}

private struct SampleRootView: View {
    @State private var selection: SampleTab = .capture

    var body: some View {
        TabView(selection: $selection) {
            Group {
                if selection == .capture {
                    CameraSampleView()
                } else {
                    Color.black
                }
            }
            .tag(SampleTab.capture)
            .tabItem { Label("Capture", systemImage: "camera") }

            Group {
                if selection == .geometry {
                    GeometryLabView()
                } else {
                    Color.black
                }
            }
            .tag(SampleTab.geometry)
            .tabItem { Label("Geometry", systemImage: "scope") }

            Group {
                if selection == .vision {
                    VisionLabView()
                } else {
                    Color.black
                }
            }
            .tag(SampleTab.vision)
            .tabItem { Label("Vision", systemImage: "viewfinder") }

            Group {
                if selection == .depth {
                    DepthLabView()
                } else {
                    Color.black
                }
            }
            .tag(SampleTab.depth)
            .tabItem { Label("Depth", systemImage: "square.3.layers.3d") }

            Group {
                if selection == .image {
                    ImageLabView()
                } else {
                    Color.black
                }
            }
            .tag(SampleTab.image)
            .tabItem { Label("Image", systemImage: "photo") }
        }
    }
}
