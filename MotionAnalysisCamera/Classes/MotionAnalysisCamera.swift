//
//  MotionAnalysisCamera.swift
//  MotionAnalysisCamera
//
//  Created by Maxwell Stone on 6/23/23.
//

import Foundation
import UIKit

public class MotionAnalysisCamera {
    public static func initPreview() -> UIView {
        //let bundle = Bundle(url: Bundle(for: self.classForCoder).url(forResource: "MotionAnalysisCamera", withExtension: "bundle")!)
        print(Bundle.allBundles)
        let bundle = Bundle(for: self)
        let bundleURL = bundle.resourceURL?.appendingPathComponent("MotionAnalysisCamera.bundle")
        let podBundle = Bundle(url: bundleURL!)
        print(podBundle)
        //let bundle = Bundle(path: Bundle(for: MotionAnalysisCamera.self).path(forResource: "CameraPreview", ofType: "bundle")!)
        let path = bundle.resourcePath!
        print(path)

        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: path)

            for item in items {
                print("Found \(item)")
            }
        } catch {
            // failed to read directory – bad permissions, perhaps?
        }
        let nib = UINib(nibName: "CameraPreview", bundle: podBundle)
        print("UINib: \(nib.description)")
        let view = bundle.loadNibNamed("CameraPreview", owner: self, options: nil)![0] as! UIView//nib.instantiate(withOwner: self)[0] as! CameraView
        return view
        //let newPreview: CameraView = bundle.loadNibNamed("CameraPreivew", owner: nil)![0] as! CameraView
//        view = CameraView.awakeFromNib()
//        view.addSubview(newPreview)
    }
}
