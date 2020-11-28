package com.example.handtracking;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import android.content.pm.ApplicationInfo;
import android.graphics.Color;
import android.graphics.SurfaceTexture;
import android.os.Bundle;
import android.util.Log;
import android.util.Size;
import android.view.GestureDetector;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.widget.RelativeLayout;
import android.widget.TextView;

import com.fx.handspipe.HandGesture;
import com.google.mediapipe.components.CameraHelper;
import com.google.mediapipe.components.CameraXPreviewHelper;
import com.google.mediapipe.components.ExternalTextureConverter;
import com.google.mediapipe.components.FrameProcessor;
import com.google.mediapipe.components.PermissionHelper;
import com.google.mediapipe.formats.proto.LandmarkProto;
import com.google.mediapipe.framework.AndroidAssetUtil;
import com.google.mediapipe.framework.Packet;
import com.google.mediapipe.framework.PacketCallback;
import com.google.mediapipe.framework.PacketGetter;
import com.google.mediapipe.glutil.EglManager;
import com.google.protobuf.InvalidProtocolBufferException;

import java.io.IOException;
import java.util.List;

import static com.fx.handspipe.HandGesture.getAngle;
import static com.fx.handspipe.HandGesture.getDegree;
import static com.fx.handspipe.HandGesture.getDistance;

public class MainActivity extends AppCompatActivity {
    private static final String TAG = "MainActivity";

    //
    // 加载动态库
    //
    static {
        System.loadLibrary("mediapipe_jni");
        try {
            System.loadLibrary("opencv_java3");
        } catch (Exception e) {
            System.loadLibrary("opencv_java4");
        }
    }

    //
    //  basic modules.
    //
    // Sends camera-preview frames into a MediaPipe graph for processing, and displays the processed
    // frames onto a {@link Surface}.
    protected FrameProcessor processor;
    // Handles camera access via the {@link CameraX} Jetpack support library.
    protected CameraXPreviewHelper cameraHelper;

    // {@link SurfaceTexture} where the camera-preview frames can be accessed.
    private SurfaceTexture previewFrameTexture;
    // {@link SurfaceView} that displays the camera-preview frames processed by a MediaPipe graph.
    private SurfaceView previewDisplayView;

    // Creates and manages an {@link EGLContext}.
    private EglManager eglManager;
    // Converts the GL_TEXTURE_EXTERNAL_OES texture from Android camera into a regular texture to be
    // consumed by {@link FrameProcessor} and the underlying MediaPipe graph.
    private ExternalTextureConverter converter;

    //
    // hand tracking
    //
    private static final String BINARY_GRAPH_NAME = "hand_tracking_mobile_gpu.binarypb";
    private static final String INPUT_VIDEO_STREAM_NAME = "input_video";
    private static final String OUTPUT_VIDEO_STREAM_NAME = "output_video";

    //
    // hand tracking
    //
    private static final String OUTPUT_HAND_PRESENCE_STREAM_NAME = "hand_presence";
    private static final String OUTPUT_LANDMARKS_STREAM_NAME = "hand_landmarks";
    private static final String OUTPUT_HAND_RECT_NAME = "hand_rect";

    private boolean handPresence;
    private TextView gestureview;
    private TextView gesturemovement;
    private LandmarkProto.NormalizedLandmarkList multiHandLandmarks;

    //
    // camera
    //
    // Flips the camera-preview frames vertically before sending them into FrameProcessor to be
    // processed in a MediaPipe graph, and flips the processed frames back when they are displayed.
    // This is needed because OpenGL represents images assuming the image origin is at the bottom-left
    // corner, whereas MediaPipe in general assumes the image origin is at top-left.
    private static final boolean FLIP_FRAMES_VERTICALLY = true;
    private static final boolean USE_FRONT_CAMERA = true;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        gestureview = (TextView) findViewById(R.id.handgesture);
        previewDisplayView = new SurfaceView(this);
        setupPreviewDisplayView();

        PermissionHelper.checkAndRequestCameraPermissions(this);
        // Initialize asset manager so that MediaPipe native libraries can access the app assets, e.g.,
        // binary graphs.
        AndroidAssetUtil.initializeNativeAssetManager(this);

        eglManager = new EglManager(null);
        processor = new FrameProcessor(this,
                                        eglManager.getNativeContext(),
                                        BINARY_GRAPH_NAME,
                                        INPUT_VIDEO_STREAM_NAME,
                                        OUTPUT_VIDEO_STREAM_NAME);
        processor.getVideoSurfaceOutput().setFlipY(FLIP_FRAMES_VERTICALLY);

        // 获取是否检测到手模型输出
        processor.addPacketCallback(
                OUTPUT_HAND_PRESENCE_STREAM_NAME,
                (packet) -> {
                    handPresence = PacketGetter.getBool(packet);
                    if (!handPresence) {
                        Log.d(TAG, "[TS:" + packet.getTimestamp() + "] Hand presence is false, no hands detected.");
                    }
                });

        // 获取手的关键点模型输出
        processor.addPacketCallback(
                OUTPUT_LANDMARKS_STREAM_NAME,
                (packet) -> {
                    byte[] landmarksRaw = PacketGetter.getProtoBytes(packet);
                    try {
                        LandmarkProto.NormalizedLandmarkList landmarks = LandmarkProto.NormalizedLandmarkList.parseFrom(landmarksRaw);
                        multiHandLandmarks = landmarks;
                        if (landmarks == null || !handPresence) {
                            Log.d(TAG, "[TS:" + packet.getTimestamp() + "] No hand landmarks.");
                            return;
                        }
                        // 如果没有检测到手，输出的关键点是无效的
                        Log.d(TAG, "[TS:" + packet.getTimestamp() + "] #Landmarks for hand: " + landmarks.getLandmarkCount());
//                        Log.d(TAG, getLandmarksDebugString(landmarks));
                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                gestureview.setText(handGestureCalculator(landmarks));
                            }
                        });
                    } catch (InvalidProtocolBufferException e) {
                        Log.e(TAG, "Couldn't Exception received - " + e);
                    }
                });

        // 获取手的移动轨迹
        processor.addPacketCallback(
                OUTPUT_HAND_RECT_NAME,
                (packet) -> {
//                    List<RectProto.NormalizedRect> normalizedRectsList = PacketGetter.getProtoVector(packet, RectProto.NormalizedRect.parser());
//                    try {
//                        runOnUiThread(new Runnable() {
//                            @Override
//                            public void run() {
//                                gesturemovement.setText(handGestureMoveCalculator(normalizedRectsList));
//                            }
//                        });
//                    } catch (Exception e) {
//                        e.printStackTrace();
//                    }
                });
    }

    @Override
    protected void onResume() {
        super.onResume();
        converter = new ExternalTextureConverter(eglManager.getContext());
        converter.setFlipY(FLIP_FRAMES_VERTICALLY);
        converter.setConsumer(processor);
        if (PermissionHelper.cameraPermissionsGranted(this)) {
            startCamera();
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        converter.close();
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        PermissionHelper.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        return super.onTouchEvent(event);

    }

    protected Size computeViewSize(int width, int height) {
        return new Size(width, height);
    }

    protected void onPreviewDisplaySurfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        // (Re-)Compute the ideal size of the camera-preview display (the area that the
        // camera-preview frames get rendered onto, potentially with scaling and rotation)
        // based on the size of the SurfaceView that contains the display.
        Size viewSize = computeViewSize(width, height);
        Size displaySize = cameraHelper.computeDisplaySizeFromViewSize(viewSize);

        // Connect the converter to the camera-preview frames as its input (via
        // previewFrameTexture), and configure the output width and height as the computed
        // display size.
		boolean isCameraRotated = cameraHelper.isCameraRotated();
        converter.setSurfaceTextureAndAttachToGLContext(
                                previewFrameTexture,
                                isCameraRotated ? displaySize.getHeight() : displaySize.getWidth(),
                                isCameraRotated ? displaySize.getWidth() : displaySize.getHeight());
    }

    private void setupPreviewDisplayView() {
        previewDisplayView.setVisibility(View.GONE);
        ViewGroup viewGroup = findViewById(R.id.preview_display_layout);
        viewGroup.addView(previewDisplayView);

        previewDisplayView.getHolder().addCallback(new SurfaceHolder.Callback() {
            @Override
            public void surfaceCreated(@NonNull SurfaceHolder holder) {
                processor.getVideoSurfaceOutput().setSurface(holder.getSurface());
            }

            @Override
            public void surfaceChanged(@NonNull SurfaceHolder holder, int format, int width, int height) {
                onPreviewDisplaySurfaceChanged(holder, format, width, height);
            }

            @Override
            public void surfaceDestroyed(@NonNull SurfaceHolder holder) {
                processor.getVideoSurfaceOutput().setSurface(null);
            }
        });
    }
	
    private void startCamera() {
        cameraHelper = new CameraXPreviewHelper();
        cameraHelper.setOnCameraStartedListener(
                surfaceTexture -> {
                    previewFrameTexture = surfaceTexture;
                    // Make the display view visible to start showing the preview. This triggers the
                    // SurfaceHolder.Callback added to (the holder of) previewDisplayView.
                    previewDisplayView.setVisibility(View.VISIBLE);
                });
        CameraHelper.CameraFacing cameraFacing =
                USE_FRONT_CAMERA ? CameraHelper.CameraFacing.FRONT : CameraHelper.CameraFacing.BACK;
        cameraHelper.startCamera(this, cameraFacing, /*surfaceTexture=*/ null, cameraTargetResolution());
    }

    // 设置相机大小
    protected Size cameraTargetResolution() {
        return null;
    }

    // 解析关键点
    private static String getLandmarksDebugString(LandmarkProto.NormalizedLandmarkList landmarks) {
        int landmarkIndex = 0;
        String landmarksString = "";
        float total_z = 0f;
        float avg_z = 0f;
        for (LandmarkProto.NormalizedLandmark landmark : landmarks.getLandmarkList()) {
                landmarksString += "\t\tLandmark["
                                + landmarkIndex + "]: ("
                                + landmark.getX() + ", "
                                + landmark.getY() + ", "
                                + landmark.getZ() + ")\n";
            total_z += landmark.getZ();
            ++landmarkIndex;
        }
        avg_z = total_z / landmarks.getLandmarkCount();
        Log.i(TAG, "getLandmarksDebugString: count = "+landmarks.getLandmarkCount()+", total_z = "+total_z+", avg_z = "+avg_z);
        //分析得出，全部landmark 21个取其中的12个为，0~3，5，6，9，10，13，14，17，18
        return landmarksString.toString();
    }

    public boolean IsThumbConnectFinger_1(LandmarkProto.NormalizedLandmark point1, LandmarkProto.NormalizedLandmark point2) {
        double distance = getDistance(point1.getX(), point1.getY(), point2.getX(), point2.getY());
        return distance < 0.1;
    }

//    //手势landmark节点索引
//      拇指 食指  中指  无名指  小指
//      1     5    9    13     17
//      2     6    10   14     18
//      3     7    11   15     19
//      4     8    12   16     20
//            0
    private String handGestureCalculator(LandmarkProto.NormalizedLandmarkList multiHandLandmarks) {
        boolean IsThumb = false;
        boolean IsFinger_1 = false;
        boolean IsFinger_2 = false;
        boolean IsFinger_3 = false;
        boolean IsFinger_4 = false;

        for (int i = 0; i < multiHandLandmarks.getLandmarkCount(); i++) {
            List<LandmarkProto.NormalizedLandmark> landmarkList = multiHandLandmarks.getLandmarkList();
            if (landmarkList.get(2).getX() < landmarkList.get(9).getX()) {
                if (landmarkList.get(3).getX() < landmarkList.get(2).getX() && landmarkList.get(4).getX() < landmarkList.get(2).getX()) {
                    IsThumb = true;
                }
            }
            if (landmarkList.get(2).getX() > landmarkList.get(9).getX()) {
                if (landmarkList.get(3).getX() > landmarkList.get(2).getX() && landmarkList.get(4).getX() > landmarkList.get(2).getX()) {
                    IsThumb = true;
                }
            }

            if (landmarkList.get(7).getY() < landmarkList.get(6).getY() && landmarkList.get(7).getY() > landmarkList.get(8).getY()) {
                IsFinger_1 = true;
            }
            if (landmarkList.get(11).getY() < landmarkList.get(10).getY() && landmarkList.get(11).getY() > landmarkList.get(12).getY()) {
                IsFinger_2 = true;
            }
            if (landmarkList.get(15).getY() < landmarkList.get(14).getY() && landmarkList.get(15).getY() > landmarkList.get(16).getY()) {
                IsFinger_3 = true;
            }
            if (landmarkList.get(19).getY() < landmarkList.get(18).getY() && landmarkList.get(19).getY() > landmarkList.get(20).getY()) {
                IsFinger_4 = true;
            }

//            String info = "IsThumb(" + IsThumb +
//                    "), IsFinger_1(" + IsFinger_1 + "), IsFinger_2(" + IsFinger_2 +
//                    "), IsFinger_3(" + IsFinger_3 + "), IsFinger_4(" + IsFinger_4;
//            Log.d(TAG, "handGestureCalculator: = " + info);
            if (IsThumb && IsFinger_1 && IsFinger_2 && IsFinger_3 && IsFinger_4) {
                return "Five";
            } else if (!IsThumb && IsFinger_1 && IsFinger_2 && IsFinger_3 && IsFinger_4) {
                return "Four";
            } else if (IsThumb && IsFinger_1 && IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
                return "Three";
            } else if (IsThumb && IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
                return "Two";
            } else if (!IsThumb && IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
                return "One";
            } else if (!IsThumb && IsFinger_1 && IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
                return "Yeah";
            } else if (!IsThumb && !IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
                return "Fist";
            } else if (IsThumb && !IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
                return "Wonderful";
//            } else if (IsThumb && IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
//                return "Love Heart";
            } else if (!IsFinger_1 && IsFinger_2 && IsFinger_3 && IsFinger_4 && IsThumbConnectFinger_1(landmarkList.get(4), landmarkList.get(8))) {
                return "OK";
            } else {
                return "";
            }
        }
        return "";
    }

//    float previousXCenter;
//    float previousYCenter;
//    float previousAngle; // angle between the hand and the x-axis. in radian
//    float previous_rectangle_width;
//    float previousRectangleHeight;
//    boolean frameCounter;
//    private String handGestureMoveCalculator(List<RectProto.NormalizedRect> normalizedRectList, LandmarkProto.NormalizedLandmarkList multiHandLandmarks) {
//        RectProto.NormalizedRect normalizedRect = normalizedRectList.get(0);
//        float height = normalizedRect.getHeight();
//        float centerX = normalizedRect.getXCenter();
//        float centerY = normalizedRect.getYCenter();
//        if (previousXCenter != 0) {
//            double mouvementDistance = getDistance(centerX, centerY,
//                    previousXCenter, previousYCenter);
//            // LOG(INFO) << "Distance: " << mouvementDistance;
//
//            double mouvementDistanceFactor = 0.02; // only large mouvements will be recognized.
//
//            // the height is normed [0.0, 1.0] to the camera window height.
//            // so the mouvement (when the hand is near the camera) should be equivalent to the mouvement when the hand is far.
//            double mouvementDistanceThreshold = mouvementDistanceFactor * height;
//            if (mouvementDistance > mouvementDistanceThreshold) {
//                double angle = getDegree(getAngle(centerX, centerY,
//                        previousXCenter, previousYCenter, previousXCenter + 0.1,
//                        previousYCenter));
//                // LOG(INFO) << "Angle: " << angle;
//                if (angle >= -45 && angle < 45) {
//                    return "Scrolling right";
//                } else if (angle >= 45 && angle < 135) {
//                    return "Scrolling up";
//                } else if (angle >= 135 || angle < -135) {
//                    return "Scrolling left";
//                } else if (angle >= -135 && angle < -45) {
//                    return "Scrolling down";
//                }
//            }
//        }
//
//        previousXCenter = centerX;
//        previousYCenter = centerY;
//        // 2. FEATURE - Zoom in/out
//        if (previousRectangleHeight != 0) {
//            double heightDifferenceFactor = 0.03;
//
//            // the height is normed [0.0, 1.0] to the camera window height.
//            // so the mouvement (when the hand is near the camera) should be equivalent to the mouvement when the hand is far.
//            double heightDifferenceThreshold = height * heightDifferenceFactor;
//            if (height < previousRectangleHeight - heightDifferenceThreshold) {
//                return "Zoom out";
//            } else if (height > previousRectangleHeight + heightDifferenceThreshold) {
//                return "Zoom in";
//            }
//        }
//        previousRectangleHeight = height;
//        // each odd Frame is skipped. For a better result.
//        frameCounter = !frameCounter;
//        if (frameCounter && multiHandLandmarks != null) {
//            for (int i = 0; i < multiHandLandmarks.getLandmarkCount(); i++) {
////                List<LandmarkProto.NormalizedLandmark> landmarkList = landmarks.getLandmarkList();
//                LandmarkProto.NormalizedLandmark wrist = multiHandLandmarks.getLandmark(0);
//                LandmarkProto.NormalizedLandmark MCP_of_second_finger = multiHandLandmarks.getLandmark(9);
//
//                // angle between the hand (wirst and MCP) and the x-axis.
//                double ang_in_radian =
//                        getAngle(MCP_of_second_finger.getX(), MCP_of_second_finger.getY(),
//                                wrist.getX(), wrist.getY(), wrist.getX() + 0.1, wrist.getY());
//                int ang_in_degree = getDegree(ang_in_radian);
//                // LOG(INFO) << "Angle: " << ang_in_degree;
//                if (previousAngle != 0) {
//                    double angleDifferenceTreshold = 12;
//                    if (previousAngle >= 80 && previousAngle <= 100) {
//                        if (ang_in_degree > previousAngle + angleDifferenceTreshold) {
//                            return "Slide left";
//
//                        } else if (ang_in_degree < previousAngle - angleDifferenceTreshold) {
//                            return "Slide right";
//                        }
//                    }
//                }
//                previousAngle = ang_in_degree;
//            }
//        }
//        return "";
//    }
}
