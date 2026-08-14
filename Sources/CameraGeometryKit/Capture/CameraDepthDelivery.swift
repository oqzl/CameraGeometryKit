@preconcurrency import AVFoundation
import Foundation

final class CameraDepthDelivery: NSObject, @unchecked Sendable {
    let frameStream: CameraFrameStream
    let depthOutput: AVCaptureDepthDataOutput
    let synchronizer: AVCaptureDataOutputSynchronizer
    let callbackQueue: DispatchQueue

    init(frameStream: CameraFrameStream, depthOutput: AVCaptureDepthDataOutput) {
        self.frameStream = frameStream
        self.depthOutput = depthOutput
        callbackQueue = DispatchQueue(label: "net.oqzl.CameraGeometryKit.depth-sync")
        synchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [frameStream.output, depthOutput])
        super.init()
    }
}
