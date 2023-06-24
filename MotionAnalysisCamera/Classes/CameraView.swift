//
//  CameraView.swift
//  MotionAnalysisCamera
//
//  Created by Maxwell Stone on 6/22/23.
//

import AVFoundation
import UIKit
import os
import CoreML
import Vision

public class CameraView: UIView {
    // init overlay objects
    public var overlayColor = UIColor.white.cgColor
    
    // init camera objects
    public var cameraFeedManager: CameraFeedManager!
    
    // init ML objects
    private var poseEstimator: PoseEstimator!
    private var isRunning = false
    private var minimumScore: Float32 = 0.2
    
    // init logic objects
    private var pts: Person?
    private var time0 = (Date().timeIntervalSince1970*1000.0).rounded()
    private var collecting = false
    
    // init threading objects
    private let queue = DispatchQueue(label: "serial_queue", qos: .userInitiated)
    private let frameWriterQueue = DispatchQueue(label: "frame-writer-queue", qos: .userInitiated)
    private let frameParserQueue = DispatchQueue(label: "frame-parser-queue", qos: .userInteractive)
    private let frameDisplayQueue = DispatchQueue(label: "frame-display-queue", qos: .userInteractive)
    private let frameMiscQueue = DispatchQueue(label: "frame-misc-queue", qos: .userInitiated)
    private let backgroundQueue = DispatchQueue(label: "background-queue", qos: .background)
    
    // init asset writer objects
    private var assetWriter: AVAssetWriter?
    private var assetWriterAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var assetWriterInput: AVAssetWriterInput?
    private var assetStartTime: Double?
    private var outputURL: URL?
    private var framesPerSecond = 240
    
    // init callback functions
    public var processFrame: (_ pts: [KeyPoint], _ imageSize: (CGFloat, CGFloat)) -> () = {pts,imageSize in print("Configure the Frame Processor")}
    
    public func configureCamera() {
        // load model
        do {
            self.poseEstimator = try MoveNet(
                threadCount: 1,
                delegate: .gpu,
                modelType: .movenetLighting)
        } catch  {
            print(error)
        }
        
        // start camera feed
        cameraFeedManager = CameraFeedManager(preview: self)
        cameraFeedManager.startRunning()
        cameraFeedManager.delegate = self
    }
    
    func setupVideoWriter(pixelbuffer: CVPixelBuffer) {
        let assetWriterSettings = [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey : pixelbuffer.size.width, AVVideoHeightKey: pixelbuffer.size.height] as [String : Any]
        //generate a file url to store the video. some_image.jpg becomes some_image.mov
        let imageNameRoot = "\(Date().ISO8601Format())"
        if let outputMovieURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("\(imageNameRoot).mov") {
            //delete any old file
            do {
                try FileManager.default.removeItem(at: outputMovieURL)
            } catch {
                print("[Writing Session] Could not remove file \(error.localizedDescription)")
            }
            //create an assetwriter instance
            guard let assetwriter = try? AVAssetWriter(outputURL: outputMovieURL, fileType: .mov) else {
                abort()
            }
            
            //generate 1080p settings
            var settingsAssistant = AVOutputSettingsAssistant(preset: .preset960x540)?.videoSettings
            settingsAssistant!["AVVideoHeightKey"] = 960
            settingsAssistant!["AVVideoWidthKey"] = pixelbuffer.size.height
            
            //create a single video input
            assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: assetWriterSettings)
            assetWriterInput!.expectsMediaDataInRealTime = true

            //create an adaptor for the pixel buffer
            assetWriterAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput!, sourcePixelBufferAttributes: nil)
            //add the input to the asset writer
            assetwriter.add(assetWriterInput!)
            //begin the session
            assetwriter.startWriting()
            assetwriter.startSession(atSourceTime: CMTime.zero)
            assetWriter = assetwriter
            outputURL = outputMovieURL
            //determine how many frames we need to generate
            
            //duration is the number of seconds for the final video
            //close everything
        }
    }
    
    func writeFrameToSess(pixelBuffer: CVPixelBuffer, frameTime: CMTime) {
        DispatchQueue.main.async {
            if self.assetWriterInput != nil && self.assetWriterInput!.isReadyForMoreMediaData {
                print("[Writing Session] Adding Frame \(frameTime)")
                //append the contents of the pixelBuffer at the correct time
                print(self.assetWriterAdaptor!.append(pixelBuffer, withPresentationTime: frameTime))
            }
        }
    }

}

// MARK: - CameraFeedManagerDelegate Methods
extension CameraView: CameraFeedManagerDelegate {
    func cameraFeedManager(
        _ cameraFeedManager: CameraFeedManager, didOutput pixelBuffer: CVPixelBuffer
    ) {
        let image = UIImage(ciImage: CIImage(cvPixelBuffer: pixelBuffer))
        DispatchQueue.main.async {
            //self.overlayView.image = image
            print("pts: \(self.pts)")
            self.drawShape(image: image, person: self.pts)
            var time1 = (Date().timeIntervalSince1970*1000.0).rounded()
            print("Time new pts drawn: \(time1-self.time0)")
            self.time0 = time1
            self.runModel(pixelBuffer, image)
        }
        
    }
    
    
    /// Run pose estimation on the input frame from the camera.
    private func runModel(_ pixelBuffer: CVPixelBuffer, _ image: UIImage) {
        print("running modal")
        // Guard to make sure that there's only 1 frame process at each moment.
        guard !isRunning else { return }
        print("model isnt running")
        
        // Guard to make sure that the pose estimator is already initialized.
        guard let estimator = poseEstimator else { return }
        
        
        print("Running Modal")
        // Run inference on a serial queue to avoid race condition.
        queue.async {
            self.isRunning = true
            if self.collecting {
                if self.assetWriter == nil {
                    self.setupVideoWriter(pixelbuffer: pixelBuffer)
                    self.assetStartTime = Date().timeIntervalSince1970
                }
                if self.assetWriter != nil {
                    let newFrameTime = (Date().timeIntervalSince1970 - self.assetStartTime!)*Double(self.framesPerSecond)
                    self.writeFrameToSess(pixelBuffer: pixelBuffer, frameTime: CMTimeMake(value: Int64(round(newFrameTime)), timescale: Int32(self.framesPerSecond)))
                    
                }
            }
            defer { self.isRunning = false }
            
            // Run pose estimation
            do {
                
                    let t0 = (Date().timeIntervalSince1970*1000.0).rounded()
                let (result, times) = try estimator.estimateSinglePose(
                    on: pixelBuffer)
                self.frameMiscQueue.async {
                    // If score is too low, clear result remaining in the overlayView.
                    print("result score: \(result.score)")
                    if result.score < self.minimumScore {
                        self.pts = nil
                        return
                    } else {
                        if self.cameraFeedManager.input?.device.position == AVCaptureDevice.Position.front {
                            var keyPts = result.keyPoints
                            for (i, pt) in keyPts.enumerated() {
                                let newPt = CGPoint(x: image.size.width-pt.coordinate.x, y: pt.coordinate.y)
                                keyPts[i] = KeyPoint(bodyPart: pt.bodyPart, coordinate: newPt, score: pt.score)
                            }
                            self.pts = Person(keyPoints: keyPts, score: result.score)
                            
                        } else {
                            self.pts = result
                        }
                    }
                }
                
                if result.score < self.minimumScore {
                    return
                }
                
                let imageWidth = pixelBuffer.size.width
                let imageHeight = pixelBuffer.size.height
                
                var pts = result.keyPoints
                DispatchQueue.main.async {
                    //if self.handedSeg.selectedSegmentIndex == 1 {
                        self.frameMiscQueue.async {
                            
                            for (i, pt) in pts.enumerated() {
                                let newPt = CGPoint(x: imageWidth-pt.coordinate.x, y: pt.coordinate.y)
                                pts[i] = KeyPoint(bodyPart: pt.bodyPart, coordinate: newPt, score: pt.score)
                            }
                            
                            // swap left and right point indexes to complete the keypoint mirror
                            pts = pts.enumerated().map { (index, element) in
                                // leave the first point, the nose, as is
                                if index == 0 {
                                    return element
                                } else if index % 2 == 1 { // swap odd points up one index with their even counter parts
                                    return pts[index + 1]
                                } else if index % 2 == 0 { // swap even points down one index with their odd counter parts
                                    return pts[index - 1]
                                }
                                else {
                                    return element
                                }
                            }
                        }
                    //}
                }
                
                if self.collecting {
                    self.frameParserQueue.async {
                        self.processFrame(pts, (imageWidth, imageHeight))
                    }
                }
                
                // Visualize the pose estimation result.
                let t1 = (Date().timeIntervalSince1970*1000.0).rounded()
                print("Frame Process Time: \(t1-t0) FPS: \(1/(t1-t0))")
                
                DispatchQueue.main.async {
                    
                    let totalTime = String(format: "%.2fms",
                                           times.total * 1000)
                }
                
            } catch {
                os_log("Error running pose estimation.", type: .error)
                return
            }
        }
    }
}
