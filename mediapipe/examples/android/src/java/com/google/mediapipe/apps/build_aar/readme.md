# 1. Generate aar
`bazel build -c opt --host_crosstool_top=@bazel_tools//tools/cpp:toolchain --fat_apk_cpu=arm64-v8a,armeabi-v7a mediapipe/examples/android/src/java/com/google/mediapipe/apps/build_aar/face_detection:mediapipe_face_detection`
# 2. Generate binarypb
`bazel build -c opt mediapipe/graphs/face_detection:mobile_gpu_binary_graph`
# 3. Copy resources files
`cp bazel-bin/mediapipe/graphs/face_detection/mobile_gpu.binarypb /path/to/your/app/src/main/assets/`
`cp mediapipe/models/face_detection_front.tflite /path/to/your/app/src/main/assets/`
`cp mediapipe/models/face_detection_front_labelmap.txt /path/to/your/app/src/main/assets/`
# 4. Copy OpenCV JNI libraries into app/src/main/jniLibs
`cp -R /OpenCV-android-sdk/sdk/native/libs/arm* /path/to/your/app/src/main/jniLibs/`
# 5. Modify app/build.gradle to add MediaPipe dependencies and MediaPipe AAR.
`implementation fileTree(dir: 'libs', include: ['*.jar', '*.aar'])`
# 6. Clean project
`bazel clean --expunge`

bazel build -c opt --fat_apk_cpu=arm64-v8a,armeabi-v7a mediapipe/examples/android/src/java/com/google/mediapipe/apps/build_aar/face_mesh:mediapipe_face_mesh

bazel build -c opt mediapipe/graphs/face_mesh:face_mesh_mobile_gpu_binary_graph
