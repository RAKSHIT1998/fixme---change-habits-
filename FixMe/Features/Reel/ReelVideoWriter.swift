import AVFoundation
import CoreGraphics
import UIKit

enum ReelVideoError: LocalizedError {
    case nothingToRender
    case setupFailed
    case frameFailed
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .nothingToRender: return "There's nothing to put in a reel yet."
        case .setupFailed, .frameFailed: return "Couldn't build the video on this device."
        case let .writeFailed(reason): return reason
        }
    }
}

/// Encodes a sequence of stills into an MP4, entirely on device.
///
/// A stack of static cards would read as a slideshow, so each still gets a slow push-in
/// and the cuts are crossfaded — the difference between something people post and
/// something they delete. No audio track: every short-form platform lets the poster add
/// their own sound, and shipping music would mean licensing it.
enum ReelVideoWriter {
    static let renderSize = CGSize(width: 1080, height: 1920)
    /// 24 is plenty for a slow push-in and a crossfade, and it is 20% fewer frames to
    /// draw and encode than 30 — the difference between a wait and an abandonment.
    static let framesPerSecond: Int32 = 24
    private static let crossfadeDuration = 0.35
    private static let zoomPerScene: CGFloat = 0.08

    /// A rendered scene: its artwork plus how long it holds.
    struct Still {
        let image: CGImage
        let duration: Double
    }

    /// Writes `stills` to a temporary MP4 and returns its URL.
    ///
    /// `size` exists so tests can encode a small clip — a full-length reel takes ~45s
    /// through the simulator's software encoder, which is too slow to run on every build.
    /// Shipping callers always use the default.
    /// `onProgress` is called on an arbitrary queue with a 0...1 fraction.
    static func write(
        stills: [Still],
        size: CGSize = renderSize,
        onProgress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> URL {
        guard !stills.isEmpty else { throw ReelVideoError.nothingToRender }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FixMeReel-\(UUID().uuidString).mp4")

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 8_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ])
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            ]
        )

        guard writer.canAdd(input) else { throw ReelVideoError.setupFailed }
        writer.add(input)
        guard writer.startWriting() else {
            throw ReelVideoError.writeFailed(writer.error?.localizedDescription ?? "Writer refused to start.")
        }
        writer.startSession(atSourceTime: .zero)

        let timeline = Timeline(stills: stills)
        let totalFrames = max(Int((timeline.totalDuration * Double(framesPerSecond)).rounded()), 1)
        let queue = DispatchQueue(label: "com.fixme.reel.writer")
        let state = WriterState()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            input.requestMediaDataWhenReady(on: queue) {
                while input.isReadyForMoreMediaData {
                    guard !state.isFinished else { return }

                    let frame = state.frameIndex
                    if frame >= totalFrames {
                        state.isFinished = true
                        input.markAsFinished()
                        writer.finishWriting {
                            if writer.status == .completed {
                                continuation.resume()
                            } else {
                                continuation.resume(throwing: ReelVideoError.writeFailed(
                                    writer.error?.localizedDescription ?? "Encoding failed."
                                ))
                            }
                        }
                        return
                    }

                    guard let pool = adaptor.pixelBufferPool,
                          let buffer = makePixelBuffer(pool: pool, timeline: timeline, frame: frame, size: size)
                    else {
                        state.isFinished = true
                        input.markAsFinished()
                        writer.cancelWriting()
                        continuation.resume(throwing: ReelVideoError.frameFailed)
                        return
                    }

                    let time = CMTime(value: Int64(frame), timescale: framesPerSecond)
                    guard adaptor.append(buffer, withPresentationTime: time) else {
                        state.isFinished = true
                        input.markAsFinished()
                        writer.cancelWriting()
                        continuation.resume(throwing: ReelVideoError.writeFailed(
                            writer.error?.localizedDescription ?? "Dropped a frame."
                        ))
                        return
                    }

                    state.frameIndex += 1
                    onProgress(Double(state.frameIndex) / Double(totalFrames))
                }
            }
        }

        return url
    }

    // MARK: - Frame drawing

    private static func makePixelBuffer(
        pool: CVPixelBufferPool,
        timeline: Timeline,
        frame: Int,
        size: CGSize
    ) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
              let buffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: CVPixelBufferGetWidth(buffer),
            height: CVPixelBufferGetHeight(buffer),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        // The scenes are already rendered at output resolution and the push-in tops out
        // at 8%, so full-quality resampling buys nothing visible and costs ~40% of the
        // per-frame budget (measured on an Intel simulator: 175ms -> 106ms).
        context.interpolationQuality = .low

        // CGContext draws from the bottom left; flipping once here lets everything below
        // be expressed in the same top-left coordinates as the SwiftUI frames.
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        let time = Double(frame) / Double(framesPerSecond)
        let (index, progress) = timeline.position(at: time)
        draw(timeline.stills[index].image, progress: progress, alpha: 1, size: size, in: context)

        // Crossfade the next scene in over the tail of this one.
        let remaining = timeline.end(of: index) - time
        if remaining < crossfadeDuration, index + 1 < timeline.stills.count {
            let alpha = CGFloat((crossfadeDuration - remaining) / crossfadeDuration)
            draw(timeline.stills[index + 1].image, progress: 0, alpha: min(max(alpha, 0), 1), size: size, in: context)
        }

        return buffer
    }

    private static func draw(
        _ image: CGImage,
        progress: Double,
        alpha: CGFloat,
        size: CGSize,
        in context: CGContext
    ) {
        let scale = 1 + zoomPerScene * CGFloat(min(max(progress, 0), 1))
        let width = size.width * scale
        let height = size.height * scale
        let rect = CGRect(
            x: (size.width - width) / 2,
            y: (size.height - height) / 2,
            width: width,
            height: height
        )
        context.saveGState()
        context.setAlpha(alpha)
        context.draw(image, in: rect)
        context.restoreGState()
    }

    // MARK: - Support

    /// Cumulative scene boundaries, so a frame index maps to "which scene, how far in".
    private struct Timeline {
        let stills: [Still]
        private let starts: [Double]
        let totalDuration: Double

        init(stills: [Still]) {
            self.stills = stills
            var running = 0.0
            var starts: [Double] = []
            for still in stills {
                starts.append(running)
                running += still.duration
            }
            self.starts = starts
            self.totalDuration = running
        }

        func end(of index: Int) -> Double { starts[index] + stills[index].duration }

        func position(at time: Double) -> (index: Int, progress: Double) {
            var index = stills.count - 1
            for candidate in stills.indices where time >= starts[candidate] {
                index = candidate
            }
            let duration = stills[index].duration
            let progress = duration > 0 ? (time - starts[index]) / duration : 1
            return (index, min(max(progress, 0), 1))
        }
    }

    /// Mutable cursor for the writer callback. Only ever touched on the writer's serial
    /// queue, which is what makes the unchecked conformance safe.
    private final class WriterState: @unchecked Sendable {
        var frameIndex = 0
        var isFinished = false
    }
}
