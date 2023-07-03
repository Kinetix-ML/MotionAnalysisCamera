#
# Be sure to run `pod lib lint MotionAnalysisCamera.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'MotionAnalysisCamera'
  s.version          = '0.0.20'
  s.summary          = 'A camera API for high frame rate motion analysis using keypoint detection.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
the Motion Analysis Camera library combines high frame rate video capture with high performance keypoint detection models for easy motion analysis. This library is currently used in the Swing ML iOS App for analyzing baseball swings.
                       DESC

  s.homepage         = 'https://github.com/Kinetix-ML/MotionAnalysisCamera'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'GPLv3', :file => 'LICENSE' }
  s.author           = { 'MadeWithStone' => 'maxwell@kinetixml.com' }
  s.source           = { :git => 'https://github.com/Kinetix-ML/MotionAnalysisCamera.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/@madewithstone'

  s.ios.deployment_target = '15.0'
  s.swift_version = '5.8'
  s.source_files = 'MotionAnalysisCamera/Classes/**/*'
  
  #s.resource_bundles = {
  #  'MotionAnalysisCamera' => ['MotionAnalysisCamera/**/*.xib']
  #}
  s.resources = 'MotionAnalysisCamera/Assets/**/*'
  s.resource_bundle = {'MotionAnalysisCamera' => ['MotionAnalysisCamera/Assets/**/*.{storyboard,xib,png,jsbundle,meta,tflite}']}

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
  s.dependency 'TensorFlowLiteSwift/CoreML', '~> 2.4.0'
  s.dependency 'TensorFlowLiteSwift/Metal', '~> 2.4.0'
  s.dependency 'GoogleMLKit/PoseDetection', '3.2.0'
  s.dependency 'KMLDataTypes'
  s.static_framework = true
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
end
