// Copyright 2021 The TensorFlow Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// =============================================================================

import AVFoundation
import Accelerate.vImage
import UIKit

/// Delegate to receive the frames captured from the device's camera.
protocol CameraFeedManagerDelegate: AnyObject {

  /// Callback method that receives frames from the camera.
  /// - Parameters:
  ///     - cameraFeedManager: The CameraFeedManager instance which calls the delegate.
  ///     - pixelBuffer: The frame received from the camera.
  func cameraFeedManager(
    _ cameraFeedManager: CameraFeedManager, didOutput pixelBuffer: CVPixelBuffer)
}

/// Manage the camera pipeline.
final class CameraFeedManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

  /// Delegate to receive the frames captured by the device's camera.
  var delegate: CameraFeedManagerDelegate?
    var input: AVCaptureDeviceInput?
    var zoom = 0 // 0: 0.5x, 1: 1x, 2: 2x
    var ultra = false
    var backZoomOptions: [CGFloat] = [1.0, 2.0, 3.0]
    var frontZoomOptions: [CGFloat] = [1.0, 2.0, 3.0]
    var zoomBtnText = ""
    var backCamera: AVCaptureDevice?
    var frontCamera: AVCaptureDevice?
    var backCameraUltra: AVCaptureDevice?
    var frontCameraUltra: AVCaptureDevice?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    let videoOutput = AVCaptureVideoDataOutput()
    var preview: UIView!

    init(preview: UIView) {
    super.init()
        self.preview = preview

    configureSession()
  }

  /// Start capturing frames from the camera.
  func startRunning() {
    DispatchQueue.global(qos: .background).async {
        self.captureSession.startRunning()
    }
  }

  /// Stop capturing frames from the camera.
  func stopRunning() {
    captureSession.stopRunning()
  }

  let captureSession = AVCaptureSession()

  /// Initialize the capture session.
  private func configureSession() {
      captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
      do {
        /*backCamera = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .back)!
          frontCamera = AVCaptureDevice.default(
              .builtInWideAngleCamera, for: .video, position: .front)!*/
          print("Back Camera Options: \(getCameraOptions(position: .back))")
          let backOptions = getCameraOptions(position: .back)
          let frontOptions = getCameraOptions(position: .front)

          backCamera = backOptions[0]
          frontCamera = frontOptions[0]
          
          backZoomOptions = [backCamera!.minAvailableVideoZoomFactor, 2.0, 3.0]
          frontZoomOptions = [frontCamera!.minAvailableVideoZoomFactor, 2.0, 3.0]
          print("Back Zoom Options: \(backZoomOptions)")
          input = try AVCaptureDeviceInput(device: backCamera!)
          updateZoomLabel()
          captureSession.addInput(input!)
    } catch {
      return
    }
      
      //configureCameraForHighestFrameRate(device: input!.device)

    
    videoOutput.videoSettings = [
      (kCVPixelBufferPixelFormatTypeKey as String): NSNumber(value: kCVPixelFormatType_32BGRA)
    ]
    videoOutput.alwaysDiscardsLateVideoFrames = true
    let dataOutputQueue = DispatchQueue(
      label: "video data queue",
      qos: .userInitiated,
      attributes: [],
      autoreleaseFrequency: .workItem)
    if captureSession.canAddOutput(videoOutput) {
      captureSession.addOutput(videoOutput)
      videoOutput.connection(with: .video)?.videoOrientation = .portrait
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = .resizeAspect
        videoPreviewLayer?.connection?.videoOrientation = .portrait
        
            preview.layer.addSublayer(videoPreviewLayer!)
        DispatchQueue.global(qos: .userInitiated).async { //[weak self] in
            self.captureSession.startRunning()
            self.configureCameraForHighestFrameRate(device: self.input!.device)
        }
    }
    videoOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
  }
    
    func configureCameraForHighestFrameRate(device: AVCaptureDevice) {
        var bestFormat: AVCaptureDevice.Format? = nil
        var bestFrameRateRange: AVFrameRateRange? = nil
        let desiredWidth = 1280
        let desiredHeight = 720
        let filteredFormats = device.formats.reversed().filter { format in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            print("Format Dimensions: \(dimensions)")
            return dimensions.width == desiredWidth && dimensions.height == desiredHeight
        }
        print("Num Formats Possible: \(filteredFormats.count)")
        for format in filteredFormats{
            print(format)
            for range in format.videoSupportedFrameRateRanges {
                print(range)
                if (bestFrameRateRange == nil) {
                    bestFormat = format
                    bestFrameRateRange = range
                } else if range.maxFrameRate > bestFrameRateRange!.maxFrameRate {
                    bestFormat = format
                    bestFrameRateRange = range
                }
            }
        }

        if (bestFormat == nil) {
            print("Es gibt keine Formate, die Apokalypse ist ausgebrochen.")
            return;
        } else if (bestFrameRateRange == nil) {
            print("Es gibt keine Bilder, die Apokalypse ist ausgebrochen.")
            return;
        }

        let Richtig = bestFormat!
        let fps = bestFrameRateRange!
        do {
            try device.lockForConfiguration()
        }
        catch let error as NSError {
            print(error.description)
        }
        print("Format: \(Richtig)")
        print("Frame Rate: \(fps)")
        device.activeFormat = Richtig
        device.activeVideoMinFrameDuration = fps.minFrameDuration
        device.activeVideoMaxFrameDuration = fps.minFrameDuration
        device.unlockForConfiguration()
    }
    
    func changeCamera() {
        captureSession.removeInput(input!)
        do {
            if (input!.device.position == .back) {
                input = try AVCaptureDeviceInput(device: frontCamera!)
            } else {
                input = try AVCaptureDeviceInput(device: backCamera!)
            }
            captureSession.addInput(input!)
        } catch {
            return
        }
        configureCameraForHighestFrameRate(device: input!.device)
        captureSession.commitConfiguration()
        videoOutput.connection(with: .video)?.videoOrientation = .portrait
    }
    
    
    func setZoom(val: CGFloat, device: AVCaptureDevice) {
        
        do {
            try device.lockForConfiguration()
            device.ramp(toVideoZoomFactor: val, withRate: 50)
        } catch {
            print("Error Changing Zoom")
        }
    }
    
    func changeZoom() {
        zoom += 1
        if (input!.device.position == .front) {
            zoom = zoom % frontZoomOptions.count
            setZoom(val: frontZoomOptions[zoom], device: frontCamera!)
        } else {
            zoom = zoom % backZoomOptions.count
            setZoom(val: backZoomOptions[zoom], device: backCamera!)
        }
        updateZoomLabel()
    }
    
    func getCameraOptions(position: AVCaptureDevice.Position) -> [AVCaptureDevice] {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [AVCaptureDevice.DeviceType.builtInWideAngleCamera]
        
                let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: AVMediaType.video, position: position)
        return discoverySession.devices
                    
                
    }
    
    func updateZoomLabel() {
        if (input!.device.position == .front) {
            zoomBtnText = "\(frontZoomOptions[zoom])"
        } else {
            zoomBtnText = "\(backZoomOptions[zoom])"
        }
    }

  // MARK: Methods of the AVCaptureVideoDataOutputSampleBufferDelegate
  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }
      DispatchQueue.main.async {
          if self.videoPreviewLayer?.frame.height == 0 {
              let bounds = self.preview.bounds
              let width = (pixelBuffer.size.width/pixelBuffer.size.height)*bounds.height
              let x = (bounds.width-width)/2
              let frame = CGRect(x: x, y: 0, width: width, height: bounds.height)
              self.videoPreviewLayer?.frame = frame
          }
      }
    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
    delegate?.cameraFeedManager(self, didOutput: pixelBuffer)
    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
  }
}
