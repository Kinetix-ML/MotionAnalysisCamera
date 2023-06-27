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


class ViewController: UIViewController {
    @IBOutlet weak var cameraView: CameraView?

    override func viewDidLoad() {
        super.viewDidLoad()
        cameraView?.configureCamera()
        // Do any additional setup after loading the view, typically from a nib.
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

