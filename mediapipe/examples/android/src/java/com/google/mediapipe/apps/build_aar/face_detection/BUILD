load("//mediapipe/java/com/google/mediapipe:mediapipe_aar.bzl", "mediapipe_aar")

mediapipe_aar(
    name = "mediapipe_face_detection",
    calculators = ["//mediapipe/graphs/face_detection:mobile_calculators"],
)

#1.generate aar
#bazel build -c opt --host_crosstool_top=@bazel_tools//tools/cpp:toolchain --fat_apk_cpu=arm64-v8a,armeabi-v7a mediapipe/examples/android/src/java/com/google/mediapipe/apps/build_aar/face_detection:mediapipe_face_detection
#2. generate binarypb
#bazel build -c opt mediapipe/mediapipe/graphs/face_detection:mobile_gpu_binary_graph
#3. copy resources files
#cp bazel-bin/mediapipe/graphs/face_detection/mobile_gpu.binarypb /path/to/your/app/src/main/assets/
#cp mediapipe/models/face_detection_front.tflite /path/to/your/app/src/main/assets/
#cp mediapipe/models/face_detection_front_labelmap.txt /path/to/your/app/src/main/assets/
#4. copy OpenCV JNI libraries into app/src/main/jniLibs
#cp -R /OpenCV-android-sdk/sdk/native/libs/arm* /path/to/your/app/src/main/jniLibs/
#5. Modify app/build.gradle to add MediaPipe dependencies and MediaPipe AAR.
#implementation fileTree(dir: 'libs', include: ['*.jar', '*.aar'])
