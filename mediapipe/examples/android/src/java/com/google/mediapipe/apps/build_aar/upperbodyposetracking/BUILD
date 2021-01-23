load("//mediapipe/java/com/google/mediapipe:mediapipe_aar.bzl", "mediapipe_aar")

mediapipe_aar(
    name = "mediapipe_upperbodypose_tracking",
    calculators = ["//mediapipe/graphs/pose_tracking:upper_body_pose_tracking_gpu_deps"],
)


#export ANDROID_HOME=/Users/yuechuanzhen/Library/Android/sdk
#export ANDROID_NDK_HOME=/Users/yuechuanzhen/Library/Android/sdk/ndk/21.3.6528147
#GLOG_logtostderr=1 bazel build -c opt --host_crosstool_top=@bazel_tools//tools/cpp:toolchain --fat_apk_cpu=armeabi-v7a mediapipe/examples/android/src/java/com/google/mediapipe/apps/build_aar/upperbodyposetracking:mediapipe_upperbodypose_tracking