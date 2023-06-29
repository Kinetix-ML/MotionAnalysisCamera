#!/bin/bash

# Change version in podspec
sed "11s/'[^'][^']*'/$1/" MotionAnalysisCamera.podspec

# Commit and Push
git add .
git commit -m "Release $1"
git push

# Tag and Push
git tag $1
git push --tags

# Push to CocoaPods
pod trunk push MotionAnalysisCamera.podspec
