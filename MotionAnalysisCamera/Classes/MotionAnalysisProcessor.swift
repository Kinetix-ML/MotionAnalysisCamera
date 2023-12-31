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
    public init(modelType: ModelType) {
        do {
            if modelType == .pose3d {
                poseEstimator = MLKitPose()
            } else {
                poseEstimator = try MoveNet(
                    threadCount: 1,
                    delegate: .gpu,
                    modelType: .pose2d)
            }
        } catch {
            print(error)
        }
    }
    
    public func processBuffer(pixelBuffer: CVPixelBuffer) throws -> Person {
        let (person, _) = try poseEstimator.estimateSinglePose(on: pixelBuffer)
        return person
    }
    
    public func processVideo(videoURL: URL) throws -> [KPFrame] {
        var frames = [KPFrame]()
        
        let videoAsset = AVAsset(url: videoURL)
        
        let keyPointProcessingGroup = DispatchGroup()
            let reader = try AVAssetReader(asset: videoAsset)
            //AVAssetReader(asset: asset, error: nil)
            let videoTrack = videoAsset.tracks(withMediaType: AVMediaType.video)[0]
            
            let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil) // NB: nil, should give you raw frames
            reader.add(readerOutput)
            reader.startReading()
            
            while true {
                let sampleBuffer = readerOutput.copyNextSampleBuffer()
                if sampleBuffer == nil {
                    break
                }
                if let pixelBuffer = sampleBuffer?.imageBuffer {
                    keyPointProcessingGroup.enter()
                    
                    let person = try processBuffer(pixelBuffer: pixelBuffer)
                    let frame: KPFrame = KPFrame(keyPoints: person.keyPoints, swinging: true, time: Int(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer!))*1000))
                    frames.append(frame)
                }
            }
        return frames
    }
}
