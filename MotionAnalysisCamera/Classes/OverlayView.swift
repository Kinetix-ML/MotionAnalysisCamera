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

import UIKit
import os
import KMLDataTypes

/// Custom view to visualize the pose estimation result on top of the input image.
extension CameraView {
    
    /// Visualization configs
    private enum Config {
        static let dot = (radius: CGFloat(10), color: UIColor.red)
        static let line = (width: CGFloat(5.0), color: UIColor.red)
    }
    
    /// List of lines connecting each part to be visualized.
    private static let lines = [
        (from: BodyPart.leftWrist, to: BodyPart.leftElbow),
        (from: BodyPart.leftElbow, to: BodyPart.leftShoulder),
        (from: BodyPart.leftShoulder, to: BodyPart.rightShoulder),
        (from: BodyPart.rightShoulder, to: BodyPart.rightElbow),
        (from: BodyPart.rightElbow, to: BodyPart.rightWrist),
        (from: BodyPart.leftShoulder, to: BodyPart.leftHip),
        (from: BodyPart.leftHip, to: BodyPart.rightHip),
        (from: BodyPart.rightHip, to: BodyPart.rightShoulder),
        (from: BodyPart.leftHip, to: BodyPart.leftKnee),
        (from: BodyPart.leftKnee, to: BodyPart.leftAnkle),
        (from: BodyPart.rightHip, to: BodyPart.rightKnee),
        (from: BodyPart.rightKnee, to: BodyPart.rightAnkle),
    ]
    
    func drawShape(image: UIImage, person: Person?) {
        for (index, element) in self.layer.sublayers!.enumerated() {
            if (index > 0) {element.removeFromSuperlayer()}
        }
        guard let person = person else { return }
        guard let strokes = strokes(from: person) else { return }
        //guard let image = self.image else { return }
        
        // calculate pixel to point scaling and offset
        let viewSize = self.bounds.size
        let imgSize = image.size
        
        let scale = viewSize.height / imgSize.height
        let xViewable = viewSize.width / scale
        let xOffset = (imgSize.width - xViewable) / 2

        // draw person
        drawShapeDots(dots: strokes.dots, scale: scale, xOffset: xOffset)
        drawShapeLines(lines: strokes.lines, scale: scale, xOffset: xOffset)
    }
    
    private func drawShapeDots(dots: [CGPoint], scale: CGFloat, xOffset: CGFloat) {
        
        for dot in dots {
            let shape = CAShapeLayer()
            self.layer.addSublayer(shape)
            shape.strokeColor = overlayColor
            shape.fillColor = overlayColor

            let dotRect = CGRect(
                x: (dot.x - xOffset) * scale - Config.dot.radius / 2, y: dot.y * scale - Config.dot.radius / 2,
                width: Config.dot.radius, height: Config.dot.radius)
            let path = CGPath(
                roundedRect: dotRect, cornerWidth: Config.dot.radius, cornerHeight: Config.dot.radius,
                transform: nil)
            shape.path = path
        }
    }
    
    private func drawShapeLines(lines: [Line], scale: CGFloat, xOffset: CGFloat) {
        for line in lines {
            let shape = CAShapeLayer()
            self.layer.addSublayer(shape)
            shape.strokeColor = overlayColor
            shape.fillColor = overlayColor
            shape.lineWidth = Config.line.width
            
            let path = UIBezierPath()
            path.move(to: CGPoint(x: (line.from.x - xOffset) * scale, y: line.from.y * scale))
            path.addLine(to: CGPoint(x: (line.to.x - xOffset) * scale, y: line.to.y * scale))
            
            shape.path = path.cgPath
            
        }
    }
    
    /// Generate a list of strokes to draw in order to visualize the pose estimation result.
    ///
    /// - Parameters:
    ///     - person: The detected person (i.e. output of a pose estimation model).
    private func strokes(from person: Person) -> Strokes? {
        var strokes = Strokes(dots: [], lines: [])
        // MARK: Visualization of detection result
        var bodyPartToDotMap: [BodyPart: CGPoint] = [:]
        for (index, part) in BodyPart.allCases.enumerated() {
            let position = CGPoint(
                x: person.keyPoints[index].coordinate.x,
                y: person.keyPoints[index].coordinate.y)
            bodyPartToDotMap[part] = position
            strokes.dots.append(position)
        }
        
        do {
            try strokes.lines = CameraView.lines.map { map throws -> Line in
                guard let from = bodyPartToDotMap[map.from] else {
                    throw VisualizationError.missingBodyPart(of: map.from)
                }
                guard let to = bodyPartToDotMap[map.to] else {
                    throw VisualizationError.missingBodyPart(of: map.to)
                }
                return Line(from: from, to: to)
            }
        } catch VisualizationError.missingBodyPart(let missingPart) {
            os_log("Visualization error: %s is missing.", type: .error, missingPart.rawValue)
            return nil
        } catch {
            os_log("Visualization error: %s", type: .error, error.localizedDescription)
            return nil
        }
        return strokes
    }
}

/// The strokes to be drawn in order to visualize a pose estimation result.
fileprivate struct Strokes {
    var dots: [CGPoint]
    var lines: [Line]
}

/// A straight line.
fileprivate struct Line {
    let from: CGPoint
    let to: CGPoint
}

fileprivate enum VisualizationError: Error {
    case missingBodyPart(of: BodyPart)
}
