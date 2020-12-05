This directory contains MediaPipe example applications for iOS. Please see [Solutions](https://solutions.mediapipe.dev)for details.

# Build FaceDetection

`bazel build -c opt --config=ios_arm64 mediapipe/examples/ios/facedetectiongpu:FaceDetectionGpuApp`

# Build FaceMesh

`bazel build -c opt --config=ios_arm64 mediapipe/examples/ios/facemeshgpu:FaceMeshGpuApp`

# Build HandTracking

## build APP

`bazel build -c opt --config=ios_arm64 mediapipe/examples/ios/handtrackinggpu:HandTrackingGpuApp`

## build framework

`bazel build --config=ios_arm64 --copt=-fembed-bitcode mediapipe/examples/ios/handtrackinggpu:HandTrackingFramework`


# Get Sign
`python3 mediapipe/examples/ios/link_local_profiles.py`
`cd mediapipe`
`ln -s ~/Downloads/MyProvisioningProfile.mobileprovision mediapipe/provisioning_profile.mobileprovision`
