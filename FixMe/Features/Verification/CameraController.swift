@preconcurrency import AVFoundation
import UIKit
import Observation

/// Receives the captured photo.
///
/// Split out from `CameraController` so the capture call doesn't have to hand a
/// non-Sendable controller to the session queue. This holds nothing but an immutable
/// `@Sendable` closure, which is what makes the unchecked conformance honest rather than
/// a way of silencing the compiler.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: @Sendable (UIImage?) -> Void

    init(completion: @escaping @Sendable (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        completion(photo.fileDataRepresentation().flatMap { UIImage(data: $0) })
    }
}

/// Thin AVFoundation wrapper for the "Prove It" capture flow. UI-facing state lives on the
/// main actor; only AVFoundation objects are handed to the capture queue.
@MainActor
@Observable
final class CameraController {
    enum AuthorizationState { case unknown, authorized, denied, unavailable }

    private(set) var authorizationState: AuthorizationState = .unknown
    private(set) var capturedImage: UIImage?

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "fixme.camera.session")
    /// AVFoundation only holds the capture delegate weakly, so it must be retained here
    /// for the lifetime of the capture or the callback never arrives.
    private var activeDelegate: PhotoCaptureDelegate?

    var isCameraAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil ||
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    func requestAccessAndConfigure() async {
        guard isCameraAvailable else {
            authorizationState = .unavailable
            return
        }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        authorizationState = granted ? .authorized : .denied
        guard granted else { return }
        await configureSession()
    }

    private func configureSession() async {
        // Captured as locals so the closure never takes `self` onto the session queue.
        let session = self.session
        let photoOutput = self.photoOutput

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                session.beginConfiguration()
                session.sessionPreset = .photo

                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                    ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)

                if let device,
                   let input = try? AVCaptureDeviceInput(device: device),
                   session.canAddInput(input) {
                    session.addInput(input)
                }
                if session.canAddOutput(photoOutput) {
                    session.addOutput(photoOutput)
                }
                session.commitConfiguration()
                session.startRunning()
                continuation.resume()
            }
        }
    }

    func stop() {
        let session = self.session
        sessionQueue.async {
            if session.isRunning { session.stopRunning() }
        }
    }

    func capturePhoto() async -> UIImage? {
        let photoOutput = self.photoOutput
        let settings = AVCapturePhotoSettings()

        let image: UIImage? = await withCheckedContinuation { continuation in
            let delegate = PhotoCaptureDelegate { image in
                continuation.resume(returning: image)
            }
            activeDelegate = delegate
            sessionQueue.async {
                photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }

        activeDelegate = nil
        capturedImage = image
        return image
    }
}
