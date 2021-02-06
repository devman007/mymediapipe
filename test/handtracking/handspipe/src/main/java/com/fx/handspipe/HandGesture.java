package com.fx.handspipe;

import android.app.Activity;
import android.content.Context;
import android.graphics.SurfaceTexture;
import android.util.Log;
import android.util.Size;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;

import androidx.annotation.NonNull;

import com.google.mediapipe.components.CameraHelper;
import com.google.mediapipe.components.CameraXPreviewHelper;
import com.google.mediapipe.components.ExternalTextureConverter;
import com.google.mediapipe.components.FrameProcessor;
import com.google.mediapipe.components.PermissionHelper;
import com.google.mediapipe.formats.proto.LandmarkProto;
import com.google.mediapipe.framework.AndroidAssetUtil;
import com.google.mediapipe.framework.AndroidPacketCreator;
import com.google.mediapipe.framework.Packet;
import com.google.mediapipe.framework.PacketGetter;
import com.google.mediapipe.glutil.EglManager;
import com.google.protobuf.InvalidProtocolBufferException;

import java.util.HashMap;
import java.util.Map;
import java.util.List;

import static com.fx.handspipe.IHandGestureState.HAND_FINGER1;
import static com.fx.handspipe.IHandGestureState.HAND_FINGER2;
import static com.fx.handspipe.IHandGestureState.HAND_FINGER3;
import static com.fx.handspipe.IHandGestureState.HAND_FINGER4;
import static com.fx.handspipe.IHandGestureState.HAND_FINGER5;
import static com.fx.handspipe.IHandGestureState.HAND_FINGER6;
import static com.fx.handspipe.IHandGestureState.HAND_FIST;
import static com.fx.handspipe.IHandGestureState.HAND_INDEX;
import static com.fx.handspipe.IHandGestureState.HAND_MIDDLE;
import static com.fx.handspipe.IHandGestureState.HAND_OK;
import static com.fx.handspipe.IHandGestureState.HAND_PINKY;
import static com.fx.handspipe.IHandGestureState.HAND_RING;
import static com.fx.handspipe.IHandGestureState.HAND_SPIDERMAN;
import static com.fx.handspipe.IHandGestureState.HAND_UNKNOWN;
import static com.fx.handspipe.IHandGestureState.HAND_WONDERFUL;
import static com.fx.handspipe.IHandGestureState.HAND_YEAH;

/**
 * class:   HandGesture
 * by:      Jacky
 * created: 2020-11-26
 */
public class HandGesture {
    private static final String TAG = "HandGesture";

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
    // Max number of hands to detect/process.
    private static final int NUM_HANDS = 4;
    private static final String INPUT_NUM_HANDS_SIDE_PACKET_NAME = "num_hands";
    private static final String OUTPUT_HAND_PRESENCE_STREAM_NAME = "hand_presence";
    private static final String OUTPUT_LANDMARKS_STREAM_NAME = "hand_landmarks";
    private static final String OUTPUT_HAND_RECT_NAME = "hand_rect";

    //
    // camera
    //
    // Flips the camera-preview frames vertically before sending them into FrameProcessor to be
    // processed in a MediaPipe graph, and flips the processed frames back when they are displayed.
    // This is needed because OpenGL represents images assuming the image origin is at the bottom-left
    // corner, whereas MediaPipe in general assumes the image origin is at top-left.
    private static final boolean FLIP_FRAMES_VERTICALLY = true;
    private static final boolean USE_FRONT_CAMERA = true;

    private LandmarkProto.NormalizedLandmarkList multiHandLandmarks;

    private static IHandGestureState handGestureState = null;

    private static Context context = null;
    private boolean handPresence;
    private static final int TICKTOTALNUMBER = 10;
    private static final int TICKTHRESHOLDNUMBER = 6;
    private static int tickNumber = 0;
    private static int NumberFinger1 = 0;
    private static int NumberFinger2 = 0;
    private static int NumberFinger3 = 0;
    private static int NumberFinger4 = 0;
    private static int NumberFinger5 = 0;
    private static int NumberFinger6 = 0;
    private static int NumberFingerFist = 0;
    private static int NumberFingerOK = 0;
    private static int NumberFingerYeah = 0;
    private static int NumberFingerWonderful = 0;
    private static int NumberFingerSpiderMan = 0;
    private static int NumberFingerUnknown = 0;

    public HandGesture() {
    }

    public HandGesture(Context cont) {
        context = cont;
        initialize();
    }

    public void setHandGestureStateListener(IHandGestureState stateListener) {
        handGestureState = stateListener;
    }

    private void initialize() {
        previewDisplayView = new SurfaceView(context);

        // Initialize asset manager so that MediaPipe native libraries can access the app assets, e.g.,
        // binary graphs.
        AndroidAssetUtil.initializeNativeAssetManager(context);

        eglManager = new EglManager(null);
        processor = new FrameProcessor(context,
                                    eglManager.getNativeContext(),
                                    BINARY_GRAPH_NAME,
                                    INPUT_VIDEO_STREAM_NAME,
                                    OUTPUT_VIDEO_STREAM_NAME);

        processor.getVideoSurfaceOutput().setFlipY(FLIP_FRAMES_VERTICALLY);

        PermissionHelper.checkAndRequestCameraPermissions((Activity) context);
//        // 获取是否检测到手模型输出
//        processor.addPacketCallback(
//                OUTPUT_HAND_PRESENCE_STREAM_NAME,
//                (packet) -> {
//                    handPresence = PacketGetter.getBool(packet);
//                    if (!handPresence) {
//                        Log.d(TAG, "[TS:" + packet.getTimestamp() + "] Hand presence is false, no hands detected.");
//                    }
//                });
        AndroidPacketCreator packetCreator = processor.getPacketCreator();
        Map<String, Packet> inputSidePackets = new HashMap<>();
        inputSidePackets.put(INPUT_NUM_HANDS_SIDE_PACKET_NAME, packetCreator.createInt32(NUM_HANDS));
        processor.setInputSidePackets(inputSidePackets);

        // 获取手的关键点模型输出
        processor.addPacketCallback(
                OUTPUT_LANDMARKS_STREAM_NAME,
                (packet) -> {
//                    byte[] landmarksRaw = PacketGetter.getProtoBytes(packet);
                    try {
//                        LandmarkProto.NormalizedLandmarkList landmarks = LandmarkProto.NormalizedLandmarkList.parseFrom(landmarksRaw);
                        List<LandmarkProto.NormalizedLandmarkList> landmarks = PacketGetter.getProtoVector(packet, LandmarkProto.NormalizedLandmarkList.parser());
//                        multiHandLandmarks = landmarks;
//                        if (landmarks == null || !handPresence) {
//                            Log.d(TAG, "[TS:" + packet.getTimestamp() + "] No hand landmarks.");
//                            return;
//                        }
//                        // 如果没有检测到手，输出的关键点是无效的
//                        Log.d(TAG, "[TS:" + packet.getTimestamp() + "] #Landmarks for hand: " + landmarks.getLandmarkCount());
                        handGestureCalculator(landmarks);
                    } catch (Exception e) {
                        Log.e(TAG, "Couldn't Exception received - " + e);
                    }
                });

//        // 获取手的移动轨迹
//        processor.addPacketCallback(
//                OUTPUT_HAND_RECT_NAME,
//                (packet) -> {
////                    List<RectProto.NormalizedRect> normalizedRectsList = PacketGetter.getProtoVector(packet, RectProto.NormalizedRect.parser());
////                    try {
////                        runOnUiThread(new Runnable() {
////                            @Override
////                            public void run() {
////                                gesturemovement.setText(handGestureMoveCalculator(normalizedRectsList));
////                            }
////                        });
////                    } catch (Exception e) {
////                        e.printStackTrace();
////                    }
//                });

        converter = new ExternalTextureConverter(eglManager.getContext());
        converter.setFlipY(FLIP_FRAMES_VERTICALLY);
        converter.setConsumer(processor);

        previewDisplayView.setVisibility(View.GONE);
        previewDisplayView.getHolder().addCallback(new SurfaceHolder.Callback() {
            @Override
            public void surfaceCreated(@NonNull SurfaceHolder holder) {
                processor.getVideoSurfaceOutput().setSurface(holder.getSurface());
            }

            @Override
            public void surfaceChanged(@NonNull SurfaceHolder holder, int format, int width, int height) {
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

            @Override
            public void surfaceDestroyed(@NonNull SurfaceHolder holder) {
                processor.getVideoSurfaceOutput().setSurface(null);
            }
        });
    }

    public SurfaceView getSurfaceView() {
        return previewDisplayView;
    }

    protected Size computeViewSize(int width, int height) {
        return new Size(width, height);
    }

    public void startCamera() {
        if (PermissionHelper.cameraPermissionsGranted((Activity) context)) {
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
            cameraHelper.startCamera((Activity) context, cameraFacing, /*surfaceTexture=*/ null, cameraTargetResolution());
        }
    }

    public void closeCamera() {
        converter.close();
    }

    // 设置相机大小
    protected Size cameraTargetResolution() {
        return null;
    }

    public boolean IsThumbConnectFinger_1(LandmarkProto.NormalizedLandmark point1, LandmarkProto.NormalizedLandmark point2) {
        double distance = getDistance(point1.getX(), point1.getY(), point2.getX(), point2.getY());
        return distance < 0.1;
    }

//    //手势landmark节点索引
//      拇指 食指  中指  无名指  小指
//      4     8    12   16     20   小
//      3     7    11   15     19
//      2     6    10   14     18
//      1     5    9    13     17   大
//            0
    private String handGestureCalculator(List<LandmarkProto.NormalizedLandmarkList> multiHandLandmarks) {
        boolean IsThumb = false;
        boolean IsFinger_1 = false;
        boolean IsFinger_2 = false;
        boolean IsFinger_3 = false;
        boolean IsFinger_4 = false;

        int state = HAND_UNKNOWN;
        String handTxt = "";
//        for (int i = 0; i < multiHandLandmarks.getLandmarkCount(); i++) {
        LandmarkProto.NormalizedLandmarkList landmarkLists = multiHandLandmarks.get(0);
        List<LandmarkProto.NormalizedLandmark> landmarkList = landmarkLists.getLandmarkList();
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

        if (IsThumb && IsFinger_1 && IsFinger_2 && IsFinger_3 && IsFinger_4) {
            state = HAND_FINGER5;
            handTxt = "Five";
            NumberFinger5++;
        } else if (IsThumb && !IsFinger_1 && !IsFinger_2 && !IsFinger_3 && IsFinger_4) {
            state = HAND_FINGER6;
            handTxt = "Six";
            NumberFinger6++;
        } else if (!IsThumb && IsFinger_1 && IsFinger_2 && IsFinger_3 && IsFinger_4) {
            state = HAND_FINGER4;
            handTxt = "Four";
            NumberFinger4++;
        } else if (IsThumb && IsFinger_1 && IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
            state = HAND_FINGER3;
            handTxt = "Three";
            NumberFinger3++;
        } else if (IsThumb && IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
            state = HAND_FINGER2;
            handTxt = "Two";
            NumberFinger2++;
        } else if ((!IsThumb && IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) ||
                   (!IsThumb && !IsFinger_1 && IsFinger_2 && !IsFinger_3 && !IsFinger_4) ||
                   (!IsThumb && !IsFinger_1 && !IsFinger_2 && IsFinger_3 && !IsFinger_4) ||
                   (!IsThumb && !IsFinger_1 && !IsFinger_2 && !IsFinger_3 && IsFinger_4)) {
            state = HAND_FINGER1;
            handTxt = "One";
            NumberFinger1++;
        } else if (!IsThumb && IsFinger_1 && IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
            state = HAND_YEAH;
            handTxt = "Yeah";
            NumberFingerYeah++;
        } else if (!IsThumb && !IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
            state = HAND_FIST;
            handTxt = "Fist";
            NumberFingerFist++;
        } else if (IsThumb && !IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
            state = HAND_WONDERFUL;
            handTxt = "Wonderful";
            NumberFingerWonderful++;
        } else if (IsThumb && IsFinger_1 && !IsFinger_2 && !IsFinger_3 && IsFinger_4) {
            state = HAND_SPIDERMAN;
            handTxt = "SpiderMan";
            NumberFingerSpiderMan++;
        } else if (!IsFinger_1 && IsFinger_2 && IsFinger_3 && IsFinger_4 && IsThumbConnectFinger_1(landmarkList.get(4), landmarkList.get(8))) {
            state = HAND_OK;
            handTxt = "OK";
            NumberFingerOK++;
        } else {
            state = HAND_UNKNOWN;
            handTxt = "";
            NumberFingerUnknown++;
        }

        tickNumber++;
        if(tickNumber >= TICKTOTALNUMBER) {
            if(NumberFinger1 >= TICKTHRESHOLDNUMBER) {
                handGestureState.onGestureStateListener(HAND_FINGER1, "One");
            } else if(NumberFinger2 >= TICKTHRESHOLDNUMBER) {
                handGestureState.onGestureStateListener(HAND_FINGER2, "Two");
            } else if(NumberFinger3 >= TICKTHRESHOLDNUMBER) {
                handGestureState.onGestureStateListener(HAND_FINGER3, "Three");
            } else if(NumberFinger4 >= TICKTHRESHOLDNUMBER) {
                handGestureState.onGestureStateListener(HAND_FINGER4, "Four");
            } else if(NumberFinger5 >= TICKTHRESHOLDNUMBER) {
                handGestureState.onGestureStateListener(HAND_FINGER5, "Five");
            } else if(NumberFinger6 >= TICKTHRESHOLDNUMBER) {
                handGestureState.onGestureStateListener(HAND_FINGER6, "Six");
            } else if(NumberFingerFist >= TICKTHRESHOLDNUMBER) {
                handGestureState.onGestureStateListener(HAND_FIST, "Fist");
            } else if(NumberFingerOK >= TICKTHRESHOLDNUMBER) {
                handGestureState.onGestureStateListener(HAND_OK, "OK");
            } else if(NumberFingerYeah >= TICKTHRESHOLDNUMBER) {
                handGestureState.onGestureStateListener(HAND_YEAH, "Yeah");
            } else if(NumberFingerWonderful >= TICKTHRESHOLDNUMBER) {
                handGestureState.onGestureStateListener(HAND_WONDERFUL, "Wonderful");
            } else if(NumberFingerSpiderMan >= TICKTHRESHOLDNUMBER) {
                handGestureState.onGestureStateListener(HAND_SPIDERMAN, "SpiderMan");
            } else {
                handGestureState.onGestureStateListener(HAND_UNKNOWN, "");
            }
            tickNumber = 0;
            NumberFinger1 = 0;
            NumberFinger2 = 0;
            NumberFinger3 = 0;
            NumberFinger4 = 0;
            NumberFinger5 = 0;
            NumberFinger6 = 0;
            NumberFingerFist = 0;
            NumberFingerOK = 0;
            NumberFingerYeah = 0;
            NumberFingerWonderful = 0;
            NumberFingerSpiderMan = 0;
            NumberFingerUnknown = 0;
        }
        return "";
    }

//    public boolean IsThumbConnectFinger_1(LandmarkProto.NormalizedLandmark point1, LandmarkProto.NormalizedLandmark point2) {
//        double distance = getDistance(point1.getX(), point1.getY(), point2.getX(), point2.getY());
//        return distance < 0.1;
//    }

    public static double getDistance(double a_x, double a_y, double b_x, double b_y) {
        double dist = Math.pow(a_x - b_x, 2) + Math.pow(a_y - b_y, 2);
        return Math.sqrt(dist);
    }

    public static double getAngle(double a_x, double a_y, double b_x, double b_y, double c_x, double c_y) {
        double ab_x = b_x - a_x;
        double ab_y = b_y - a_y;
        double cb_x = b_x - c_x;
        double cb_y = b_y - c_y;

        double dot = (ab_x * cb_x + ab_y * cb_y);
        double cross = (ab_x * cb_y - ab_y * cb_x);

        return Math.atan2(cross, dot);
    }

    public static int getDegree(double radian) {
        return (int) Math.floor(radian * 180. / Math.PI + 0.5);
    }
}
