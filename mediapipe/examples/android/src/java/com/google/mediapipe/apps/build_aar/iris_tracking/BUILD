load("//mediapipe/java/com/google/mediapipe:mediapipe_aar.bzl", "mediapipe_aar")

mediapipe_aar(
    name = "mediapipe_iris_tracking",
    calculators = ["//mediapipe/graphs/iris_tracking:iris_tracking_gpu_deps"],
)

#export ANDROID_HOME=/Users/yuechuanzhen/Library/Android/sdk/
#export ANDROID_NDK_HOME=/Users/yuechuanzhen/Library/Android/sdk/ndk-bundle
#1.generate aar
#GLOG_logtostderr=1 bazel build -c opt --host_crosstool_top=@bazel_tools//tools/cpp:toolchain --fat_apk_cpu=armeabi-v7a mediapipe/examples/android/src/java/com/google/mediapipe/apps/build_aar/iris_tracking:mediapipe_iris_tracking
#2. generate binarypb
#bazel build -c opt mediapipe/graphs/iris_tracking:iris_tracking_gpu_binary_graph
#3. copy resources files
#cp bazel-bin/mediapipe/graphs/face_detection/mobile_gpu.binarypb /path/to/your/app/src/main/assets/
#cp mediapipe/models/face_detection_front.tflite /path/to/your/app/src/main/assets/
#cp mediapipe/models/face_detection_front_labelmap.txt /path/to/your/app/src/main/assets/
#4. copy OpenCV JNI libraries into app/src/main/jniLibs
#cp -R /OpenCV-android-sdk/sdk/native/libs/arm* /path/to/your/app/src/main/jniLibs/
#5. Modify app/build.gradle to add MediaPipe dependencies and MediaPipe AAR.
#implementation fileTree(dir: 'libs', include: ['*.jar', '*.aar'])
