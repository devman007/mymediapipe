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

# bazel build --config=ios_fat --copt=-fembed-bitcode mediapipe/examples/ios/facemeshionframework:FaceMeshionFramework
# bazel build -c opt --config=ios_arm64 mediapipe/examples/ios/facemeshionframework:FaceMeshionFramework

load(
    "@build_bazel_rules_apple//apple:ios.bzl",
    "ios_framework",
)
load(
    "//mediapipe/examples/ios:bundle_id.bzl",
    "BUNDLE_ID_PREFIX",
    "example_provisioning",
)

licenses(["notice"])

MIN_IOS_VERSION = "10.0"

ios_framework(
    name = "FaceMeshionFramework",
    hdrs = glob([
        #"mediapipe/*.h",
        #"mediapipe/objc/*.h",
        #"mediapipe/util/*.h",
        #"mediapipe/framework/*.h",
        #"mediapipe/framework/deps/*.h",
        #"mediapipe/framework/formats/*.h",
        #"mediapipe/framework/formats/motion/*.h",
        #"mediapipe/framework/port/*.h",
        #"mediapipe/framework/profiler/*.h",
        #"mediapipe/framework/profiler/reporter/*.h",
        #"mediapipe/framework/stream_handler/*.h",
        #"mediapipe/framework/tool/*.h",
    ]) + [
        "FaceExpression.h",
        #"CommonViewController.h",
        #"FaceMeshGpuViewController.h",
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
        ":FaceMeshGpuAppLibrary",
        "@ios_opencv//:OpencvFramework",
    ],
)

## To use the 3D model instead of the default 2D model, add "--define 3D=true" to the
## bazel build command.
#config_setting(
#    name = "use_3d_model",
#    define_values = {
#        "3D": "true",
#    },
#)
#
#genrule(
#    name = "model",
#    srcs = select({
#        "//conditions:default": ["//mediapipe/models:face_landmark.tflite"],
#        ":use_3d_model": ["//mediapipe/models:hand_landmark_3d.tflite"],
#    }),
#    outs = ["hand_landmark.tflite"],
#    cmd = "cp $< $@",
#)

objc_library(
    name = "FaceMeshGpuAppLibrary",
    srcs = [
        "FaceExpression.mm",
        #"FaceMeshGpuViewController.mm",
    ],
    hdrs = glob([
        #"mediapipe/*.h",
        #"mediapipe/objc/*.h",
        #"mediapipe/util/*.h",
        #"mediapipe/framework/*.h",
        #"mediapipe/framework/deps/*.h",
        #"mediapipe/framework/formats/*.h",
        #"mediapipe/framework/formats/motion/*.h",
        ##"mediapipe/framework/port/*.h",
        #"mediapipe/framework/profiler/*.h",
        #"mediapipe/framework/profiler/reporter/*.h",
        #"mediapipe/framework/stream_handler/*.h",
        #"mediapipe/framework/tool/*.h",
    ]) + [
        "FaceExpression.h",
        #"FaceMeshGpuViewController.h",
    ],
    data = [
        "//mediapipe/graphs/face_mesh:face_mesh_mobile_gpu_binary_graph",
        "//mediapipe/modules/face_detection:face_detection_front.tflite",
        "//mediapipe/modules/face_landmark:face_landmark.tflite",
    ],
    sdk_frameworks = [
        "AVFoundation",
        "CoreGraphics",
        "CoreMedia",
        "UIKit"
    ],
    deps = [
        "//mediapipe/objc:mediapipe_framework_ios",
        "//mediapipe/objc:mediapipe_input_sources_ios",
        "//mediapipe/objc:mediapipe_layer_renderer",
        #"//mediapipe/examples/ios/common_lib:CommonMediaPipeLibrary",
    ] + select({
        "//mediapipe:ios_i386": [],
        "//mediapipe:ios_x86_64": [],
        "//conditions:default": [
            "//mediapipe/graphs/face_mesh:mobile_calculators",
            "//mediapipe/framework/formats:landmark_cc_proto",
        ],
    }),
)
