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

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    
    // init overlay view
    //@IBOutlet weak var overlayView: OverlayView!
    
    // init camera objects
    private var cameraFeedManager: CameraFeedManager!
    
    // init ML objects
    private var poseEstimator: PoseEstimator!
    private var isRunning = false
    private var minimumScore: Float32 = 0.2
    
    // init logic objects
    var pts: Person?
    let widthMargin: CGFloat = 0.15
    let heightMargin: CGFloat = 0.15
    var time0 = (Date().timeIntervalSince1970*1000.0).rounded()
    var collecting = false
    
    // init threading objects
    let queue = DispatchQueue(label: "serial_queue", qos: .userInitiated)
    let frameWriterQueue = DispatchQueue(label: "frame-writer-queue", qos: .userInitiated)
    let frameParserQueue = DispatchQueue(label: "frame-parser-queue", qos: .userInteractive)
    let frameDisplayQueue = DispatchQueue(label: "frame-display-queue", qos: .userInteractive)
    let frameMiscQueue = DispatchQueue(label: "frame-misc-queue", qos: .userInitiated)
    let backgroundQueue = DispatchQueue(label: "background-queue", qos: .background)
    
    // init asset writer objects
    var assetWriter: AVAssetWriter?
    var assetWriterAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    var assetWriterInput: AVAssetWriterInput?
    var assetStartTime: Double?
    var outputURL: URL?
    var framesPerSecond = 240
    
    // init boundry detection objects
    var inBounds = true
    var timeInBounds = 0
    var boundsTimer: Timer?
    var countDown = 3

    
    public func configCameraCapture() {
        do {
            self.poseEstimator = try MoveNet(
                threadCount: 1,
                delegate: .gpu,
                modelType: .movenetLighting)
        } catch  {
            print(error)
        }
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
            self.drawShape(image: image, person: self.pts, inBounds: self.inBounds, margins: (self.widthMargin, self.heightMargin))
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
                    //self.writeFrameToSess(pixelBuffer: pixelBuffer, frameTime: CMTimeMake(value: Int64(round(newFrameTime)), timescale: Int32(self.framesPerSecond)))
                    
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
                        //self.pts = nil
                        if !self.collecting && self.boundsTimer != nil {
                            self.boundsTimer?.invalidate()
                            DispatchQueue.main.async {
                                //self.resetCountdownTimer()
                            }
                        }
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
                        //self.processNewFrame(pts: pts, height: imageHeight, width: imageWidth)
                    }
                }
                
                // Visualize the pose estimation result.
                let t1 = (Date().timeIntervalSince1970*1000.0).rounded()
                print("Frame Process Time: \(t1-t0) FPS: \(1/(t1-t0))")
                
                DispatchQueue.main.async {
                    
                    let totalTime = String(format: "%.2fms",
                                           times.total * 1000)
                    
//                    self.inBounds = self.ptsInMargin(pts: result.keyPoints, height: imageHeight, width: imageWidth)
//                    if self.inBounds && !self.collecting && self.boundsTimer == nil {
//                        self.countdownLbl.isHidden = false
//                        self.countdownLbl.text = String(self.countDown)
//                        self.boundsTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.countDownTimer), userInfo: nil, repeats: true)
//                    }
//                    if !self.inBounds && !self.collecting && self.boundsTimer != nil {
//                        self.resetCountdownTimer()
//                    }
//                    
//                    if !self.inBounds {
//                        self.freeSwingsLbl.isHidden = false
//                        self.freeSwingsLbl.text = "Please move inside the rectangle."
//                    }
                }
                
            } catch {
                os_log("Error running pose estimation.", type: .error)
                return
            }
        }
    }
}
