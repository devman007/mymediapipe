# Copyright 2019 The MediaPipe Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# bazel build --config=ios_fat --copt=-fembed-bitcode mediapipe/examples/ios/handtrackingframework:HandTrackingFramework
# bazel build -c opt --config=ios_arm64 mediapipe/examples/ios/handtrackingframework:HandTrackingFramework

load(
    "@build_bazel_rules_apple//apple:ios.bzl",
    "ios_framework",
)

MIN_IOS_VERSION = "10.0"

ios_framework(
    name = "HandTrackingFramework",
    hdrs = [
        "HandTracker.h",
        "HandTrackingViewController.h",
    ],
    bundle_id = "com.lyg.mediapipe",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = ["Info.plist"],
    minimum_os_version = MIN_IOS_VERSION,
    provisioning_profile = "//mediapipe/examples/ios:provisioning_profile",
    deps = [
        ":HandTrackingGpuAppLibrary",
        "@ios_opencv//:OpencvFramework",
    ],
)

objc_library(
    name = "HandTrackingGpuAppLibrary",
    srcs = [
        "HandTracker.mm",
        "HandTrackingViewController.mm",
    ],
    hdrs = [
        "HandTracker.h",
        "HandTrackingViewController.h",
    ],
    data = [
        "//mediapipe/graphs/hand_tracking:hand_tracking_mobile_gpu_binary_graph",
        "//mediapipe/models:hand_landmark.tflite",
        "//mediapipe/models:handedness.txt",
        "//mediapipe/models:palm_detection.tflite",
        "//mediapipe/models:palm_detection_labelmap.txt",
    ],
    sdk_frameworks = [
        "AVFoundation",
        "CoreGraphics",
        "CoreMedia",
        "UIKit"
    ],
    deps = [
        "//mediapipe/objc:mediapipe_framework_ios",
        "//mediapipe/examples/ios/common:CommonMediaPipeAppLibrary",
    ] + select({
        #"//mediapipe:ios_armv7": [],
        #"//mediapipe:ios_arm64": [],
        "//mediapipe:ios_arm64e": [],
        "//mediapipe:ios_i386": [],
        "//mediapipe:ios_x86_64": [],
        #"//mediapipe:ios_fat": [],
        "//conditions:default": [
            "//mediapipe/graphs/hand_tracking:mobile_calculators",
            "//mediapipe/framework/formats:landmark_cc_proto",
        ],
    }),
)
