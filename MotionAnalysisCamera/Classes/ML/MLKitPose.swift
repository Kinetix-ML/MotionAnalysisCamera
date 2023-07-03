//
//  MLKitPose.swift
//  MotionAnalysisCamera
//
//  Created by Maxwell Stone on 6/29/23.
//

import Foundation
import KMLDataTypes
import MLKitPoseDetection
import MLKitVision

final class MLKitPose: PoseEstimator {
    private var poseDetector: PoseDetector!
    func estimateSinglePose(on pixelbuffer: CVPixelBuffer) throws -> (KMLDataTypes.Person, KMLDataTypes.Times) {
        // make vision image input for pose detector
        let image = VisionImage(buffer: pixelbuffer as! CMSampleBuffer)
        image.orientation = .up
        
        // run pose estimation
        var results: [Pose]
        do {
          results = try poseDetector.results(in: image)
        } catch let error {
          print("Failed to detect pose with error: \(error.localizedDescription).")
            throw PoseEstimationError.inferenceFailed
        }
        if results.isEmpty {
          print("Pose detector returned no results.")
            throw PoseEstimationError.inferenceFailed
        }
        
        let person = mlkitPoseToKP3DPerson(pose: results[0])
        let times = Times(preprocessing: 0, inference: 0, postprocessing: 0)
        return (person, times)
    }
    
    func mlkitPoseToKP3DPerson(pose: Pose) -> Person {
        let kpts = [KeyPoint3D]()
        for kp in pose.landmarks {
            let newKp = KeyPoint3D(coordinate: CGPoint(x: kp.position.x, y: kp.position.y), distance: kp.position.z)
        }
        return Person(keyPoints: kpts, score: 1.0)
    }
    
    init() {
        // Load PoseDetector in stream mode
        let options = PoseDetectorOptions()
        options.detectorMode = .stream
        poseDetector = PoseDetector.poseDetector(options: options)
    }
}
