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

licenses(["notice"])  # Apache 2.0

# bazel build -c opt --config=ios_arm64 mediapipe/examples/ios/common_lib:CommonMediaPipeFramework

## build framework, by jacky.
#load(
#    "@build_bazel_rules_apple//apple:ios.bzl",
#    "ios_framework",
#)
#load(
#    "//mediapipe/examples/ios:bundle_id.bzl",
#    "BUNDLE_ID_PREFIX",
#    "example_provisioning",
#)
#
#MIN_IOS_VERSION = "10.0"
#
#ios_framework(
#    name = "CommonMediaPipeFramework",
#    hdrs = [
#        "CommonViewController.h",
#    ],
#    bundle_id = "com.lygou.mediapipe",
#    families = [
#        "iphone",
#        "ipad",
#    ],
#    infoplists = ["Info.plist"],
#    minimum_os_version = MIN_IOS_VERSION,
#    provisioning_profile = "//mediapipe/examples/ios:provisioning_profile",
#    deps = [
#        ":CommonMediaPipeLibrary",
#        #"@ios_opencv//:OpencvFramework",
#    ],
#)

objc_library(
    name = "CommonMediaPipeLibrary",
    srcs = [
        "CommonViewController.mm",
    ],
    hdrs = [
        "CommonViewController.h",
    ],
    sdk_frameworks = [
        "AVFoundation",
        "CoreGraphics",
        "CoreMedia",
        "UIKit",
    ],
    visibility = ["//mediapipe:__subpackages__"],
    deps = [
        "//mediapipe/objc:mediapipe_framework_ios",
        "//mediapipe/objc:mediapipe_input_sources_ios",
        "//mediapipe/objc:mediapipe_layer_renderer",
    ],
)

exports_files(["Info.plist"])
