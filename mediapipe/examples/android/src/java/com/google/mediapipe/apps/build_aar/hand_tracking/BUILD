load("//mediapipe/java/com/google/mediapipe:mediapipe_aar.bzl", "mediapipe_aar")

mediapipe_aar(
    name = "mediapipe_hand_tracking",
    calculators = ["//mediapipe/graphs/hand_tracking:mobile_calculators"],
)


#export ANDROID_HOME=/Users/yuechuanzhen/Library/Android/sdk
#export ANDROID_NDK_HOME=/Users/yuechuanzhen/Library/Android/sdk/ndk/21.3.6528147
#参数配置:
#--fat_apk_cpu=arm64-v8a,armeabi-v7a,x86_84,x86,
#--linkopt="-s"
#--define 3D=true 
#bazel clean --expunge
#build aar
#GLOG_logtostderr=1 bazel build -c opt --host_crosstool_top=@bazel_tools//tools/cpp:toolchain --fat_apk_cpu=armeabi-v7a mediapipe/examples/android/src/java/com/google/mediapipe/apps/build_aar/hand_tracking:mediapipe_hand_tracking
#build binary_graph
#bazel build -c opt mediapipe/graphs/hand_tracking:hand_tracking_mobile_gpu_binary_graph
