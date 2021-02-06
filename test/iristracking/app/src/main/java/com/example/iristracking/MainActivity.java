package com.example.iristracking;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import android.annotation.SuppressLint;
import android.content.pm.ApplicationInfo;
import android.graphics.Color;
import android.graphics.SurfaceTexture;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
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

import com.google.mediapipe.components.CameraHelper;
import com.google.mediapipe.components.CameraXPreviewHelper;
import com.google.mediapipe.components.ExternalTextureConverter;
import com.google.mediapipe.components.FrameProcessor;
import com.google.mediapipe.components.PermissionHelper;
import com.google.mediapipe.formats.proto.LandmarkProto;
import com.google.mediapipe.framework.AndroidAssetUtil;
import com.google.mediapipe.framework.Packet;
import com.google.mediapipe.framework.PacketGetter;
import com.google.mediapipe.glutil.EglManager;
import com.google.protobuf.InvalidProtocolBufferException;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

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
    //  for iris tracking.
    //
    private static final String BINARY_GRAPH_NAME = "iris_tracking_gpu.binarypb";
//    private static final String BINARY_GRAPH_NAME = "hand_tracking_mobile_gpu.binarypb";
    private static final String INPUT_VIDEO_STREAM_NAME = "input_video";
    private static final String OUTPUT_VIDEO_STREAM_NAME = "output_video";
    private static final String LEFT_IRIS_DEPTH_MM = "left_iris_depth_mm";
    private static final String RIGHT_IRIS_DEPTH_MM = "right_iris_depth_mm";

//    //
//    // hand tracking
//    //
//    private static final String OUTPUT_HAND_PRESENCE_STREAM_NAME = "hand_presence";
//    private static final String OUTPUT_LANDMARKS_STREAM_NAME = "hand_landmarks";
//
//    private boolean handPresence;

    //
    // iris tracking
    //
    private static final String FOCAL_LENGTH_STREAM_NAME = "focal_length_pixel";
    private static final String OUTPUT_LANDMARKS_STREAM_NAME = "face_landmarks_with_iris";
    private static float mFocalLength = 0f;

    //
    // camera
    //
    // Flips the camera-preview frames vertically before sending them into FrameProcessor to be
    // processed in a MediaPipe graph, and flips the processed frames back when they are displayed.
    // This is needed because OpenGL represents images assuming the image origin is at the bottom-left
    // corner, whereas MediaPipe in general assumes the image origin is at top-left.
    private static final boolean FLIP_FRAMES_VERTICALLY = true;
    private static final boolean USE_FRONT_CAMERA = true;

    private static TextView ctlshowCapture;

    @SuppressLint("HandlerLeak")
    static Handler textHandle = new Handler() {
        @Override
        public void handleMessage(@NonNull Message msg) {
            super.handleMessage(msg);
            if (msg.what == 1) {
                //update ui
                Bundle bundle = msg.getData();
                String s = bundle.getString("msg");
                ctlshowCapture.setText(s);
            }
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // 用于显示信息的控件
        ctlshowCapture = (TextView)findViewById(R.id.showCapture);
        ctlshowCapture.setTextColor(Color.GREEN);
        ctlshowCapture.setTextSize(25);
        ctlshowCapture.setText("");

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

        // To show verbose logging, run:
        // adb shell setprop log.tag.MainActivity VERBOSE
        //if (Log.isLoggable(TAG, Log.VERBOSE)) {
            processor.addPacketCallback(OUTPUT_LANDMARKS_STREAM_NAME,
                (packet) -> {
                    byte[] landmarksRaw = PacketGetter.getProtoBytes(packet);
                    try {
                        LandmarkProto.NormalizedLandmarkList landmarks = LandmarkProto.NormalizedLandmarkList.parseFrom(landmarksRaw);
                        if (landmarks == null) {
                            Log.v(TAG, "[TS:" + packet.getTimestamp() + "] No landmarks.");
                            return;
                        }
                        Log.v(TAG,"[TS:" + packet.getTimestamp()
                                              + "] #Landmarks for face (including iris): "
                                              + landmarks.getLandmarkCount());
                        Log.v(TAG, getLandmarksDebugString(landmarks));
                    } catch (InvalidProtocolBufferException e) {
                        Log.e(TAG, "Couldn't Exception received - " + e);
                        return;
                    }
                });
//            //尝试获取iris depth，failed
//        processor.addPacketCallback(LEFT_IRIS_DEPTH_MM,
//                (packet)->{
//                    float left_iris_depth = PacketGetter.getFloat32(packet);
//                    Log.v(TAG,"left depth in cm is: " + left_iris_depth/10);
//                    String capText = "左: "+left_iris_depth;
//                    Bundle bundle = new Bundle();
//                    bundle.putString("msg", capText);
//                    Message msg = Message.obtain();
//                    msg.what = 1;
//                    msg.setData(bundle);
//                    textHandle.sendMessageDelayed(msg, 1000);
//                });
        //}
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

                    float focalLength = cameraHelper.getFocalLengthPixels();
                    mFocalLength = focalLength;
                    if (focalLength != Float.MIN_VALUE) {
                        Packet focalLengthSidePacket = processor.getPacketCreator().createFloat32(focalLength);
                        Map<String, Packet> inputSidePackets = new HashMap<>();
                        inputSidePackets.put(FOCAL_LENGTH_STREAM_NAME, focalLengthSidePacket);
                        processor.setInputSidePackets(inputSidePackets);
                    }
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
//        for (LandmarkProto.NormalizedLandmark landmark : landmarks.getLandmarkList()) {
//            landmarksString += "\t\tLandmark["
//                            + landmarkIndex   + "]: ("
//                            + landmark.getX() + ", "
//                            + landmark.getY() + ", "
//                            + landmark.getZ() + ")\n";
//            ++landmarkIndex;
//        }
//        //实例数据
//        Left 0, x(0.302470), y(0.777250), z(0.003873)
//        Left 1, x(0.301649), y(0.758543), z(0.003890)
//        Left 2, x(0.303053), y(0.795565), z(0.003930)
//        Left 3, x(0.282136), y(0.777626), z(0.003890)
//        Left 4, x(0.322129), y(0.776609), z(0.003916)
//        Right 0, x(0.518205), y(0.768968), z(0.011022)
//        Right 1, x(0.517543), y(0.750978), z(0.010942)
//        Right 2, x(0.518891), y(0.786738), z(0.011089)
//        Right 3, x(0.499230), y(0.769548), z(0.011063)
//        Right 4, x(0.537797), y(0.768142), z(0.011016)
//        left_iris_size(41.609215), right_iris_size(40.163750)
//        left_iris_depth(336.245605, 0.000000) - right
//        right_iris_depth(313.534180, 0.000000)
//        focalLength = 1001.7391
//        left_iris_depth = 302.6113            - wrong
//        right_iris_depth = 306.4842
//        focalLength = 1127.229459
//        left_iris_depth = 336.24365
//        right_iris_depth = 342.04236
//
//        LandmarkProto.NormalizedLandmarkList.Builder landmarks_l = LandmarkProto.NormalizedLandmarkList.newBuilder();
//        LandmarkProto.NormalizedLandmark.Builder landmark_l = LandmarkProto.NormalizedLandmark.newBuilder();
//        LandmarkProto.NormalizedLandmarkList.Builder landmarks_r = LandmarkProto.NormalizedLandmarkList.newBuilder();
//        LandmarkProto.NormalizedLandmark.Builder landmark_r = LandmarkProto.NormalizedLandmark.newBuilder();
//        landmark_l.setX((float) 0.302470); landmark_l.setY((float) 0.777250); landmark_l.setZ((float) 0.003873);
//        landmarks_l.addLandmark(0, landmark_l);
//        landmark_l.setX((float) 0.301649); landmark_l.setY((float) 0.758543); landmark_l.setZ((float) 0.003890);
//        landmarks_l.addLandmark(1, landmark_l);
//        landmark_l.setX((float) 0.303053); landmark_l.setY((float) 0.795565); landmark_l.setZ((float) 0.003930);
//        landmarks_l.addLandmark(2, landmark_l);
//        landmark_l.setX((float) 0.282136); landmark_l.setY((float) 0.777626); landmark_l.setZ((float) 0.003890);
//        landmarks_l.addLandmark(3, landmark_l);
//        landmark_l.setX((float) 0.322129); landmark_l.setY((float) 0.776609); landmark_l.setZ((float) 0.003916);
//        landmarks_l.addLandmark(4, landmark_l);
//
//        landmark_r.setX((float) 0.518205); landmark_r.setY((float) 0.768968); landmark_r.setZ((float) 0.011022);
//        landmarks_r.addLandmark(0, landmark_r);
//        landmark_r.setX((float) 0.517543); landmark_r.setY((float) 0.750978); landmark_r.setZ((float) 0.010942);
//        landmarks_r.addLandmark(1, landmark_r);
//        landmark_r.setX((float) 0.518891); landmark_r.setY((float) 0.786738); landmark_r.setZ((float) 0.011089);
//        landmarks_r.addLandmark(2, landmark_r);
//        landmark_r.setX((float) 0.499230); landmark_r.setY((float) 0.769548); landmark_r.setZ((float) 0.011063);
//        landmarks_r.addLandmark(3, landmark_r);
//        landmark_r.setX((float) 0.537797); landmark_r.setY((float) 0.768142); landmark_r.setZ((float) 0.011016);
//        landmarks_r.addLandmark(4, landmark_r);
//
//        float left_iris_size = CalculateIrisDiameter(left_iris.getLandmark(1).getX(), left_iris.getLandmark(1).getY(),
//                                                    left_iris.getLandmark(2).getX(), left_iris.getLandmark(2).getY(),
//                                                    left_iris.getLandmark(3).getX(), left_iris.getLandmark(3).getY(),
//                                                    left_iris.getLandmark(4).getX(), left_iris.getLandmark(4).getY(),
//                                                    size);
//        float right_iris_size = CalculateIrisDiameter(right_iris.getLandmark(1).getX(), right_iris.getLandmark(1).getY(),
//                                                    right_iris.getLandmark(2).getX(), right_iris.getLandmark(2).getY(),
//                                                    right_iris.getLandmark(3).getX(), right_iris.getLandmark(3).getY(),
//                                                    right_iris.getLandmark(4).getX(), right_iris.getLandmark(4).getY(),
//                                                    size);
//        mFocalLength = 1127.229459f;  //calculateFocalLengthInPixels(); //847.67444 3/2 = , 5/3 =

        LandmarkProto.NormalizedLandmarkList left_iris = GetLeftIris(landmarks);    //landmarks_l.build();    //
        LandmarkProto.NormalizedLandmarkList right_iris = GetRightIris(landmarks);   //landmarks_r.build();   //

        Size size = new Size(1080, 1080);
        float left_iris_size = CalculateIrisDiameter(left_iris, size);
        float right_iris_size = CalculateIrisDiameter(right_iris, size);

        float left_iris_depth = CalculateDepth(left_iris.getLandmark(0), mFocalLength, left_iris_size, size.getWidth(), size.getHeight());
        float right_iris_depth = CalculateDepth(right_iris.getLandmark(0), mFocalLength, right_iris_size, size.getWidth(), size.getHeight());
        String capText = "左: "+(int)(left_iris_depth/10)+"\t右: "+(int)(right_iris_depth/10);
        Bundle bundle = new Bundle();
        bundle.putString("msg", capText);
        Message msg = Message.obtain();
        msg.what = 1;
        msg.setData(bundle);
        textHandle.sendMessageDelayed(msg, 1000);
        Log.i(TAG, "getLandmarkDebug: left_iris_size = "+left_iris_size +", right_iris_size = "+right_iris_size+", left_iris_depth = "+left_iris_depth+", right_iris_depth = "+right_iris_depth);
        return landmarksString;
    }

    private static LandmarkProto.NormalizedLandmarkList GetLeftIris(LandmarkProto.NormalizedLandmarkList lds) {
        LandmarkProto.NormalizedLandmarkList.Builder iris = LandmarkProto.NormalizedLandmarkList.newBuilder();
        iris.addLandmark(lds.getLandmark(0));
        iris.addLandmark(lds.getLandmark(2));
        iris.addLandmark(lds.getLandmark(4));
        iris.addLandmark(lds.getLandmark(3));
        iris.addLandmark(lds.getLandmark(1));
//        for(int i = 0; i <= 4; i++) {
//            Log.i(TAG, "getLandmarkDebug: Left = "+i+", x("+iris.getLandmark(i).getX()+"), y("+iris.getLandmark(i).getY()+")"+", z("+iris.getLandmark(i).getZ()+")");
//        }
        return iris.build();
    }

    private static LandmarkProto.NormalizedLandmarkList GetRightIris(LandmarkProto.NormalizedLandmarkList lds) {
        LandmarkProto.NormalizedLandmarkList.Builder iris = LandmarkProto.NormalizedLandmarkList.newBuilder();
        iris.addLandmark(lds.getLandmark(5));
        iris.addLandmark(lds.getLandmark(7));
        iris.addLandmark(lds.getLandmark(9));
        iris.addLandmark(lds.getLandmark(6));
        iris.addLandmark(lds.getLandmark(8));
//        for(int i = 0; i <= 4; i++) {
//            Log.i(TAG, "getLandmarkDebug: Right = "+i+", x("+iris.getLandmark(i).getX()+"), y("+iris.getLandmark(i).getY()+")"+", z("+iris.getLandmark(i).getZ()+")");
//        }
        return iris.build();
    }

    private static float GetDepth(double x0, double y0, double x1, double y1) {
        float ret = (float)(Math.sqrt((x0 - x1) * (x0 - x1) + (y0 - y1) * (y0 - y1)));
        return ret;
    }

    private static float GetLandmarkDepth(LandmarkProto.NormalizedLandmark ld0,
                                          LandmarkProto.NormalizedLandmark ld1,
                                          Size image_size) {
        float ret = GetDepth(ld0.getX() * image_size.getWidth(), ld0.getY() * image_size.getHeight(),
                        ld1.getX() * image_size.getWidth(), ld1.getY() * image_size.getHeight());
        return ret;
    }

    private static float CalculateIrisDiameter(LandmarkProto.NormalizedLandmarkList lds, Size image_size) {
        float dist_vert = GetLandmarkDepth(lds.getLandmark(1),
                                           lds.getLandmark(2), image_size);
        float dist_hori = GetLandmarkDepth(lds.getLandmark(3),
                                           lds.getLandmark(4), image_size);
        return (dist_hori + dist_vert) / 2.0f;
    }

//    private static float GetLandmarkDepth(float x0, float y0,
//                                          float x1, float y1,
//                                          Size image_size) {
//        float ret = GetDepth(x0 * image_size.getWidth(), y0 * image_size.getHeight(),
//                x1 * image_size.getWidth(), y1 * image_size.getHeight());
//        return ret;
//    }
//
//    private static float CalculateIrisDiameter(float x1, float y1,
//                                               float x2, float y2,
//                                               float x3, float y3,
//                                               float x4, float y4,
//                                               Size image_size) {
//        float dist_vert = GetLandmarkDepth(x1, y1, x2, y2, image_size);
//        float dist_hori = GetLandmarkDepth(x3, y3, x4, y4, image_size);
//        return (dist_hori + dist_vert) / 2.0f;
//    }

    private static float CalculateDepth(LandmarkProto.NormalizedLandmark center, float focal_length,
                                        float iris_size,
                                        float img_w, float img_h) {
        float origin_x = img_w / 2.f;
        float origin_y = img_h / 2.f;
        float y = GetDepth(origin_x, origin_y, center.getX() * img_w, center.getY() * img_h);
        float x = (float)Math.sqrt(focal_length * focal_length + y * y);
        float kIrisSizeInMM = 11.8f;
        float depth = kIrisSizeInMM * x / iris_size;
        return depth;
    }
}
