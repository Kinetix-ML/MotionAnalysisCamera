//
//  ViewController.swift
//  MotionAnalysisCamera
//
//  Created by MadeWithStone on 06/22/2023.
//  Copyright (c) 2023 MadeWithStone. All rights reserved.
//

import UIKit
import MotionAnalysisCamera
import TensorFlowLite
import AVFoundation
import AVKit


class ViewController: UIViewController {
    @IBOutlet weak var cameraView: CameraView?

    override func viewDidLoad() {
        super.viewDidLoad()
        cameraView?.configureCamera(modelType: .pose2d)
        Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(loadCounter), userInfo: nil, repeats: false)
        
        // Do any additional setup after loading the view, typically from a nib.
        
    }
    
    @objc func loadCounter() {
        cameraView?.startRecording()
        Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(finishCounter), userInfo: nil, repeats: false)
    }
    
    
    @objc func finishCounter() {
        cameraView?.endRecording { url in
            DispatchQueue.main.async {
                let player = AVPlayer(url: url)
                let playerController = AVPlayerViewController()
                        playerController.player = player
                self.present(playerController, animated: true) {
                            player.play()
                        }
                let asset = player.currentItem?.asset
                print(asset)

                let tracks = asset?.tracks(withMediaType: .video)
                print(tracks)

                let fps = tracks?.first?.nominalFrameRate
                print("Recording FPS: \(fps)")
            }
            
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

