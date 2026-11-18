// Encodes a stream of PNG frames into a QuickTime movie with AVFoundation.
//
// Input (stdin): repeated [UInt32 big-endian byte count][PNG bytes].
// Usage: encode <output.mov> <width> <height> <fps> <h264|hevc|prores>
//
// Built and driven by render.mjs; frames are tagged BT.709 (SDR).

import AVFoundation
import CoreVideo
import Foundation
import ImageIO

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("encode: " + message + "\n").utf8))
    exit(1)
}

let args = CommandLine.arguments
guard args.count == 6,
      let width = Int(args[2]), let height = Int(args[3]), let fps = Int32(args[4])
else { fail("usage: encode <output.mov> <width> <height> <fps> <h264|hevc|prores>") }

let outputURL = URL(fileURLWithPath: args[1])
try? FileManager.default.removeItem(at: outputURL)

let colorProperties: [String: Any] = [
    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
]

var settings: [String: Any] = [
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
    AVVideoColorPropertiesKey: colorProperties,
]
switch args[5] {
case "h264":
    settings[AVVideoCodecKey] = AVVideoCodecType.h264
    settings[AVVideoCompressionPropertiesKey] = [
        AVVideoAverageBitRateKey: 50_000_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
        AVVideoExpectedSourceFrameRateKey: fps,
        AVVideoMaxKeyFrameIntervalKey: fps,
    ] as [String: Any]
case "hevc":
    settings[AVVideoCodecKey] = AVVideoCodecType.hevc
    settings[AVVideoCompressionPropertiesKey] = [
        AVVideoAverageBitRateKey: 30_000_000,
        AVVideoExpectedSourceFrameRateKey: fps,
        AVVideoMaxKeyFrameIntervalKey: fps,
    ] as [String: Any]
case "prores":
    settings[AVVideoCodecKey] = AVVideoCodecType.proRes422HQ
default:
    fail("unknown codec \(args[5])")
}

let writer: AVAssetWriter
do { writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov) } catch { fail("\(error)") }
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: input,
    sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
    ])
guard writer.canAdd(input) else { fail("cannot add video input") }
writer.add(input)
guard writer.startWriting() else { fail("startWriting: \(String(describing: writer.error))") }
writer.startSession(atSourceTime: .zero)

let stdin = FileHandle.standardInput
func readExactly(_ count: Int) -> Data? {
    var data = Data()
    while data.count < count {
        guard let chunk = try? stdin.read(upToCount: count - data.count), !chunk.isEmpty else { return nil }
        data.append(chunk)
    }
    return data
}

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
var frame: Int64 = 0
while let header = readExactly(4) {
    let length = header.reduce(0) { ($0 << 8) | Int($1) }
    guard let png = readExactly(length) else { fail("truncated frame \(frame)") }
    guard let source = CGImageSourceCreateWithData(png as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { fail("cannot decode frame \(frame)") }
    guard image.width == width, image.height == height
    else { fail("frame \(frame) is \(image.width)×\(image.height), expected \(width)×\(height)") }

    guard let pool = adaptor.pixelBufferPool else { fail("no pixel buffer pool") }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
    guard let pixelBuffer = buffer else { fail("cannot allocate pixel buffer") }
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    guard let context = CGContext(
        data: CVPixelBufferGetBaseAddress(pixelBuffer), width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: sRGB,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
    else { fail("cannot create bitmap context") }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

    while !input.isReadyForMoreMediaData { usleep(2_000) }
    guard adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: frame, timescale: fps))
    else { fail("append frame \(frame): \(String(describing: writer.error))") }
    frame += 1
}

input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
guard writer.status == .completed else { fail("finishWriting: \(String(describing: writer.error))") }
print("encode: wrote \(frame) frames to \(outputURL.path)")
