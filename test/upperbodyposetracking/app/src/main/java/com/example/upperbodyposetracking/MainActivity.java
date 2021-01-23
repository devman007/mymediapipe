package com.example.upperbodyposetracking;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import android.content.pm.ApplicationInfo;
import android.annotation.SuppressLint;
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
import com.google.mediapipe.formats.proto.LandmarkProto.NormalizedLandmark;
import com.google.mediapipe.formats.proto.LandmarkProto.NormalizedLandmarkList;
import com.google.mediapipe.framework.AndroidAssetUtil;
import com.google.mediapipe.framework.Packet;
import com.google.mediapipe.framework.PacketGetter;
import com.google.mediapipe.glutil.EglManager;
import com.google.protobuf.InvalidProtocolBufferException;

import java.util.List;

public class MainActivity extends AppCompatActivity {
    private static final String TAG = "MainActivity";

    //
    // 公共部分(6): (1)加载动态库
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
    //   公共部分(6): (2)basic modules.
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
    //  for upper body pose tracking.
    //
    private static final String BINARY_GRAPH_NAME = "upper_body_pose_tracking_gpu.binarypb";
    private static final String INPUT_VIDEO_STREAM_NAME = "input_video";
    private static final String OUTPUT_VIDEO_STREAM_NAME = "output_video";
    private static final String OUTPUT_LANDMARKS_STREAM_NAME = "pose_landmarks";

    //
    // camera
    //
    // Flips the camera-preview frames vertically before sending them into FrameProcessor to be
    // processed in a MediaPipe graph, and flips the processed frames back when they are displayed.
    // This is needed because OpenGL represents images assuming the image origin is at the bottom-left
    // corner, whereas MediaPipe in general assumes the image origin is at top-left.
    private static final boolean FLIP_FRAMES_VERTICALLY = true;
    private static final boolean USE_FRONT_CAMERA = true;

    private static TextView txBody_pose_capture;

    @SuppressLint("HandlerLeak")
    static Handler textHandle = new Handler() {
        @Override
        public void handleMessage(@NonNull Message msg) {
            super.handleMessage(msg);
            if (msg.what == 1) {
                //update ui
                Bundle bundle = msg.getData();
                String s = bundle.getString("msg");
                txBody_pose_capture.setText(s);
            }
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        txBody_pose_capture = (TextView)findViewById(R.id.body_pose_capture);
        txBody_pose_capture.setTextAlignment(View.TEXT_ALIGNMENT_CENTER);
        txBody_pose_capture.setTextColor(Color.GREEN);
        txBody_pose_capture.setTextSize(24);
        txBody_pose_capture.setText("");

        // 公共部分(6): (3)初始化 MediaPipe
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

        // upper body pose tracking.
        processor.addPacketCallback(
                OUTPUT_LANDMARKS_STREAM_NAME,
                (packet) -> {
                    Log.v(TAG, "Received pose landmarks packet.");
                    byte[] landmarksRaw = PacketGetter.getProtoBytes(packet);
                    try {
//                        NormalizedLandmarkList poseLandmarks =
//                                PacketGetter.getProto(packet, NormalizedLandmarkList.class);
                        NormalizedLandmarkList poseLandmarks = NormalizedLandmarkList.parseFrom(landmarksRaw);
                        Log.v( TAG, "[TS:"
                                        + packet.getTimestamp()
                                        + "] "
                                        + getLandmarksDebugString(poseLandmarks));
                    } catch (InvalidProtocolBufferException exception) {
                        Log.e(TAG, "Failed to get proto.", exception);
                    }
                });
    }

    @Override
    protected void onResume() {
        super.onResume();
        // 公共部分(6): (4)初始化摄像头
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
        // 公共部分(6): (5)关闭 Convert
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

    static double getAverage(double arr[]) {
        double ret = 0;
        double sum = 0;
        int num = arr.length;
        for (int i = 0; i < num; i++) {
            sum += arr[i];
        }
        ret = sum/num;
        return ret;
    }

    static double getCurveFit(double pX[], double pY[]) {
        double K = 0, A = 0, B = 0, C = 0, D = 0;
        int num = pX.length;
        for(int i = 0; i < num; i++){
            A += pX[i] * pY[i];
            B += pX[i];
            C += pY[i];
            D += pX[i] * pX[i];
        }
        K = (num*A-B*C)/(num*D-B*B);
        return K;
    }

    // // 公共部分(6): (6)解析关键点
    private static final int ARR_CNT = 10;
    private static int arr_cnt = 0;
    static double[] dLeftArr_wrist_elbow_w = new double[ARR_CNT];
    static double[] dLeftArr_wrist_elbow_h = new double[ARR_CNT];
    static double[] dLeftArr_elbow_shoulder_w = new double[ARR_CNT];
    static double[] dLeftArr_elbow_shoulder_h = new double[ARR_CNT];
    static double[] dRightArr_wrist_elbow_w = new double[ARR_CNT];
    static double[] dRightArr_wrist_elbow_h = new double[ARR_CNT];
    static double[] dRightArr_elbow_shoulder_w = new double[ARR_CNT];
    static double[] dRightArr_elbow_shoulder_h = new double[ARR_CNT];
    static double[] dLeftArr_wrist_nose_w = new double[ARR_CNT];
    static double[] dLeftArr_wrist_nose_h = new double[ARR_CNT];
    static double[] dLeftArr_elbow_nose_w = new double[ARR_CNT];
    static double[] dLeftArr_elbow_nose_h = new double[ARR_CNT];
    static double[] dRightArr_wrist_nose_w = new double[ARR_CNT];
    static double[] dRightArr_wrist_nose_h = new double[ARR_CNT];
    static double[] dRightArr_elbow_nose_w = new double[ARR_CNT];
    static double[] dRightArr_elbow_nose_h = new double[ARR_CNT];
    private static String getLandmarksDebugString(LandmarkProto.NormalizedLandmarkList landmarks) {
        int landmarkIndex = 0;
        String landmarksString = "";
        boolean isHighLefthand = false;
        boolean isHighRighthand = false;
        int cnt = landmarks.getLandmarkCount();
//        for (LandmarkProto.NormalizedLandmark landmark : landmarks.getLandmarkList()) {
//            landmarksString += "\tLandmark ["
//                            + cnt             + " : "
//                            + landmarkIndex   + "]: ("
//                            + landmark.getX() + ", "
//                            + landmark.getY() + ", "
//                            + landmark.getZ() + ")\n";
//            ++landmarkIndex;
//        }
        LandmarkProto.NormalizedLandmark nose = landmarks.getLandmark(0);
        LandmarkProto.NormalizedLandmark left_eye_inner = landmarks.getLandmark(1);
        LandmarkProto.NormalizedLandmark left_eye = landmarks.getLandmark(2);
        LandmarkProto.NormalizedLandmark left_eye_outer = landmarks.getLandmark(3);
        LandmarkProto.NormalizedLandmark right_eye_inner = landmarks.getLandmark(4);
        LandmarkProto.NormalizedLandmark right_eye = landmarks.getLandmark(5);
        LandmarkProto.NormalizedLandmark right_eye_outer = landmarks.getLandmark(6);
        LandmarkProto.NormalizedLandmark left_ear = landmarks.getLandmark(7);
        LandmarkProto.NormalizedLandmark right_ear = landmarks.getLandmark(8);
        LandmarkProto.NormalizedLandmark mouth_left = landmarks.getLandmark(9);
        LandmarkProto.NormalizedLandmark mouth_right = landmarks.getLandmark(10);
        LandmarkProto.NormalizedLandmark left_shoulder = landmarks.getLandmark(11);
        LandmarkProto.NormalizedLandmark right_shoulder = landmarks.getLandmark(12);
        LandmarkProto.NormalizedLandmark left_elbow = landmarks.getLandmark(13);
        LandmarkProto.NormalizedLandmark right_elbow = landmarks.getLandmark(14);
        LandmarkProto.NormalizedLandmark left_wrist = landmarks.getLandmark(15);
        LandmarkProto.NormalizedLandmark right_wrist = landmarks.getLandmark(16);
        LandmarkProto.NormalizedLandmark left_pinky = landmarks.getLandmark(17);
        LandmarkProto.NormalizedLandmark right_pinky = landmarks.getLandmark(18);
        LandmarkProto.NormalizedLandmark left_index = landmarks.getLandmark(19);
        LandmarkProto.NormalizedLandmark right_index = landmarks.getLandmark(20);
        LandmarkProto.NormalizedLandmark left_thumb = landmarks.getLandmark(21);
        LandmarkProto.NormalizedLandmark right_thumb = landmarks.getLandmark(22);
        LandmarkProto.NormalizedLandmark left_hip = landmarks.getLandmark(23);
        LandmarkProto.NormalizedLandmark right_hip = landmarks.getLandmark(24);

        //左手腕 - 左肘
        double left_wrist_elbow_w = left_wrist.getX() - left_elbow.getX();
        double left_wrist_elbow_h = left_wrist.getY() - left_elbow.getY();
        //左肘 - 左肩
        double left_elbow_shoulder_w = left_elbow.getX() - left_shoulder.getX();
        double left_elbow_shoulder_h = left_elbow.getY() - left_shoulder.getY();
        //右手腕 - 右肘
        double right_wrist_elbow_w = right_wrist.getX() - right_elbow.getX();
        double right_wrist_elbow_h = right_wrist.getY() - right_elbow.getY();
        //右肘 - 右肩
        double right_elbow_shoulder_w = right_elbow.getX() - right_shoulder.getX();
        double right_elbow_shoulder_h = right_elbow.getY() - right_shoulder.getY();
        //左手腕 - 鼻子
        double left_wrist_nose_w = left_wrist.getX() - nose.getX();
        double left_wrist_nose_h = left_wrist.getY() - nose.getY();
        //左肘 - 鼻子
        double left_elbow_nose_w = left_elbow.getX() - nose.getX();
        double left_elbow_nose_h = left_elbow.getY() - nose.getY();
        //右手腕 - 鼻子
        double right_wrist_nose_w = right_wrist.getX() - nose.getX();
        double right_wrist_nose_h = right_wrist.getY() - nose.getY();
        //右肘 - 鼻子
        double right_elbow_nose_w = right_elbow.getX() - nose.getX();
        double right_elbow_nose_h = right_elbow.getY() - nose.getY();

        Vector3D lshoulder = new Vector3D(left_shoulder.getX(), left_shoulder.getY(), left_shoulder.getZ());
        Vector3D lelbow = new Vector3D(left_elbow.getX(), left_elbow.getY(), left_elbow.getZ());
        Vector3D lwrist = new Vector3D(left_wrist.getX(), left_wrist.getY(), left_wrist.getZ());
        double lshoulder_elbow = CalculateDistance.Distance(lshoulder, lelbow);
        double lwrist_elbow = CalculateDistance.Distance(lwrist, lelbow);
        Log.i(TAG, "UpperBody: left shoulder_elbow = "+lshoulder_elbow+", wrist_elbow = "+lwrist_elbow);

        if(arr_cnt < ARR_CNT) {
            dLeftArr_wrist_elbow_w[arr_cnt] = left_wrist_elbow_w;
            dLeftArr_wrist_elbow_h[arr_cnt] = left_wrist_elbow_h;
            dLeftArr_elbow_shoulder_w[arr_cnt] = left_elbow_shoulder_w;
            dLeftArr_elbow_shoulder_h[arr_cnt] = left_elbow_shoulder_h;
            dRightArr_wrist_elbow_w[arr_cnt] = right_wrist_elbow_w;
            dRightArr_wrist_elbow_h[arr_cnt] = right_wrist_elbow_h;
            dRightArr_elbow_shoulder_w[arr_cnt] = right_elbow_shoulder_w;
            dRightArr_elbow_shoulder_h[arr_cnt] = right_elbow_shoulder_h;
            dLeftArr_wrist_nose_w[arr_cnt] = left_wrist_nose_w;
            dLeftArr_wrist_nose_h[arr_cnt] = left_wrist_nose_h;
            dLeftArr_elbow_nose_w[arr_cnt] = left_elbow_nose_w;
            dLeftArr_elbow_nose_h[arr_cnt] = left_elbow_nose_h;
            dRightArr_wrist_nose_w[arr_cnt] = right_wrist_nose_w;
            dRightArr_wrist_nose_h[arr_cnt] = right_wrist_nose_h;
            dRightArr_elbow_nose_w[arr_cnt] = right_elbow_nose_w;
            dRightArr_elbow_nose_h[arr_cnt] = right_elbow_nose_h;
        }
        arr_cnt++;
        double AvgLeft_wrist_elbow_w, AvgLeft_elbow_shoulder_w, AvgRight_wrist_elbow_w, AvgRight_elbow_shoulder_w;
        double AvgLeft_wrist_elbow_h, AvgLeft_elbow_shoulder_h, AvgRight_wrist_elbow_h, AvgRight_elbow_shoulder_h;
        double AvgLeft_wrist_nose_w, AvgLeft_wrist_nose_h, AvgLeft_elbow_nose_w, AvgLeft_elbow_nose_h;
        double AvgRight_wrist_nose_w, AvgRight_wrist_nose_h, AvgRight_elbow_nose_w, AvgRight_elbow_nose_h;
        if(arr_cnt >= ARR_CNT) {
            AvgLeft_wrist_elbow_w = getAverage(dLeftArr_wrist_elbow_w);
            AvgLeft_wrist_elbow_h = getAverage(dLeftArr_wrist_elbow_h);
            AvgLeft_elbow_shoulder_w = getAverage(dLeftArr_elbow_shoulder_w);
            AvgLeft_elbow_shoulder_h = getAverage(dLeftArr_elbow_shoulder_h);
            AvgRight_wrist_elbow_w = getAverage(dRightArr_wrist_elbow_w);
            AvgRight_wrist_elbow_h = getAverage(dRightArr_wrist_elbow_h);
            AvgRight_elbow_shoulder_w = getAverage(dRightArr_elbow_shoulder_w);
            AvgRight_elbow_shoulder_h = getAverage(dRightArr_elbow_shoulder_h);
            AvgLeft_wrist_nose_w = getAverage(dLeftArr_wrist_nose_w);
            AvgLeft_wrist_nose_h = getAverage(dLeftArr_wrist_nose_h);
            AvgLeft_elbow_nose_w = getAverage(dLeftArr_elbow_nose_w);
            AvgLeft_elbow_nose_h = getAverage(dLeftArr_elbow_nose_h);
            AvgRight_wrist_nose_w = getAverage(dRightArr_wrist_nose_w);
            AvgRight_wrist_nose_h = getAverage(dRightArr_wrist_nose_h);
            AvgRight_elbow_nose_w = getAverage(dRightArr_elbow_nose_w);
            AvgRight_elbow_nose_h = getAverage(dRightArr_elbow_nose_h);

//            Log.i(TAG, "UpperBody: left_wrist_nose_w = "+AvgLeft_wrist_nose_w+", left_elbow_nose_w = "+AvgLeft_elbow_nose_w);
//            Log.i(TAG, "UpperBody: left_wrist_nose_h = "+AvgLeft_wrist_nose_h+", left_elbow_nose_h = "+AvgLeft_elbow_nose_h);
//            Log.i(TAG, "UpperBody: right_wrist_nose_w = "+AvgRight_wrist_nose_w+", right_elbow_nose_w = "+AvgRight_elbow_nose_w);
//            Log.i(TAG, "UpperBody: right_wrist_nose_h = "+AvgRight_wrist_nose_h+", right_elbow_nose_h = "+AvgRight_elbow_nose_h);
//            Log.i(TAG, "UpperBody: Left_wrist_elbow_w = "+AvgLeft_wrist_elbow_w+", Left_elbow_shoulder_w = "+AvgLeft_elbow_shoulder_w);
            if((AvgLeft_wrist_nose_h < 0) && (AvgLeft_elbow_nose_h < 0))   {
                isHighLefthand = true;
            }
            //(Avgleft_wrist_elbow_h > 0) && (AvgLeft_elbow_shoulder_h > 0) &&
            if((AvgRight_wrist_nose_h < 0) && (AvgRight_elbow_nose_h < 0))   {
                isHighRighthand = true;
            }
            //(AvgRight_wrist_elbow_h > 0) && (AvgRight_elbow_shoulder_h > 0) &&

            if(isHighLefthand && !isHighRighthand) {
                landmarksString = "举左手";
            } else if(!isHighLefthand && isHighRighthand) {
                landmarksString = "举右手";
            } else if(isHighLefthand && isHighRighthand) {
                landmarksString = "举双手";
            } else {
                landmarksString = "";
            }
            arr_cnt = 0;

            Bundle bundle = new Bundle();
            bundle.putString("msg", landmarksString);
            Message msg = Message.obtain();
            msg.what = 1;
            msg.setData(bundle);
            textHandle.sendMessageDelayed(msg, 1000);
        }
        return landmarksString;
    }
}
