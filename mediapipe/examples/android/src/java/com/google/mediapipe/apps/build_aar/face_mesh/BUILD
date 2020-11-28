load("//mediapipe/java/com/google/mediapipe:mediapipe_aar.bzl", "mediapipe_aar")

mediapipe_aar(
    name = "mediapipe_face_mesh",
    calculators = ["//mediapipe/graphs/face_mesh:mobile_calculators"],
)

#bazel clean --expunge
#GLOG_logtostderr=1 bazel build -c opt --host_crosstool_top=@bazel_tools//tools/cpp:toolchain --fat_apk_cpu=armeabi-v7a mediapipe/examples/android/src/java/com/google/mediapipe/apps/build_aar/face_mesh:mediapipe_face_mesh
