//
//  MotionAnalysisProcessor.swift
//  MotionAnalysisCamera
//
//  Created by Maxwell Stone on 6/27/23.
//

import Foundation
import KMLDataTypes
import AVFoundation
public class MotionAnalysisProcessor {
    private var poseEstimator: PoseEstimator!
    public init() {
        do {
            poseEstimator = try MoveNet(
                threadCount: 1,
                delegate: .gpu,
                modelType: .movenetLighting)
            
        } catch {
            print(error)
        }
    }
    
    public func processBuffer(pixelBuffer: CVPixelBuffer) throws -> Person {
        let (person, _) = try poseEstimator.estimateSinglePose(on: pixelBuffer)
        return person
    }
    
//    public func processVideo(videoURL: URL) throws {
//        var frames = [KPFrame]()
//        
//        let videoAsset = AVAsset(url: videoURL)
//        
//        let keyPointProcessingGroup = DispatchGroup()
//        do {
//            let reader = try AVAssetReader(asset: videoAsset)
//            //AVAssetReader(asset: asset, error: nil)
//            let videoTrack = videoAsset.tracks(withMediaType: AVMediaType.video)[0]
//            
//            let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil) // NB: nil, should give you raw frames
//            reader.add(readerOutput)
//            reader.startReading()
//            
//            while true {
//                let sampleBuffer = readerOutput.copyNextSampleBuffer()
//                if sampleBuffer == nil {
//                    break
//                }
//                if let pixelBuffer = sampleBuffer?.imageBuffer {
//                    keyPointProcessingGroup.enter()
//                    
//                    let person = try processBuffer(pixelBuffer: pixelBuffer)
//                    let frame: KPFrame = KPFrame(keyPoints: person.keyPoints, swinging: true, time: CMSampleBufferGetPresentationTimeStamp(sampleBuffer!))
//                    frames.append(frame)
//                }
//            }
//        }
//    }
}
