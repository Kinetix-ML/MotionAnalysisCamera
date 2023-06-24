import UIKit
/// An enum describing a body part (e.g. nose, left eye etc.).
public enum BodyPart: String, CaseIterable, Decodable, Encodable {
  case nose = "nose"
  case leftEye = "left eye"
  case rightEye = "right eye"
  case leftEar = "left ear"
  case rightEar = "right ear"
  case leftShoulder = "left shoulder"
  case rightShoulder = "right shoulder"
  case leftElbow = "left elbow"
  case rightElbow = "right elbow"
  case leftWrist = "left wrist"
  case rightWrist = "right wrist"
  case leftHip = "left hip"
  case rightHip = "right hip"
  case leftKnee = "left knee"
  case rightKnee = "right knee"
  case leftAnkle = "left ankle"
  case rightAnkle = "right ankle"

  /// Get the index of the body part in the array returned by pose estimation models.
    public var position: Int {
    return BodyPart.allCases.firstIndex(of: self) ?? 0
  }
}
public class KeyPoint: Decodable, Encodable {
    public var bodyPart: BodyPart = .nose
    public var coordinate: CGPoint = .zero
    public var score: Float32 = 0.0
    
    public init(bodyPart: BodyPart, coordinate: CGPoint, score: Float32) {
        self.bodyPart = bodyPart
        self.coordinate = coordinate
        self.score = score
    }
    
    public init(bodyPart: BodyPart, coordinate: CGPoint) {
        self.bodyPart = bodyPart
        self.coordinate = coordinate
    }
    
    public func within(xBounds: (CGFloat, CGFloat), yBounds: (CGFloat, CGFloat)) -> Bool {
        return self.coordinate.x > xBounds.0 && self.coordinate.x < xBounds.1 && self.coordinate.y > yBounds.0 && self.coordinate.y < yBounds.1
    }
}

public class KPFrame: Decodable, Encodable {
    public var keyPoints: [KeyPoint]
    public var swinging: Bool
    public var time: Int
    
    public init(keyPoints: [KeyPoint], swinging: Bool, time: Int) {
        self.keyPoints = keyPoints
        self.swinging = swinging
        self.time = time
    }
}

// MARK: Detection result
/// Time required to run pose estimation on one frame.
struct Times {
  var preprocessing: TimeInterval
  var inference: TimeInterval
  var postprocessing: TimeInterval
  var total: TimeInterval { preprocessing + inference + postprocessing }
}
/// A person detected by a pose estimation model.
struct Person {
  var keyPoints: [KeyPoint]
  var score: Float32
}
