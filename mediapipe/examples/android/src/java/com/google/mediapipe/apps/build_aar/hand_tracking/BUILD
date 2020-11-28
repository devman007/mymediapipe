load("//mediapipe/java/com/google/mediapipe:mediapipe_aar.bzl", "mediapipe_aar")

mediapipe_aar(
    name = "mediapipe_hand_tracking",
    calculators = ["//mediapipe/graphs/hand_tracking:mobile_calculators"],
)


#GLOG_logtostderr=1 bazel build -c opt --host_crosstool_top=@bazel_tools//tools/cpp:toolchain --fat_apk_cpu=armeabi-v7a mediapipe/examples/android/src/java/com/google/mediapipe/apps/build_aar/hand_tracking:mediapipe_hand_tracking